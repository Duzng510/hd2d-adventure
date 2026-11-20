class_name Projectile
extends Area3D

## Ranged projectile: straight line, damages the player at most once, despawns
## on player hit, world contact or lifetime expiry (each logged with a reason).

const WORLD_MASK := 1
const PLAYER_HURTBOX_MASK := 16
const PLAYER_TARGET_ID := 2
const DESPAWN_HIT := 1
const DESPAWN_WALL := 2
const DESPAWN_LIFETIME := 3

@export var tuning: CombatTuning
@export var director: CombatDirector
@export var player_combat: PlayerCombat
var attack_id: int = 0
var direction := Vector3.RIGHT

var _frames: int = 0
var _dead := false


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.85, 0.6, 1.0)
	$MeshInstance3D.material_override = material


func _physics_process(_delta: float) -> void:
	if _dead or director == null or director.frozen_tick:
		return
	_frames += 1
	if _frames > tuning.ranged_projectile_lifetime_frames:
		_despawn(DESPAWN_LIFETIME)
		return
	var from := global_position
	var to := from + direction * (tuning.ranged_projectile_speed / 60.0)
	var ray := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	ray.collide_with_areas = false
	var wall_hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not wall_hit.is_empty():
		global_position = wall_hit.position
		_despawn(DESPAWN_WALL)
		return
	if _try_hit_player(to):
		return
	global_position = to


func _try_hit_player(at: Vector3) -> bool:
	if player_combat == null or player_combat.is_dead() or player_combat.is_invulnerable():
		return false
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = $CollisionShape3D.shape
	params.transform = Transform3D(Basis(), at)
	params.collision_mask = PLAYER_HURTBOX_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_shape(params, 8)
	for hit in hits:
		var area := hit.collider as Area3D
		if area == null or not area.is_in_group(&"player_hurtbox"):
			continue
		var applied := player_combat.apply_hit(tuning.ranged_damage)
		director.log_event(&"projectile", &"projectile_hit", attack_id, PLAYER_TARGET_ID)
		director.log_event(&"projectile", &"damage", attack_id, PLAYER_TARGET_ID, applied)
		director.request_hitstop(tuning.hitstop_frames)
		global_position = at
		_despawn(DESPAWN_HIT)
		return true
	return false


func _despawn(reason: int) -> void:
	_dead = true
	if director != null:
		director.log_event(&"projectile", &"projectile_despawn", attack_id, 0, reason)
	queue_free()
