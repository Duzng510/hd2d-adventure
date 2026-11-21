class_name BuffPool
extends RefCounted

## T-030: the six buffs from spec §6.1. Keys are the kernel's stat names;
## a wrong key would silently no-op, so test_buff_kernel proves each entry moves
## at least one stat. Numbers stay HYPOTHESIS until L4.


static func pool() -> Array[Dictionary]:
	return [
		{"id": &"heavy_edge", "title": UiCopy.BUFF_HEAVY_EDGE,
			"gain": UiCopy.BUFF_HEAVY_EDGE_GAIN, "cost": UiCopy.BUFF_HEAVY_EDGE_COST,
			"ops": {&"light_damage_mult": 1.3, &"light_recovery_frames_add": 3.0}},
		{"id": &"quick_rhythm", "title": UiCopy.BUFF_QUICK_RHYTHM,
			"gain": UiCopy.BUFF_QUICK_RHYTHM_GAIN, "cost": UiCopy.BUFF_QUICK_RHYTHM_COST,
			"ops": {&"light_recovery_frames_add": -3.0, &"combo_window_frames_add": 4.0,
				&"light_damage_mult": 0.9, &"fatigue_free_swings_add": -1.0}},
		{"id": &"root_armor", "title": UiCopy.BUFF_ROOT_ARMOR,
			"gain": UiCopy.BUFF_ROOT_ARMOR_GAIN, "cost": UiCopy.BUFF_ROOT_ARMOR_COST,
			"ops": {&"player_max_hp_add": 40.0, &"player_move_speed_mult": 0.88}},
		{"id": &"slow_breath", "title": UiCopy.BUFF_SLOW_BREATH,
			"gain": UiCopy.BUFF_SLOW_BREATH_GAIN, "cost": UiCopy.BUFF_SLOW_BREATH_COST,
			"ops": {&"fatigue_free_swings_add": 2.0, &"fatigue_decay_frames_add": -2.0,
				&"light_recovery_frames_add": 2.0}},
		{"id": &"long_reach", "title": UiCopy.BUFF_LONG_REACH,
			"gain": UiCopy.BUFF_LONG_REACH_GAIN, "cost": UiCopy.BUFF_LONG_REACH_COST,
			"ops": {&"light_reach_add": 0.4, &"light_startup_frames_add": 2.0}},
		{"id": &"fourth_hook", "title": UiCopy.BUFF_FOURTH_HOOK,
			"gain": UiCopy.BUFF_FOURTH_HOOK_GAIN, "cost": UiCopy.BUFF_FOURTH_HOOK_COST,
			"ops": {&"light_combo_hits_add": 1.0, &"combo_window_frames_add": -4.0}},
	]


static func index_of(id: StringName) -> int:
	var entries := pool()
	for i in entries.size():
		if entries[i]["id"] == id:
			return i
	return -1
