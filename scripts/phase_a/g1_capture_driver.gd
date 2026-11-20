extends Node

## G1 movement gate capture driver. Simulates InputMap actions on a fixed
## frame schedule, saves screenshots + a per-frame CSV, then quits.
## Run with a real renderer: <GODOT> --path . res://scenes/phase_a/capture_g1.tscn --resolution 1280x720 --fixed-fps 60

const EVIDENCE_DIR := "res://docs/phase-a/evidence/g1/"
const END_FRAME := 601

var _player: PlayerController
var _camera: CameraRig
var _frame: int = 0
var _log: FileAccess
var _finished := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	_player = get_node("../PhaseAPlayground/Player")
	_camera = get_node("../PhaseAPlayground/CameraRig")
	_log = FileAccess.open(EVIDENCE_DIR + "g1_log.csv", FileAccess.WRITE)
	_log.store_line("situation,frame,x,z,vx,vz,facing,cam_x,cam_z")


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	_frame += 1
	_run_schedule(_frame)
	var p := _player.global_position
	var v := _player.velocity
	var c := _camera.global_position
	_log.store_line("%s,%d,%.4f,%.4f,%.4f,%.4f,%d,%.4f,%.4f" % [
		_situation(_frame), _frame, p.x, p.z, v.x, v.z, _player.facing, c.x, c.z,
	])
	if _frame >= END_FRAME:
		_finish()


func _run_schedule(f: int) -> void:
	match f:
		1:
			_teleport(Vector3.ZERO)
			_hold(&"move_right")
		90:
			_capture("g1_1_f090")
		180:
			_capture("g1_1_f180")
		181:
			_release_all()
			_hold(&"move_up")
		183:
			_capture("g1_2_f183")
		300:
			_capture("g1_2_f300")
		301:
			_release_all()
			_teleport(Vector3(4, 0, -1))
			_hold(&"move_up")
		360:
			_capture("g1_3_f360")
		480:
			_capture("g1_3_f480")
		481:
			_teleport(Vector3.ZERO)
		540:
			_capture("g1_4_f540")
		601:
			_release_all()
	if f >= 481 and f <= 600 and (f - 481) % 24 == 0:
		_release_all()
		var idx := int(float(f - 481) / 24.0)
		_hold(&"move_right" if idx % 2 == 0 else &"move_left")


func _situation(f: int) -> String:
	if f <= 180:
		return "g1_1"
	if f <= 300:
		return "g1_2"
	if f <= 480:
		return "g1_3"
	if f <= 600:
		return "g1_4"
	return "end"


func _teleport(pos: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO


func _hold(action: StringName) -> void:
	Input.action_press(action)


func _release_all() -> void:
	for action in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(action)


func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(EVIDENCE_DIR + tag + ".png")


func _finish() -> void:
	_finished = true
	_release_all()
	_log.close()
	print("G1 capture done: %d frames, CSV + 7 PNGs at %s" % [END_FRAME, EVIDENCE_DIR])
	get_tree().quit(0)