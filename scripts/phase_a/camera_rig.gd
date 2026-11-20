class_name CameraRig
extends Camera3D

enum ProjectionMode { PERSPECTIVE, ORTHOGRAPHIC }

@export var target_path: NodePath = NodePath("../Player")
@export var offset: Vector3 = Vector3(0.0, 10.0, 8.0)
@export var perspective_fov: float = 35.0
@export var ortho_size: float = 10.0
@export var follow_smoothing: float = 0.0

var mode: ProjectionMode = ProjectionMode.PERSPECTIVE

var _target: Node3D


func _ready() -> void:
	_target = get_node(target_path)
	_apply_projection()
	_update_position(0.0)


func _physics_process(delta: float) -> void:
	_update_position(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_projection"):
		mode = ProjectionMode.ORTHOGRAPHIC if mode == ProjectionMode.PERSPECTIVE else ProjectionMode.PERSPECTIVE
		_apply_projection()


func _apply_projection() -> void:
	if mode == ProjectionMode.PERSPECTIVE:
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = perspective_fov
	else:
		projection = Camera3D.PROJECTION_ORTHOGONAL
		size = ortho_size


func _update_position(delta: float) -> void:
	var desired := _target.global_position + offset
	if follow_smoothing <= 0.0 or delta == 0.0:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_smoothing * delta))
	look_at(_target.global_position, Vector3.UP)