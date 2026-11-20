extends Node

## B7.3 evidence: uniform attack spam for 10 runs. The player stands still and
## requests a light attack whenever the action phase is NONE; no dodge, no
## movement, no waiting for a punish window.
## Headless spam run:
## <GODOT> --headless --path . res://scenes/phase_b/run_b7_spam.tscn --fixed-fps 60
## Passive control (never attacks -> must lose all 10):
## ... res://scenes/phase_b/run_b7_spam.tscn --fixed-fps 60 -- passive

const EVIDENCE_DIR := "res://docs/phase-b/evidence/b7/"
const RUNS := 10
const MAX_TICKS_PER_RUN := 1200

var _combat: PlayerCombat
var _grunt: Grunt
var _player: PlayerController
var _director: CombatDirector
var _manager: EncounterManager
var _passive := false
var _results: Array[String] = []
var _ticks: Array[int] = []


func _ready() -> void:
	_passive = OS.get_cmdline_user_args().has("passive")
	var playground := get_node("../PhaseAPlayground")
	_combat = playground.get_node("Player/PlayerCombat")
	_grunt = playground.get_node("Grunt")
	_player = playground.get_node("Player")
	_director = playground.get_node("CombatDirector")
	_manager = playground.get_node("EncounterManager")
	_manager.reset_delay_frames = 100000
	_combat.aim_override_enabled = true
	_run()


func _run() -> void:
	for run in RUNS:
		var ticks := 0
		while _grunt.hp() > 0 and not _combat.is_dead() and ticks < MAX_TICKS_PER_RUN:
			if not _passive:
				_combat.aim_override_point = _grunt.global_position
				if _combat.attack_phase() == AttackState.Phase.NONE:
					_combat.debug_request_attack()
			await get_tree().physics_frame
			ticks += 1
		if _grunt.hp() <= 0:
			_results.append("W")
		elif _combat.is_dead():
			_results.append("L")
		else:
			_results.append("?")
		_ticks.append(ticks)
		await get_tree().physics_frame
		if run < RUNS - 1:
			_manager.reset_encounter()
	_director.log.close()
	var wins := _results.count("W")
	var losses := _results.count("L")
	var report := "runs=%d wins=%d losses=%d ticks=%s" % [RUNS, wins, losses, str(_ticks)]
	print(report)
	if _passive:
		if losses == RUNS and wins == 0:
			print("PASS b7_passive: 10 losses, win detection cannot be trivially green")
			get_tree().quit(0)
		else:
			print("FAIL b7_passive")
			get_tree().quit(1)
		return
	_write_evidence(report)
	if wins == RUNS:
		print("B7.3 FAIL: attack spam won all %d runs" % RUNS)
	else:
		print("B7.3 PASS: attack spam lost at least one run")
	get_tree().quit(0)


func _write_evidence(report: String) -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var source := FileAccess.open(_director.log_path, FileAccess.READ)
	if source != null:
		var target := FileAccess.open(EVIDENCE_DIR + "spam_combat_log.csv", FileAccess.WRITE)
		if target != null:
			target.store_string(source.get_as_text())
			target.close()
		source.close()
	var summary := FileAccess.open(EVIDENCE_DIR + "spam_summary.txt", FileAccess.WRITE)
	if summary != null:
		summary.store_string(report + "\n")
		summary.close()
