class_name PlayerController
extends CharacterBody3D

@export var speed: float = 4.0

var facing: int = 1

@onready var _sprite: Sprite3D = $Sprite3D


func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = MovementModel.compute_velocity(input_vector, speed)
	facing = MovementModel.compute_facing(input_vector, facing)
	_sprite.flip_h = facing < 0
	move_and_slide()