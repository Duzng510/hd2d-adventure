extends Node

## T-026 visual proof: does the self-marker ring actually stay visible when a
## boss body stands over the player? Stages the overlap, freezes the boss so the
## only change between the two frames is the ring, then counts differing pixels
## in a box around the feet.
##
##   <GODOT> --path . res://scenes/phase_c/capture_t026.tscn            -> exit 0
##   ... -- negative   ring depth-tested again: control must report 0 px  -> exit 0

## +Z is the camera side: a body there projects down over the sprite and its
## feet, which is the pose that hid the player in the L4 report. A body north of
## the player never overlaps the ring, so it proves nothing.
const BOSS_OFFSET := Vector3(0.0, 0.0, 1.2)
const SAMPLE_BOX := 80
const RING_MIN_DIFF := 40

var _arena: Node3D
var _player: PlayerController
var _encounter: WaveEncounter
var _marker: MeshInstance3D
var _boss: Node3D
var _shots: Array = []
var _checks := 0
var _failures := 0


func _ready() -> void:
	_arena = get_node("../GroveArena")
	_player = _arena.get_node("Player") as PlayerController
	_encounter = _arena.get_node("WaveEncounter") as WaveEncounter
	_marker = _arena.get_node("Player/SelfMarker") as MeshInstance3D
	_stage()


func _stage() -> void:
	# Away from the trigger so no wave spawns: this scene tests rendering, not AI.
	_player.global_position = Vector3(0.0, 0.0, 0.85)
	_player.velocity = Vector3.ZERO
	_boss = _encounter.debug_spawn("boss", _player.global_position + BOSS_OFFSET)
	if _boss == null:
		_report()
		return
	_boss.set_process(false)
	_boss.set_physics_process(false)
	_capture.call_deferred()


func _capture() -> void:
	await _settle()
	if OS.get_cmdline_user_args().has("negative"):
		var material := _marker.material_override as StandardMaterial3D
		if material == null:
			material = (_marker.mesh as QuadMesh).material as StandardMaterial3D
			_marker.material_override = material
		material.no_depth_test = false
	_marker.visible = false
	var before := await _grab("before")
	_marker.visible = true
	var after := await _grab("after")
	_shots = [before, after]
	_report()


func _settle() -> void:
	# A physics tick is not a drawn frame: reading the viewport texture before
	# the renderer presents gives an all-black image and a meaningless diff.
	for _i in 3:
		await RenderingServer.frame_post_draw


func _diagnose(before: Image, after: Image) -> void:
	# Only printed when a check went red, so a failure explains itself.
	var camera := _arena.get_node("CameraRig") as Camera3D
	var center := camera.unproject_position(_player.global_position + Vector3(0.0, 0.05, 0.0))
	print("DIAG size=%s lit_before=%d lit_after=%d center=%s box=%d" % [
		before.get_size(), _nonblack(before), _nonblack(after), center, SAMPLE_BOX,
	])
	print("DIAG marker=%s visible=%s pos=%s quad=%s mat=%s" % [
		is_instance_valid(_marker), _marker.visible if is_instance_valid(_marker) else null,
		_marker.global_position if is_instance_valid(_marker) else Vector3.ZERO,
		(_marker.mesh as QuadMesh).size if is_instance_valid(_marker) else Vector2.ZERO,
		(_marker.mesh as QuadMesh).material if is_instance_valid(_marker) else null,
	])


static func _nonblack(img: Image) -> int:
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).get_luminance() > 0.01:
				n += 1
	return n


func _grab(label: String) -> Image:
	await _settle()
	var image := get_viewport().get_texture().get_image()
	var file := "t026_%s.png" % label
	if image.save_png("user://" + file) == OK:
		print("SHOT user://%s (%d lit px)" % [file, _nonblack(image)])
	return image


func _report() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	_check(_shots.size() == 2 and _shots[0] != null and _shots[1] != null, "P26.1 both frames captured")
	if _shots.size() == 2:
		var lit_before := _nonblack(_shots[0])
		var lit_after := _nonblack(_shots[1])
		_check(lit_before > 0 and lit_after > 0,
			"P26.3 both frames really rendered (lit px %d / %d)" % [lit_before, lit_after])
	var diff := _diff_pixels(_shots[0], _shots[1]) if _shots.size() == 2 else 0
	if negative:
		_check(diff == 0,
			"P26.2 control: depth-tested ring is hidden by the boss (0 px changed, got %d)" % diff)
	else:
		_check(diff >= RING_MIN_DIFF,
			"P26.2 ring stays visible over the boss body (%d px changed, need >= %d)" % [diff, RING_MIN_DIFF])
	if _failures > 0 and _shots.size() == 2:
		_diagnose(_shots[0], _shots[1])
	print("checks=%d failures=%d" % [_checks, _failures])
	print("%s t026_self_marker%s" % ["PASS" if _failures == 0 else "FAIL", " (control)" if negative else ""])
	get_tree().quit(0 if _failures == 0 else 1)


func _diff_pixels(before: Image, after: Image) -> int:
	if before == null or after == null:
		return 0
	var camera := _arena.get_node("CameraRig") as Camera3D
	var feet := _player.global_position + Vector3(0.0, 0.05, 0.0)
	var center := camera.unproject_position(feet)
	var changed := 0
	for y in range(int(center.y) - SAMPLE_BOX / 2, int(center.y) + SAMPLE_BOX / 2):
		for x in range(int(center.x) - SAMPLE_BOX / 2, int(center.x) + SAMPLE_BOX / 2):
			if x < 0 or y < 0 or x >= before.get_width() or y >= before.get_height():
				continue
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				changed += 1
	return changed


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
