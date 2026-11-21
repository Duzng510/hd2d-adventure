class_name Hd2dTheme
extends RefCounted

## T-029: code-generated HD-2D UI theme. No downloaded frames; StyleBoxFlat on
## a 4 px grid keeps the pixel discipline while the font carries the character.

const PANEL := Color("#12161c")
const BORDER := Color("#2c3542")
const ACCENT := Color("#d9b26a")
const TEXT := Color("#e8e4da")
const COST := Color("#c0695a")
const FONT_PATH := "res://assets/ui/fonts/vt323.ttf"
const UI_FONT_SIZE := 16  # native 8x16 terminal grid of VT323
const TITLE_FONT_SIZE := 32  # 2x body: still on the 8x16 cell, no resampling
const SHEET_SIZE := Vector2i(480, 432)
const CARD_SIZE := Vector2i(160, 220)
const GAP := 16


static func build() -> Theme:
	var theme := Theme.new()
	# Load the imported FontFile, not the raw ttf: load_dynamic_font bypasses the
	# import pipeline and silently falls back in exported builds.
	var font := load(FONT_PATH) as FontFile
	if font == null:
		push_error("Hd2dTheme: font failed to load: " + FONT_PATH)
	else:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.hinting = TextServer.HINTING_NONE
		if font.antialiasing != TextServer.FONT_ANTIALIASING_NONE \
				or font.subpixel_positioning != TextServer.SUBPIXEL_POSITIONING_DISABLED \
				or font.hinting != TextServer.HINTING_NONE:
			push_error("Hd2dTheme: cannot pin font rendering flags: " + FONT_PATH)
		theme.default_font = font
	theme.default_font_size = UI_FONT_SIZE

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = BORDER
	panel.set_border_width_all(2)
	panel.set_content_margin_all(GAP)
	panel.anti_aliasing = false
	theme.set_stylebox(&"panel", &"PanelContainer", panel)

	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_color(&"font_color", &"Button", TEXT)
	theme.set_color(&"font_focus_color", &"Button", ACCENT)
	theme.set_color(&"font_hover_color", &"Button", ACCENT)

	var button := StyleBoxFlat.new()
	button.bg_color = PANEL
	button.border_color = BORDER
	button.set_border_width_all(2)
	button.set_content_margin_all(8)
	button.anti_aliasing = false
	theme.set_stylebox(&"normal", &"Button", button)
	var focus := button.duplicate() as StyleBoxFlat
	focus.border_color = ACCENT
	theme.set_stylebox(&"focus", &"Button", focus)
	return theme
