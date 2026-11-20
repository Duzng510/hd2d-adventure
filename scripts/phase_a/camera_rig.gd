class_name CameraRig
extends Camera3D

enum ProjectionMode { PERSPECTIVE, ORTHOGRAPHIC }

@export var target_path: NodePath = NodePath("../Player")
@export var offset: Vector3 = Vector3(0.0, 10.0, 8.0)
@export var perspective_fov: float = 35.0
## Manual ortho size, used only when texel_scale <= 0 (comparison mode).
@export var ortho_size: float = 10.0
@export var follow_smoothing: float = 0.0
@export var pixel_size: float = 0.05
## Integer screen px per texel horizontally; derives ortho size from viewport height.
@export var texel_scale: int = 4
@export var snap_to_pixel: bool = true

var mode: ProjectionMode = ProjectionMode.ORTHOGRAPHIC

var _target: Node3D


func _ready() -> void:
	# Camera must settle before the player's visual snap reads its transform.
	process_priority = -1
	_target = get_node(target_path)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_projection()
	_update_position(0.0)


func _physics_process(delta: float) -> void:
	_update_position(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_projection"):
		apply_mode(ProjectionMode.ORTHOGRAPHIC if mode == ProjectionMode.PERSPECTIVE else ProjectionMode.PERSPECTIVE)


func apply_mode(new_mode: ProjectionMode) -> void:
	mode = new_mode
	_apply_projection()


func _apply_projection() -> void:
	if mode == ProjectionMode.PERSPECTIVE:
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = perspective_fov
	else:
		projection = Camera3D.PROJECTION_ORTHOGONAL
		size = _ortho_size_for_viewport()


func _ortho_size_for_viewport() -> float:
	if texel_scale <= 0:
		return ortho_size
	return PixelGrid.ortho_size_for_scale(get_viewport().get_visible_rect().size.y, pixel_size, texel_scale)


func _on_viewport_size_changed() -> void:
	if mode == ProjectionMode.ORTHOGRAPHIC:
		size = _ortho_size_for_viewport()


func _update_position(delta: float) -> void:
	var desired := _target.global_position + offset
	if follow_smoothing <= 0.0 or delta == 0.0:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_smoothing * delta))
	look_at(_target.global_position, Vector3.UP)
	if snap_to_pixel:
		# Orientation comes from the fixed offset, not from the snapped position,
		# otherwise look_at would reintroduce the sub-pixel error every frame.
		var basis := Basis.looking_at(-offset.normalized(), Vector3.UP)
		var snapped := PixelGrid.snap_position(global_position, basis, PixelGrid.snap_step(px_per_unit()))
		global_transform = Transform3D(basis, snapped)


## Screen pixels per world unit at the target's depth.
func px_per_unit() -> float:
	var h := get_viewport().get_visible_rect().size.y
	if projection == Camera3D.PROJECTION_ORTHOGONAL:
		return PixelGrid.ortho_px_per_unit(h, size)
	return PixelGrid.persp_px_per_unit(h, fov, global_position.distance_to(_target.global_position))