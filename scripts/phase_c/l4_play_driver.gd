extends Node

## T-025 play mount: puts the L4 probe on the real arena without editing
## grove_arena.tscn, so the shipped scene and the measurement rig stay separate.
##
##   playtest : <GODOT> --path . res://scenes/phase_c/play_arena.tscn
##   selftest : <GODOT> --headless --path . res://scenes/phase_c/play_arena.tscn
##              --fixed-fps 60 -- auto      (walking bot, must exit 0)
##   death path: ... --fixed-fps 60 -- auto passive  (bot never swings, must die)
##   negative : ... -- auto negative        (probe blind, must exit 1)

const ARENA_PATH := NodePath("../GroveArena")
const PROBE_PATH := "user://l4_probe.csv"
const TELEGRAPH_FLOOR := 18
const KNOWN_SOURCES := ["grunt", "swarm", "ranged", "boss", "projectile"]
const ENGAGE_DISTANCE := 1.2
const TURN_DEADZONE := 0.2

@export var auto_ticks := 3600

var _probe: L4Probe
var _player: PlayerController
var _combat: PlayerCombat
var _encounter: WaveEncounter
var _director: CombatDirector
var _auto := false
var _passive := false
var _negative := false
var _ticks := 0
var _observed_hits := 0
var _leads: Array[int] = []
var _checks := 0
var _failures := 0
var _done := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_auto = args.has("auto")
	_negative = args.has("negative")
	_passive = args.has("passive")
	var arena := get_node(ARENA_PATH)
	_player = arena.get_node("Player") as PlayerController
	_combat = arena.get_node("Player/PlayerCombat") as PlayerCombat
	_encounter = arena.get_node("WaveEncounter") as WaveEncounter
	_director = arena.get_node("CombatDirector") as CombatDirector
	_probe = L4Probe.new()
	_probe.name = &"L4Probe"
	_probe.tap_events = not _negative
	_probe.capture_death_shots = DisplayServer.get_name() != "headless"
	arena.add_child(_probe)
	_director.event_logged.connect(_observe)
	# T-030 bot runs must never park on the chooser: the wave-clear pick is taken
	# on the spot. Passive/normal play keeps UI mode (auto_pick stays false).
	var choice := get_node_or_null("../BuffChoice") as BuffChoice
	if choice != null and _auto:
		choice.auto_pick = true


func _physics_process(_delta: float) -> void:
	if not _auto or _done:
		return
	_ticks += 1
	var state := _encounter.kernel.state
	if state == WaveKernel.State.FIGHTING or state == WaveKernel.State.PAUSED:
		if _encounter.alive_count() > 0:
			# The bot walks through the real InputMap and only swings inside reach, so
			# the probe observes genuine positions, movement and contact. A statue that
			# swings at 9 m of empty floor produces hits=0 and proves nothing.
			var target := _encounter.nearest_alive_position()
			_walk_towards(target)
			_combat.aim_override_enabled = true
			_combat.aim_override_point = target
			var within := _player.global_position.distance_to(target) <= ENGAGE_DISTANCE
			if within and not _passive and _combat.attack_phase() == AttackState.Phase.NONE:
				_combat.debug_request_attack()
	if _ticks >= auto_ticks or state == WaveKernel.State.WON or state == WaveKernel.State.LOST:
		_done = true
		_verify()
		_release_inputs()


func _walk_towards(target: Vector3) -> void:
	var delta := target - _player.global_position
	_axis(&"move_left", &"move_right", delta.x)
	_axis(&"move_up", &"move_down", delta.z)


func _axis(negative: StringName, positive: StringName, value: float) -> void:
	_hold(negative, value < -TURN_DEADZONE)
	_hold(positive, value > TURN_DEADZONE)


func _hold(action: StringName, pressed: bool) -> void:
	if Input.is_action_pressed(action) == pressed:
		return
	if pressed:
		Input.action_press(str(action))
	else:
		Input.action_release(str(action))


