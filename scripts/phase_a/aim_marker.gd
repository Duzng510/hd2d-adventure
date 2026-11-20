class_name AimMarker
extends Node3D

## Debug ground reticle placed at the camera-ray / ground-plane intersection.
## Reads the continuous pointer position (not a discrete key action).

@export var camera_path: NodePath = NodePath("../CameraRig")
@export var ground_y: float = 0.0
@export var marker_size: float = 0.7
@export var hover: float = 0.02

var aim_point: Vector3 = Vector3.ZERO
var screen_offset_px: float = -1.0
var has_hit: bool = false

var _camera: Camera3D
var _reticle: MeshInstance3D


func _ready() -> void:
	_camera = get_node(camera_path)
	_reticle = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(marker_size, marker_size)
	_reticle.mesh = quad
	_reticle.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = PlaceholderTextures.make_aim_marker_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_reticle.material_override = mat
	_reticle.visible = false
	add_child(_reticle)


func _process(_delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	var hit := AimModel.ground_hit(origin, dir, ground_y)
	has_hit = hit.is_finite()
	if has_hit:
		aim_point = hit
		_reticle.global_position = Vector3(hit.x, ground_y + hover, hit.z)
		_reticle.visible = true
		screen_offset_px = _camera.unproject_position(hit).distance_to(mouse)
	else:
		_reticle.visible = false
		screen_offset_px = -1.0