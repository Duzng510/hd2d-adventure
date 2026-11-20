extends Node

## B3 evidence: 10 independent trials.
## B3.1 alert latency from entering detect range <= 5 ticks (log alert frame).
## B3.2 grunt only attacks inside attack range (telegraph + damage distance).
## B3.3 chase does not penetrate the wall or the player (240-tick sample).
## Headless run:
## <GODOT> --headless --path . res://scenes/phase_b/run_b3_trials.tscn --fixed-fps 60
## Negative control (attack range inflated) -> exit 1:
## ... res://scenes/phase_b/run_b3_trials.tscn --fixed-fps 60 -- negative

const EVIDENCE_DIR := "res://docs/phase-b/evidence/b3/"
const TRIALS := 10
const OUTSIDE_X := 10.0
const INSIDE_X := 7.0
const GRUNT_X := 3.0
const MAX_ALERT_TICKS := 10
const MAX_CHASE_TICKS := 400
const MAX_DAMAGE_TICKS := 60
const MAX_ALERT_LATENCY := 5
const RANGE_MARGIN := 0.05
const WALL_MIN_CLEARANCE := 0.3
const MIN_PLAYER_DISTANCE := 0.7
const WALL_CHASE_TICKS := 240
const WALL_MIN_X := 1.0
const WALL_MAX_X := 7.0
const WALL_MIN_Z := -3.25
const WALL_MAX_Z := -2.75

var _combat: PlayerCombat
var _grunt: Grunt
var _player: PlayerController
var _director: CombatDirector
var _negative := false
var _attack_range := 1.3


func _ready() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var playground := get_node("../PhaseAPlayground")
	_combat = playground.get_node("Player/PlayerCombat")
	_grunt = playground.get_node("Grunt")
	_player = playground.get_node("Player")
	_director = playground.get_node("CombatDirector")
	playground.get_node("EncounterManager").reset_delay_frames = 100000
	_attack_range = _grunt.tuning.grunt_attack_range
	_run()


func _run() -> void:
	if _negative:
		_grunt._ai.attack_range = 8.0
	var problems: Array[String] = []
	var entries: Array[int] = []
	var telegraph_distances: Array[float] = []
	for trial in TRIALS:
		_reset_actors()
		_player.global_position = Vector3(OUTSIDE_X, 0.0, 0.0)
		_grunt.global_position = Vector3(GRUNT_X, 0.0, 0.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		if _grunt.ai_state() != GruntAI.State.IDLE:
			problems.append("t%d alert while outside detect" % (trial + 1))
		_player.global_position = Vector3(INSIDE_X, 0.0, 0.0)
		entries.append(_director.sim_frame + 1)
		var alert_ok := false
		for _i in MAX_ALERT_TICKS:
			await get_tree().physics_frame
			if _grunt.ai_state() != GruntAI.State.IDLE:
				alert_ok = true
				break
		if not alert_ok:
			problems.append("t%d no alert" % (trial + 1))
		var tele_distance := -1.0
		var hp_before := _combat.hp()
		for _i in MAX_CHASE_TICKS:
			if _grunt.ai_state() == GruntAI.State.TELEGRAPH:
				tele_distance = _flat_distance()
				break
			if _combat.hp() < hp_before:
				problems.append("t%d damage before telegraph" % (trial + 1))
			await get_tree().physics_frame
		if tele_distance < 0.0:
			problems.append("t%d no telegraph" % (trial + 1))
		elif tele_distance > _attack_range + RANGE_MARGIN:
			problems.append("t%d telegraph at %.2f" % [trial + 1, tele_distance])
		telegraph_distances.append(tele_distance)
		hp_before = _combat.hp()
		var damaged := false
		for _i in MAX_DAMAGE_TICKS:
			await get_tree().physics_frame
			if _combat.hp() < hp_before:
				damaged = true
				break
		if not damaged:
			problems.append("t%d no damage inside range" % (trial + 1))
		elif _flat_distance() > _attack_range + RANGE_MARGIN:
			problems.append("t%d damage at %.2f" % [trial + 1, _flat_distance()])
	_director.log.close()

	var alerts := _events(&"alert")
	var telegraphs := _events(&"telegraph_start")
	if alerts.size() < TRIALS:
		problems.append("alerts=%d<%d" % [alerts.size(), TRIALS])
	if telegraphs.size() < TRIALS:
		problems.append("telegraphs=%d<%d" % [telegraphs.size(), TRIALS])
	var latencies: Array[int] = []
	for i in mini(alerts.size(), entries.size()):
		latencies.append(alerts[i] - entries[i])
		if alerts[i] - entries[i] > MAX_ALERT_LATENCY:
			problems.append("t%d alert latency %d" % [i + 1, alerts[i] - entries[i]])

	var wall := await _run_wall_chase()
	var min_clearance: float = wall["clearance"]
	var min_player: float = wall["player"]
	if min_clearance < WALL_MIN_CLEARANCE:
		problems.append("wall clearance %.3f" % min_clearance)
	if min_player < MIN_PLAYER_DISTANCE:
		problems.append("player distance %.3f" % min_player)

	var report := "trials=%d alerts=%d telegraphs=%d latencies=%s tele_dist=%s wall_min=%.3f player_min=%.3f problems=%s" % [
		TRIALS, alerts.size(), telegraphs.size(), str(latencies),
		str(telegraph_distances), min_clearance, min_player, str(problems),
	]
	print(report)
	if problems.is_empty():
		if not _negative:
			_write_evidence(report)
		print("PASS b3_trials: %d trials" % TRIALS)
		get_tree().quit(0)
	else:
		print("FAIL b3_trials")
		get_tree().quit(1)


func _write_evidence(report: String) -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var source := FileAccess.open(_director.log_path, FileAccess.READ)
	if source != null:
		var target := FileAccess.open(EVIDENCE_DIR + "combat_log_trials.csv", FileAccess.WRITE)
		if target != null:
			target.store_string(source.get_as_text())
			target.close()
		source.close()
	var summary_file := FileAccess.open(EVIDENCE_DIR + "summary.txt", FileAccess.WRITE)
	if summary_file != null:
		summary_file.store_string(report + "\nPASS b3_trials: %d trials\n" % TRIALS)
		summary_file.close()


func _reset_actors() -> void:
	_combat.reset()
	_grunt.reset()
	_director.reset()


func _flat_distance() -> float:
	var a := _player.global_position
	var b := _grunt.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


func _events(event_name: StringName) -> Array[int]:
	var frames: Array[int] = []
	var text := FileAccess.get_file_as_string(_director.log_path)
	for raw_line in text.split("\n"):
		var cols := raw_line.split(",")
		if cols.size() != 6 or cols[1] != "grunt":
			continue
		if StringName(cols[2]) == event_name:
			frames.append(int(cols[0]))
	return frames


func _run_wall_chase() -> Dictionary:
	_reset_actors()
	_grunt.global_position = Vector3(5.0, 0.0, 0.0)
	_player.global_position = Vector3(5.0, 0.0, -5.5)
	var min_clearance := INF
	var min_player := INF
	for _i in WALL_CHASE_TICKS:
		await get_tree().physics_frame
		min_clearance = minf(min_clearance, _wall_clearance(_grunt.global_position))
		min_player = minf(min_player, _flat_distance())
	return {"clearance": min_clearance, "player": min_player}


func _wall_clearance(p: Vector3) -> float:
	var cx := clampf(p.x, WALL_MIN_X, WALL_MAX_X)
	var cz := clampf(p.z, WALL_MIN_Z, WALL_MAX_Z)
	return Vector2(p.x - cx, p.z - cz).length()
