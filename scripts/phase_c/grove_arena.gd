extends Node3D

## Phase C arena wiring: code-gen placeholder textures + fadeable pillars.
## Mirrors playground.gd for the arena layout; playground itself stays untouched.

const FADEABLE := [
	"PillarA/MeshInstance3D",
	"PillarB/MeshInstance3D",
	"PillarC/MeshInstance3D",
]

@onready var _floor_mesh: MeshInstance3D = $Floor/MeshInstance3D
@onready var _player_sprite: Sprite3D = $Player/Sprite3D
@onready var _player_telegraph: MeshInstance3D = $Player/Telegraph


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PlaceholderTextures.make_grid_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	_floor_mesh.material_override = mat
	_player_sprite.texture = PlaceholderTextures.make_player_sprite()
	for path in FADEABLE:
		var mesh := get_node_or_null(path) as MeshInstance3D
		if mesh == null:
			continue
		var fader_material := StandardMaterial3D.new()
		fader_material.albedo_color = Color(0.85, 0.85, 0.88, 1.0)
		fader_material.roughness = 1.0
		fader_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = fader_material
		mesh.add_to_group(&"fadeable")
	var telegraph_material := StandardMaterial3D.new()
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_material.albedo_texture = PlaceholderTextures.make_telegraph_texture()
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	telegraph_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_player_telegraph.material_override = telegraph_material
	_player_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
