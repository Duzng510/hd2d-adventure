extends Node

## T-029 visual proof: the sheet must really render (lit-pixel guard) and the
## open pose must differ from the closed one inside the panel band only.
##   <GODOT> --path . res://scenes/ui/capture_sheet.tscn --fixed-fps 60
##   ... -- negative   same pose twice: control must report 0 px

const EVIDENCE_DIR := "res://docs/phase-d/evidence/t029/"
const PANEL_BAND := Rect2(0.30, 0.27, 0.40, 0.46)
const PANEL_MIN_DIFF := 40
const LIT_MIN_PIXELS := 500

var _shots: Array = []
var _checks := 0
var _failures := 0


func _ready() -> void:
	# The wave must not start: player spawn sits inside the trigger radius.
	var arena := get_node("../GroveArena")
	arena.get_node("WaveEncounter").set_physics_process(false)
	_capture.call_deferred()


func _capture() -> void:
	await _settle()
	var negative := OS.get_cmdline_user_args().has("negative")
	_shots.append(_grab("sheet_closed"))
	if negative:
		_shots.append(_grab("sheet_control"))
	else:
		await _press_escape()
		_shots.append(_grab("sheet_open"))
	_report(negative)


func _settle() -> void:
	for _i in 3:
		await RenderingServer.frame_post_draw


func _press_escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _grab(label: String) -> Image:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(EVIDENCE_DIR + "%s.png" % label)
	print("SHOT %s%s (%d lit px)" % [label, "" if err == OK else " SAVE FAILED",
		_lit_pixels(image)])
	return image


static func _lit_pixels(image: Image) -> int:
	var n := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).get_luminance() > 0.02:
				n += 1
	return n


static func _band_diff(a: Image, b: Image) -> int:
	var w := a.get_width()
	var h := a.get_height()
	var from := Vector2i(int(PANEL_BAND.position.x * w), int(PANEL_BAND.position.y * h))
	var to := Vector2i(int((PANEL_BAND.position.x + PANEL_BAND.size.x) * w),
		int((PANEL_BAND.position.y + PANEL_BAND.size.y) * h))
	var changed := 0
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				changed += 1
	return changed


func _report(negative: bool) -> void:
	_check(_shots.size() == 2 and _shots[0] != null and _shots[1] != null,
		"P29.1 both frames captured")
	if _shots.size() < 2:
		print("checks=%d failures=%d" % [_checks, _failures])
		print("FAIL t029_sheet_capture")
		get_tree().quit(1)
		return
	var lit := [_lit_pixels(_shots[0]), _lit_pixels(_shots[1])]
	_check(lit[0] >= LIT_MIN_PIXELS and lit[1] >= LIT_MIN_PIXELS,
		"P29.2 the arena really rendered, not a black frame (lit px %d / %d)" % lit)
	var diff := _band_diff(_shots[0], _shots[1])
	if negative:
		_check(diff == 0,
			"P29.3 control: one pose twice changes 0 px in the panel band (got %d)" % diff)
	else:
		_check(diff >= PANEL_MIN_DIFF,
			"P29.3 the sheet open/closed differs (%d px in the panel band, need >= %d)"
			% [diff, PANEL_MIN_DIFF])
	print("checks=%d failures=%d band_diff=%d lit=%s" % [_checks, _failures, diff, lit])
	print("%s t029_sheet_capture%s" % ["PASS" if _failures == 0 else "FAIL",
		" (control)" if negative else ""])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
