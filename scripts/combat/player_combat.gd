class_name PlayerCombat
extends Node

## Player combat wiring: kernel states, snapshot-aim hitbox, combat log, hitstop.
## Runs at priority -10 so movement lock/override reach PlayerController the same tick.

const ENEMY_HURTBOX_MASK := 32

@export var tuning: CombatTuning
@export var director_path: NodePath = NodePath("../../CombatDirector")
@export var aim_path: NodePath = NodePath("../../AimMarker")
@export var hitbox_path: NodePath = NodePath("../AttackHitbox")
@export var hitbox_shape_path: NodePath = NodePath("../AttackHitbox/CollisionShape3D")
@export var swing_visual_path: NodePath = NodePath("../AttackHitbox/SwingArc")
@export var sprite_path: NodePath = NodePath("../Sprite3D")
## Capture/debug hook: attack aim uses aim_override_point instead of the mouse.
@export var aim_override_enabled: bool = false
@export var aim_override_point := Vector3.ZERO

var health: Health

var _player: PlayerController
var _director: CombatDirector
var _aim: AimMarker
var _hitbox: Area3D
var _hitbox_shape: CollisionShape3D
var _swing: MeshInstance3D
var _sprite: Sprite3D

var _attack: AttackState
var _buffer: InputBuffer
var _dodge: DodgeState
var _registry := HitRegistry.new()

var _combat_frame: int = 0
var _swing_id: int = 0
var _attack_dir := Vector3.RIGHT
var _dodge_dir := Vector3.RIGHT
var _was_active: bool = false
var _hit_flash_frames: int = 0
var _logged_death: bool = false


func _ready() -> void:
	process_priority = -10
	_player = get_parent()
	_director = get_node(director_path)
	_aim = get_node(aim_path)
	_hitbox = get_node(hitbox_path)
	_hitbox_shape = get_node(hitbox_shape_path)
	_swing = get_node_or_null(swing_visual_path)
	_sprite = get_node_or_null(sprite_path)
	health = Health.new(tuning.player_max_hp)
	_attack = AttackState.new(
		tuning.light_startup_frames,
		tuning.light_active_frames,
		tuning.light_recovery_frames,
		tuning.combo_window_frames,
		tuning.light_combo_hits
	)
	_buffer = InputBuffer.new(tuning.input_buffer_frames)
	_dodge = DodgeState.new(tuning.dodge_total_frames, tuning.dodge_iframe_frames)
	_hitbox.monitoring = false
	if _swing != null:
		_swing.visible = false
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.6, 0.85, 1.0, 0.5)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_swing.material_override = material


func _physics_process(_delta: float) -> void:
	_tick_hit_flash()
	if health.is_dead():
		if not _logged_death:
			_logged_death = true
			_director.log_event(&"player", &"death")
		_set_locked(true, Vector3.ZERO)
		return
	if _director.frozen_tick:
		_capture_frozen_input()
		_set_locked(true, Vector3.ZERO)
		return
	_combat_frame += 1
	_capture_input()
	if Input.is_action_just_pressed(&"dodge") and _can_dodge():
		_start_dodge()
		return
	if _dodge.is_active():
		_tick_dodge()
		return
	if _attack.is_attacking():
		_tick_attack()
		return
	_try_start_from_locomotion()


func attack_phase() -> AttackState.Phase:
	return _attack.phase


## Capture/debug hook: queue a light attack without hardware input.
func debug_request_attack() -> void:
	if health.is_dead():
		return
	_director.log_event(&"player", &"input_light")
	_buffer.push(_combat_frame)


func current_swing_id() -> int:
	return _swing_id


func _capture_input() -> void:
	if Input.is_action_just_pressed(&"light_attack"):
		_director.log_event(&"player", &"input_light")
		_buffer.push(_combat_frame)
	if Input.is_action_just_pressed(&"dodge"):
		_director.log_event(&"player", &"input_dodge")
	if _buffer.has_pending() and not _buffer.is_valid(_combat_frame):
		_buffer.clear()


func _capture_frozen_input() -> void:
	if Input.is_action_just_pressed(&"light_attack"):
		_director.log_event(&"player", &"input_light")
		_buffer.push(_combat_frame + 1)
	if Input.is_action_just_pressed(&"dodge"):
		_director.log_event(&"player", &"input_dodge")


func _try_start_from_locomotion() -> void:
	if _buffer.has_pending() and _buffer.consume(_combat_frame):
		_start_attack(1)
	else:
		_set_locked(false, Vector3.ZERO)


