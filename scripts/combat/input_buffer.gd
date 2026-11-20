class_name InputBuffer
extends RefCounted

## Attack input buffer: a captured input stays valid for window_frames sim ticks.

var window_frames: int

var _captured_frame: int = -1


func _init(p_window_frames: int) -> void:
	window_frames = maxi(p_window_frames, 0)


func push(sim_frame: int) -> void:
	_captured_frame = sim_frame


func is_valid(sim_frame: int) -> bool:
	return _captured_frame >= 0 and sim_frame - _captured_frame <= window_frames


func consume(sim_frame: int) -> bool:
	var ok := is_valid(sim_frame)
	_captured_frame = -1
	return ok


func has_pending() -> bool:
	return _captured_frame >= 0


func clear() -> void:
	_captured_frame = -1
