class_name WaveHUD
extends CanvasLayer

## Arena HUD: player HP, current wave, alive enemies, encounter state.

@export var player_path: NodePath = NodePath("../Player")
@export var encounter_path: NodePath = NodePath("../WaveEncounter")

var _combat: PlayerCombat
var _encounter: WaveEncounter
var _label: Label


func _ready() -> void:
	_combat = get_node(player_path).get_node("PlayerCombat")
	_encounter = get_node(encounter_path)
	_label = Label.new()
	_label.position = Vector2(8, 64)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	add_child(_label)


func _process(_delta: float) -> void:
	var kernel := _encounter.kernel
	var state_text := "ĐANG ĐÁNH"
	var wave_text := "-"
	if kernel.state != WaveKernel.State.INACTIVE:
		wave_text = "%d/%d" % [kernel.wave_index + 1, kernel.wave_count()]
	match kernel.state:
		WaveKernel.State.PAUSED:
			state_text = "WAVE TIẾP THEO"
		WaveKernel.State.WON:
			state_text = "THẮNG — R chơi lại"
		WaveKernel.State.LOST:
			state_text = "THUA — R chơi lại"
	var line := "PLAYER %d/%d | WAVE %s | ENEMIES %d | %s" % [
		_combat.health.hp, _combat.health.max_hp,
		wave_text, _encounter.alive_count(), state_text,
	]
	var boss_line := _boss_line()
	if boss_line != "":
		line += "\n" + boss_line
	_label.text = line


## Boss row carries HP and phase so the phase flip is readable in the arena.
func _boss_line() -> String:
	for enemy in _encounter.enemies():
		if enemy is Boss:
			var boss := enemy as Boss
			return "BOSS %d/%d | PHASE %d" % [boss.hp(), boss.health.max_hp, boss.phase_number()]
	return ""
