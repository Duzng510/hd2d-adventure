class_name DodgeState
extends RefCounted

var total_frames: int
var iframe_frames: int
var frame: int = 0


func _init(p_total_frames: int, p_iframe_frames: int) -> void:
	total_frames = maxi(p_total_frames, 1)
	iframe_frames = clampi(p_iframe_frames, 0, total_frames)


func start() -> void:
	frame = 1


func tick() -> void:
	if frame == 0:
		return
	frame += 1
	if frame > total_frames:
		frame = 0


func cancel() -> void:
	frame = 0


func is_active() -> bool:
	return frame > 0


func is_invulnerable() -> bool:
	return frame >= 1 and frame <= iframe_frames
