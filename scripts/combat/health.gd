class_name Health
extends RefCounted

var max_hp: int
var hp: int


func _init(p_max_hp: int) -> void:
	max_hp = maxi(p_max_hp, 1)
	hp = max_hp


func apply_damage(amount: int) -> int:
	if hp <= 0 or amount <= 0:
		return 0
	var applied := mini(amount, hp)
	hp -= applied
	return applied


func is_dead() -> bool:
	return hp <= 0


func reset() -> void:
	hp = max_hp
