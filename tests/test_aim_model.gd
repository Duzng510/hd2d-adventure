extends SceneTree

## Headless test for AimModel.ground_hit. Run:
## <GODOT> --headless --path . -s res://tests/test_aim_model.gd
## Single quit() via if/else (quit is deferred; last call wins).

const AimModel = preload("res://scripts/phase_a/aim_model.gd")

var _fail := 0


func _init() -> void:
	_check("straight_down", AimModel.ground_hit(Vector3(0, 10, 0), Vector3(0, -1, 0)), Vector3(0, 0, 0))
	_check("angled_to_origin", AimModel.ground_hit(Vector3(0, 10, 8), Vector3(0, -10, -8).normalized()), Vector3(0, 0, 0))
	_check("xz_preserved", AimModel.ground_hit(Vector3(2, 5, 3), Vector3(0, -1, 0)), Vector3(2, 0, 3))
	_check("raised_plane", AimModel.ground_hit(Vector3(0, 10, 0), Vector3(0, -1, 0), 2.0), Vector3(0, 2, 0))
	_no_hit("parallel", AimModel.ground_hit(Vector3(0, 10, 0), Vector3(1, 0, 0)))
	_no_hit("behind_camera", AimModel.ground_hit(Vector3(0, 10, 0), Vector3(0, 1, 0)))
	if _fail == 0:
		print("AIM MODEL TEST PASS (6 checks)")
		quit(0)
	else:
		print("AIM MODEL TEST FAIL (%d)" % _fail)
		quit(1)


func _check(name: String, got: Vector3, want: Vector3) -> void:
	if got.is_finite() and got.distance_to(want) < 1e-4:
		print("  ok %s" % name)
	else:
		_fail += 1
		print("  FAIL %s got=%s want=%s" % [name, got, want])


func _no_hit(name: String, got: Vector3) -> void:
	if not got.is_finite():
		print("  ok %s (no hit)" % name)
	else:
		_fail += 1
		print("  FAIL %s expected no-hit got=%s" % [name, got])