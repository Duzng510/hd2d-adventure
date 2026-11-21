extends SceneTree

## T-030: the chooser pauses the world, shows exactly three cards from the
## emitted offer, applies the picked buff through the encounter, and ESC cannot
## open the character sheet while a pick is pending. auto_pick keeps every
## harness/L4 auto run unpaused and silent.

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	await _run()
	_finish()


func _run() -> void:
	var arena: Node = load("res://scenes/phase_c/grove_arena.tscn").instantiate()
	root.add_child(arena)
	# physics_frame fires before _physics_process, so the process frame after it
	# is what guarantees _start_run() has built the buff kernel.
	await physics_frame
	await process_frame
	var encounter: WaveEncounter = arena.get_node("WaveEncounter")
	_check(encounter.buff != null, "the first run built a buff kernel")

	var choice := BuffChoice.new()
	choice.encounter_path = NodePath("../WaveEncounter")
	choice.auto_pick = false
	arena.add_child(choice)
	await process_frame
	_check(encounter.buff_pick_enabled, "mounting the chooser opts the flow in")

	var sheet := CharacterSheet.new()
	root.add_child(sheet)
	await process_frame
	sheet.set_sources(encounter_scene_player_stats(arena), func() -> int: return 55, encounter)
	sheet.refresh()
	_check(sheet.body_text().contains(UiCopy.HUD_WAVE_PROGRESS % [1, 3]),
		"the sheet shows the current wave from the encounter kernel")
	_check(sheet.body_text().contains(str(encounter.buff_seed())),
		"the sheet shows the run's buff seed")

	var emitted: Array = []
	# Lambdas capture locals by value, so mutate the (reference) array instead of
	# reassigning the variable.
	encounter.buff_offer.connect(func(offers: Array) -> void: emitted.append_array(offers),
		CONNECT_ONE_SHOT)
	encounter.debug_force_buff_pending()
	await process_frame
	_check(paused == (not _negative), "presenting the offer pauses the world")
	_check(choice.is_open(), "the chooser is visible")
	_check(choice.card_count() == 3, "three cards are shown")
	var titles_ok := emitted.size() == 3
	if titles_ok:
		for i in 3:
			titles_ok = titles_ok and choice.card_text(i).contains(emitted[i]["title"])
	_check(titles_ok, "the cards carry the titles from the emitted offer")

	await _press_escape()
	_check(not sheet.is_open(), "ESC is ignored while the pick is pending")
	_check(paused, "the pick is still pending after ESC")

	var first_id: StringName = emitted[0]["id"]
	choice.debug_pick(0)
	_check(not paused and not choice.is_open(), "picking closes the chooser and unpauses")
	var stats: PlayerStats = encounter_scene_player_stats(arena)
	_check(stats.active_modifiers().size() == (0 if _negative else 1),
		"the pick landed on PlayerStats exactly once")
	_check(stats.active_modifiers().is_empty() or stats.active_modifiers()[0]["source"] == first_id,
		"the landed modifier carries the picked id")
	sheet.refresh()
	_check(sheet.body_text().contains(emitted[0]["title"]),
		"the buff row shows the pool title for the picked id")
	choice.queue_free()
	await process_frame

	# auto_pick: the harness path must resolve the offer with no pause and no UI.
	var auto_choice := BuffChoice.new()
	auto_choice.encounter_path = NodePath("../WaveEncounter")
	auto_choice.auto_pick = true
	arena.add_child(auto_choice)
	await process_frame
	encounter.debug_force_buff_pending()
	await process_frame
	_check(not paused and not auto_choice.is_open(), "auto pick neither pauses nor opens the panel")
	_check(stats.active_modifiers().size() == (0 if _negative else 2),
		"auto pick applies the first card through the encounter")

	auto_choice.queue_free()
	arena.queue_free()
	sheet.queue_free()
	await process_frame


func encounter_scene_player_stats(arena: Node) -> PlayerStats:
	return (arena.get_node("Player/PlayerCombat") as PlayerCombat).stats


func _press_escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await physics_frame


func _finish() -> void:
	if _failures == 0:
		print("PASS test_buff_choice: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_buff_choice: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
