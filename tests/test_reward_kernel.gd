extends SceneTree

## RewardKernel state machine + Health.heal. Run:
##   <GODOT> --headless --path . -s res://tests/test_reward_kernel.gd
## Negative (heal allowed before the gate opens) must exit 1:
##   <GODOT> --headless --path . -s res://tests/test_reward_kernel.gd -- negative

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	_test_kernel(negative)
	_test_health_heal()
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("FAIL: %s" % failure)
	var ok := _failures.is_empty()
	print("PASS test_reward_kernel" if ok else "FAIL test_reward_kernel")
	quit(0 if ok else 1)


func _test_kernel(negative: bool) -> void:
	var kernel: RewardKernel
	if negative:
		kernel = AlwaysHealKernel.new()
	else:
		kernel = RewardKernel.new()
	_check(kernel.state == RewardKernel.State.LOCKED, "starts LOCKED")
	_check(not kernel.gate_open(), "gate closed before reward")
	_check(kernel.try_heal(40, 100) == 0, "heal blocked before gate")
	_check(kernel.grant(), "first grant succeeds")
	_check(kernel.gate_open(), "gate open after grant")
	_check(not kernel.grant(), "grant does not repeat")
	_check(kernel.try_heal(40, 100) == 60, "heal restores missing hp once")
	_check(kernel.state == RewardKernel.State.HEALED, "state HEALED after heal")
	_check(kernel.try_heal(40, 100) == 0, "heal is one shot per run")
	kernel.reset()
	_check(kernel.state == RewardKernel.State.LOCKED, "reset closes gate")
	_check(kernel.try_heal(50, 100) == 0, "heal blocked again after reset")
	_check(kernel.grant(), "grant available again after reset")


func _test_health_heal() -> void:
	var health := Health.new(100)
	health.apply_damage(70)
	_check(health.heal(30) == 30, "heal applies requested amount")
	_check(health.hp == 60, "heal adds exactly what was applied")
	_check(health.heal(80) == 40, "heal clamps to missing hp")
	_check(health.hp == 100, "heal stops at max hp")
	_check(health.heal(10) == 0, "heal at full hp does nothing")
	var dead := Health.new(50)
	dead.apply_damage(50)
	_check(dead.heal(20) == 0, "no heal while dead")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


class AlwaysHealKernel extends RewardKernel:
	func try_heal(current_hp: int, max_hp: int) -> int:
		return maxi(max_hp - current_hp, 0)
