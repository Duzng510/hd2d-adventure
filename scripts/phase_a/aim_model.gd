class_name AimModel
extends RefCounted

## Pure ray -> ground-plane intersection, separated from nodes for headless tests.
## Returns Vector3.INF when the ray is parallel to the plane or points away from it.
static func ground_hit(origin: Vector3, direction: Vector3, ground_y: float = 0.0) -> Vector3:
	if absf(direction.y) < 1e-6:
		return Vector3.INF
	var t := (ground_y - origin.y) / direction.y
	if t < 0.0:
		return Vector3.INF
	return origin + direction * t