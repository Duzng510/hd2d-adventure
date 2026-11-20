class_name CombatHUD
extends CanvasLayer

@export var player_path: NodePath = NodePath("../Player")
@export var grunt_path: NodePath = NodePath("../Grunt")
@export var manager_path: NodePath = NodePath("../EncounterManager")

var _combat: PlayerCombat
var _grunt: Grunt
var _manager: EncounterManager
var _label: Label


func _ready() -> void:
	_combat = get_node(player_path).get_node("PlayerCombat")
	_grunt = get_node(grunt_path)
	_manager = get_node(manager_path)
	_label = Label.new()
	_label.position = Vector2(8, 64)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	add_child(_label)


func _process(_delta: float) -> void:
	var state_text := "ĐANG ĐÁNH"
	match _manager.encounter_state():
		EncounterManager.State.WON:
			state_text = "THẮNG — R chơi lại"
		EncounterManager.State.LOST:
			state_text = "THUA — R chơi lại"
	_label.text = "PLAYER %d/%d | GRUNT %d/%d | %s" % [
		_combat.health.hp, _combat.health.max_hp,
		_grunt.health.hp, _grunt.health.max_hp,
		state_text,
	]
