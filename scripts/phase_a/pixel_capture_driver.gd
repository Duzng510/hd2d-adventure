extends Node

## T-006 pixel-grid + shimmer capture. Run with a real renderer:
## <GODOT> --path . res://scenes/phase_a/capture_pixel.tscn --resolution 1280x720 --fixed-fps 60
##
## Shimmer metric: translate frame B by the rounded world screen shift and diff
## against frame A. Residual changed pixels = sub-pixel crawl (not rigid motion).
## HUD and the player/telegraph box are masked out, so the residual is world-only;
## sprite crawl is measured separately via the player's fractional screen position.

const EVIDENCE_DIR := "res://docs/phase-a/evidence/pixel/"
const ANCHOR := Vector3(6.0, 0.0, -2.0)
const MOTION_FRAMES := 24
const GRAB_A := 10
const GRAB_B := 11
const HUD_RECT := Rect2(0, 0, 1024, 64)
const PLAYER_MASK_HALF := 180.0
const DIFF_THRESHOLD := 8

const CONFIGS := [
	{"name": "persp_nosnap", "ortho": false, "size": 10.0, "snap": false},
	{"name": "persp_snap", "ortho": false, "size": 10.0, "snap": true},
	{"name": "ortho10_nosnap", "ortho": true, "size": 10.0, "snap": false},
	{"name": "ortho10_snap", "ortho": true, "size": 10.0, "snap": true},
	{"name": "ortho9_nosnap", "ortho": true, "size": 9.0, "snap": false},
	{"name": "ortho9_snap", "ortho": true, "size": 9.0, "snap": true},
]

var _player: PlayerController
var _camera: CameraRig
var _log: FileAccess


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	_player = get_node("../PhaseAPlayground/Player")
	_camera = get_node("../PhaseAPlayground/CameraRig")
	_log = FileAccess.open(EVIDENCE_DIR + "pixel_log.csv", FileAccess.WRITE)
	_log.store_line("config,frame,ppu,texel_w,texel_h,aspect,engine_texel_w,anchor_fx,anchor_fy,player_fx,player_fy,cam_x,cam_z")
	_run()


func _run() -> void:
	for cfg in CONFIGS:
		await _capture_config(cfg)
	_log.close()
	print("T-006 pixel capture done: %d configs -> %s" % [CONFIGS.size(), EVIDENCE_DIR])
	get_tree().quit(0)


func _capture_config(cfg: Dictionary) -> void:
	_camera.ortho_size = cfg.size
	_camera.snap_to_pixel = cfg.snap
	_camera.apply_mode(CameraRig.ProjectionMode.ORTHOGRAPHIC if cfg.ortho else CameraRig.ProjectionMode.PERSPECTIVE)
	_release_all()
	_player.global_position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	await _step(3)

	Input.action_press(&"move_right")
	var base := Vector2.ZERO
	var prev_pfrac := Vector2.ZERO
	var anchor_dev := Vector2.ZERO
	var player_dev := Vector2.ZERO
	var prev_img: Image = null
	var prev_anchor := Vector2.ZERO
	var prev_player := Vector2.ZERO
	var residual := -1
	var ppu := 0.0
	var texel := Vector2.ZERO

	for i in MOTION_FRAMES:
		await _step()
		var anchor := _camera.unproject_position(ANCHOR)
		var pscreen := _camera.unproject_position(_player.global_position)
		var afrac := _frac(anchor)
		var pfrac := _frac(pscreen)
		if i == 0:
			base = afrac
			prev_pfrac = pfrac
		anchor_dev.x = maxf(anchor_dev.x, absf(_wrap(afrac.x - base.x)))
		anchor_dev.y = maxf(anchor_dev.y, absf(_wrap(afrac.y - base.y)))
		player_dev.x = maxf(player_dev.x, absf(_wrap(pfrac.x - prev_pfrac.x)))
		player_dev.y = maxf(player_dev.y, absf(_wrap(pfrac.y - prev_pfrac.y)))
		prev_pfrac = pfrac

		ppu = _camera.px_per_unit()
		var cb := _camera.global_transform.basis
		texel = Vector2(
			PixelGrid.texel_screen_delta(cb.x, cb.x, cb.y, ppu, _camera.pixel_size).length(),
			PixelGrid.texel_screen_delta(Vector3.UP, cb.x, cb.y, ppu, _camera.pixel_size).length(),
		)
		var engine_texel_w := anchor.distance_to(_camera.unproject_position(ANCHOR + cb.x * _camera.pixel_size))
		var aspect := texel.y / texel.x
		_log.store_line("%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f" % [
			cfg.name, i, ppu, texel.x, texel.y, aspect,
			engine_texel_w, afrac.x, afrac.y, pfrac.x, pfrac.y,
			_camera.global_position.x, _camera.global_position.z,
		])

		if i == GRAB_A:
			prev_img = await _grab()
			prev_anchor = anchor
			prev_player = pscreen
			prev_img.save_png(EVIDENCE_DIR + cfg.name + "_a.png")
		elif i == GRAB_B:
			var cur := await _grab()
			cur.save_png(EVIDENCE_DIR + cfg.name + "_b.png")
			residual = _save_residual(prev_img, cur, Vector2i((anchor - prev_anchor).round()), (prev_player + pscreen) * 0.5, cfg.name)

	Input.action_release(&"move_right")
	print("%s: ppu=%.3f texel=%.3fx%.3f aspect=%.4f | anchor_dev=%.4f,%.4f player_dev=%.4f,%.4f | residual_px=%d" % [
		cfg.name, ppu, texel.x, texel.y, texel.y / texel.x, anchor_dev.x, anchor_dev.y,
		player_dev.x, player_dev.y, residual,
	])


func _save_residual(a: Image, b: Image, shift: Vector2i, mask_center: Vector2, tag: String) -> int:
	var w := a.get_width()
	var h := a.get_height()
	var da := a.get_data()
	var db := b.get_data()
	var out := PackedByteArray()
	out.resize(w * h * 3)
	var count := 0
	for y in h:
		for x in w:
			if HUD_RECT.has_point(Vector2(x, y)):
				continue
			if absf(x - mask_center.x) <= PLAYER_MASK_HALF and absf(y - mask_center.y) <= PLAYER_MASK_HALF:
				continue
			var bx := x + shift.x
			var by := y + shift.y
			if bx < 0 or by < 0 or bx >= w or by >= h:
				continue
			var ia := (y * w + x) * 4
			var ib := (by * w + bx) * 4
			var d := maxi(absi(da[ia] - db[ib]), maxi(absi(da[ia + 1] - db[ib + 1]), absi(da[ia + 2] - db[ib + 2])))
			if d > DIFF_THRESHOLD:
				count += 1
				var v := mini(255, d * 4)
				var o := (y * w + x) * 3
				out[o] = v
				out[o + 1] = v
				out[o + 2] = v
	Image.create_from_data(w, h, false, Image.FORMAT_RGB8, out).save_png(EVIDENCE_DIR + tag + "_residual.png")
	return count


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _step(n: int = 1) -> void:
	for i in n:
		await get_tree().process_frame


func _frac(v: Vector2) -> Vector2:
	return Vector2(v.x - floorf(v.x), v.y - floorf(v.y))


func _wrap(d: float) -> float:
	return d - roundf(d)


func _release_all() -> void:
	for action in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(action)