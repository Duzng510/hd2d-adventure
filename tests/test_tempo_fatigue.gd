extends SceneTree

## T-027: the mash penalty is a tempo cost, not a control cost. These checks pin
## the accrual/cap/decay/clear law independently of any node, so the numbers the
## harness measures later are the numbers decided here.

const FREE := 3
const STEP := 4
const CAP := 12
const DECAY := 6
## A cap that is not a multiple of the step: pins the display law for tunings
## where `level() * step == frames()` cannot hold.
const RAGGED_FREE := 1
const RAGGED_CAP := 10
const RAGGED_DECAY := 3

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var fatigue := TempoFatigue.new(FREE, STEP, CAP, DECAY)
	_check(fatigue.level_max() == CAP / STEP, "the tell has as many slots as the cost has steps")
	_check(fatigue.frames() == 0, "a fresh player swings at full speed")
	_check(fatigue.level() == 0, "a fresh player reads no tier")
	for swing in FREE:
		fatigue.swing()
		_check(fatigue.frames() == 0, "swing %d still inside the free allowance" % (swing + 1))
		_check(fatigue.level() == 0, "tier holds at 0 inside the allowance (swing %d)" % (swing + 1))
	fatigue.swing()
	_check(fatigue.frames() == (0 if _negative else STEP), "the 4th consecutive swing costs one step")
	_check(fatigue.level() == 1, "the 4th swing shows one paid tier")
	fatigue.swing()
	_check(fatigue.frames() == STEP * 2, "the 5th costs two steps")
	_check(fatigue.level() == 2, "the 5th shows two paid tiers")
	fatigue.swing()
	fatigue.swing()
	_check(fatigue.frames() == CAP, "the cost reaches its ceiling and stops there")
	_check(fatigue.level() == fatigue.level_max(), "the ceiling reads as the last tier, not a fourth one")
	fatigue.swing()
	fatigue.swing()
	_check(fatigue.frames() == CAP, "the ceiling holds no matter how much longer the chain runs")
	_check(fatigue.level() == fatigue.level_max(), "the tier holds at the ceiling too")

	fatigue.clear()
	for swing in FREE:
		fatigue.swing()
	_check(fatigue.frames() == 0, "after a clear the free allowance is earned back")
	_check(fatigue.level() == 0, "a cleared chain reads tier 0")
	fatigue.swing()
	_check(fatigue.frames() == STEP, "the first swing past the allowance costs one step again")
	_check(fatigue.level() == 1, "and reads as tier 1 again")
	for tick in DECAY - 1:
		fatigue.tick_idle()
	_check(fatigue.frames() == STEP, "one tick short of a decay period changes nothing")
	_check(fatigue.level() == 1, "one tick short of decay keeps the tier")
	fatigue.tick_idle()
	_check(fatigue.frames() == 0, "a full period of not pressing the button removes one step")
	_check(fatigue.level() == 0, "a full period hands one tier back")
	for period in 4:
		for tick in DECAY:
			fatigue.tick_idle()
	_check(fatigue.frames() == 0, "idle play never decays below full speed")

	for swing in 6:
		fatigue.swing()
	_check(fatigue.frames() > 0, "mashing again builds fatigue again")
	_check(fatigue.level() > 0, "the tell follows the rebuilt cost")
	fatigue.clear()
	_check(fatigue.frames() == 0, "dodge is a real commitment and wipes the cost")
	_check(fatigue.level() == 0, "the wipe is readable, not only computed")

	# The bounds law, not the identity, is what the display owes the cost: with a
	# ragged cap the two can never be equal, and the tier must still lag or match.
	var ragged := TempoFatigue.new(RAGGED_FREE, STEP, RAGGED_CAP, RAGGED_DECAY)
	for swing in 5:
		ragged.swing()
		_check(ragged.level() * STEP <= ragged.frames(), "the tier never reads above the cost it mirrors")
		_check(ragged.frames() < (ragged.level() + 1) * STEP, "the tier never reads a step ahead of the cost")
	_check(ragged.level() == ragged.level_max(), "a capped ragged chain sits on the last slot")
	_check(ragged.level_max() == RAGGED_CAP / STEP, "slots come from the tuning, not from a hardcoded three")

	if _negative:
		# frames() already goes red above; the tier needs its own deliberate failure
		# or a level() bug could ship behind a ruler that only measures the old axis.
		_check(fatigue.level() == 1, "negative: tier pinned wrong on purpose")

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
