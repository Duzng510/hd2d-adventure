extends SceneTree

## Boss tuning envelope (gate doc Phase C §9). Run:
##   <GODOT> --headless --path . -s res://tests/test_boss_tuning.gd
## Negative (sweep telegraph below GDD floor) must exit 1:
##   <GODOT> --headless --path . -s res://tests/test_boss_tuning.gd -- negative

const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	var loaded := load(TUNING_PATH) as CombatTuning
	if loaded == null:
		print("FAIL test_boss_tuning: cannot load tuning")
		quit(1)
		return
	var tuning := loaded.duplicate() as CombatTuning
	if negative:
		tuning.boss_sweep_telegraph_frames = 12
	_check(tuning.boss_max_hp == 300, "boss hp 300")
	_check(tuning.boss_phase_hp_percent == 50, "phase threshold 50 percent")
	_check(tuning.boss_phase_switch_frames == 45, "phase switch telegraph 45")
	_check(tuning.boss_smash_telegraph_frames == 30, "smash telegraph 30")
	_check(tuning.boss_smash_active_frames == 6, "smash active 6")
	_check(tuning.boss_smash_recovery_frames == 30, "smash recovery 30")
	_check(tuning.boss_smash_phase2_recovery_frames == 20, "smash phase 2 recovery 20")
	_check(tuning.boss_smash_damage == 20, "smash damage 20")
	_check(absf(tuning.boss_smash_radius - 2.2) < 0.0001, "smash radius 2.2")
	_check(tuning.boss_lunge_telegraph_frames == 24, "lunge telegraph 24")
	_check(tuning.boss_lunge_active_frames == 8, "lunge active 8")
	_check(tuning.boss_lunge_recovery_frames == 24, "lunge recovery 24")
	_check(tuning.boss_lunge_phase2_recovery_frames == 16, "lunge phase 2 recovery 16")
	_check(tuning.boss_lunge_damage == 12, "lunge damage 12")
	_check(absf(tuning.boss_lunge_range - 5.0) < 0.0001, "lunge range 5.0")
	_check(tuning.boss_sweep_telegraph_frames == 20, "sweep telegraph 20")
	_check(tuning.boss_sweep_active_frames == 6, "sweep active 6")
	_check(tuning.boss_sweep_recovery_frames == 24, "sweep recovery 24")
	_check(tuning.boss_sweep_damage == 10, "sweep damage 10")
	_check(absf(tuning.boss_sweep_radius - 2.6) < 0.0001, "sweep radius 2.6")
	_check(tuning.boss_smash_telegraph_frames >= 18, "smash telegraph >= 18 (GDD floor)")
	_check(tuning.boss_lunge_telegraph_frames >= 18, "lunge telegraph >= 18 (GDD floor)")
	_check(tuning.boss_sweep_telegraph_frames >= 18, "sweep telegraph >= 18 (GDD floor)")
	_check(tuning.boss_phase_switch_frames >= 18, "switch telegraph >= 18 (GDD floor)")
	_check(tuning.boss_smash_phase2_recovery_frames < tuning.boss_smash_recovery_frames, "phase 2 smash faster via recovery")
	_check(tuning.boss_lunge_phase2_recovery_frames < tuning.boss_lunge_recovery_frames, "phase 2 lunge faster via recovery")
	_check(absf(tuning.boss_chase_speed - 2.0) < 0.0001, "boss chase speed 2.0 (hypothesis)")
	_check(tuning.boss_detect_range > tuning.boss_lunge_range, "detect beyond lunge range")
	_check(tuning.grunt_max_hp == 30 and tuning.swarm_max_hp == 20, "grunt/swarm hp regression")
	_check(tuning.ranged_max_hp == 30 and tuning.ranged_damage == 8, "ranged regression hp/damage")
	var boss_node := Boss.new()
	boss_node.tuning = tuning
	_check(boss_node._max_hp() == 300, "boss node reads boss hp")
	_check(absf(boss_node._detect_range() - 12.0) < 0.0001, "boss node detect range 12")
	_check(boss_node._log_entity() == &"boss", "boss node logs entity boss")
	_check(boss_node._create_ai() is BossAI, "boss node builds BossAI")
	boss_node.free()
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("FAIL: %s" % failure)
	var ok := _failures.is_empty()
	print("PASS test_boss_tuning" if ok else "FAIL test_boss_tuning")
	quit(0 if ok else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
