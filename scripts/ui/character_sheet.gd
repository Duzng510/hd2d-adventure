class_name CharacterSheet
extends CanvasLayer

## T-029: ESC opens a paused character sheet. Every number is read from
## PlayerStats/WaveEncounter, so the panel cannot claim a value combat does not
## use. Nodes are built in code so the theme stays the single style source.

@export var combat_path: NodePath = NodePath("../Player/PlayerCombat")
@export var encounter_path: NodePath = NodePath("../WaveEncounter")
@export var damage_numbers_path: NodePath = NodePath("../DamageNumbers")

var _stats: PlayerStats
var _hp_source: Callable = Callable()
var _encounter: WaveEncounter
var _numbers: DamageNumbers
var _open := false

var _panel: PanelContainer
var _column: VBoxContainer
var _rows: Dictionary = {}
var _buff_list: VBoxContainer
var _toggle: Button
var _close: Button


func _ready() -> void:
	# ALWAYS, not WHEN_PAUSED: ESC has to be heard while the game runs, then
	# again while it is paused. WHEN_PAUSED would make the sheet unopenable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	_resolve_sources()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_character_sheet"):
		# T-030: the buff pick owns the screen until it resolves; opening the
		# sheet here would stack two pauses and hide the cards.
		if _encounter != null and _encounter.kernel != null \
				and _encounter.kernel.state == WaveKernel.State.BUFF_PENDING:
			return
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func set_sources(stats: PlayerStats, hp_source: Callable, encounter: WaveEncounter = null) -> void:
	_stats = stats
	_hp_source = hp_source
	_encounter = encounter
	if _open:
		refresh()


func is_open() -> bool:
	return _open


func set_damage_numbers(numbers: DamageNumbers) -> void:
	if _numbers != null and _numbers.enabled_changed.is_connected(_refresh_toggle):
		_numbers.enabled_changed.disconnect(_refresh_toggle)
	_numbers = numbers
	if _numbers != null and not _numbers.enabled_changed.is_connected(_refresh_toggle):
		_numbers.enabled_changed.connect(_refresh_toggle)
	_refresh_toggle()


## The state lives on the layer, so the sheet never has to remember it.
func toggle_numbers() -> void:
	if _numbers == null:
		return
	_numbers.set_enabled(not _numbers.is_enabled())
	_refresh_toggle()


func toggle_value_text() -> String:
	return "" if _toggle == null else _toggle.text


func _refresh_toggle() -> void:
	if _toggle == null:
		return
	var on := _numbers != null and _numbers.is_enabled()
	_toggle.text = UiCopy.SHEET_TOGGLE % [UiCopy.STATE_ON if on else UiCopy.STATE_OFF]
	_toggle.disabled = _numbers == null


func open() -> void:
	if _open:
		return
	# Child _ready order in the arena is not guaranteed to put PlayerCombat
	# first, so a source missed at _ready time is retried here.
	if _stats == null:
		_resolve_sources()
	_open = true
	visible = true
	refresh()
	_refresh_toggle()
	get_tree().paused = true
	if _close != null:
		_close.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false


func refresh() -> void:
	if _stats == null:
		return
	_rows[&"hp"].text = UiCopy.SHEET_HP_ROW % [_current_hp(), _stats.player_max_hp()]
	var cycle := _stats.light_startup_frames() + _stats.light_active_frames() \
		+ _stats.light_recovery_frames()
	_rows[&"damage"].text = UiCopy.SHEET_DAMAGE_ROW % [
		_stats.light_damage(), float(_stats.light_damage()) / float(maxi(cycle, 1))]
	_rows[&"cycle"].text = UiCopy.SHEET_CYCLE_ROW % [
		_stats.light_startup_frames(), _stats.light_active_frames(),
		_stats.light_recovery_frames(), cycle]
	_rows[&"reach"].text = UiCopy.SHEET_REACH_ROW % _stats.light_reach()
	_rows[&"combo"].text = UiCopy.SHEET_COMBO_ROW % [
		_stats.light_combo_hits(), _stats.combo_window_frames()]
	_rows[&"dodge"].text = UiCopy.SHEET_DODGE_ROW % [
		_stats.dodge_speed(), _stats.dodge_total_frames(), _stats.dodge_iframe_frames()]
	_rows[&"fatigue"].text = UiCopy.SHEET_FATIGUE_ROW % [
		_stats.fatigue_free_swings(), _stats.fatigue_step_frames(),
		_stats.fatigue_max_frames(), _stats.fatigue_decay_frames()]
	_rows[&"wave"].text = UiCopy.SHEET_PLACEHOLDER
	if _encounter != null and _encounter.kernel != null \
			and _encounter.kernel.state != WaveKernel.State.INACTIVE:
		_rows[&"wave"].text = UiCopy.SHEET_WAVE_ROW % [
			_encounter.kernel.wave_index + 1, _encounter.kernel.wave_count(),
			wave_state_text(_encounter.kernel.state)]
	_rows[&"seed"].text = UiCopy.SHEET_PLACEHOLDER
	if _encounter != null:
		_rows[&"seed"].text = str(_encounter.buff_seed())
	_refresh_buffs()


## The wave row has to say which of the three waiting states the player is in,
## and the HUD uses the same wording, so the mapping lives here as pure copy
## lookup rather than a second match a future state could miss.
static func wave_state_text(state: int) -> String:
	match state:
		WaveKernel.State.BUFF_PENDING:
			return UiCopy.BUFF_PANEL_TITLE
		WaveKernel.State.PAUSED:
			return UiCopy.HUD_NEXT
		WaveKernel.State.WON:
			return UiCopy.HUD_WIN
		WaveKernel.State.LOST:
			return UiCopy.HUD_LOSE
	return UiCopy.HUD_FIGHT


