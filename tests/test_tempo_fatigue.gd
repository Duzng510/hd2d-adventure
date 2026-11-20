extends SceneTree

## T-027: the mash penalty is a tempo cost, not a control cost. These checks pin
## the accrual/cap/decay/clear law independently of any node, so the numbers the
## harness measures later are the numbers decided here.

const FREE := 3
const STEP := 4
const CAP := 12
const DECAY := 6

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var fatigue := TempoFatigue.new(FREE, STEP, CAP, DECAY)
	_check(fatigue.frames() == 0, "a fresh player swings at full speed")
	for swing in FREE:
		fatigue.swing()
		_check(fatigue.frames() == 0, "swing %d still inside the free allowance" % (swing + 1))
	fatigue.swing()
	_check(fatigue.frames() == (0 if _negative else STEP), "the 4th consecutive swing costs one step")
	fatigue.swing()
	_check(fatigue.frames() == STEP * 2, "the 5th costs two steps")
	fatigue.swing()
	fatigue.swing()
	_check(fatigue.frames() == CAP, "the cost reaches its ceiling and stops there")
	fatigue.swing()
	fatigue.swing()
	_check(fatigue.frames() == CAP, "the ceiling holds no matter how much longer the chain runs")

	fatigue.clear()
	for swing in FREE:
		fatigue.swing()
	_check(fatigue.frames() == 0, "after a clear the free allowance is earned back")
	fatigue.swing()
	_check(fatigue.frames() == STEP, "the first swing past the allowance costs one step again")
	for tick in DECAY - 1:
		fatigue.tick_idle()
	_check(fatigue.frames() == STEP, "one tick short of a decay period changes nothing")
	fatigue.tick_idle()
	_check(fatigue.frames() == 0, "a full period of not pressing the button removes one step")
	for period in 4:
		for tick in DECAY:
			fatigue.tick_idle()
	_check(fatigue.frames() == 0, "idle play never decays below full speed")

	for swing in 6:
		fatigue.swing()
	_check(fatigue.frames() > 0, "mashing again builds fatigue again")
	fatigue.clear()
	_check(fatigue.frames() == 0, "dodge is a real commitment and wipes the cost")

	if _failures == 0:
		print("PASS test_tempo_fatigue: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_tempo_fatigue: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
