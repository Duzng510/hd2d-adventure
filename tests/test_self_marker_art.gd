extends SceneTree

## T-032 art laws for the feet ring. The ring already carries one meaning
## (T-026: "where am I"), so the tempo tier has to be provable as an addition
## that never rewrites it - and never touches the palette meanings D-017 fixed.

const DIAMETER := 0.9
const SIZE := 18
const CENTER := (SIZE - 1) * 0.5
const RADIUS := SIZE * 0.5
const TELL_INNER := 5.0
const TELL_OUTER := 6.0

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var tempo: Color = PlaceholderTextures.PALETTE.tempo
	_check(
		tempo != PlaceholderTextures.PALETTE.tunic
			and tempo != PlaceholderTextures.PALETTE.aim
			and tempo != PlaceholderTextures.PALETTE.outline,
		"the tell colour is not the ring, the reticle or the outline (D-017 meanings)"
	)

	var base := PlaceholderTextures.make_self_marker(DIAMETER)
	_check(base.get_width() == SIZE and base.get_height() == SIZE, "one tier of art is 18 whole texels at 0.9 m")

	# The T-026 evidence measured this exact texture, so tier 0 must still be it.
	var tier0 := _pixels(PlaceholderTextures.make_self_marker(DIAMETER, 0))
	var identical := true
	for y in SIZE:
		for x in SIZE:
			if base.get_image().get_pixel(x, y) != tier0[y][x]:
				identical = false
	_check(identical, "tier 0 is pixel-identical to the T-026 ring")

	var grown: Array = []
	for level in 4:
		grown.append(_tempo_count(PlaceholderTextures.make_self_marker(DIAMETER, level), tempo))
	_check(grown[0] == 0, "tier 0 paints no tell texel at all")
	for level in 3:
		_check(grown[level + 1] > grown[level], "tier %d paints more tell texels than tier %d" % [level + 1, level])
	_check(grown[1] == 0 if _negative else grown[1] > 0, "tier 1 is visible at all")
	_check(grown[3] > grown[2], "the ceiling tier is the fullest arc, not a fourth meaning")

	# The band and the four diagonal notches stay exactly as T-026 drew them.
	var untouched := true
	var band0 := _pixels(PlaceholderTextures.make_self_marker(DIAMETER, 0))
	var band3 := _pixels(PlaceholderTextures.make_self_marker(DIAMETER, 3))
	for y in SIZE:
		for x in SIZE:
			var d := _distance(x, y)
			if d < RADIUS - 2.0 or d > RADIUS:
				continue
			if band0[y][x] != band3[y][x]:
				untouched = false
	_check(untouched, "the position ring keeps every pixel the tier adds around it")

	# Texel-lock D-008 plus the gap: the arc may not merge with the ring band.
	var clean := true
	for y in SIZE:
		for x in SIZE:
			var d := _distance(x, y)
			if band3[y][x] == tempo and (d < TELL_INNER or d > TELL_OUTER + 1.0):
				clean = false
	_check(clean, "the arc lives inside d 5..6 and never touches the ring band")

	if _failures == 0:
		print("PASS test_self_marker_art: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_self_marker_art: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _pixels(texture: ImageTexture) -> Array:
	var image := texture.get_image()
	var rows: Array = []
	for y in SIZE:
		var row: Array = []
		for x in SIZE:
			row.append(image.get_pixel(x, y))
		rows.append(row)
	return rows


func _tempo_count(texture: ImageTexture, tempo: Color) -> int:
	var image := texture.get_image()
	var count := 0
	for y in SIZE:
		for x in SIZE:
			if image.get_pixel(x, y) == tempo:
				count += 1
	return count


func _distance(x: int, y: int) -> float:
	return Vector2(x - CENTER, y - CENTER).length()


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
