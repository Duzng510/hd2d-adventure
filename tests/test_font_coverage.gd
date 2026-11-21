extends SceneTree

## T-029: every glyph the UI can draw must exist in the shipped pixel font.
## Missing diacritics would render tofu boxes in play; only a machine check
## keeps that from shipping silently.

const FONT_PATH := "res://assets/ui/fonts/vt323.ttf"
const CONTROL_CHAR := 0x4E00  # CJK ideograph: must be absent from VT323

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	var font := FontFile.new()
	_check(font.load_dynamic_font(FONT_PATH) == OK, "font file loads")
	var copy: Dictionary = (load("res://scripts/ui/ui_copy.gd") as GDScript).get_script_constant_map()
	var seen := {}
	var missing: Array[String] = []
	for value in copy.values():
		if typeof(value) != TYPE_STRING:
			continue
		var text := value as String
		for i in text.length():
			var code := text.unicode_at(i)
			if code <= 32 or seen.has(code):
				continue
			seen[code] = true
			if not font.has_char(code):
				missing.append("%s(U+%04X)" % [String.chr(code), code])
	_check(missing.is_empty(), "every UI glyph renders (missing: %s)" % [missing])
	# Control: the detector must be able to report a missing glyph.
	_check(font.has_char(CONTROL_CHAR) == negative,
		"control: coverage detector alive (has CJK = %s, expected %s)"
		% [font.has_char(CONTROL_CHAR), negative])
	if _failures == 0:
		print("PASS test_font_coverage: %d checks, %d glyphs, font cmap=%d codepoints, control U+%04X present=%s"
			% [_checks, seen.size(), font.get_supported_chars().length(), CONTROL_CHAR,
			font.has_char(CONTROL_CHAR)])
		quit(0)
	else:
		print("FAIL test_font_coverage: %d/%d checks failed (missing: %s)"
			% [_failures, _checks, missing])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
