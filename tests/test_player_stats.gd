extends SceneTree

## T-029: PlayerStats is the single runtime stat source; base numbers mirror
## combat_tuning and modifiers compose add-before-multiply with a floor.

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var tuning := CombatTuning.new()
	var stats := PlayerStats.new(tuning)

	_check(stats.light_damage() == 10, "base damage mirrors tuning")
	_check(stats.player_max_hp() == 100, "base hp mirrors tuning")
	_check(stats.light_startup_frames() == 4 and stats.light_active_frames() == 3
		and stats.light_recovery_frames() == 10, "base swing frames mirror tuning")
	_check(is_equal_approx(stats.move_speed(), 4.0), "base move speed comes from tuning")
	_check(is_equal_approx(stats.light_reach(), 1.4), "base reach mirrors tuning")
	_check(stats.light_combo_hits() == 3 and stats.combo_window_frames() == 10,
		"base combo mirrors tuning")
	_check(stats.fatigue_free_swings() == 3 and stats.fatigue_step_frames() == 4
		and stats.fatigue_max_frames() == 12 and stats.fatigue_decay_frames() == 6,
		"base fatigue mirrors tuning")

	stats.add_modifier(&"heavy_edge", {&"light_damage_add": 2.0, &"light_damage_mult": 1.5})
	# add first, multiply after: (10 + 2) * 1.5 = 18. The wrong order gives 17.
	_check(stats.light_damage() == (17 if _negative else 18),
		"adds apply before multipliers (got %d)" % stats.light_damage())

	stats.add_modifier(&"quick_rhythm", {&"light_damage_mult": 0.9})
	_check(stats.light_damage() == (15 if _negative else 16),
		"modifiers multiply together: floor((10+2)*1.5*0.9) = 16 (got %d)" % stats.light_damage())

	stats.add_modifier(&"heavy_edge", {&"light_damage_mult": 2.0})
	# Re-adding a source replaces it. Stacking both heavy_edge ops instead of
	# replacing would give floor((10+2)*1.5*2.0*0.9) = floor(32.4) = 32;
	# replacement gives floor((10+2)*2.0*0.9) = floor(21.6) = 18.
	_check(stats.light_damage() == (32 if _negative else 18),
		"re-adding the same source replaces it instead of stacking (got %d)"
		% stats.light_damage())

	stats.remove_modifier(&"heavy_edge")
	_check(stats.light_damage() == (10 if _negative else 9),
		"removing a source restores its share: floor(10*0.9) = 9 (got %d)" % stats.light_damage())

	stats.clear_modifiers()
	_check(stats.light_damage() == 10, "clear wipes every modifier")

	stats.add_modifier(&"floor_probe", {&"light_damage_add": -500.0})
	_check(stats.light_damage() == (0 if _negative else 1),
		"damage clamps at 1, never 0 or negative")
	stats.clear_modifiers()

	var changes := [0]
	stats.changed.connect(func() -> void: changes[0] += 1)
	stats.add_modifier(&"probe", {&"light_damage_mult": 1.3})
	stats.remove_modifier(&"probe")
	stats.remove_modifier(&"missing")
	_check(changes[0] == (3 if _negative else 2),
		"changed fires per real mutation only (got %d)" % changes[0])

	var hp_stats := PlayerStats.new(CombatTuning.new())
	hp_stats.add_modifier(&"root_armor", {&"player_max_hp_add": 40.0,
		&"player_move_speed_mult": 0.88})
	_check(hp_stats.player_max_hp() == 140, "hp add lands on the base")
	_check(is_equal_approx(hp_stats.move_speed(), 3.52), "move speed multiplies the base")

	if _failures == 0:
		print("PASS test_player_stats: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_player_stats: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
