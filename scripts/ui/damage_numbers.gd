class_name DamageNumbers
extends CanvasLayer

## T-031: the floating damage numbers. The kernel owns when a number lives and
## what it says; this node only turns a world point into an integer pixel box and
## keeps that box out of the telegraph decal under the target's feet.

signal shown(target_id: int, amount: int, total: int)
## Emitted whenever the readout turns on or off, whoever asked. The sheet listens
## instead of remembering the flag, so a third caller (the capture, a bot mode)
## cannot leave the button lying about the state.
signal enabled_changed

## Spec §4 anchor: above the receiver's origin (its feet), below its head.
const DEFAULT_ANCHOR_M := 1.1
## Rounding slack when converting a required pixel lift into world metres.
const LIFT_EPSILON_M := 0.01

## 0 keeps the jitter sequence fixed, which is what makes the capture repeatable.
@export var seed_value: int = 0
@export var anchor_min_m: float = DEFAULT_ANCHOR_M
## The clearance law can be switched off to prove the ruler works; the negative
## control in the L3 capture does exactly that.
@export var avoid_telegraph_band: bool = true

var _kernel: DamageNumbersKernel
var _root: Control
var _labels: Array[Label] = []
var _tick := 0
var _enabled := true
var _height_px := 0


func _ready() -> void:
	_kernel = DamageNumbersKernel.new(seed_value)
	_root = Control.new()
	_root.name = "Numbers"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Hd2dTheme.build()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	for i in DamageNumbersKernel.POOL_SIZE:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override(&"font_color", Hd2dTheme.DAMAGE)
		label.add_theme_color_override(&"font_outline_color", Hd2dTheme.DAMAGE_OUTLINE)
		label.add_theme_constant_override(&"outline_size", Hd2dTheme.DAMAGE_OUTLINE_PX)
		label.add_theme_font_size_override(&"font_size", Hd2dTheme.DAMAGE_FONT_SIZE)
		label.visible = false
		_root.add_child(label)
		_labels.append(label)


func _physics_process(_delta: float) -> void:
	_tick += 1
	_kernel.sweep(_tick)
	_render()


func show_hit(receiver: Node3D, target_id: int, amount: int) -> void:
	if not _enabled or amount <= 0:
		return
	var point := receiver.global_position + Vector3(0.0, anchor_min_m, 0.0)
	point = _clear_decal(receiver, point)
	var index := _kernel.spawn(target_id, amount, point, _tick)
	var total := int(_kernel.slot(index)["amount"])
	shown.emit(target_id, amount, total)


func set_enabled(flag: bool) -> void:
	if _enabled == flag:
		return
	_enabled = flag
	if not flag:
		_kernel.reset()
		_hide_all()
	enabled_changed.emit()


func is_enabled() -> bool:
	return _enabled


func reset() -> void:
	_kernel.reset()
	_hide_all()


func label_count() -> int:
	return _labels.size()


func active_count() -> int:
	return _kernel.active_count()


func slot_text(index: int) -> String:
	return _labels[index].text


## The pool is a law, so the tests and the capture verify the instances stayed
## the same objects instead of trusting a count.
func label_instance_ids() -> Array:
	var ids: Array = []
	for label in _labels:
		ids.append(label.get_instance_id())
	return ids


func slot_target_id(index: int) -> int:
	var entry := _kernel.slot(index)
	return -1 if entry.is_empty() else int(entry["target_id"])


## The box is the label's measured minimum, not its layout size: a Control inside
## a CanvasLayer is only sorted on a drawn frame, and both the tests and the
## capture need the number's extent on the tick it was placed.
func slot_rect(index: int) -> Rect2:
	var label := _labels[index]
	if not label.visible:
		return Rect2()
	return Rect2(label.position, label.get_combined_minimum_size())


static func aabb_corners(xform: Transform3D, aabb: AABB) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in 8:
		var corner := Vector3(
			aabb.position.x if (i & 1) == 0 else aabb.end.x,
			aabb.position.y if (i & 2) == 0 else aabb.end.y,
			aabb.position.z if (i & 4) == 0 else aabb.end.z)
		points.append(xform * corner)
	return points


static func projected_bbox(points: PackedVector3Array, camera: Camera3D) -> Rect2:
	if camera == null or points.is_empty():
		return Rect2()
	var band := Rect2()
	for i in points.size():
		var screen := camera.unproject_position(points[i])
		band = Rect2(screen, Vector2.ZERO) if i == 0 else band.expand(screen)
	return band


func _render() -> void:
	var camera := get_viewport().get_camera_3d()
	for i in _labels.size():
		var entry := _kernel.slot(i)
		var label := _labels[i]
		if entry.is_empty() or camera == null:
			label.visible = false
			continue
		var screen := camera.unproject_position(entry["point"] as Vector3)
		var age := _tick - int(entry["born"])
		var offset := entry["jitter"] as Vector2i
		var position := DamageNumbersKernel.snap_screen_px(screen) + offset
		position.y -= DamageNumbersKernel.rise_px(age)
		label.position = Vector2(position)
		label.text = str(int(entry["amount"]))
		label.modulate = Color(1, 1, 1, DamageNumbersKernel.alpha(age))
		label.visible = true


func _hide_all() -> void:
	for label in _labels:
		label.visible = false


## D-027 law: the number's box never overlaps the decal band that is visible
## under its target. The lift is resolved once, in world metres along the camera
## up axis, so the number keeps tracking the enemy as the camera follows the
## player instead of being pinned to a stale screen y.
func _clear_decal(receiver: Node3D, point: Vector3) -> Vector3:
	if not avoid_telegraph_band:
		return point
	var decal := receiver.get_node_or_null("Telegraph") as MeshInstance3D
	if decal == null or not decal.visible:
		return point
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return point
	var band := projected_bbox(aabb_corners(decal.global_transform, decal.get_aabb()), camera)
	var bottom := camera.unproject_position(point).y + float(_label_height_px())
	var need := bottom - band.position.y
	if need <= 0.0:
		return point
	var per_unit := _px_per_unit(camera, point)
	if per_unit <= 0.0:
		return point
	return point + camera.global_transform.basis.y * (ceilf(need / per_unit) + LIFT_EPSILON_M)


## The font cell is the floor: a label whose theme has not sorted yet still gets a
## clearance that matches what will actually be drawn.
func _label_height_px() -> int:
	if _height_px <= 0:
		_height_px = maxi(int(_labels[0].get_combined_minimum_size().y),
			Hd2dTheme.DAMAGE_FONT_SIZE)
	return _height_px


func _px_per_unit(camera: Camera3D, point: Vector3) -> float:
	var height := get_viewport().get_visible_rect().size.y
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return PixelGrid.ortho_px_per_unit(height, camera.size)
	return PixelGrid.persp_px_per_unit(height, camera.fov,
		camera.global_position.distance_to(point))
