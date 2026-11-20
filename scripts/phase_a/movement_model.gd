class_name MovementModel
extends RefCounted

## Pure input -> velocity/facing logic, node-free for headless tests.
## Gameplay lives on the XZ plane; Y is always zero (Phase A hypothesis).


static func compute_velocity(input_vector: Vector2, speed: float) -> Vector3:
	var limited := input_vector.limit_length(1.0)
	return Vector3(limited.x, 0.0, limited.y) * speed


static func compute_facing(input_vector: Vector2, current_facing: int) -> int:
	if input_vector.x > 0.0:
		return 1
	if input_vector.x < 0.0:
		return -1
	return current_facing