class_name Reward
extends Node3D

## Phase C reward wiring: boss death opens the gate, the shrine past it heals the
## player once per run. Every decision lives in RewardKernel; this node only
## moves visuals, measures distance and logs.

const PLAYER_TARGET_ID := 2
const SHRINE_BODY_COLOR := Color(0.75, 0.85, 0.9)
const SHRINE_RING_COLOR := Color(0.45, 0.95, 0.75)

@export var encounter_path: NodePath = NodePath("../WaveEncounter")
@export var player_path: NodePath = NodePath("../Player")
@export var director_path: NodePath = NodePath("../CombatDirector")
@export var gate_body_path: NodePath = NodePath("../Gate")
@export var shrine_position := Vector3(0.0, 0.0, -7.2)
@export var shrine_radius: float = 1.5

var kernel := RewardKernel.new()

var _encounter: WaveEncounter
var _combat: PlayerCombat
var _player: PlayerController
var _director: CombatDirector
var _gate_shape: CollisionShape3D
var _gate_mesh: MeshInstance3D
var _shrine_ring: MeshInstance3D


func _ready() -> void:
	_encounter = get_node(encounter_path)
	_player = get_node(player_path)
	_combat = _player.get_node("PlayerCombat")
	_director = get_node(director_path)
	var gate := get_node(gate_body_path) as StaticBody3D
	_gate_shape = gate.get_node("CollisionShape3D") as CollisionShape3D
	_gate_mesh = gate.get_node("MeshInstance3D") as MeshInstance3D
	_build_shrine()
	_encounter.run_ended.connect(_on_run_ended)
	_encounter.run_reset.connect(_on_run_reset)
	_close_gate()


func _physics_process(_delta: float) -> void:
	if not kernel.gate_open() or _director.frozen_tick or _combat.is_dead():
		return
	if _player.global_position.distance_to(shrine_position) > shrine_radius:
		return
	var amount := kernel.try_heal(_combat.hp(), _combat.health.max_hp)
	if amount > 0:
		var applied := _combat.health.heal(amount)
		_director.log_event(&"reward", &"heal", 0, PLAYER_TARGET_ID, applied)


func _on_run_ended(won: bool) -> void:
	if not won or not kernel.grant():
		return
	_director.log_event(&"reward", &"reward_granted", 0, 0, 1)
	_open_gate()


func _on_run_reset() -> void:
	kernel.reset()
	_close_gate()


func _open_gate() -> void:
	_gate_shape.disabled = true
	_gate_mesh.visible = false
	_shrine_ring.visible = true


func _close_gate() -> void:
	_gate_shape.disabled = false
	_gate_mesh.visible = true
	_shrine_ring.visible = false


func _build_shrine() -> void:
	var shrine := Node3D.new()
	shrine.name = "Shrine"
	shrine.position = shrine_position
	add_child(shrine)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.8, 1.4, 0.8)
	body.mesh = body_mesh
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = SHRINE_BODY_COLOR
	body_material.roughness = 1.0
	body.material_override = body_material
	shrine.add_child(body)
	_shrine_ring = MeshInstance3D.new()
	var ring_mesh := QuadMesh.new()
	ring_mesh.size = Vector2(shrine_radius * 2.0, shrine_radius * 2.0)
	_shrine_ring.mesh = ring_mesh
	_shrine_ring.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, 0.04, 0.0))
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.albedo_texture = PlaceholderTextures.make_telegraph_disc(shrine_radius * 2.0)
	ring_material.albedo_color = SHRINE_RING_COLOR
	_shrine_ring.material_override = ring_material
	_shrine_ring.visible = false
	shrine.add_child(_shrine_ring)
