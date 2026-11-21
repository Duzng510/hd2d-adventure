class_name PlayerStats
extends RefCounted

## T-029: single runtime source of player stats. combat_tuning.tres stays the
## immutable base; modifiers arrive keyed by source and compose add-then-mult.

signal changed

var _base: CombatTuning
var _modifiers: Array[Dictionary] = []


func _init(tuning: CombatTuning) -> void:
	_base = tuning


func add_modifier(source: StringName, ops: Dictionary) -> void:
	var entry := {"source": source, "ops": ops.duplicate()}
	for i in _modifiers.size():
		if _modifiers[i]["source"] == source:
			_modifiers[i] = entry
			changed.emit()
			return
	_modifiers.append(entry)
	changed.emit()


func remove_modifier(source: StringName) -> void:
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i]["source"] == source:
			_modifiers.remove_at(i)
			changed.emit()
			return


func clear_modifiers() -> void:
	if _modifiers.is_empty():
		return
	_modifiers.clear()
	changed.emit()


func active_modifiers() -> Array[Dictionary]:
	return _modifiers.duplicate(true)


func light_damage() -> int:
	return _int(&"light_damage", _base.light_damage)


func player_max_hp() -> int:
	return _int(&"player_max_hp", _base.player_max_hp)


func light_startup_frames() -> int:
	return _int(&"light_startup_frames", _base.light_startup_frames)


func light_active_frames() -> int:
	return _int(&"light_active_frames", _base.light_active_frames)


func light_recovery_frames() -> int:
	return _int(&"light_recovery_frames", _base.light_recovery_frames)


func light_combo_hits() -> int:
	return _int(&"light_combo_hits", _base.light_combo_hits)


func combo_window_frames() -> int:
	return _int(&"combo_window_frames", _base.combo_window_frames)


func fatigue_free_swings() -> int:
	return _int(&"fatigue_free_swings", _base.fatigue_free_swings)


func fatigue_step_frames() -> int:
	return _int(&"fatigue_step_frames", _base.fatigue_step_frames)


func fatigue_max_frames() -> int:
	return _int(&"fatigue_max_frames", _base.fatigue_max_frames)


func fatigue_decay_frames() -> int:
	return _int(&"fatigue_decay_frames", _base.fatigue_decay_frames)


func dodge_total_frames() -> int:
	return _int(&"dodge_total_frames", _base.dodge_total_frames)


func dodge_iframe_frames() -> int:
	return _int(&"dodge_iframe_frames", _base.dodge_iframe_frames)


func light_reach() -> float:
	return _value(&"light_reach", _base.light_reach, 0.1)


func move_speed() -> float:
	return _value(&"player_move_speed", _base.player_move_speed, 0.1)


func dodge_speed() -> float:
	return _value(&"dodge_speed", _base.dodge_speed, 0.1)


func _int(key: StringName, base: int) -> int:
	return int(floor(_value(key, float(base), 1.0)))


func _value(key: StringName, base: float, min_value: float) -> float:
	var add := 0.0
	var mult := 1.0
	for entry in _modifiers:
		var ops: Dictionary = entry["ops"]
		add += float(ops.get(StringName(str(key, "_add")), 0.0))
		mult *= float(ops.get(StringName(str(key, "_mult")), 1.0))
	return maxf((base + add) * mult, min_value)
