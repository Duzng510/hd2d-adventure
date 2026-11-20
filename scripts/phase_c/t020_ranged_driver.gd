extends Node

## T-020 Ranged evidence: range gate, telegraph lead, one-hit projectile,
## wall despawn, lifetime despawn. Headless:
##   <GODOT> --headless --path . res://scenes/phase_c/run_t020_ranged.tscn --fixed-fps 60
## Negative (range gate widened to 100 m) must exit 1 with an E2.1 assert:
##   ... --fixed-fps 60 -- negative

const RANGED_SCENE := preload("res://scenes/combat/ranged.tscn")
const TUNING_PATH := "res://scripts/combat/combat_tuning.tres"
const FIRE_OUTSIDE_TICKS := 120
const HIT_TIMEOUT := 180
const WALL_TIMEOUT := 120
const LIFETIME_WAIT := 240

var _arena: Node3D
var _director: CombatDirector
var _combat: PlayerCombat
var _player: PlayerController
var _ranged: Ranged
var _tuning: CombatTuning
var _negative := false
var _checks: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	_arena = get_node("../GroveArena")
	_director = _arena.get_node("CombatDirector")
	_combat = _arena.get_node("Player/PlayerCombat")
	_player = _arena.get_node("Player")
	var encounter := _arena.get_node("WaveEncounter")
	encounter.process_mode = Node.PROCESS_MODE_DISABLED
	_tuning = (load(TUNING_PATH) as CombatTuning).duplicate() as CombatTuning
	if _negative:
		_tuning.ranged_max_range = 100.0
	_spawn_ranged()
	_run()


func _spawn_ranged() -> void:
	_ranged = RANGED_SCENE.instantiate() as Ranged
	_ranged.tuning = _tuning
	_ranged.spawn_position = Vector3.ZERO
	_ranged.position = Vector3.ZERO
	_ranged.name = "T020Ranged"
	_arena.add_child(_ranged)


func _run() -> void:
	await _phase_range_gate()
	await _phase_hit_once()
	await _phase_wall_despawn()
	await _phase_lifetime()
	var ok := _failures.is_empty()
	print("checks=%d failures=%d" % [_checks, _failures.size()])
	for failure in _failures:
		print("ASSERT FAIL: %s" % failure)
	print("PASS t020_ranged" if ok else "FAIL t020_ranged")
	get_tree().quit(0 if ok else 1)


func _phase_range_gate() -> void:
	_reset_ranged(Vector3(0.0, 0.0, -4.0))
	_set_player(Vector3(0.0, 0.0, 6.0))
	var before := _count(&"projectile_fire")
	await _ticks(FIRE_OUTSIDE_TICKS)
	var fires := _count(&"projectile_fire") - before
	_check(fires == 0, "E2.1 no projectile_fire outside max range (fires=%d)" % fires)


func _phase_hit_once() -> void:
	_reset_ranged(Vector3(0.0, 0.0, -2.0))
	_set_player(Vector3(0.0, 0.0, 3.0))
	var fire_before := _count(&"projectile_fire")
	var hit_before := _count(&"projectile_hit")
	var despawn_before := _count(&"projectile_despawn")
	var hp_before := _combat.hp()
	var telegraph_tick := -1
	var active_tick := -1
	var tick := 0
	while tick < HIT_TIMEOUT and _count(&"projectile_hit") == hit_before:
		await get_tree().physics_frame
		tick += 1
		if telegraph_tick < 0 and _ranged.ai_state() == GruntAI.State.TELEGRAPH:
			telegraph_tick = tick
		if active_tick < 0 and _ranged.ai_state() == GruntAI.State.ACTIVE:
			active_tick = tick
			_ranged.set_physics_process(false)
	var fires := _count(&"projectile_fire") - fire_before
	var hits := _count(&"projectile_hit") - hit_before
	var despawns := _count(&"projectile_despawn") - despawn_before
	var hp_delta := hp_before - _combat.hp()
	_check(fires >= 1, "E2.2 fires inside band (fires=%d)" % fires)
	_check(telegraph_tick >= 0 and active_tick >= 0 and active_tick - telegraph_tick >= 18, "E2.2 telegraph >= 18 before fire (delta=%d)" % (active_tick - telegraph_tick))
	_check(hits == 1, "E2.3 projectile hits player once (hits=%d)" % hits)
	_check(hp_delta == _tuning.ranged_damage, "E2.3 damage = ranged_damage (hp_delta=%d)" % hp_delta)
	_check(despawns == 1, "E2.3 projectile despawns on hit (despawns=%d)" % despawns)
	await _ticks(30)
	_check(_count(&"projectile_hit") - hit_before == 1, "E2.3 no second hit after despawn")


