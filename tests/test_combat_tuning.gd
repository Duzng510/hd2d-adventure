extends SceneTree

# Envelope checks mirror the GDD 6.4 HYPOTHESIS ranges (prototype guard, not a design rule).
const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var tuning: CombatTuning = load(TUNING_PATH)
	if tuning == null:
		print("FAIL: cannot load ", TUNING_PATH)
		quit(1)
		return
	_check(tuning.input_buffer_frames >= 5 and tuning.input_buffer_frames <= 8, "input buffer 5-8")
	_check(tuning.light_startup_frames >= 3 and tuning.light_startup_frames <= 6, "startup 3-6")
	_check(tuning.light_active_frames >= 2 and tuning.light_active_frames <= 4, "active 2-4")
	_check(tuning.light_recovery_frames >= 8 and tuning.light_recovery_frames <= 14, "recovery 8-14")
	_check(tuning.combo_window_frames >= 8 and tuning.combo_window_frames <= 14, "combo window 8-14")
	_check(tuning.light_combo_hits >= 2 and tuning.light_combo_hits <= 4, "combo hits 2-4")
	_check(tuning.dodge_iframe_frames >= 8 and tuning.dodge_iframe_frames <= 14, "dodge iframe 8-14")
	_check(tuning.dodge_total_frames >= 18 and tuning.dodge_total_frames <= 28, "dodge total 18-28")
	_check(tuning.dodge_iframe_frames < tuning.dodge_total_frames, "iframe shorter than dodge")
	_check(tuning.hitstop_frames >= 2 and tuning.hitstop_frames <= 5, "hitstop 2-5")
	_check(tuning.grunt_telegraph_frames >= 18, "telegraph >= 18")
	_check(tuning.player_max_hp > 0 and tuning.grunt_max_hp > 0, "hp positive")
	_check(tuning.light_damage > 0 and tuning.grunt_damage > 0, "damage positive")
	_check(tuning.light_reach > 0.0, "light reach positive")
	_check(tuning.grunt_detect_range > tuning.grunt_attack_range, "detect > attack range")
	_check(tuning.dodge_speed > 0.0 and tuning.grunt_approach_speed > 0.0, "speeds positive")
	if _failures == 0:
		print("PASS test_combat_tuning: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_combat_tuning: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
