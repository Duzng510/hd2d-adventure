class_name Grunt
extends CharacterBody3D

const PLAYER_HURTBOX_MASK := 16
const PLAYER_TARGET_ID := 2
const BASE_COLOR := Color(0.55, 0.3, 0.35)
const TELEGRAPH_COLOR := Color(1.0, 0.55, 0.2)

@export var tuning: CombatTuning
@export var player_path: NodePath = NodePath("../Player")
@export var director_path: NodePath = NodePath("../CombatDirector")
@export var target_id: int = 1
@export var spawn_position := Vector3(3.0, 0.0, 0.0)

var health: Health

var _player: PlayerController
var _player_combat: PlayerCombat
var _director: CombatDirector
var _ai: GruntAI
var _registry := HitRegistry.new()
var _attack_id: int = 0
var _flash_frames: int = 0
var _previous_state: GruntAI.State = GruntAI.State.IDLE
var _body_material: StandardMaterial3D

@onready var _body_mesh: MeshInstance3D = $MeshInstance3D
@onready var _telegraph: MeshInstance3D = $Telegraph
@onready var _hurtbox: Area3D = $Hurtbox
@onready var _hitbox: Area3D = $AttackHitbox
@onready var _hitbox_shape: CollisionShape3D = $AttackHitbox/CollisionShape3D


func _ready() -> void:
	_player = get_node(player_path)
	_player_combat = _player.get_node("PlayerCombat")
	_director = get_node(director_path)
	_ai = GruntAI.new(
		_detect_range(),
		_attack_range(),
		_telegraph_frames(),
		_active_frames(),
		_recovery_frames()
	)
	health = Health.new(_max_hp())
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = _base_color()
	_body_mesh.material_override = _body_material
	_telegraph.visible = false
	var telegraph_material := StandardMaterial3D.new()
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_material.albedo_texture = PlaceholderTextures.make_telegraph_texture()
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	telegraph_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_telegraph.material_override = telegraph_material
	_hitbox.monitoring = false
	_previous_state = _ai.state


func _physics_process(_delta: float) -> void:
	_tick_flash()
	if health.is_dead():
		velocity = Vector3.ZERO
		return
	if _director.frozen_tick:
		velocity = Vector3.ZERO
		return
	_ai.tick(_player.global_position, global_position)
	_handle_events()
	if _ai.state == GruntAI.State.ACTIVE:
		_resolve_damage()
	_move()


func ai_state() -> GruntAI.State:
	return _ai.state


func current_attack_id() -> int:
	return _attack_id


func hp() -> int:
	return health.hp


func apply_hit(amount: int) -> int:
	var applied := health.apply_damage(amount)
	if applied > 0:
		_flash_frames = 6
		if health.is_dead():
			_die()
	return applied


func reset() -> void:
	health.reset()
	_ai.reset()
	_registry.clear()
	_attack_id = 0
	_flash_frames = 0
	_previous_state = _ai.state
	global_position = spawn_position
	velocity = Vector3.ZERO
	_body_mesh.visible = true
	_telegraph.visible = false
	_hurtbox.collision_layer = 32
	_body_material.albedo_color = _base_color()


func _handle_events() -> void:
	if _ai.alert_pending:
		_ai.alert_pending = false
		_director.log_event(_log_entity(), &"alert")
	if _ai.state == _previous_state:
		return
	match _ai.state:
		GruntAI.State.CHASE:
			_telegraph.visible = false
			_body_material.albedo_color = _base_color()
		GruntAI.State.TELEGRAPH:
			_attack_id += 1
			_hitbox.rotation.y = atan2(-_ai.attack_dir.z, _ai.attack_dir.x)
			_telegraph.visible = true
			_body_material.albedo_color = _telegraph_color()
			_director.log_event(_log_entity(), &"telegraph_start", _attack_id)
		GruntAI.State.ACTIVE:
			_telegraph.visible = false
			_body_material.albedo_color = _base_color()
			_director.log_event(_log_entity(), &"telegraph_end", _attack_id)
			_director.log_event(_log_entity(), &"active_start", _attack_id)
		GruntAI.State.RECOVERY:
			_director.log_event(_log_entity(), &"active_end", _attack_id)
	_previous_state = _ai.state


func _move() -> void:
	if _ai.state == GruntAI.State.CHASE and _ai.distance > _attack_range():
		velocity = _ai.move_dir * _approach_speed()
	else:
		velocity = Vector3.ZERO
	move_and_slide()


func _resolve_damage() -> void:
	if _player_combat.is_dead():
		return
	var shape := _hitbox_shape.shape
	if shape == null:
		return
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = _hitbox.global_transform * _hitbox_shape.transform
	params.collision_mask = PLAYER_HURTBOX_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_shape(params, 8)
	for hit in hits:
		var area := hit.collider as Area3D
		if area == null or not area.is_in_group(&"player_hurtbox"):
			continue
		if _player_combat.is_invulnerable():
			continue
		if not _registry.try_register(_attack_id, PLAYER_TARGET_ID):
			continue
		var applied := _player_combat.apply_hit(_damage())
		_director.log_event(&"grunt", &"hit", _attack_id, PLAYER_TARGET_ID)
		_director.log_event(&"grunt", &"damage", _attack_id, PLAYER_TARGET_ID, applied)
		_director.request_hitstop(tuning.hitstop_frames)


func _tick_flash() -> void:
	if _flash_frames <= 0:
		return
	_flash_frames -= 1
	if _flash_frames > 3:
		_body_material.albedo_color = Color.WHITE
	elif _flash_frames == 0:
		_body_material.albedo_color = _telegraph_color() if _ai.state == GruntAI.State.TELEGRAPH else _base_color()


func _die() -> void:
	_director.log_event(&"grunt", &"death", _attack_id)
	velocity = Vector3.ZERO
	_body_mesh.visible = false
	_telegraph.visible = false
	_hurtbox.collision_layer = 0


func _max_hp() -> int:
	return tuning.grunt_max_hp


func _detect_range() -> float:
	return tuning.grunt_detect_range


func _attack_range() -> float:
	return tuning.grunt_attack_range


func _approach_speed() -> float:
	return tuning.grunt_approach_speed


func _telegraph_frames() -> int:
	return tuning.grunt_telegraph_frames


func _active_frames() -> int:
	return tuning.grunt_active_frames


func _recovery_frames() -> int:
	return tuning.grunt_recovery_frames


func _damage() -> int:
	return tuning.grunt_damage


func _base_color() -> Color:
	return BASE_COLOR


func _telegraph_color() -> Color:
	return TELEGRAPH_COLOR


func _log_entity() -> StringName:
	return &"grunt"
