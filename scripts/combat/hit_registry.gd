class_name HitRegistry
extends RefCounted

## One-hit-per-swing registry keyed by (attack_id, target_id).

var enforce: bool = true
var duplicate_applied: int = 0
var blocked_repeats: int = 0

var _hits: Dictionary = {}


func try_register(attack_id: int, target_id: int) -> bool:
	var targets: Dictionary = _hits.get(attack_id, {})
	if targets.has(target_id):
		if enforce:
			blocked_repeats += 1
			return false
		duplicate_applied += 1
		return true
	targets[target_id] = true
	_hits[attack_id] = targets
	return true


func clear() -> void:
	_hits.clear()
	duplicate_applied = 0
	blocked_repeats = 0
