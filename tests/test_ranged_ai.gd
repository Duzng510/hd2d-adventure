extends SceneTree

## RangedAI kite state machine. Run:
##   <GODOT> --headless --path . -s res://tests/test_ranged_ai.gd
## Negative (range gates removed) must exit 1:
##   <GODOT> --headless --path . -s res://tests/test_ranged_ai.gd -- negative

const MIN_RANGE := 3.5
const MAX_RANGE := 7.0
const TELEGRAPH := 24
const ACTIVE := 4
const RECOVERY := 30

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	_test_outside_range(negative)
	_test_cycle(negative)
	_test_kite(negative)
	_test_snapshot(negative)
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("FAIL: %s" % failure)
	var ok := _failures.is_empty()
	print("PASS test_ranged_ai" if ok else "FAIL test_ranged_ai")
	quit(0 if ok else 1)


func _new_ai(negative: bool) -> GruntAI:
	if negative:
		return BrokenRangedAI.new(MAX_RANGE, MIN_RANGE, TELEGRAPH, ACTIVE, RECOVERY)
	return RangedAI.new(MAX_RANGE, MIN_RANGE, TELEGRAPH, ACTIVE, RECOVERY)


func _test_outside_range(negative: bool) -> void:
	var ai := _new_ai(negative)
	for i in 120:
		ai.tick(Vector3(8.0, 0.0, 0.0), Vector3.ZERO)
	_check(ai.state == GruntAI.State.IDLE, "no engagement outside max range")
	_check(not ai.alert_pending, "no alert outside max range")


func _test_cycle(negative: bool) -> void:
	var ai := _new_ai(negative)
	var player := Vector3(5.0, 0.0, 0.0)
	ai.tick(player, Vector3.ZERO)
	_check(ai.state == GruntAI.State.CHASE, "in range -> CHASE")
	_check(ai.alert_pending, "alert event on first detection")
	ai.alert_pending = false
	var tick := 0
	var telegraph_at := -1
	var deltas: Array[int] = []
	var cycles := 0
	var last_state := ai.state
	while tick < 3000 and cycles < 3:
		tick += 1
		ai.tick(player, Vector3.ZERO)
		if ai.state != last_state:
			if ai.state == GruntAI.State.TELEGRAPH:
				telegraph_at = tick
			elif ai.state == GruntAI.State.ACTIVE and telegraph_at >= 0:
				deltas.append(tick - telegraph_at)
				telegraph_at = -1
			elif ai.state == GruntAI.State.CHASE:
				cycles += 1
			last_state = ai.state
	_check(deltas.size() == 3, "three fire cycles")
	if deltas.size() == 3:
		_check(deltas[0] == TELEGRAPH, "telegraph -> active 24 (cycle 1)")
		_check(deltas[1] == TELEGRAPH, "telegraph -> active 24 (cycle 2)")
		_check(deltas[2] == TELEGRAPH, "telegraph -> active 24 (cycle 3)")


func _test_kite(negative: bool) -> void:
	var ai := _new_ai(negative)
	var close := Vector3(2.0, 0.0, 0.0)
	ai.tick(close, Vector3.ZERO)
	ai.tick(close, Vector3.ZERO)
	_check(ai.state == GruntAI.State.CHASE, "too close stays CHASE")
	_check(ai.move_dir.dot(Vector3.RIGHT) < -0.5, "too close retreats")
	ai.tick(Vector3(8.0, 0.0, 0.0), Vector3.ZERO)
	_check(ai.state == GruntAI.State.CHASE, "far stays CHASE")
	_check(ai.move_dir.dot(Vector3.RIGHT) > 0.5, "far advances")
	ai.tick(Vector3(5.0, 0.0, 0.0), Vector3.ZERO)
	_check(ai.state == GruntAI.State.TELEGRAPH, "in band telegraphs")


func _test_snapshot(negative: bool) -> void:
	var ai := _new_ai(negative)
	ai.tick(Vector3(5.0, 0.0, 0.0), Vector3.ZERO)
	ai.tick(Vector3(5.0, 0.0, 0.0), Vector3.ZERO)
	var snapshot := ai.attack_dir
	ai.tick(Vector3(0.0, 0.0, 5.0), Vector3.ZERO)
	_check(ai.state == GruntAI.State.TELEGRAPH, "telegraph persists after player moves")
	_check(ai.attack_dir.is_equal_approx(snapshot), "attack direction snapshotted")
	_check(snapshot.dot(Vector3.RIGHT) > 0.99, "snapshot points at telegraph-start player")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


class BrokenRangedAI extends RangedAI:
	func _within_range() -> bool:
		return true

	func _can_fire() -> bool:
		return true
