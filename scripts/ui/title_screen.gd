extends Node

## T-028 entry point. Start hands over to the arena; Option and Credit stay
## focusable placeholders so the arrow keys already have somewhere to go before
## those screens exist.

@export var game_title: String = "HD-2D ADVENTURE"
@export_file("*.tscn") var start_scene: String = "res://scenes/phase_c/play_arena.tscn"
@export var fade_seconds: float = 0.25

@onready var _title: Label = $UI/TitleBox/Title
@onready var _start: Button = $UI/MenuBox/Menu/Start
@onready var _fade: ColorRect = $UI/Fade

var _leaving := false


func _ready() -> void:
	_title.text = game_title
	_start.pressed.connect(_on_start_pressed)
	_start.grab_focus()


func _on_start_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_seconds)
	tween.tween_callback(_open_start_scene)


func _open_start_scene() -> void:
	get_tree().change_scene_to_file(start_scene)
