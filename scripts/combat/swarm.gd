class_name Swarm
extends Grunt

## Swarm role: same state machine as Grunt with a smaller body and faster,
## weaker attacks. All values come from the CombatTuning swarm_* group.

const SWARM_BASE_COLOR := Color(0.45, 0.65, 0.35)


func _max_hp() -> int:
	return tuning.swarm_max_hp


func _detect_range() -> float:
	return tuning.swarm_detect_range


func _attack_range() -> float:
	return tuning.swarm_attack_range


func _approach_speed() -> float:
	return tuning.swarm_approach_speed


func _telegraph_frames() -> int:
	return tuning.swarm_telegraph_frames


func _active_frames() -> int:
	return tuning.swarm_active_frames


func _recovery_frames() -> int:
	return tuning.swarm_recovery_frames


func _damage() -> int:
	return tuning.swarm_damage


func _base_color() -> Color:
	return SWARM_BASE_COLOR


func _log_entity() -> StringName:
	return &"swarm"
