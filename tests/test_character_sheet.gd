extends SceneTree

## T-029: ESC pauses the world, and the sheet shows the same numbers the combat
## code uses (no hand-written constants). It must also stay closed and
## non-pausing until asked, so headless drivers are never suspended.

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	await _run()
	_finish()


func _run() -> void:
	var stats := PlayerStats.new(CombatTuning.new())
	var sheet := CharacterSheet.new()
	root.add_child(sheet)
	await process_frame
	sheet.set_sources(stats, func() -> int: return 77, null)
	_check(not paused and not sheet.visible,
		"the sheet starts closed and the game keeps running")

	# T-031: the readout toggle is an information toggle (spec §5) — the sheet owns
	# the button, the layer owns the state, so the sheet must never cache it.
	var numbers := DamageNumbers.new()
	root.add_child(numbers)
	await process_frame
	sheet.set_damage_numbers(numbers)
	_check(not sheet.is_open() and numbers.is_enabled(),
		"the numbers layer starts enabled and the sheet stays closed")
	sheet.open()
	_check(sheet.toggle_value_text().contains(UiCopy.STATE_ON),
		"the sheet states the current toggle value")
	sheet.toggle_numbers()
	_check(not numbers.is_enabled() and numbers.active_count() == 0,
		"the sheet toggle really turns the readout off")
	_check(sheet.toggle_value_text().contains(UiCopy.STATE_OFF),
		"the label flips with the state")
	sheet.close()
	sheet.open()
	_check(not numbers.is_enabled() and sheet.toggle_value_text().contains(UiCopy.STATE_OFF),
		"the choice survives a close/reopen (session variable, not a save)")
	numbers.set_enabled(true)
	_check(sheet.toggle_value_text().contains(UiCopy.STATE_ON),
		"the sheet reads the state back from the layer, it does not cache it")
	sheet.close()
	numbers.queue_free()
	sheet.set_damage_numbers(null)
	await process_frame

	sheet.open()
	_check(paused == (not _negative), "opening pauses the world")
	_check(sheet.body_text().contains("77/100"), "hp row reads current and effective max")
	_check(sheet.body_text().contains("10  (0.59 dmg/tick)"),
		"damage row reads the effective damage")
	_check(sheet.body_text().contains(UiCopy.SHEET_NONE),
		"an empty buff list shows the empty marker")
	stats.add_modifier(&"heavy_edge", {&"light_damage_mult": 1.3})
	sheet.refresh()
	_check(sheet.body_text().contains("13  (0.76 dmg/tick)"),
		"damage row follows a buff instead of a constant")

	# T-030 final review: the buff rows must explain each pick (spec §5 name +
	# gain/cost), not only print the title.
	var long_reach: Dictionary = BuffPool.pool()[BuffPool.index_of(&"long_reach")]
	stats.add_modifier(&"long_reach", long_reach["ops"])
	sheet.refresh()
	var body := sheet.body_text()
	var payloads := [UiCopy.BUFF_HEAVY_EDGE_GAIN, UiCopy.BUFF_HEAVY_EDGE_COST,
		UiCopy.BUFF_LONG_REACH_GAIN, UiCopy.BUFF_LONG_REACH_COST]
	var payloads_ok := true
	for payload in payloads:
		payloads_ok = payloads_ok and body.contains(payload)
	_check(payloads_ok, "the buff rows carry every gain and cost line verbatim")
	_check(body.contains(UiCopy.BUFF_HEAVY_EDGE) and body.contains(UiCopy.BUFF_LONG_REACH),
		"the buff rows carry both pool titles")
	await process_frame
	var minimum := sheet.content_minimum_size()
	print("SHEET content_minimum_size=%s sheet_size=%s"
		% [minimum, Vector2(Hd2dTheme.SHEET_SIZE)])
	_check(minimum.x <= Hd2dTheme.SHEET_SIZE.x and minimum.y <= Hd2dTheme.SHEET_SIZE.y,
		"the toggle row and the two buff rows fit the sheet geometry (min %s)" % minimum)
	# T-030 debt: a sheet asked for its body before _ready must not crash.
	var cold := CharacterSheet.new()
	_check(cold.body_text() == "", "body_text before _ready returns empty, not an error")
	_check(cold.content_minimum_size() == Vector2(Hd2dTheme.SHEET_SIZE),
		"content_minimum_size before _ready falls back to the panel size")
	cold.free()
	# T-031: "1/3" alone did not say whether the wave was fighting, parked for a
	# pick, or over (spec §5).
	_check(CharacterSheet.wave_state_text(WaveKernel.State.BUFF_PENDING)
		== UiCopy.BUFF_PANEL_TITLE, "a parked wave says a pick is owed")
	_check(CharacterSheet.wave_state_text(WaveKernel.State.FIGHTING) == UiCopy.HUD_FIGHT,
		"a live wave says fighting")
	_check(CharacterSheet.wave_state_text(WaveKernel.State.WON) == UiCopy.HUD_WIN,
		"a finished wave reads as the win line")
	stats.clear_modifiers()
	sheet.refresh()
	_check(sheet.body_text().contains(UiCopy.SHEET_NONE),
		"clearing the buffs restores the empty marker")
	_check((sheet._rows[&"wave"] as Label).text == UiCopy.SHEET_PLACEHOLDER,
		"the wave row shows the placeholder without an encounter")
	sheet.close()
	_check(not paused and not sheet.visible, "closing releases the pause")

	await _press_escape()
	_check(paused and sheet.visible, "Escape through InputMap opens the sheet")
	await _press_escape()
	_check(not paused and not sheet.visible, "Escape again closes it")
	sheet.queue_free()
	await process_frame


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
		print("PASS test_character_sheet: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_character_sheet: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
