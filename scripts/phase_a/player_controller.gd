class_name PlayerController
extends CharacterBody3D

## Pushed by PlayerCombat from PlayerStats (T-029); never owned by the scene.
var speed: float = 4.0
@export var visual_snap: bool = true
@export var camera_path: NodePath = NodePath("../CameraRig")

var facing: int = 1
var movement_locked: bool = false
var override_velocity := Vector3.ZERO

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _camera: CameraRig = get_node(camera_path)

var _sprite_offset := Vector3.ZERO


func _ready() -> void:
	_sprite_offset = _sprite.position


func _physics_process(_delta: float) -> void:
	if movement_locked:
		velocity = override_velocity
	else:
		var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		velocity = MovementModel.compute_velocity(input_vector, speed)
		facing = MovementModel.compute_facing(input_vector, facing)
	_sprite.flip_h = facing < 0
	move_and_slide()
	_update_sprite_visual()


## Keep the sprite's texel grid on whole screen pixels; logic position stays continuous.
func _update_sprite_visual() -> void:
	if not visual_snap:
		_sprite.position = _sprite_offset
		return
	var desired := global_position + _sprite_offset
	var screen := _camera.unproject_position(desired)
	var d := (screen.round() - screen) / _camera.px_per_unit()
	var b := _camera.global_transform.basis
	_sprite.global_position = desired + b.x * d.x - b.y * d.y