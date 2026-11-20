extends SceneTree

## WaveKernel tests. Run:
##   <GODOT> --headless --path . -s res://tests/test_wave_kernel.gd
## Negative control (broken kernel ignoring alive_count) must exit 1:
##   <GODOT> --headless --path . -s res://tests/test_wave_kernel.gd -- negative

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	var kernel: WaveKernel
	if negative:
		kernel = BrokenWaveKernel.new([2, 2, 1], 3)
	else:
		kernel = WaveKernel.new([2, 2, 1], 3)
	_run_all(kernel)
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("FAIL: %s" % failure)
	var ok := _failures.is_empty()
	print("PASS test_wave_kernel" if ok else "FAIL test_wave_kernel")
	quit(0 if ok else 1)


func _run_all(kernel: WaveKernel) -> void:
	kernel.start()
	_check(kernel.state == WaveKernel.State.FIGHTING, "start -> FIGHTING")
	_check(kernel.wave_index == 0, "start at wave 0")
	_check(kernel.wave_start_pending, "start sets wave_start_pending")
	kernel.wave_start_pending = false
	kernel.tick(2)
	_check(kernel.state == WaveKernel.State.FIGHTING, "alive enemies keep FIGHTING")
	kernel.tick(0)
	_check(kernel.state == WaveKernel.State.PAUSED, "cleared wave -> PAUSED")
	_check(kernel.pause_remaining == 3, "pause_remaining = pause_frames")
	kernel.tick(0)
	kernel.tick(0)
	_check(kernel.state == WaveKernel.State.PAUSED, "pause not elapsed yet")
	kernel.tick(0)
	_check(kernel.state == WaveKernel.State.FIGHTING, "pause elapsed -> FIGHTING")
	_check(kernel.wave_index == 1, "advanced to wave 1")
	_check(kernel.wave_start_pending, "advance sets wave_start_pending")
	kernel.wave_start_pending = false
	kernel.tick(0)
	_check(kernel.state == WaveKernel.State.PAUSED, "wave 2 cleared -> PAUSED")
	for i in 3:
		kernel.tick(0)
	_check(kernel.state == WaveKernel.State.FIGHTING and kernel.wave_index == 2, "final wave active")
	kernel.tick(0)
	_check(kernel.state == WaveKernel.State.WON, "final wave cleared -> WON")
	var lost := WaveKernel.new([2], 3)
	lost.start()
	lost.player_died()
	_check(lost.state == WaveKernel.State.LOST, "player death -> LOST")
	lost.reset()
	_check(lost.state == WaveKernel.State.INACTIVE and lost.wave_index == 0, "reset -> INACTIVE wave 0")
	_check(WaveKernel.new([5, 4, 1], 60).wave_count() == 3, "wave_count = wave_sizes.size()")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


class BrokenWaveKernel extends WaveKernel:
	func tick(_alive_count: int) -> void:
		super.tick(0)
