extends SceneTree

## Headless test for PixelGrid. Run:
## <GODOT> --headless --path . -s res://tests/test_pixel_grid.gd
## Negative control (must exit 1): append `-- negative`
## Single quit() via if/else (quit is deferred; last call wins).

const PixelGrid = preload("res://scripts/phase_a/pixel_grid.gd")

const H := 720.0
const PIXEL_SIZE := 0.05
const PPU := 72.0
## Camera offset (0,10,8) -> elevation atan(10/8); basis columns right/up/back.
const CAM_RIGHT := Vector3(1, 0, 0)
const CAM_UP := Vector3(0, 0.6246950476, -0.7808688094)
const CAM_BACK := Vector3(0, 0.7808688094, 0.6246950476)

var _fail := 0


func _init() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	if negative:
		# Known-bad fixture: claims the current FIXED_Y + tilted camera rig has square texels.
		_near("negative_control_square_texels", _fixed_y_aspect(), 1.0)
	else:
		_run_checks()
	if _fail == 0:
		print("PIXEL GRID TEST PASS")
		quit(0)
	else:
		print("PIXEL GRID TEST FAIL (%d)" % _fail)
		quit(1)


func _run_checks() -> void:
	_near("ortho_ppu", PixelGrid.ortho_px_per_unit(H, 10.0), PPU)
	_near("persp_ppu_fov90", PixelGrid.persp_px_per_unit(H, 90.0, 360.0), 1.0)
	_near("persp_ppu_double_depth", PixelGrid.persp_px_per_unit(H, 90.0, 720.0), 0.5)

	var horiz := PixelGrid.texel_screen_delta(CAM_RIGHT, CAM_RIGHT, CAM_UP, PPU, PIXEL_SIZE)
	var vert := PixelGrid.texel_screen_delta(Vector3.UP, CAM_RIGHT, CAM_UP, PPU, PIXEL_SIZE)
	_near("fixed_y_horiz_px", horiz.length(), 3.6)
	_near("fixed_y_vert_px", vert.length(), 3.6 * CAM_UP.y)
	_near("fixed_y_aspect", PixelGrid.texel_aspect(horiz, vert), CAM_UP.y)

	var bb_vert := PixelGrid.texel_screen_delta(CAM_UP, CAM_RIGHT, CAM_UP, PPU, PIXEL_SIZE)
	_near("full_billboard_aspect", PixelGrid.texel_aspect(horiz, bb_vert), 1.0)

	_near("ortho_size_1x", PixelGrid.ortho_size_for_scale(H, PIXEL_SIZE, 1), 36.0)
	_near("ortho_size_4x", PixelGrid.ortho_size_for_scale(H, PIXEL_SIZE, 4), 9.0)
	_near("integer_roundtrip_4x", PixelGrid.ortho_px_per_unit(H, 9.0) * PIXEL_SIZE, 4.0)
	_near("current_ortho_not_integer", fmod(PPU * PIXEL_SIZE, 1.0), 0.6)

	var step := PixelGrid.snap_step(PPU)
	_near("snap_step", step, 1.0 / PPU)
	var basis := Basis(CAM_RIGHT, CAM_UP, CAM_BACK)
	var desired := Vector3(0.3, 0.7, -1.1)
	var snapped := PixelGrid.snap_position(desired, basis, step)
	var local := basis.inverse() * snapped
	_near("snap_local_x_integer", fmod(local.x / step + 0.5, 1.0), 0.5)
	_near("snap_local_y_integer", fmod(local.y / step + 0.5, 1.0), 0.5)
	_near("snap_keeps_depth", local.z, (basis.inverse() * desired).z)
	_near("snap_idempotent", PixelGrid.snap_position(snapped, basis, step).distance_to(snapped), 0.0)
	_near("snap_disabled_noop", PixelGrid.snap_position(desired, basis, 0.0).distance_to(desired), 0.0)


func _fixed_y_aspect() -> float:
	var horiz := PixelGrid.texel_screen_delta(CAM_RIGHT, CAM_RIGHT, CAM_UP, PPU, PIXEL_SIZE)
	var vert := PixelGrid.texel_screen_delta(Vector3.UP, CAM_RIGHT, CAM_UP, PPU, PIXEL_SIZE)
	return PixelGrid.texel_aspect(horiz, vert)


func _near(name: String, got: float, want: float) -> void:
	if is_finite(got) and absf(got - want) < 1e-4:
		print("  ok %s" % name)
	else:
		_fail += 1
		printerr("  FAIL %s got=%.6f want=%.6f" % [name, got, want])