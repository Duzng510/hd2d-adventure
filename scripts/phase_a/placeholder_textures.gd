class_name PlaceholderTextures
extends RefCounted

## Code-generated placeholder textures: deterministic, shared palette, no external assets.

const PALETTE := {
	"outline": Color8(26, 28, 44),
	"skin": Color8(232, 190, 152),
	"tunic": Color8(86, 140, 110),
	"legs": Color8(52, 60, 88),
	"eye": Color8(26, 28, 44),
	"floor_a": Color8(122, 148, 104),
	"floor_b": Color8(112, 138, 96),
	"grid": Color8(84, 104, 74),
	"aim": Color8(255, 214, 90),
}


static func make_player_sprite() -> ImageTexture:
	# 24x32, facing right, feet on the bottom row (foot pivot = bottom center).
	var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var o: Color = PALETTE.outline
	_rect(img, 7, 1, 10, 10, o)
	_rect(img, 8, 2, 8, 8, PALETTE.skin)
	_rect(img, 13, 4, 2, 2, PALETTE.eye)
	_rect(img, 6, 10, 12, 12, o)
	_rect(img, 7, 11, 10, 10, PALETTE.tunic)
	_rect(img, 7, 18, 10, 2, PALETTE.legs)
	_rect(img, 7, 22, 10, 10, o)
	_rect(img, 8, 22, 3, 9, PALETTE.legs)
	_rect(img, 13, 22, 3, 9, PALETTE.legs)
	_rect(img, 7, 30, 5, 2, o)
	_rect(img, 12, 30, 5, 2, o)
	return ImageTexture.create_from_image(img)


static func make_grid_texture() -> ImageTexture:
	# 256x256, 8x8 cells of 32px; 1 cell = 1 world unit after uv1_scale.
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var c: Color = PALETTE.floor_a if ((x >> 5) + (y >> 5)) % 2 == 0 else PALETTE.floor_b
			if x % 32 == 0 or y % 32 == 0:
				c = PALETTE.grid
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func make_aim_marker_texture() -> ImageTexture:
	# 32x32 ground reticle: hollow ring + cross ticks + center dot, transparent bg.
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Color = PALETTE.aim
	var o: Color = PALETTE.outline
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			if d >= 11.0 and d < 13.0:
				img.set_pixel(x, y, c)
			elif d >= 13.0 and d < 14.0:
				img.set_pixel(x, y, o)
	_rect(img, 15, 2, 2, 6, c)
	_rect(img, 15, 24, 2, 6, c)
	_rect(img, 2, 15, 6, 2, c)
	_rect(img, 24, 15, 6, 2, c)
	_rect(img, 15, 15, 2, 2, c)
	return ImageTexture.create_from_image(img)


static func make_telegraph_texture() -> ImageTexture:
	# 64x64 danger-zone decal: translucent red fill + solid border + hazard ticks.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var fill := Color(0.85, 0.2, 0.2, 0.35)
	var edge := Color(0.95, 0.3, 0.25, 0.9)
	for y in 64:
		for x in 64:
			var border := x < 3 or y < 3 or x >= 61 or y >= 61
			img.set_pixel(x, y, edge if border else fill)
	for i in range(0, 64, 8):
		_rect(img, i, 30, 4, 4, edge)
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for iy in range(y, y + h):
		for ix in range(x, x + w):
			img.set_pixel(ix, iy, c)