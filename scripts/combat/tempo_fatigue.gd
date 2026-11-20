class_name TempoFatigue
extends RefCounted

## T-027: mashing costs tempo, never control. The length of the current chain of
## consecutive swings decides how much extra recovery the next swing pays, and
## the only ways to pay it back are not pressing the button, or committing to a
## dodge. Enemy AI does not use this class - authored cadence stays authoritative.

var free_swings: int
var step_frames: int
var max_frames: int
var decay_frames: int

var _chain: int = 0
var _idle_ticks: int = 0


func _init(p_free_swings: int, p_step_frames: int, p_max_frames: int, p_decay_frames: int) -> void:
	free_swings = maxi(p_free_swings, 0)
	step_frames = maxi(p_step_frames, 1)
	max_frames = maxi(p_max_frames, 0)
	decay_frames = maxi(p_decay_frames, 1)


## Extra recovery frames the next swing will pay.
func frames() -> int:
	return mini(maxi(0, _chain - free_swings) * step_frames, max_frames)


func swing() -> void:
	_chain += 1
	_idle_ticks = 0


## Call once per physics frame while the player is neither attacking nor dodging.
func tick_idle() -> void:
	_idle_ticks += 1
	if _idle_ticks < decay_frames:
		return
	_idle_ticks = 0
	_chain = maxi(free_swings, _chain - 1)


func clear() -> void:
	_chain = 0
	_idle_ticks = 0