## T-030: each carried buff gets name + gain/cost rows (spec §5), sourced from
## the pool entry so the sheet cannot drift from the card copy. Old labels are
## freed immediately, not queue_free()d, so body_text() never reads a stale row.
func _refresh_buffs() -> void:
	for label in _buff_list.get_children():
		_buff_list.remove_child(label)
		label.free()
	var mods := _stats.active_modifiers()
	if mods.is_empty():
		_add_buff_line(UiCopy.SHEET_NONE)
		return
	var entries := {}
	for entry in BuffPool.pool():
		entries[entry["id"]] = entry
	for mod in mods:
		var source: StringName = mod["source"]
		var buff: Dictionary = entries.get(source, {})
		if buff.is_empty():
			_add_buff_line(str(source))
			continue
		_add_buff_line(UiCopy.SHEET_BUFF_LINE % [
			buff["title"],
			str(buff["gain"]).replace("\n", " · "),
			str(buff["cost"]).replace("\n", " · ")])


func _add_buff_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	_buff_list.add_child(label)


func body_text() -> String:
	if _rows.is_empty():
		return ""
	var parts: Array[String] = []
	for value in _rows.values():
		parts.append((value as Label).text)
	for label in _buff_list.get_children():
		parts.append((label as Label).text)
	return "\n".join(parts)


## Geometry truth gate: the panel must never have to grow past SHEET_SIZE, or the
## buff rows would leave the 4 px grid / overlap the arena framing.
func content_minimum_size() -> Vector2:
	if _column == null:
		return Vector2(Hd2dTheme.SHEET_SIZE)
	return _column.get_combined_minimum_size() \
		+ Vector2(Hd2dTheme.GAP * 2, Hd2dTheme.GAP * 2)


func _current_hp() -> int:
	if _hp_source.is_valid():
		return int(_hp_source.call())
	return _stats.player_max_hp()


func _resolve_sources() -> void:
	# The panel is built before sources resolve, so the toggle row already exists.
	set_damage_numbers(get_node_or_null(damage_numbers_path) as DamageNumbers)
	var combat := get_node_or_null(combat_path) as PlayerCombat
	if combat == null or combat.stats == null:
		return
	var hp := combat.health
	set_sources(combat.stats, func() -> int: return hp.hp,
		get_node_or_null(encounter_path) as WaveEncounter)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	# CanvasLayer has no theme; the panel roots every Control that reads it.
	_panel.theme = Hd2dTheme.build()
	_panel.custom_minimum_size = Vector2(Hd2dTheme.SHEET_SIZE)
	# Half-offset anchors, not PRESET_CENTER: the preset offsets from the size at
	# call time, which is still 0 before layout, so the panel would grow from the
	# middle of the screen instead of sitting on it.
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -Hd2dTheme.SHEET_SIZE.x / 2.0
	_panel.offset_top = -Hd2dTheme.SHEET_SIZE.y / 2.0
	_panel.offset_right = Hd2dTheme.SHEET_SIZE.x / 2.0
	_panel.offset_bottom = Hd2dTheme.SHEET_SIZE.y / 2.0
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", Hd2dTheme.GAP / 2)
	_panel.add_child(column)
	_column = column

	var title := Label.new()
	title.text = UiCopy.SHEET_TITLE
	title.add_theme_color_override(&"font_color", Hd2dTheme.ACCENT)
	title.add_theme_font_size_override(&"font_size", Hd2dTheme.TITLE_FONT_SIZE)
	column.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", Hd2dTheme.GAP)
	column.add_child(grid)
	_add_row(grid, &"hp", UiCopy.SHEET_HP)
	_add_row(grid, &"damage", UiCopy.SHEET_DAMAGE)
	_add_row(grid, &"cycle", UiCopy.SHEET_CYCLE)
	_add_row(grid, &"reach", UiCopy.SHEET_REACH)
	_add_row(grid, &"combo", UiCopy.SHEET_COMBO)
	_add_row(grid, &"dodge", UiCopy.SHEET_DODGE)
	_add_row(grid, &"fatigue", UiCopy.SHEET_FATIGUE)
	_add_row(grid, &"wave", UiCopy.SHEET_WAVE)
	_add_row(grid, &"seed", UiCopy.SHEET_SEED)

	var buff_title := Label.new()
	buff_title.text = UiCopy.SHEET_BUFFS
	buff_title.add_theme_color_override(&"font_color", Hd2dTheme.ACCENT)
	column.add_child(buff_title)
	_buff_list = VBoxContainer.new()
	_buff_list.add_theme_constant_override(&"separation", Hd2dTheme.GAP / 2)
	column.add_child(_buff_list)
	_add_buff_line(UiCopy.SHEET_NONE)

	_toggle = Button.new()
	_toggle.pressed.connect(toggle_numbers)
	column.add_child(_toggle)
	_refresh_toggle()

	_close = Button.new()
	_close.text = UiCopy.SHEET_CLOSE
	_close.pressed.connect(close)
	column.add_child(_close)


func _add_row(grid: GridContainer, key: StringName, label_text: String) -> void:
	var name_label := Label.new()
	name_label.text = label_text
	grid.add_child(name_label)
	var value := Label.new()
	value.text = UiCopy.SHEET_PLACEHOLDER
	grid.add_child(value)
	_rows[key] = value
