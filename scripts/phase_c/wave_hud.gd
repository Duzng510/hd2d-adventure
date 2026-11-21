class_name WaveHUD
extends CanvasLayer

## Arena HUD: player HP, current wave, alive enemies, encounter state.

@export var player_path: NodePath = NodePath("../Player")
@export var encounter_path: NodePath = NodePath("../WaveEncounter")
@export var reward_path: NodePath = NodePath("../Reward")

var _combat: PlayerCombat
var _encounter: WaveEncounter
var _reward: Reward
var _label: Label


func _ready() -> void:
	_combat = get_node(player_path).get_node("PlayerCombat")
	_encounter = get_node(encounter_path)
	_reward = get_node_or_null(reward_path) as Reward
	_label = Label.new()
	_label.position = Vector2(8, 64)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	add_child(_label)


func _process(_delta: float) -> void:
	var kernel := _encounter.kernel
	# One state->wording map (T-031): the sheet row and this HUD row must never
	# drift apart, and a second match is how BUFF_PENDING went missing here.
	var state_text := CharacterSheet.wave_state_text(kernel.state)
	var wave_text := UiCopy.HUD_WAVE_NONE
	if kernel.state != WaveKernel.State.INACTIVE:
		wave_text = UiCopy.HUD_WAVE_PROGRESS % [kernel.wave_index + 1, kernel.wave_count()]
	var line := UiCopy.HUD_ROW % [
		_combat.health.hp, _combat.health.max_hp,
		wave_text, _encounter.alive_count(), state_text,
	]
	var boss_line := _boss_line()
	if boss_line != "":
		line += "\n" + boss_line
	if _reward != null and _reward.kernel.gate_open():
		var reward_text := UiCopy.HUD_GATE_OPEN
		if _reward.kernel.state == RewardKernel.State.HEALED:
			reward_text = UiCopy.HUD_GATE_HEALED
		line += "\n" + reward_text
	_label.text = line


## Boss row carries HP and phase so the phase flip is readable in the arena.
func _boss_line() -> String:
	for enemy in _encounter.enemies():
		if enemy is Boss:
			var boss := enemy as Boss
			return UiCopy.HUD_BOSS_PHASE % [boss.hp(), boss.health.max_hp, boss.phase_number()]
	return ""
