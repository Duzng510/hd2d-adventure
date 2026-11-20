class_name Boss
extends Grunt

## Grove Warden mini-boss: three attacks with distinct ground telegraphs and one
## phase switch. All values come from the CombatTuning boss_* group.

const BOSS_BASE_COLOR := Color(0.32, 0.38, 0.5)
const SWITCH_TELEGRAPH_SIZE := 6.0
const LUNGE_TRACK_WIDTH := 1.6

var attack_textures: Dictionary = {}

var _boss_ai: BossAI

@onready var _smash_hitbox: Area3D = $SmashHitbox
@onready var _lunge_hitbox: Area3D = $LungeHitbox
@onready var _sweep_hitbox: Area3D = $SweepHitbox
@onready var _smash_shape: CollisionShape3D = $SmashHitbox/CollisionShape3D
@onready var _lunge_shape: CollisionShape3D = $LungeHitbox/CollisionShape3D
@onready var _sweep_shape: CollisionShape3D = $SweepHitbox/CollisionShape3D


func _ready() -> void:
	super()
	attack_textures[BossAI.Attack.SMASH] = PlaceholderTextures.make_telegraph_disc(tuning.boss_smash_radius * 2.0)
	attack_textures[BossAI.Attack.LUNGE] = PlaceholderTextures.make_telegraph_arrow(tuning.boss_lunge_range, LUNGE_TRACK_WIDTH)
	attack_textures[BossAI.Attack.SWEEP] = PlaceholderTextures.make_telegraph_bands(tuning.boss_sweep_radius * 2.0)
	attack_textures[BossAI.Attack.SWITCH] = PlaceholderTextures.make_telegraph_spokes(SWITCH_TELEGRAPH_SIZE)


func _create_ai() -> GruntAI:
	_boss_ai = BossAI.new(tuning)
	return _boss_ai


func attack_kind() -> int:
	return _boss_ai.attack


func phase_number() -> int:
	return _boss_ai.phase


func _max_hp() -> int:
	return tuning.boss_max_hp


func _detect_range() -> float:
	return tuning.boss_detect_range


func _approach_speed() -> float:
	return tuning.boss_chase_speed


func _base_color() -> Color:
	return BOSS_BASE_COLOR


func _log_entity() -> StringName:
	return &"boss"


func apply_hit(amount: int) -> int:
	var applied := super.apply_hit(amount)
	if applied > 0:
		_boss_ai.report_damage(health.hp, health.max_hp)
	return applied


func reset() -> void:
	super()
	_lunge_hitbox.rotation.y = 0.0


func _handle_events() -> void:
	if _ai.alert_pending:
		_ai.alert_pending = false
		_director.log_event(_log_entity(), &"alert")
	if _boss_ai.phase_flip_pending:
		_boss_ai.phase_flip_pending = false
		_director.log_event(_log_entity(), &"boss_phase", _attack_id, 0, _boss_ai.phase)
	if _ai.state == _previous_state:
		return
	match _ai.state:
		GruntAI.State.CHASE:
			_telegraph.visible = false
			_body_material.albedo_color = _base_color()
		GruntAI.State.TELEGRAPH:
			_attack_id += 1
			_apply_telegraph_visual()
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
	if _ai.state == GruntAI.State.ACTIVE and _boss_ai.attack == BossAI.Attack.LUNGE:
		velocity = _ai.move_dir * _dash_speed()
	elif _ai.state == GruntAI.State.CHASE:
		velocity = _ai.move_dir * _approach_speed()
	else:
		velocity = Vector3.ZERO
	move_and_slide()


func _resolve_damage() -> void:
	if _boss_ai.attack == BossAI.Attack.SWITCH or _player_combat.is_dead():
		return
	var area := _active_hitbox()
	var shape_node := _active_shape()
	if area == null or shape_node == null or shape_node.shape == null:
		return
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape_node.shape
	params.transform = area.global_transform * shape_node.transform
	params.collision_mask = PLAYER_HURTBOX_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_shape(params, 8)
	for hit in hits:
		var hurt := hit.collider as Area3D
		if hurt == null or not hurt.is_in_group(&"player_hurtbox"):
			continue
		if _player_combat.is_invulnerable():
			continue
		if not _registry.try_register(_attack_id, PLAYER_TARGET_ID):
			continue
		var applied := _player_combat.apply_hit(_attack_damage())
		_director.log_event(_log_entity(), &"hit", _attack_id, PLAYER_TARGET_ID)
		_director.log_event(_log_entity(), &"damage", _attack_id, PLAYER_TARGET_ID, applied)
		_director.request_hitstop(tuning.hitstop_frames)


func _apply_telegraph_visual() -> void:
	var kind := _boss_ai.attack
	var dir := _ai.attack_dir
	var angle := atan2(-dir.z, dir.x)
	var size := Vector3(1.0, 1.0, 1.0)
	var origin := Vector3(0.0, 0.03, 0.0)
	match kind:
		BossAI.Attack.SMASH:
			size = Vector3(tuning.boss_smash_radius * 2.0, tuning.boss_smash_radius * 2.0, 1.0)
		BossAI.Attack.SWEEP:
			size = Vector3(tuning.boss_sweep_radius * 2.0, tuning.boss_sweep_radius * 2.0, 1.0)
		BossAI.Attack.SWITCH:
			size = Vector3(SWITCH_TELEGRAPH_SIZE, SWITCH_TELEGRAPH_SIZE, 1.0)
		BossAI.Attack.LUNGE:
			size = Vector3(tuning.boss_lunge_range, LUNGE_TRACK_WIDTH, 1.0)
			origin += Vector3(dir.x, 0.0, dir.z) * (tuning.boss_lunge_range * 0.5)
			_lunge_hitbox.rotation.y = angle
	var spin := Basis(Vector3.UP, angle if kind == BossAI.Attack.LUNGE else 0.0)
	var pivot := Basis(Vector3.RIGHT, -PI / 2.0)
	_telegraph.transform = Transform3D(spin * pivot * Basis.from_scale(size), origin)
	_telegraph.material_override.albedo_texture = attack_textures.get(kind)
	_telegraph.material_override.albedo_color = _telegraph_color_for(kind)
	_telegraph.visible = true
	_body_material.albedo_color = _telegraph_color_for(kind)


func _telegraph_color_for(kind: int) -> Color:
	match kind:
		BossAI.Attack.LUNGE:
			return Color(1.0, 0.9, 0.35)
		BossAI.Attack.SWEEP:
			return Color(0.7, 0.45, 1.0)
		BossAI.Attack.SWITCH:
			return Color(0.95, 0.95, 1.0)
		_:
			return TELEGRAPH_COLOR


func _active_hitbox() -> Area3D:
	match _boss_ai.attack:
		BossAI.Attack.LUNGE:
			return _lunge_hitbox
		BossAI.Attack.SWEEP:
			return _sweep_hitbox
		_:
			return _smash_hitbox


func _active_shape() -> CollisionShape3D:
	match _boss_ai.attack:
		BossAI.Attack.LUNGE:
			return _lunge_shape
		BossAI.Attack.SWEEP:
			return _sweep_shape
		_:
			return _smash_shape


func _attack_damage() -> int:
	match _boss_ai.attack:
		BossAI.Attack.LUNGE:
			return tuning.boss_lunge_damage
		BossAI.Attack.SWEEP:
			return tuning.boss_sweep_damage
		_:
			return tuning.boss_smash_damage


func _dash_speed() -> float:
	return tuning.boss_lunge_range / float(tuning.boss_lunge_active_frames) * 60.0
