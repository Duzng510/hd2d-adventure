class_name OcclusionFader
extends Node

## One consistent occlusion rule: fade any world occluder intersecting the
## camera->player or camera->aim ray so the player / reticle stay readable.

@export var camera_path: NodePath = NodePath("../CameraRig")
@export var player_path: NodePath = NodePath("../Player")
@export var aim_path: NodePath = NodePath("../AimMarker")
@export var fade_alpha: float = 0.25
@export var enabled: bool = true

var active_fades: int = 0

var _camera: Camera3D
var _player: Node3D
var _aim: AimMarker
var _mats: Dictionary = {}


func _ready() -> void:
	_camera = get_node(camera_path)
	_player = get_node(player_path)
	_aim = get_node(aim_path)


func _collect() -> void:
	# Group is populated by playground._ready, which runs after child _ready.
	for mesh in get_tree().get_nodes_in_group(&"fadeable"):
		_mats[mesh.get_parent()] = mesh.material_override


func _physics_process(_delta: float) -> void:
	if _mats.is_empty():
		_collect()
	for mat in _mats.values():
		mat.albedo_color.a = 1.0
	active_fades = 0
	if not enabled:
		return
	var space := get_viewport().world_3d.direct_space_state
	var targets: Array[Vector3] = [_player.global_position + Vector3(0, 0.8, 0)]
	if _aim.has_hit:
		targets.append(_aim.aim_point)
	for target in targets:
		var params := PhysicsRayQueryParameters3D.create(_camera.global_position, target, 1)
		var hit := space.intersect_ray(params)
		if hit.is_empty():
			continue
		var mat: StandardMaterial3D = _mats.get(hit.collider)
		if mat != null and mat.albedo_color.a > fade_alpha:
			mat.albedo_color.a = fade_alpha
			active_fades += 1