func _release_inputs() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(str(action))


## Independent observer: the ground truth the probe file is scored against,
## computed from the director records rather than from the probe's own math.
func _observe(entity: StringName, event_name: StringName, attack_id: int, target_id: int, _value: int) -> void:
	if event_name != &"damage" or target_id != 2:
		return
	_observed_hits += 1
	var record: StringName = &"ranged" if entity == &"projectile" else entity
	var start := _director.attack_event_frame(record, attack_id, &"telegraph_start")
	if start < 0:
		_leads.append(-1)
		return
	var frozen := int(_director.attack_event_frozen(record, attack_id, &"telegraph_start"))
	_leads.append((_director.sim_frame - _director.frozen_ticks) - (start - frozen))


func _verify() -> void:
	var rows := _read_probe()
	var hits := _rows_of(rows, "h")
	var samples := _rows_of(rows, "s")
	var deaths := _rows_of(rows, "d")
	_check(not rows.is_empty() and samples.size() >= 20 and hits.size() > 0,
		"P25.1 probe wrote a banner, %d samples and %d hit rows" % [samples.size(), hits.size()])
	_check(hits.size() == _observed_hits and _observed_hits > 0,
		"P25.2 probe hit rows %d == observed player damage %d" % [hits.size(), _observed_hits])
	var short := 0
	var unreadable := 0
	for index in hits.size():
		var lead := int(str(hits[index]["dreact"]))
		if lead < 0:
			unreadable += 1
		elif lead < TELEGRAPH_FLOOR:
			short += 1
	_check(short == 0 and unreadable == 0 and hits.size() > 0,
		"P25.3 every hit had a >= %d frame telegraph (short=%d unreadable=%d)" % [TELEGRAPH_FLOOR, short, unreadable])
	var bad_source := 0
	for row in deaths:
		if not KNOWN_SOURCES.has(str(row["src"])):
			bad_source += 1
	_check(bad_source == 0, "P25.4 %d death row(s) each naming a known killer" % deaths.size())
	_check(not _passive or deaths.size() >= 1,
		"P25.6 death path observed (passive=%s, deaths=%d)" % [_passive, deaths.size()])
	var framed := 0
	for row in hits + samples + deaths:
		if int(str(row.get("frame", "-1"))) > 0:
			framed += 1
	_check(framed == hits.size() + samples.size() + deaths.size(),
		"P25.8 every data row carries a sim_frame for joining (%d/%d)" % [framed, hits.size() + samples.size() + deaths.size()])
	var shots := _rows_of(rows, "p")
	_check(not _probe.capture_death_shots or shots.size() == deaths.size(),
		"P25.7 one PNG per death (shots=%d deaths=%d)" % [shots.size(), deaths.size()])
	_check(_leads.count(-1) == unreadable and _leads.size() == _observed_hits,
		"P25.5 probe and observer agree on unreadable telegraphs (%d vs %d)" % [unreadable, _leads.count(-1)])
	var verdict := "PASS" if _failures == 0 else "FAIL"
	print("checks=%d failures=%d ticks=%d hits=%d deaths=%d" % [_checks, _failures, _ticks, _observed_hits, deaths.size()])
	print("%s t025_probe: L4 capture rig self-check" % verdict)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)


func _read_probe() -> Array:
	var file := FileAccess.open(PROBE_PATH, FileAccess.READ)
	if file == null:
		return []
	var lines: Array = []
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges() != "":
			lines.append(line)
	if lines.size() < 2:
		return []
	var header: PackedStringArray = lines[0].split(",")
	var rows: Array = []
	for index in range(1, lines.size()):
		var cells: PackedStringArray = lines[index].split(",")
		var row := {}
		for column in header.size():
			row[header[column]] = cells[column] if column < cells.size() else ""
		rows.append(row)
	return rows


func _rows_of(rows: Array, kind: String) -> Array:
	var found: Array = []
	for row in rows:
		if str(row.get("kind", "")) == kind:
			found.append(row)
	return found
