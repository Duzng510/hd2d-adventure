class_name DebugHUD
extends CanvasLayer

@export var player_path: NodePath = NodePath("../Player")
@export var camera_path: NodePath = NodePath("../CameraRig")
@export var aim_path: NodePath = NodePath("../AimMarker")

var _label: Label
var _cursor: Control
var _player: PlayerController
var _camera: CameraRig
var _aim: AimMarker
var _frame: int = 0
var _log_enabled: bool = false
var _log_file: FileAccess


func _ready() -> void:
	_player = get_node(player_path)
	_camera = get_node(camera_path)
	_aim = get_node(aim_path)
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	add_child(_label)
	# Screen-space cursor indicator: the OS cursor is not part of the captured
	# viewport texture, so draw a marker at the pointer for G2 evidence.
	_cursor = Control.new()
	_cursor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor)
	_cursor.draw.connect(_on_cursor_draw)


func _physics_process(_delta: float) -> void:
	_frame += 1
	var p := _player.global_position
	var v := _player.velocity
	var projection := "persp" if _camera.mode == CameraRig.ProjectionMode.PERSPECTIVE else "ortho"
	var aim_txt := "none"
	if _aim.has_hit:
		aim_txt = "(%.2f, %.2f) off %.1fpx" % [_aim.aim_point.x, _aim.aim_point.z, _aim.screen_offset_px]
	var ppu := _camera.px_per_unit()
	var cb := _camera.global_transform.basis
	var horiz := PixelGrid.texel_screen_delta(cb.x, cb.x, cb.y, ppu, _camera.pixel_size)
	var vert := PixelGrid.texel_screen_delta(Vector3.UP, cb.x, cb.y, ppu, _camera.pixel_size)
	_label.text = "frame %d | pos (%.2f, %.2f, %.2f) | vel (%.2f, %.2f) | fps %d | %s | log %s | aim %s\ntexel %.2fx%.2fpx aspect %.3f snap %s | P: projection | L: frame log" % [
		_frame, p.x, p.y, p.z, v.x, v.z, Engine.get_frames_per_second(), projection,
		"on" if _log_enabled else "off", aim_txt,
		horiz.length(), vert.length(), PixelGrid.texel_aspect(horiz, vert),
		"on" if _camera.snap_to_pixel else "off",
	]
	_cursor.queue_redraw()
	if _log_enabled and _log_file != null:
		_log_file.store_line("%d,%.4f,%.4f,%.4f,%.4f" % [_frame, p.x, p.z, v.x, v.z])


func _on_cursor_draw() -> void:
	var m := get_viewport().get_mouse_position()
	var col := Color(1.0, 0.3, 0.3, 0.9)
	_cursor.draw_line(m + Vector2(-9, 0), m + Vector2(9, 0), col, 1.0)
	_cursor.draw_line(m + Vector2(0, -9), m + Vector2(0, 9), col, 1.0)
	_cursor.draw_circle(m, 2.5, col)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_log"):
		_log_enabled = not _log_enabled
		if _log_enabled:
			_log_file = FileAccess.open("user://phase_a_movement.log", FileAccess.WRITE)
			if _log_file != null:
				_log_file.store_line("frame,x,z,vx,vz")
		elif _log_file != null:
			_log_file.close()
			_log_file = null