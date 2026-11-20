extends SceneTree

const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var tuning: CombatTuning = load(TUNING_PATH)
	if tuning == null:
		print("FAIL: cannot load ", TUNING_PATH)
		quit(1)
		return
	# Negative control: an AI with a 1-frame telegraph must fail the
	# duration/threshold checks below (proving the harness detects it).
	var telegraph := 1 if _negative else tuning.grunt_telegraph_frames
	_test_ai(tuning, telegraph)
	if _failures == 0:
		print("PASS test_grunt_ai: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_grunt_ai: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _test_ai(tuning: CombatTuning, telegraph_frames: int) -> void:
	var ai := GruntAI.new(
		tuning.grunt_detect_range,
		tuning.grunt_attack_range,
		telegraph_frames,
		tuning.grunt_active_frames,
		tuning.grunt_recovery_frames
	)
	var self_pos := Vector3.ZERO
	ai.tick(Vector3(8, 0, 0), self_pos)
	_check(ai.state == GruntAI.State.IDLE, "idle outside detect range")
	ai.tick(Vector3(5, 0, 0), self_pos)
	_check(ai.state == GruntAI.State.CHASE, "detect -> chase")
	_check(ai.alert_pending, "alert event raised")
	ai.alert_pending = false
	ai.tick(Vector3(2, 0, 0), self_pos)
	_check(ai.state == GruntAI.State.CHASE, "no telegraph outside attack range")
	ai.tick(Vector3(tuning.grunt_attack_range * 0.8, 0, 0), self_pos)
	_check(ai.state == GruntAI.State.TELEGRAPH, "attack range -> telegraph")
	_check(ai.attack_dir.is_equal_approx(Vector3.RIGHT), "attack direction snapshot")
	var locked_dir := ai.attack_dir
	var telegraph_ticks := 0
	while ai.state == GruntAI.State.TELEGRAPH:
		ai.tick(Vector3(0, 0, 5), self_pos)
		telegraph_ticks += 1
	_check(ai.state == GruntAI.State.ACTIVE, "telegraph -> active without cancel")
	_check(ai.attack_dir.is_equal_approx(locked_dir), "direction stays locked")
	_check(telegraph_ticks == tuning.grunt_telegraph_frames, "telegraph lasts tuning frames")
	_check(telegraph_ticks >= 18, "telegraph meets GDD 18f threshold")
	var active_ticks := 0
	while ai.state == GruntAI.State.ACTIVE:
		ai.tick(Vector3(0, 0, 5), self_pos)
		active_ticks += 1
	_check(ai.state == GruntAI.State.RECOVERY, "active -> recovery")
	_check(active_ticks == tuning.grunt_active_frames, "active lasts tuning frames")
	var recovery_ticks := 0
	while ai.state == GruntAI.State.RECOVERY:
		ai.tick(Vector3(0, 0, 5), self_pos)
		recovery_ticks += 1
	_check(ai.state == GruntAI.State.CHASE, "recovery -> chase")
	_check(recovery_ticks == tuning.grunt_recovery_frames, "recovery lasts tuning frames")
	ai.tick(Vector3(8, 0, 0), self_pos)
	_check(ai.state == GruntAI.State.IDLE, "leash outside detect range")
	ai.reset()
	_check(ai.state == GruntAI.State.IDLE and ai.frame == 0, "reset restores idle")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