func _phase_wall_despawn() -> void:
	_reset_ranged(Vector3(0.0, 0.0, -4.0))
	_set_player(Vector3(0.0, 0.0, 2.0))
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 1.0)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = Vector3(0.0, 1.0, -1.0)
	_arena.add_child(blocker)
	var hit_before := _count(&"projectile_hit")
	var despawn_before := _count(&"projectile_despawn")
	var hp_before := _combat.hp()
	var tick := 0
	while tick < WALL_TIMEOUT and _count(&"projectile_despawn") == despawn_before:
		await get_tree().physics_frame
		tick += 1
		if _ranged.ai_state() == GruntAI.State.ACTIVE:
			_ranged.set_physics_process(false)
	var despawns := _count(&"projectile_despawn") - despawn_before
	var hits := _count(&"projectile_hit") - hit_before
	_check(despawns == 1, "E2.3 projectile despawns on wall (despawns=%d)" % despawns)
	_check(hits == 0 and _combat.hp() == hp_before, "E2.3 wall despawn deals no damage")
	_check(tick < 100, "E2.3 wall despawn before lifetime (tick=%d)" % tick)
	blocker.queue_free()


func _phase_lifetime() -> void:
	_reset_ranged(Vector3(-6.5, 0.0, 0.0))
	_set_player(Vector3(-1.5, 0.0, 0.0))
	var hit_before := _count(&"projectile_hit")
	var despawn_before := _count(&"projectile_despawn")
	var hp_before := _combat.hp()
	var fire_tick := -1
	var despawn_tick := -1
	var tick := 0
	while tick < LIFETIME_WAIT and despawn_tick < 0:
		await get_tree().physics_frame
		tick += 1
		if fire_tick < 0 and _ranged.ai_state() == GruntAI.State.ACTIVE:
			fire_tick = tick
			_ranged.set_physics_process(false)
			_set_player(Vector3(-1.5, 0.0, 5.0))
		if fire_tick >= 0 and _count(&"projectile_despawn") > despawn_before:
			despawn_tick = tick
	var elapsed := despawn_tick - fire_tick if despawn_tick >= 0 and fire_tick >= 0 else -1
	_check(despawn_tick >= 0, "E2.3 projectile despawns by lifetime")
	_check(elapsed >= 118 and elapsed <= 126, "E2.3 lifetime despawn ~121 ticks (elapsed=%d)" % elapsed)
	_check(_count(&"projectile_hit") == hit_before, "E2.3 lifetime despawn deals no damage")
	_check(_combat.hp() == hp_before, "E2.3 lifetime path keeps player HP")


func _reset_ranged(position: Vector3) -> void:
	_ranged.set_physics_process(true)
	_ranged.reset()
	_ranged.global_position = position
	_combat.health.reset()
	for projectile in get_tree().get_nodes_in_group(&"enemy_projectile"):
		projectile.queue_free()


func _set_player(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _count(event_name: StringName) -> int:
	return int(_director.event_counts.get(String(event_name), 0))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	print("CHECK %s %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures.append(label)
