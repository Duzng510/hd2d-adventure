class_name DebugHitboxes
extends Node3D

## F1 overlay built from the actual Area3D CollisionShape3D boxes, never approximations.

const ATTACK_GROUPS: Array[StringName] = [&"player_attack", &"enemy_attack"]
const HURTBOX_GROUPS: Array[StringName] = [&"player_hurtbox", &"enemy_hurtbox"]
const ATTACK_COLOR := Color(1.0, 0.2, 0.2, 0.35)
const HURTBOX_COLOR := Color(0.2, 0.5, 1.0, 0.3)

var _overlays: Array[MeshInstance3D] = []


func _ready() -> void:
	for group in ATTACK_GROUPS:
		_build_group(group, ATTACK_COLOR)
	for group in HURTBOX_GROUPS:
		_build_group(group, HURTBOX_COLOR)
	set_overlays_visible(false)


func set_overlays_visible(value: bool) -> void:
	for overlay in _overlays:
		overlay.visible = value


func is_overlay_visible() -> bool:
	return _overlays.size() > 0 and _overlays[0].visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_hitboxes"):
		set_overlays_visible(not is_overlay_visible())


func _build_group(group: StringName, color: Color) -> void:
	for node in get_tree().get_nodes_in_group(group):
		var area := node as Area3D
		if area == null:
			continue
		for child in area.get_children():
			var shape_node := child as CollisionShape3D
			if shape_node == null:
				continue
			var box := shape_node.shape as BoxShape3D
			if box == null:
				continue
			_add_overlay(area, shape_node, box, color)


func _add_overlay(area: Area3D, shape_node: CollisionShape3D, box: BoxShape3D, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	mesh.transform = shape_node.transform
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	area.add_child(mesh)
	_overlays.append(mesh)
