extends Node3D

## T-028 menu backdrop. The grove is rebuilt here instead of instancing
## grove_arena.tscn, because WaveEncounter arms on the first physics frame and a
## live fight would run behind the menu. CameraRig keeps the drift on the
## whole-pixel grid, so the pan obeys the same texel law as gameplay.

const DRIFT_BASE := Vector3(0.0, 0.8, 2.0)

@export var drift_amplitude: float = 3.0
@export var drift_radians_per_second: float = 0.5

@onready var _drift: Node3D = $DriftPath
@onready var _floor_mesh: MeshInstance3D = $Floor/MeshInstance3D
@onready var _hero: Sprite3D = $Hero

var _elapsed := 0.0


func _ready() -> void:
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_texture = PlaceholderTextures.make_grid_texture()
	floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_material.roughness = 1.0
	# The floor is wider than the arena's 20x16 so a frame never shows the world
	# edge; these repeats bring the cells back to the arena's 0.625 x 0.5 m.
	floor_material.uv1_scale = Vector3(5.2, 6.0, 1.0)
	_floor_mesh.material_override = floor_material
	_hero.texture = PlaceholderTextures.make_player_sprite()


func _process(delta: float) -> void:
	_elapsed += delta
	_drift.position = DRIFT_BASE + Vector3(
		sin(_elapsed * drift_radians_per_second) * drift_amplitude, 0.0, 0.0)
