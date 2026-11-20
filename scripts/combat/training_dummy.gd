class_name TrainingDummy
extends Area3D

## Placeholder target for T-010 hit/capture evidence; the Grunt replaces it in T-011.

@export var target_id: int = 1
@export var max_hp: int = 1000

var health: Health

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _material: StandardMaterial3D
var _flash_frames: int = 0

const BASE_COLOR := Color(0.32, 0.55, 0.38)


func _ready() -> void:
	health = Health.new(max_hp)
	_material = StandardMaterial3D.new()
	_material.albedo_color = BASE_COLOR
	_mesh.material_override = _material


func apply_hit(amount: int) -> int:
	var applied := health.apply_damage(amount)
	if applied > 0:
		_flash_frames = 6
	return applied


func _physics_process(_delta: float) -> void:
	if _flash_frames <= 0:
		return
	_flash_frames -= 1
	_material.albedo_color = Color.WHITE if _flash_frames > 3 else BASE_COLOR


func reset() -> void:
	health.reset()
	_flash_frames = 0
	_material.albedo_color = BASE_COLOR
