class_name BuffChoice
extends CanvasLayer

## T-030: the 3-card buff chooser from spec §6.3. Mounting it opts the wave
## flow into BUFF_PENDING (presence = enable); the panel is built in code so
## Hd2dTheme and UiCopy stay the only style/copy sources.

## 3 * CARD_SIZE.x + 4 * GAP wide; title + wave + cards + hint + margins tall.
const PANEL_SIZE := Vector2(544, 360)
const CARD_INSET := 8

@export var encounter_path: NodePath = NodePath("../GroveArena/WaveEncounter")
## Harness/L4 mode: take the first card on the spot, no pause and no UI.
@export var auto_pick: bool = false

var _encounter: WaveEncounter
var _offers: Array = []
var _open := false
var _tween: Tween

var _panel: PanelContainer
var _wave_label: Label
var _cards: Array[Button] = []
var _card_titles: Array[Label] = []
var _card_gains: Array[Label] = []
var _card_costs: Array[Label] = []


func _ready() -> void:
	# ALWAYS so the cards keep taking input (and the tween keeps running) while
	# the tree is paused by the chooser itself.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	_encounter = get_node_or_null(encounter_path) as WaveEncounter
	if _encounter == null:
		push_error("BuffChoice: encounter not found at " + str(encounter_path))
		return
	_encounter.set_buff_pick_enabled(true)
	_encounter.buff_offer.connect(_on_offer)


func present(offers: Array) -> void:
	_offers = offers.duplicate()
	for i in _cards.size():
		var has_card := i < _offers.size()
		_cards[i].visible = has_card
		_cards[i].disabled = not has_card
		_card_titles[i].text = ""
		_card_gains[i].text = ""
		_card_costs[i].text = ""
		if not has_card:
			continue
		var entry: Dictionary = _offers[i]
		_card_titles[i].text = str(entry["title"])
		# Prefix on its own line: "ĐỔI LẠI " costs 51 px of the 144 px text area,
		# which no informative cost fits after. Measured, not guessed.
		_card_gains[i].text = UiCopy.BUFF_GAIN + "\n" + str(entry["gain"])
		_card_costs[i].text = UiCopy.BUFF_COST + "\n" + str(entry["cost"])
	_wave_label.text = ""
	if _encounter != null and _encounter.kernel != null:
		_wave_label.text = UiCopy.BUFF_PANEL_WAVE % (_encounter.kernel.wave_index + 1)
	_open = true
	visible = true
	get_tree().paused = true
	_play_stagger()
	if not _cards.is_empty() and _cards[0].visible:
		_cards[0].grab_focus()


func is_open() -> bool:
	return _open


func card_count() -> int:
	return _offers.size()


func card_text(index: int) -> String:
	if index < 0 or index >= _cards.size():
		return ""
	return "\n".join([_card_titles[index].text, _card_gains[index].text,
		_card_costs[index].text])


## Test/capture seam: same path as a card press.
func debug_pick(index: int) -> void:
	_pick(index)


func _pick(index: int) -> void:
	if not _open:
		return
	if index < 0 or index >= _offers.size():
		return
	var id: StringName = _offers[index]["id"]
	if _encounter == null:
		push_error("BuffChoice: cannot apply buff without an encounter")
		return
	# A rejected pick (stale offer, wrong state) must not close the panel.
	if not _encounter.apply_buff(id):
		return
	_close()


func _on_offer(offers: Array) -> void:
	if _encounter == null:
		return
	if auto_pick:
		if not offers.is_empty():
			_encounter.apply_buff(offers[0]["id"])
		return
	present(offers)


func _close() -> void:
	_open = false
	visible = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	get_tree().paused = false


func _play_stagger() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	for i in _cards.size():
		var card := _cards[i]
		if not card.visible:
			continue
		card.pivot_offset = Vector2(Hd2dTheme.CARD_SIZE) / 2.0
		card.scale = Vector2(0.9, 0.9)
		card.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var delay := 0.05 * i
		_tween.tween_property(card, "scale", Vector2.ONE, 0.12) \
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(card, "modulate:a", 1.0, 0.12) \
			.set_delay(delay).set_ease(Tween.EASE_OUT)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme = Hd2dTheme.build()
	_panel.custom_minimum_size = PANEL_SIZE
	# Half-offset anchors, the sheet's proven pattern: PRESET_CENTER offsets
	# from a size that is still 0 before layout.
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -PANEL_SIZE.x / 2.0
	_panel.offset_top = -PANEL_SIZE.y / 2.0
	_panel.offset_right = PANEL_SIZE.x / 2.0
	_panel.offset_bottom = PANEL_SIZE.y / 2.0
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", Hd2dTheme.GAP / 2)
	_panel.add_child(column)

	var title := Label.new()
	title.text = UiCopy.BUFF_PANEL_TITLE
	title.add_theme_color_override(&"font_color", Hd2dTheme.ACCENT)
	title.add_theme_font_size_override(&"font_size", Hd2dTheme.TITLE_FONT_SIZE)
	column.add_child(title)

	_wave_label = Label.new()
	column.add_child(_wave_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", Hd2dTheme.GAP)
	column.add_child(row)
	for i in 3:
		_add_card(row, i)

	var hint := Label.new()
	hint.text = UiCopy.BUFF_PANEL_HINT
	column.add_child(hint)


func _add_card(row: HBoxContainer, index: int) -> void:
	var card := Button.new()
	card.custom_minimum_size = Vector2(Hd2dTheme.CARD_SIZE)
	card.pressed.connect(_pick.bind(index))
	row.add_child(card)

	# Button is not a Container: anchor the text stack into its rect by hand.
	var stack := VBoxContainer.new()
	stack.anchor_right = 1.0
	stack.anchor_bottom = 1.0
	stack.offset_left = CARD_INSET
	stack.offset_top = CARD_INSET
	stack.offset_right = -CARD_INSET
	stack.offset_bottom = -CARD_INSET
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override(&"separation", Hd2dTheme.GAP / 2)
	card.add_child(stack)

	var card_title := Label.new()
	card_title.add_theme_color_override(&"font_color", Hd2dTheme.ACCENT)
	card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(card_title)

	var gain := Label.new()
	gain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gain.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(gain)

	var cost := Label.new()
	cost.add_theme_color_override(&"font_color", Hd2dTheme.COST)
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(cost)

	_cards.append(card)
	_card_titles.append(card_title)
	_card_gains.append(gain)
	_card_costs.append(cost)