func _start_attack(combo_index: int) -> void:
	_swing_id += 1
	_attack.start(combo_index)
	_attack_dir = _aim_direction()
	_player.facing = 1 if _attack_dir.x >= 0.0 else -1
	_hitbox.rotation.y = atan2(-_attack_dir.z, _attack_dir.x)
	_was_active = false
	_set_active_visuals(false)
	_set_locked(true, Vector3.ZERO)
	_director.log_event(&"player", &"action_start", _swing_id)


func _tick_attack() -> void:
	if _attack.is_active():
		_resolve_hits()
	_attack.tick()
	var active_now := _attack.is_active()
	if active_now and not _was_active:
		_director.log_event(&"player", &"active_start", _swing_id)
		_set_active_visuals(true)
	elif _was_active and not active_now:
		_director.log_event(&"player", &"active_end", _swing_id)
		_set_active_visuals(false)
	_was_active = active_now
	if not _attack.is_attacking():
		_set_locked(false, Vector3.ZERO)
		return
	_set_locked(true, Vector3.ZERO)
	if _attack.can_combo() and _buffer.has_pending() and _buffer.is_valid(_combat_frame):
		if _buffer.consume(_combat_frame):
			_start_attack(_attack.combo_index + 1)


func _resolve_hits() -> void:
	var shape := _hitbox_shape.shape
	if shape == null:
		return
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = _hitbox.global_transform * _hitbox_shape.transform
	params.collision_mask = ENEMY_HURTBOX_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := _player.get_world_3d().direct_space_state.intersect_shape(params, 8)
	for hit in hits:
		var area := hit.collider as Area3D
		if area == null or not area.is_in_group(&"enemy_hurtbox"):
			continue
		var receiver: Node = area
		if not receiver.has_method(&"apply_hit"):
			receiver = area.get_parent()
		var target_id := 0
		if receiver.get(&"target_id") != null:
			target_id = int(receiver.get(&"target_id"))
		if not _registry.try_register(_swing_id, target_id):
			continue
		var applied := 0
		if receiver.has_method(&"apply_hit"):
			applied = int(receiver.call(&"apply_hit", tuning.light_damage))
		_director.log_event(&"player", &"hit", _swing_id, target_id)
		_director.log_event(&"player", &"damage", _swing_id, target_id, applied)
		_director.request_hitstop(tuning.hitstop_frames)


func _can_dodge() -> bool:
	if _dodge.is_active():
		return false
	if not _attack.is_attacking():
		return true
	return _attack.phase == AttackState.Phase.RECOVERY


func _start_dodge() -> void:
	if _attack.is_attacking():
		_attack.cancel()
		_was_active = false
		_set_active_visuals(false)
	_buffer.clear()
	_dodge.start()
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input.length_squared() > 0.0001:
		_dodge_dir = Vector3(input.x, 0.0, input.y).normalized()
	else:
		_dodge_dir = Vector3(float(_player.facing), 0.0, 0.0)
	_director.log_event(&"player", &"action_start", 0)
	_set_locked(true, _dodge_dir * tuning.dodge_speed)


func _tick_dodge() -> void:
	_dodge.tick()
	if _dodge.is_active():
		_set_locked(true, _dodge_dir * tuning.dodge_speed)
	else:
		_set_locked(false, Vector3.ZERO)


func _aim_direction() -> Vector3:
	var target := Vector3.ZERO
	var has_target := false
	if aim_override_enabled:
		target = aim_override_point
		has_target = true
	elif _aim != null and _aim.has_hit:
		target = _aim.aim_point
		has_target = true
	if has_target:
		var direction := target - _player.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			return direction.normalized()
	return Vector3(float(_player.facing), 0.0, 0.0)


func reset() -> void:
	health.reset()
	_attack.cancel()
	_dodge.cancel()
	_buffer.clear()
	_registry.clear()
	_hit_flash_frames = 0
	_logged_death = false
	_was_active = false
	_set_active_visuals(false)
	_set_locked(false, Vector3.ZERO)
	if _sprite != null:
		_sprite.modulate = Color.WHITE


func is_invulnerable() -> bool:
	return _dodge.is_invulnerable()


func is_dead() -> bool:
	return health.is_dead()


func hp() -> int:
	return health.hp


func apply_hit(amount: int) -> int:
	var applied := health.apply_damage(amount)
	if applied > 0:
		_hit_flash_frames = 6
		if _sprite != null:
			_sprite.modulate = Color(1.0, 0.35, 0.35)
	return applied


func _tick_hit_flash() -> void:
	if _hit_flash_frames <= 0:
		return
	_hit_flash_frames -= 1
	if _hit_flash_frames == 0 and _sprite != null:
		_sprite.modulate = Color.WHITE


func _set_locked(locked: bool, override_velocity: Vector3) -> void:
	_player.movement_locked = locked
	_player.override_velocity = override_velocity


func _set_active_visuals(active: bool) -> void:
	if _swing != null:
		_swing.visible = active
