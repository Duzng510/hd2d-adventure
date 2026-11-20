extends Node

## B3.3 visual evidence: Grunt chases the player and is stopped by the wall
## (never crosses it) while the player waits behind it. Real renderer:
## <GODOT> --path . res://scenes/phase_b/capture_b3.tscn --resolution 1280x720 --fixed-fps 60

const EVIDENCE_DIR := "res://docs/phase-b/evidence/b3/"
const TICKS := 240
const WALL_MIN_X := 1.0
const WALL_MAX_X := 7.0
const WALL_MIN_Z := -3.25
const WALL_MAX_Z := -2.75

var _player: PlayerController
var _grunt: Grunt
var _manager: EncounterManager
var _director: CombatDirector


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var playground := get_node("../PhaseAPlayground")
	_player = playground.get_node("Player")
	_grunt = playground.get_node("Grunt")
	_manager = playground.get_node("EncounterManager")
	_director = playground.get_node("CombatDirector")
	_manager.reset_delay_frames = 100000
	_run()


func _run() -> void:
	_player.global_position = Vector3(5.0, 0.0, -5.5)
	_grunt.global_position = Vector3(5.0, 0.0, 0.0)
	var grabbed := false
	var min_clearance := INF
	for _i in TICKS:
		await get_tree().physics_frame
		var p := _grunt.global_position
		min_clearance = minf(min_clearance, _wall_clearance(p))
		if not grabbed and p.z <= -2.0:
			grabbed = true
			await _grab("chase_wall.png")
	await _grab("chase_blocked.png")
	_copy_log()
	print("b3 capture: wall_min=%.3f grabbed=%s" % [min_clearance, str(grabbed)])
	get_tree().quit(0)


func _grab(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(EVIDENCE_DIR + filename)


func _copy_log() -> void:
	var source := FileAccess.open(_director.log_path, FileAccess.READ)
	if source == null:
		return
	var target := FileAccess.open(EVIDENCE_DIR + "combat_log_wall.csv", FileAccess.WRITE)
	if target != null:
		target.store_string(source.get_as_text())
		target.close()
	source.close()


func _wall_clearance(p: Vector3) -> float:
	var cx := clampf(p.x, WALL_MIN_X, WALL_MAX_X)
	var cz := clampf(p.z, WALL_MIN_Z, WALL_MAX_Z)
	return Vector2(p.x - cx, p.z - cz).length()
