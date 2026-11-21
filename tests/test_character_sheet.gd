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

	sheet.open()
	_check(paused == (not _negative), "opening pauses the world")
	_check(sheet.body_text().contains("77/100"), "hp row reads current and effective max")
	_check(sheet.body_text().contains("10  (0.59 dmg/tick)"),
		"damage row reads the effective damage")
	stats.add_modifier(&"heavy_edge", {&"light_damage_mult": 1.3})
	sheet.refresh()
	_check(sheet.body_text().contains("13  (0.76 dmg/tick)"),
		"damage row follows a buff instead of a constant")
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
