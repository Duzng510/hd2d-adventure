extends SceneTree

## T-028 title screen entry flow.
##
## The menu is loaded through the same call the engine uses for main_scene, and
## the player's key presses are pushed through the window's GUI input, so focus
## routing and the scene change are exercised for real. Calling button.pressed
## directly would keep passing even when the button cannot be reached with the
## keyboard, which is the failure that matters here.

const TITLE_PATH := "res://scenes/ui/title_screen.tscn"
const ARENA_PATH := "res://scenes/phase_c/play_arena.tscn"
const BOGUS_PATH := "res://scenes/ui/no_such_scene.tscn"
const MENU_LABELS := ["Start", "Option", "Credit"]
const SETTLE_FRAMES := 30
const MAX_WAIT_FRAMES := 900

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	await _run()
	_finish()


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == TITLE_PATH,
		"P28.1 booting the project lands on the title screen")
	_check(change_scene_to_file(TITLE_PATH) == OK, "P28.2 the title scene opens")
	var title := await _wait_for_scene(TITLE_PATH)
	if title == null:
		_check(false, "P28.2 the title scene became current within %d frames" % MAX_WAIT_FRAMES)
		return
	_check(title.get_child_count() > 0, "P28.3 the title scene carries a UI subtree")

	var buttons: Array[Node] = title.find_children("*", "Button", true, false)
	var labels: Array = []
	for button in buttons:
		labels.append(button.text)
	_check(labels == MENU_LABELS,
		"P28.4 the menu reads Start, Option, Credit in order (got %s)" % [labels])

	_check(title.get("start_scene") != null and title.start_scene == ARENA_PATH,
		"P28.5 Start is wired to the Phase C arena, not a stale path")
	var shown := _label_text(title, "Title")
	_check(shown != "" and shown == title.game_title,
		"P28.6 the title line carries the project name, not an empty placeholder (got \"%s\")" % shown)

	_check(root.gui_get_focus_owner() == buttons[0],
		"P28.7 Start owns keyboard focus the moment the menu opens")

	# Arrow navigation is the input model the menu is built on. It is only real if
	# a ui_down event moves focus, so no neighbour setup can silently regress.
	await _press_key(KEY_DOWN)
	await _settle(2)
	_check(root.gui_get_focus_owner() == buttons[1], "P28.8 ui_down moves the highlight to Option")
	await _press_key(KEY_DOWN)
	await _settle(2)
	_check(root.gui_get_focus_owner() == buttons[2], "P28.9 ui_down moves the highlight to Credit")
	await _press_key(KEY_UP)
	await _press_key(KEY_UP)
	await _settle(2)
	_check(root.gui_get_focus_owner() == buttons[0], "P28.10 ui_up returns the highlight to Start")

	# Option and Credit are placeholders on purpose: they must never change scene.
	for placeholder in [buttons[1], buttons[2]]:
		placeholder.grab_focus()
		await _press_key(KEY_SPACE)
		await _settle(SETTLE_FRAMES)
		_check(_current_scene_path() == TITLE_PATH,
			"P28.11 %s stays put instead of leaving the menu" % placeholder.text)

	buttons[0].grab_focus()
	await _press_key(KEY_SPACE)
	var expected := BOGUS_PATH if _negative else ARENA_PATH
	var arrived := await _wait_for_scene(expected)
	_check(arrived != null,
		"P28.12 accepting Start swaps the menu for %s" % expected)
	if arrived != null:
		_check(not is_instance_valid(title),
			"P28.13 the menu is freed on the way out, no stray UI under the window")


func _current_scene_path() -> String:
	return "" if current_scene == null else current_scene.scene_file_path


func _label_text(node: Node, label_name: String) -> String:
	var label := node.find_child(label_name, true, false) as Label
	return "" if label == null else label.text


func _wait_for_scene(path: String) -> Node:
	for _frame in MAX_WAIT_FRAMES:
		await process_frame
		if _current_scene_path() == path:
			return current_scene
	return null


func _settle(frames: int) -> void:
	for _frame in frames:
		await process_frame


## Push one real key press+release at the window, the same event a keyboard
## produces, so Viewport focus handling and BaseButton do the work.
func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event)
		await process_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)


func _finish() -> void:
	if _failures == 0:
		print("PASS test_title_entry: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_title_entry: %d/%d checks failed" % [_failures, _checks])
		quit(1)
