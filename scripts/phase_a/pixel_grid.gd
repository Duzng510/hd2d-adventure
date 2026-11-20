class_name PixelGrid
extends RefCounted

## Pure texel -> screen-pixel math, node-free for headless tests.
## Ortho `size` is the vertical world extent (Camera3D keep_aspect = KEEP_HEIGHT).


static func ortho_px_per_unit(viewport_height: float, ortho_size: float) -> float:
	if ortho_size <= 1e-6:
		return 0.0
	return viewport_height / ortho_size


static func persp_px_per_unit(viewport_height: float, fov_deg: float, depth: float) -> float:
	if depth <= 1e-6:
		return 0.0
	return viewport_height / (2.0 * depth * tan(deg_to_rad(fov_deg) * 0.5))


static func texel_screen_delta(world_axis: Vector3, cam_right: Vector3, cam_up: Vector3, px_per_unit: float, pixel_size: float) -> Vector2:
	var scale := px_per_unit * pixel_size
	return Vector2(world_axis.dot(cam_right), world_axis.dot(cam_up)) * scale


## On-screen texel height / width. 1.0 means square texels.
static func texel_aspect(horizontal: Vector2, vertical: Vector2) -> float:
	var w := horizontal.length()
	if w <= 1e-6:
		return 0.0
	return vertical.length() / w


static func ortho_size_for_scale(viewport_height: float, pixel_size: float, px_per_texel: int) -> float:
	if px_per_texel <= 0:
		return 0.0
	return viewport_height * pixel_size / float(px_per_texel)


static func snap_step(px_per_unit: float) -> float:
	if px_per_unit <= 1e-6:
		return 0.0
	return 1.0 / px_per_unit


## Quantize along camera right/up so every world point shifts by whole screen pixels.
## Only exact for ortho: perspective px_per_unit varies with depth.
static func snap_position(desired: Vector3, cam_basis: Basis, step: float) -> Vector3:
	if step <= 0.0:
		return desired
	var local := cam_basis.inverse() * desired
	local.x = roundf(local.x / step) * step
	local.y = roundf(local.y / step) * step
	return cam_basis * local