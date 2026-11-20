extends SceneTree

## Headless test for MovementModel. Run:
## <GODOT> --headless --path . -s res://tests/test_movement_model.gd
## Exit code 0 = pass, 1 = fail.

const MovementModel = preload("res://scripts/phase_a/movement_model.gd")


func _init() -> void:
	var failures: Array[String] = []
	var speed := 4.0

	var v := MovementModel.compute_velocity(Vector2(1, 0), speed)
	if v != Vector3(4, 0, 0):
		failures.append("straight right: got %s" % v)

	v = MovementModel.compute_velocity(Vector2(0, -1), speed)
	if v != Vector3(0, 0, -4):
		failures.append("straight up (-Z): got %s" % v)

	v = MovementModel.compute_velocity(Vector2.ZERO, speed)
	if v != Vector3.ZERO:
		failures.append("instant stop: got %s" % v)

	v = MovementModel.compute_velocity(Vector2(1, 1), speed)
	var expected := Vector3(1, 0, 1).normalized() * speed
	if v.distance_to(expected) > 0.0001:
		failures.append("diagonal normalized: got %s expected %s" % [v, expected])

	if MovementModel.compute_facing(Vector2(1, 0), -1) != 1:
		failures.append("facing right")
	if MovementModel.compute_facing(Vector2(-1, 0), 1) != -1:
		failures.append("facing left")
	if MovementModel.compute_facing(Vector2(0, -1), -1) != -1:
		failures.append("facing kept on vertical input")

	for i in 100:
		var dir := 1.0 if i % 2 == 0 else -1.0
		v = MovementModel.compute_velocity(Vector2(dir, 0), speed)
		if v.x != dir * speed:
			failures.append("rapid reversal %d: got %s" % [i, v])
			break

	if failures.is_empty():
		print("TEST PASS: movement_model (6 groups, 100 reversals)")
		quit(0)
	else:
		for f in failures:
			printerr("TEST FAIL: " + f)
		quit(1)