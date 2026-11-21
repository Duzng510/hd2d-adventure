extends SceneTree

## T-029: a buff must move the live objects, not only the sheet getters.
##  - reach lives in the scene's BoxShape3D, so reach_add must resize it
##  - tempo free swings live in TempoFatigue, so fatigue_free_swings_add must
##    keep five quick swings free (the base 3 would leave 8 accrued frames)
## Run: <GODOT> --headless --path . -s res://tests/test_stats_live.gd
## Negative: append `-- negative` to invert exactly one check (tempo).

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	await _run()
	_finish()


func _run() -> void:
	var arena: Node = load("res://scenes/phase_c/grove_arena.tscn").instantiate()
	# The wave must not spawn: this test only measures the player's live stats.
	arena.get_node("WaveEncounter").set_physics_process(false)
	root.add_child(arena)
	await physics_frame
	var combat := arena.get_node("Player/PlayerCombat") as PlayerCombat
	var shape_node := combat.get_node("../AttackHitbox/CollisionShape3D") as CollisionShape3D
	var box := shape_node.shape as BoxShape3D
	_check(is_equal_approx(box.size.x, 1.4) and is_equal_approx(shape_node.position.x, 0.7)
			and is_equal_approx(box.size.y, 0.8) and is_equal_approx(box.size.z, 0.8),
		"default reach is geometry-identical (1.4x0.8x0.8 box at x=0.7)")

	combat.stats.add_modifier(&"probe", {&"light_reach_add": 0.4})
	_check(is_equal_approx(box.size.x, 1.8) and is_equal_approx(shape_node.position.x, 0.9),
		"reach_add resizes the real BoxShape3D (size.x=%.2f at x=%.2f)"
		% [box.size.x, shape_node.position.x])
	_check(is_equal_approx(box.size.y, 0.8) and is_equal_approx(box.size.z, 0.8)
			and is_equal_approx(shape_node.position.y, 0.8)
			and is_equal_approx(shape_node.position.z, 0.0),
		"reach_add keeps the rest of the hitbox transform")
	combat.stats.remove_modifier(&"probe")
	await physics_frame
	_check(is_equal_approx(box.size.x, 1.4) and is_equal_approx(shape_node.position.x, 0.7),
		"removing the reach buff restores the authored hitbox")

	# Two extra free swings, applied after _ready built the live TempoFatigue.
	combat.stats.add_modifier(&"slow_breath", {&"fatigue_free_swings_add": 2.0})
	for i in 5:
		var before := combat.current_swing_id()
		combat.debug_request_attack()
		var guard := 0
		while combat.current_swing_id() == before and guard < 10:
			await physics_frame
			guard += 1
		_check(combat.current_swing_id() == before + 1, "swing %d really started" % (i + 1))
		guard = 0
		while combat.is_attacking() and guard < 60:
			await physics_frame
			guard += 1
		_check(not combat.is_attacking(), "swing %d finished" % (i + 1))
	# 5 swings against 5 free swings stay free; the base (3 free) would leave
	# (5 - 3) * 4 = 8 accrued frames here, which is exactly the inverted check.
	_check(combat.fatigue_frames() == (8 if _negative else 0),
		"live tempo uses the buffed free swings (fatigue %d)" % combat.fatigue_frames())

	arena.queue_free()
	await process_frame


func _finish() -> void:
	if _failures == 0:
		print("PASS test_stats_live: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_stats_live: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
