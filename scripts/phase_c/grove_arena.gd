extends Node3D

## Phase C arena wiring: code-gen placeholder textures + fadeable pillars.
## Mirrors playground.gd for the arena layout; playground itself stays untouched.

const FADEABLE := [
	"PillarA/MeshInstance3D",
	"PillarB/MeshInstance3D",
	"PillarC/MeshInstance3D",
]

const SELF_MARKER_DIAMETER := 0.9
const SELF_MARKER_PRIORITY := 10

## T-026: a 1.6x2.4 m boss body standing over the player hides the sprite, and
## enemy bodies cannot be faded (collision_layer 0, not in `fadeable`, and
## OcclusionFader collects once at load). A depth-free ring under the feet keeps
## "where am I" answerable without ghosting the thing the player must read.
@export var show_self_marker := true
## T-032: the paid tempo tier drawn on that same ring (D-019 risk 3 - the cost
## existed but nothing showed it). Off means the ring is exactly the T-026 art.
@export var show_tempo_tell := true

@onready var _floor_mesh: MeshInstance3D = $Floor/MeshInstance3D
@onready var _player_sprite: Sprite3D = $Player/Sprite3D
@onready var _player_telegraph: MeshInstance3D = $Player/Telegraph

## T-032: the ring material whose texture is swapped per tier, and the one tier
## of art per paid step (index 0 is the plain T-026 ring).
var _marker_material: StandardMaterial3D
var _tell_textures: Array[ImageTexture] = []


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
	_add_self_marker()


func _add_self_marker() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(SELF_MARKER_DIAMETER, SELF_MARKER_DIAMETER)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = SELF_MARKER_PRIORITY
	quad.material = material
	_marker_material = material
	_build_tell_textures()
	var marker := MeshInstance3D.new()
	marker.name = &"SelfMarker"
	marker.mesh = quad
	marker.position = Vector3(0.0, 0.03, 0.0)
	marker.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = show_self_marker
	$Player.add_child(marker)


## The ring carries the tempo tier too, so the art variants are built once here
## and the runtime path only swaps which texture the material already owns.
func _build_tell_textures() -> void:
	_tell_textures = [PlaceholderTextures.make_self_marker(SELF_MARKER_DIAMETER)]
	if not show_tempo_tell:
		return
	var combat := $Player/PlayerCombat as PlayerCombat
	var slots := combat.fatigue_level_max()
	for level in range(1, slots + 1):
		_tell_textures.append(
			PlaceholderTextures.make_self_marker(SELF_MARKER_DIAMETER, level, slots)
		)
	_marker_material.albedo_texture = _tell_textures[clampi(combat.fatigue_level(), 0, slots)]
	combat.fatigue_level_changed.connect(_on_fatigue_level_changed)


func _on_fatigue_level_changed(level: int) -> void:
	if _tell_textures.is_empty():
		return
	# Clamped in the view so a tuning change can never index past the built art.
	_marker_material.albedo_texture = _tell_textures[clampi(level, 0, _tell_textures.size() - 1)]
