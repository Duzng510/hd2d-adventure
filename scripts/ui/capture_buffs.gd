extends Node

## T-030 visual proof: the buff chooser really draws three populated cards over
## the arena. The closed/open band diff proves the panel appears; the card-text
## check proves the panel carries the pool instead of empty boxes (the T-029
## capture could not tell an empty sheet from a full one).
##   <GODOT> --path . res://scenes/ui/capture_buffs.tscn --fixed-fps 60
##   ... -- negative   same pose twice: control must report 0 px

const EVIDENCE_DIR := "res://docs/phase-d/evidence/t030/"
const PANEL_BAND := Rect2(0.18, 0.22, 0.64, 0.56)
const PANEL_MIN_DIFF := 40
const LIT_MIN_PIXELS := 500
## present() staggers the cards (0.05 s * index delay on a 0.12 s tween), so the
## settled pose arrives ~13 frames in. Photographing after the bare 3-frame
## settle would show half-faded, shrunken cards.
const STAGGER_SETTLE_FRAMES := 20

var _choice: BuffChoice
var _shots: Array = []
var _checks := 0
var _failures := 0


func _ready() -> void:
	# The wave must not start: player spawn sits inside the trigger radius. The
	# tree is paused by present() later, so keep this driver processing always.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var arena := get_node("../GroveArena")
	arena.get_node("WaveEncounter").set_physics_process(false)
	_choice = get_node("../BuffChoice") as BuffChoice
	_capture.call_deferred()


func _capture() -> void:
	await _settle()
	var negative := OS.get_cmdline_user_args().has("negative")
	_shots.append(_grab("buffs_closed"))
	if negative:
		_shots.append(_grab("buffs_control"))
	else:
		_choice.present(BuffPool.pool().slice(0, 3))
		await _wait(STAGGER_SETTLE_FRAMES)
		await _settle()
		_shots.append(_grab("buffs_open"))
	_report(negative)


func _settle() -> void:
	for _i in 3:
		await RenderingServer.frame_post_draw


func _wait(frames: int) -> void:
	for _i in frames:
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
		"P30.1 both frames captured")
	if _shots.size() < 2:
		print("checks=%d failures=%d" % [_checks, _failures])
		print("FAIL t030_buff_capture")
		get_tree().quit(1)
		return
	var lit := [_lit_pixels(_shots[0]), _lit_pixels(_shots[1])]
	_check(lit[0] >= LIT_MIN_PIXELS and lit[1] >= LIT_MIN_PIXELS,
		"P30.2 the arena really rendered, not a black frame (lit px %d / %d)" % lit)
	var diff := _band_diff(_shots[0], _shots[1])
	if negative:
		_check(diff == 0,
			"P30.3 control: one pose twice changes 0 px in the panel band (got %d)" % diff)
		_check(not _choice.is_open() and _choice.card_count() == 0,
			"P30.4 control: the chooser never opened and holds no cards")
	else:
		_check(diff >= PANEL_MIN_DIFF,
			"P30.3 the chooser open/closed differs (%d px in the panel band, need >= %d)"
			% [diff, PANEL_MIN_DIFF])
		var titles_ok := _choice.card_count() == 3
		var pool := BuffPool.pool()
		for i in 3:
			titles_ok = titles_ok and _choice.card_text(i).contains(pool[i]["title"])
		_check(titles_ok,
			"P30.4 the three cards carry the pool titles (%d cards, title[0]=%s)"
			% [_choice.card_count(), pool[0]["title"]])
	print("checks=%d failures=%d band_diff=%d lit=%s" % [_checks, _failures, diff, lit])
	print("%s t030_buff_capture%s" % ["PASS" if _failures == 0 else "FAIL",
		" (control)" if negative else ""])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
