class_name RangedAI
extends GruntAI

## Ranged variant of the shared state machine: keeps the kite band
## [attack_range = min_range, detect_range = max_range], snapshots aim at
## telegraph start and fires once on active start (the node spawns the projectile).
## Frame convention matches GruntAI: frame 1 on state entry, leave when frame > limit.

func tick(player_pos: Vector3, self_pos: Vector3) -> void:
	var to_player := player_pos - self_pos
	to_player.y = 0.0
	distance = to_player.length()
	var dir := to_player.normalized() if distance > 0.0001 else Vector3.ZERO
	match state:
		State.IDLE:
			if _within_range():
				alert_pending = true
				_enter(State.CHASE)
		State.CHASE:
			if distance < attack_range:
				move_dir = -dir
				frame += 1
			elif _can_fire():
				move_dir = Vector3.ZERO
				attack_dir = dir
				_enter(State.TELEGRAPH)
			else:
				move_dir = dir
				frame += 1
		State.TELEGRAPH:
			move_dir = Vector3.ZERO
			frame += 1
			if frame > telegraph_frames:
				_enter(State.ACTIVE)
		State.ACTIVE:
			move_dir = Vector3.ZERO
			frame += 1
			if frame > active_frames:
				_enter(State.RECOVERY)
		State.RECOVERY:
			move_dir = Vector3.ZERO
			frame += 1
			if frame > recovery_frames:
				_enter(State.CHASE)


## Overridable gates; negative-control subclasses widen them.
func _within_range() -> bool:
	return distance <= detect_range


func _can_fire() -> bool:
	return distance >= attack_range and distance <= detect_range
