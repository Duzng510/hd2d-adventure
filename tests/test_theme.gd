extends SceneTree

## T-029: the theme is the only style source; geometry obeys the grid laws.

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var theme := Hd2dTheme.build()
	_check(theme != null, "theme builds")
	_check(theme.default_font != null, "theme carries the pixel font")
	# 16 px is VT323's native 8x16 terminal grid; every size must stay on it.
	_check(theme.default_font_size % 16 == 0, "font size is a multiple of the 16 px glyph cell")
	_check(Hd2dTheme.TITLE_FONT_SIZE % 16 == 0, "title size is a multiple of the 16 px glyph cell")
	_check(Hd2dTheme.SHEET_SIZE.x % 4 == 0 and Hd2dTheme.SHEET_SIZE.y % 4 == 0,
		"sheet geometry sits on the 4 px grid")
	_check(Hd2dTheme.CARD_SIZE.x % 4 == 0 and Hd2dTheme.CARD_SIZE.y % 4 == 0,
		"card geometry sits on the 4 px grid")
	var panel := theme.get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	_check(panel != null and panel.bg_color == Hd2dTheme.PANEL, "panel stylebox uses the palette")
	_check(Hd2dTheme.ACCENT == Color("#d9b26a"), "accent is the approved gold")
	_check(Hd2dTheme.COST != Color("#d94a4a"), "cost red stays distinct from telegraph red")
	if _failures == 0:
		print("PASS test_theme: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_theme: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
