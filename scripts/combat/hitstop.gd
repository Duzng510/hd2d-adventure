class_name HitstopController
extends RefCounted

## Combat-wide hitstop counter; overlapping requests take max, never sum.

var remaining: int = 0


func request(frames: int) -> void:
	remaining = maxi(remaining, frames)


func tick() -> bool:
	if remaining <= 0:
		return false
	remaining -= 1
	return true


func reset() -> void:
	remaining = 0
