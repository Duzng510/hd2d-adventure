extends SceneTree

## T-031: the floating-number laws, tested without a renderer. Merge sums inside
## 6 ticks, the pool is a hard 24, the jitter sits on an 8 px grid and never
## points down, and everything is reproducible from the seed.

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	# On -- negative the second hit moves from one tick before the merge window
	# closes to the first tick it no longer covers, so the merge laws below must go
	# red instead of passing on a chain that never formed. A zeroed window cannot
	# be driven from the tick: age 0 sits inside every window the kernel has.
	var merge_offset := DamageNumbersKernel.MERGE_TICKS - 1
	if _negative:
		merge_offset = DamageNumbersKernel.MERGE_TICKS
	var kernel := DamageNumbersKernel.new(1234)
	_check(kernel.slot_count() == DamageNumbersKernel.POOL_SIZE,
		"the pool is fixed at %d slots" % DamageNumbersKernel.POOL_SIZE)
	_check(kernel.active_count() == 0, "nothing is alive before the first hit")

	var first := kernel.spawn(7, 13, Vector3(0, 1, 0), 100)
	_check(kernel.active_count() == 1, "one hit takes one slot")
	_check(int(kernel.slot(first)["amount"]) == 13, "the slot carries the amount")
	var jitter := kernel.slot(first)["jitter"] as Vector2i
	_check(jitter.x % 8 == 0 and jitter.y % 8 == 0,
		"jitter sits on the 8 px grid (%s)" % jitter)
	_check(jitter.y <= 0, "jitter never displaces downward (%s)" % jitter)
	_check(absi(jitter.x) <= 24 and absi(jitter.y) <= 24,
		"jitter stays inside 3 steps (%s)" % jitter)

	# The second hit lands one tick before the window closes: a correct kernel
	# merges, and the -- negative shift past the window's end must refuse to.
	var again := kernel.spawn(7, 13, Vector3(0, 1, 0), 100 + merge_offset)
	_check(again == first and int(kernel.slot(first)["amount"]) == 26,
		"T31.m same target inside the window merges (sum %d, slot %d/%d)"
		% [int(kernel.slot(first)["amount"]), again, first])
	_check(kernel.active_count() == 1, "the merge did not take a second slot")
	var late := kernel.spawn(7, 5, Vector3(0, 1, 0), 140)
	_check(late != first and int(kernel.slot(late)["amount"]) == 5,
		"a hit 40 ticks later opens its own chain (slot %d)" % late)

	kernel.reset()
	for i in 30:
		kernel.spawn(100 + i, 10, Vector3(i, 1, 0), 200 + i)
	_check(kernel.active_count() == DamageNumbersKernel.POOL_SIZE,
		"the pool never grows past %d (active %d)"
		% [DamageNumbersKernel.POOL_SIZE, kernel.active_count()])
	var oldest_gone := true
	for i in kernel.slot_count():
		if int(kernel.slot(i)["target_id"]) == 100:
			oldest_gone = false
	_check(oldest_gone, "the oldest slot is the one that gets evicted")

	kernel.reset()
	var born := kernel.spawn(9, 7, Vector3.ZERO, 500)
	kernel.sweep(500 + DamageNumbersKernel.LIFE_TICKS - 1)
	_check(not kernel.slot(born).is_empty(),
		"a number is still alive on its last tick")
	kernel.sweep(500 + DamageNumbersKernel.LIFE_TICKS)
	_check(kernel.slot(born).is_empty() and kernel.active_count() == 0,
		"the number is gone after 0.55 s (33 ticks)")

	var ages_ok := true
	var previous := 9999
	for age in DamageNumbersKernel.LIFE_TICKS:
		var rise := DamageNumbersKernel.rise_px(age)
		var a := DamageNumbersKernel.alpha(age)
		ages_ok = ages_ok and rise >= 0 and rise <= DamageNumbersKernel.RISE_PX \
			and a <= 1.0 and a >= 0.0 and a <= float(previous)
		previous = int(a * 1000)
	_check(ages_ok, "rise stays in 0..24 px and alpha never rises back up")
	_check(DamageNumbersKernel.rise_px(0) == 0
		and DamageNumbersKernel.rise_px(DamageNumbersKernel.LIFE_TICKS - 1)
			== DamageNumbersKernel.RISE_PX,
		"the climb spans the whole life")
	_check(DamageNumbersKernel.alpha(0) == 1.0
		and DamageNumbersKernel.alpha(DamageNumbersKernel.LIFE_TICKS - 1) < 0.1,
		"readable at birth, faded at death")

	for pair in [[Vector2(100.4, 200.6), Vector2i(100, 201)],
			[Vector2(-0.6, -3.4), Vector2i(-1, -3)],
			[Vector2(100.0, 200.0), Vector2(100, 200)]]:
		# The cast must be parenthesised: `== x as Vector2i` parses as `(== x) as Vector2i`.
		_check(DamageNumbersKernel.snap_screen_px(pair[0] as Vector2) == (pair[1] as Vector2i),
			"projection snaps to whole pixels (%s -> %s)" % [pair[0], pair[1]])
	var snapped := DamageNumbersKernel.snap_screen_px(Vector2(37.62, 91.18))
	_check(DamageNumbersKernel.snap_screen_px(Vector2(snapped)) == snapped,
		"the pixel snap is idempotent")

	var a_seq := _jitter_sequence(4242)
	var b_seq := _jitter_sequence(4242)
	var c_seq := _jitter_sequence(9001)
	_check(a_seq == b_seq, "same seed -> same jitter sequence (reproducible evidence)")
	_check(a_seq != c_seq, "a different seed moves the sequence")
	print("JITTER seed4242=%s seed9001=%s" % [a_seq, c_seq])

	_finish()


func _jitter_sequence(seed_value: int) -> Array:
	var kernel := DamageNumbersKernel.new(seed_value)
	var drawn: Array = []
	for i in DamageNumbersKernel.POOL_SIZE:
		kernel.spawn(200 + i, 1, Vector3.ZERO, i * 100)
		drawn.append(kernel.slot(i)["jitter"])
	return drawn


func _finish() -> void:
	if _failures == 0:
		print("PASS test_damage_numbers_kernel: %d checks%s"
			% [_checks, " (negative)" if _negative else ""])
		quit(0)
	else:
		print("FAIL test_damage_numbers_kernel: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
