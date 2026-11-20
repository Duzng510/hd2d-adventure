class_name Ranged
extends Grunt

## Ranged role: kite band from RangedAI, fires one projectile per attack
## instance on active start. All values come from the CombatTuning ranged_* group.

const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const RANGED_BASE_COLOR := Color(0.55, 0.45, 0.8)


func _max_hp() -> int:
	return tuning.ranged_max_hp


func _detect_range() -> float:
	return tuning.ranged_max_range


func _attack_range() -> float:
	return tuning.ranged_min_range


func _approach_speed() -> float:
	return tuning.ranged_approach_speed


func _telegraph_frames() -> int:
	return tuning.ranged_telegraph_frames


func _active_frames() -> int:
	return tuning.ranged_active_frames


func _recovery_frames() -> int:
	return tuning.ranged_recovery_frames


func _damage() -> int:
	return tuning.ranged_damage


func _base_color() -> Color:
	return RANGED_BASE_COLOR


func _log_entity() -> StringName:
	return &"ranged"


func _create_ai() -> GruntAI:
	return RangedAI.new(
		_detect_range(),
		_attack_range(),
		_telegraph_frames(),
		_active_frames(),
		_recovery_frames()
	)


func _move() -> void:
	if _ai.state == GruntAI.State.CHASE:
		velocity = _ai.move_dir * _approach_speed()
	else:
		velocity = Vector3.ZERO
	move_and_slide()


func _resolve_damage() -> void:
	pass


func _on_active_start() -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	projectile.tuning = tuning
	projectile.director = _director
	projectile.player_combat = _player_combat
	projectile.attack_id = current_attack_id()
	projectile.direction = _ai.attack_dir
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(0.0, 0.8, 0.0) + _ai.attack_dir * 0.6
	projectile.name = "Projectile%d" % current_attack_id()
	_director.log_event(_log_entity(), &"projectile_fire", current_attack_id())
