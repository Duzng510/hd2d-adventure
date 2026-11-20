extends Node3D

## Scene wiring: code-generated placeholder textures + fadeable occluder materials.

@onready var _floor_mesh: MeshInstance3D = $Floor/MeshInstance3D
@onready var _player_sprite: Sprite3D = $Player/Sprite3D
@onready var _telegraph: MeshInstance3D = $Player/Telegraph

const FADEABLE := ["Wall/MeshInstance3D", "Block/MeshInstance3D", "Roof/MeshInstance3D"]


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PlaceholderTextures.make_grid_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.uv1_scale = Vector3(5.0, 5.0, 1.0)
	_floor_mesh.material_override = mat
	_player_sprite.texture = PlaceholderTextures.make_player_sprite()
	for path in FADEABLE:
		var mesh := get_node_or_null(path) as MeshInstance3D
		if mesh == null:
			continue
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.85, 0.85, 0.88, 1.0)
		fm.roughness = 1.0
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = fm
		mesh.add_to_group(&"fadeable")
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_texture = PlaceholderTextures.make_telegraph_texture()
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_telegraph.material_override = tm
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF