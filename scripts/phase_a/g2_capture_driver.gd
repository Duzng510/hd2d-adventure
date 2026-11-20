extends Node

## G2 mouse-aim gate capture. Warps the cursor to 5 screen positions, settles,
## then saves a screenshot + CSV row per point. Real renderer required:
## <GODOT> --path . res://scenes/phase_a/capture_g2.tscn --resolution 1280x720 --fixed-fps 60

const EVIDENCE_DIR := "res://docs/phase-a/evidence/g2/"
const SETTLE_FRAMES := 6

# tag, mouse_x, mouse_y for a 1280x720 viewport.
const POINTS := [
	["g2_1_center", 640, 360],
	["g2_2_left", 40, 360],
	["g2_3_right", 1240, 360],
	["g2_4_top", 640, 40],
	["g2_5_bottom", 640, 680],
]

var _aim: AimMarker
var _log: FileAccess


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	_aim = get_node("../PhaseAPlayground/AimMarker")
	_log = FileAccess.open(EVIDENCE_DIR + "g2_log.csv", FileAccess.WRITE)
	_log.store_line("tag,mouse_x,mouse_y,aim_x,aim_z,has_hit,screen_offset_px")
	await _run()


func _run() -> void:
	# Let the window/input flush initialize so the first warp_mouse takes effect.
	for _k in 10:
		await get_tree().process_frame
	for point in POINTS:
		Input.warp_mouse(Vector2(point[1], point[2]))
		for _k in SETTLE_FRAMES:
			await get_tree().process_frame
		var mouse := get_viewport().get_mouse_position()
		_log.store_line("%s,%.1f,%.1f,%.4f,%.4f,%d,%.2f" % [
			point[0], mouse.x, mouse.y, _aim.aim_point.x, _aim.aim_point.z,
			1 if _aim.has_hit else 0, _aim.screen_offset_px,
		])
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(EVIDENCE_DIR + point[0] + ".png")
	_log.close()
	print("G2 capture done: 5 points, CSV + 5 PNGs at %s" % EVIDENCE_DIR)
	get_tree().quit(0)