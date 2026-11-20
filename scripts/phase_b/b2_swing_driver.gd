extends Node

## B2.2 evidence: >=10 in-scene light swings, each attack_id exactly one
## hit+damage pair on the Grunt (target 1), damage value = light_damage.
## Headless run:
## <GODOT> --headless --path . res://scenes/phase_b/run_b2_swings.tscn --fixed-fps 60
## Negative control (registry enforce disabled) -> duplicate damage, exit 1:
## ... res://scenes/phase_b/run_b2_swings.tscn --fixed-fps 60 -- negative

const EVIDENCE_DIR := "res://docs/phase-b/evidence/b2/"
const SWINGS := 12
const MAX_WAIT_TICKS := 90
const EXPECTED_TARGET := 1
const EXPECTED_DAMAGE := 10

var _combat: PlayerCombat
var _grunt: Grunt
var _player: PlayerController
var _director: CombatDirector
var _negative := false


func _ready() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var playground := get_node("../PhaseAPlayground")
	_combat = playground.get_node("Player/PlayerCombat")
	_grunt = playground.get_node("Grunt")
	_player = playground.get_node("Player")
	_director = playground.get_node("CombatDirector")
	playground.get_node("EncounterManager").reset_delay_frames = 100000
	_run()


func _run() -> void:
	if _negative:
		_combat._registry.enforce = false
	_combat.aim_override_enabled = true
	for _i in SWINGS:
		_prepare_swing()
		_combat.debug_request_attack()
		await _wait_swing()
	_director.log.close()
	var result := _verify()
	print(result["summary"])
	if result["ok"]:
		if not _negative:
			_write_evidence(String(result["summary"]))
		print("PASS b2_swings: %d swings, one hit+damage each" % SWINGS)
		get_tree().quit(0)
	else:
		print("FAIL b2_swings")
		get_tree().quit(1)


func _write_evidence(summary: String) -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var source := FileAccess.open(_director.log_path, FileAccess.READ)
	if source != null:
		var target := FileAccess.open(EVIDENCE_DIR + "combat_log.csv", FileAccess.WRITE)
		if target != null:
			target.store_string(source.get_as_text())
			target.close()
		source.close()
	var summary_file := FileAccess.open(EVIDENCE_DIR + "summary.txt", FileAccess.WRITE)
	if summary_file != null:
		summary_file.store_string(summary + "\nPASS b2_swings: %d swings\n" % SWINGS)
		summary_file.close()


func _wait_swing() -> void:
	var started := false
	var guard := 0
	while guard < MAX_WAIT_TICKS:
		await get_tree().physics_frame
		guard += 1
		if _combat.attack_phase() != AttackState.Phase.NONE:
			started = true
		elif started:
			return


func _prepare_swing() -> void:
	_combat.reset()
	_grunt.reset()
	_player.global_position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_grunt.global_position = Vector3(1.0, 0.0, 0.0)
	_combat.aim_override_point = _grunt.global_position
	_director.reset()


func _verify() -> Dictionary:
	var text := FileAccess.get_file_as_string(_director.log_path)
	var swings: Array[int] = []
	var hits: Dictionary = {}
	var damages: Dictionary = {}
	var hit_targets: Dictionary = {}
	var damage_targets: Dictionary = {}
	var damage_values: Dictionary = {}
	for raw_line in text.split("\n"):
		var cols := raw_line.split(",")
		if cols.size() != 6 or cols[1] != "player":
			continue
		var attack_id := int(cols[3])
		match cols[2]:
			"action_start":
				swings.append(attack_id)
			"hit":
				hits[attack_id] = int(hits.get(attack_id, 0)) + 1
				hit_targets[attack_id] = int(cols[4])
			"damage":
				damages[attack_id] = int(damages.get(attack_id, 0)) + 1
				damage_targets[attack_id] = int(cols[4])
				damage_values[attack_id] = int(cols[5])

	var problems: Array[String] = []
	if swings.size() < 10:
		problems.append("swings=%d<10" % swings.size())
	var unique: Dictionary = {}
	for attack_id in swings:
		if unique.has(attack_id):
			problems.append("attack %d repeated in action_start" % attack_id)
		unique[attack_id] = true
		if int(hits.get(attack_id, 0)) != 1:
			problems.append("attack %d hits=%d" % [attack_id, int(hits.get(attack_id, 0))])
		if int(damages.get(attack_id, 0)) != 1:
			problems.append("attack %d damages=%d" % [attack_id, int(damages.get(attack_id, 0))])
		if int(hit_targets.get(attack_id, -1)) != EXPECTED_TARGET:
			problems.append("attack %d hit target=%d" % [attack_id, int(hit_targets.get(attack_id, -1))])
		if int(damage_targets.get(attack_id, -1)) != EXPECTED_TARGET:
			problems.append("attack %d damage target=%d" % [attack_id, int(damage_targets.get(attack_id, -1))])
		if int(damage_values.get(attack_id, -1)) != EXPECTED_DAMAGE:
			problems.append("attack %d damage=%d" % [attack_id, int(damage_values.get(attack_id, -1))])
	return {
		"ok": problems.is_empty(),
		"summary": "swings=%d unique=%d problems=%s" % [swings.size(), unique.size(), str(problems)],
	}
