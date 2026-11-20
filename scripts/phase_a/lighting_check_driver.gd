extends Node

## One-shot lighting verification capture (after ambient fix). Saves a center
## screenshot to compare against pre-fix evidence (g2/g2_1_center.png).
## Run: <GODOT> --path . res://scenes/phase_a/capture_lighting.tscn --resolution 1280x720 --fixed-fps 60

const EVIDENCE_DIR := "res://docs/phase-a/evidence/lighting/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	await _run()


func _run() -> void:
	for _k in 10:
		await get_tree().process_frame
	Input.warp_mouse(Vector2(640, 360))
	for _k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(EVIDENCE_DIR + "after_center.png")
	print("Lighting check saved: after_center.png at %s" % EVIDENCE_DIR)
	get_tree().quit(0)