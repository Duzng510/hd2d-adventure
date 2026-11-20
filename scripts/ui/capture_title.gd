extends Node

## T-028 visual proof for the title screen: the frame must really render (the
## black-image trap this repo already hit twice), and the keyboard highlight has
## to land on the row the menu claims. The drift is frozen so two frames of the
## same pose differ by exactly nothing, which is what makes the control honest.
##
##   <GODOT> --path . res://scenes/ui/capture_title.tscn              -> exit 0
##   ... -- negative   same pose twice: control must report 0 px      -> exit 0

const EVIDENCE_DIR := "res://docs/phase-d/evidence/t028/"
## Fractional viewport rect over the menu rows, so the verdict reads the buttons
## and not the grove sliding underneath them.
const MENU_BAND := Rect2(0.30, 0.42, 0.40, 0.36)
const HIGHLIGHT_MIN_DIFF := 40
const LIT_MIN_PIXELS := 500

var _shots: Array = []
var _checks := 0
var _failures := 0
var _backdrop: Node


func _ready() -> void:
	var menu := get_node("../TitleScreen")
	_backdrop = menu.get_node("TitleBackdrop")
	# A drifting camera would change every pixel between two frames and let the
	# diff pass on motion alone.
	_backdrop.set_process(false)
	_capture.call_deferred()


func _capture() -> void:
	await _settle()
	var negative := OS.get_cmdline_user_args().has("negative")
	_shots.append(_grab("title_idle"))
	if negative:
		_shots.append(_grab("title_control"))
	else:
		for _i in 2:
			await _press_key(KEY_DOWN)
			await _settle()
		_shots.append(_grab("title_credit"))
	_report(negative)


func _settle() -> void:
	for _i in 3:
		await RenderingServer.frame_post_draw


func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame


func _grab(label: String) -> Image:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(EVIDENCE_DIR + "%s.png" % label)
	print("SHOT %s%s (%d lit px)" % [label, "" if err == OK else " SAVE FAILED", _lit_pixels(image)])
	return image


static func _lit_pixels(image: Image) -> int:
	var n := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).get_luminance() > 0.02:
				n += 1
	return n


## Pixels that changed inside the menu band only.
static func _band_diff(a: Image, b: Image) -> int:
	var w := a.get_width()
	var h := a.get_height()
	var from := Vector2i(int(MENU_BAND.position.x * w), int(MENU_BAND.position.y * h))
	var to := Vector2i(int((MENU_BAND.position.x + MENU_BAND.size.x) * w),
		int((MENU_BAND.position.y + MENU_BAND.size.y) * h))
	var changed := 0
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				changed += 1
	return changed


func _report(negative: bool) -> void:
	_check(_shots.size() == 2 and _shots[0] != null and _shots[1] != null,
		"P28.14 both frames captured")
	if _shots.size() < 2:
		print("checks=%d failures=%d" % [_checks, _failures])
		print("FAIL t028_title_capture")
		get_tree().quit(1)
		return
	var lit := [_lit_pixels(_shots[0]), _lit_pixels(_shots[1])]
	_check(lit[0] >= LIT_MIN_PIXELS and lit[1] >= LIT_MIN_PIXELS,
		"P28.15 the title screen really rendered, not a black frame (lit px %d / %d)" % lit)
	var diff := _band_diff(_shots[0], _shots[1])
	if negative:
		_check(diff == 0,
			"P28.16 control: one pose twice changes 0 px in the menu band (got %d)" % diff)
	else:
		_check(diff >= HIGHLIGHT_MIN_DIFF,
			"P28.16 the highlight moved onto Credit (%d px in the menu band, need >= %d)"
			% [diff, HIGHLIGHT_MIN_DIFF])
	print("checks=%d failures=%d band_diff=%d lit=%s" % [_checks, _failures, diff, lit])
	print("%s t028_title_capture%s" % ["PASS" if _failures == 0 else "FAIL",
		" (control)" if negative else ""])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
