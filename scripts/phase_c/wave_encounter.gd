class_name WaveEncounter
extends Node

## Phase C arena encounter: spawns waves, drives WaveKernel, owns win/lose/reset
## and wave logging. Wave composition is data-driven: wave_roles lists a role
## per spawn and enemy_scenes maps each role to its scene. T-022 adds the reward.
## T-030 adds the per-run buff kernel, its seed log and the picked-buff path.

signal run_ended(won: bool)
signal run_reset
## Emitted once when the flow parks in BUFF_PENDING, carrying the 3-card offer.
signal buff_offer(offers: Array)

@export var tuning: CombatTuning
@export var enemy_scenes: Dictionary = {}
@export var wave_roles: Array = [
	["grunt", "grunt", "swarm", "swarm", "swarm"],
	["swarm", "swarm", "ranged", "ranged"],
	["boss"],
]
@export var wave_pause_frames: int = 60
@export var reset_delay_frames: int = 120
## T-030 opt-in, default off so every pre-T-030 harness keeps the auto-advance.
@export var buff_pick_enabled: bool = false
## Fixed first-run seed for harnesses; 0 rolls a random seed per run.
@export var buff_seed_base: int = 0
@export var player_path: NodePath = NodePath("../Player")
@export var director_path: NodePath = NodePath("../CombatDirector")
@export var player_spawn := Vector3(0.0, 0.0, 4.5)
@export var trigger_radius: float = 2.0
@export var spawn_offsets: Array[Vector3] = [
	Vector3(-2.5, 0.0, -4.5),
	Vector3(2.5, 0.0, -4.5),
	Vector3(0.0, 0.0, -4.5),
	Vector3(-5.0, 0.0, -2.0),
	Vector3(5.0, 0.0, -2.0),
]

var kernel: WaveKernel
## Current run's buff kernel; rebuilt per run so a reset re-rolls the seed.
var buff: BuffKernel
var runs_completed: int = 0
var wins: int = 0
var losses: int = 0

var _player: PlayerController
var _combat: PlayerCombat
var _director: CombatDirector
var _enemies: Array[Grunt] = []
var _end_frame: int = -1
var _next_target_id: int = 10
var _buff_seed: int = 0
var _offer_emitted: bool = false


func _ready() -> void:
	_player = get_node(player_path)
	_combat = _player.get_node("PlayerCombat")
	_director = get_node(director_path)
	var sizes: Array[int] = []
	for roles in wave_roles:
		sizes.append((roles as Array).size())
	kernel = WaveKernel.new(sizes, wave_pause_frames)
	kernel.buff_pick_enabled = buff_pick_enabled


func _physics_process(_delta: float) -> void:
	if _director.frozen_tick:
		return
	match kernel.state:
		WaveKernel.State.INACTIVE:
			if _player.global_position.distance_to(player_spawn) <= trigger_radius:
				_start_run()
		WaveKernel.State.FIGHTING, WaveKernel.State.PAUSED:
			if _combat.is_dead():
				kernel.player_died()
				_end_run(false)
				return
			kernel.tick(alive_count())
			if kernel.wave_start_pending:
				kernel.wave_start_pending = false
				_begin_wave()
			if kernel.state == WaveKernel.State.WON:
				_end_run(true)
		WaveKernel.State.BUFF_PENDING:
			if not _offer_emitted:
				_offer_emitted = true
				buff_offer.emit(buff.offer())
		WaveKernel.State.WON, WaveKernel.State.LOST:
			# A win keeps the player in control so the opened gate stays walkable.
			if kernel.state == WaveKernel.State.LOST and _end_frame >= 0 and _director.sim_frame - _end_frame >= reset_delay_frames:
				reset_run()


func alive_count() -> int:
	var alive := 0
	for enemy in _enemies:
		if enemy.hp() > 0:
			alive += 1
	return alive


func nearest_alive_position() -> Vector3:
	for enemy in _enemies:
		if enemy.hp() > 0:
			return enemy.global_position
	return _player.global_position


func wave_size(index: int) -> int:
	return (wave_roles[index] as Array).size()


func enemies() -> Array[Grunt]:
	var copy: Array[Grunt] = _enemies.duplicate()
	return copy


## Current run's buff seed (0 before the first run starts). Logged as buff_seed
## at run start, so a real run is reproducible from its combat log.
func buff_seed() -> int:
	return _buff_seed


## Opt the flow into BUFF_PENDING; the chooser UI calls this on _ready.
func set_buff_pick_enabled(enabled: bool) -> void:
	buff_pick_enabled = enabled
	if kernel != null:
		kernel.buff_pick_enabled = enabled


## Applies a picked buff. Only valid while the flow is parked in BUFF_PENDING,
## so a pick can never change the windows of a swing already in flight.
func apply_buff(id: StringName) -> bool:
	if buff == null or kernel.state != WaveKernel.State.BUFF_PENDING:
		return false
	var entry := buff.take(id)
	if entry.is_empty():
		return false
	_combat.stats.add_modifier(id, entry["ops"])
	_director.log_event(&"buff", &"buff_pick", 0, 0, BuffPool.index_of(id) + 1)
	_offer_emitted = false
	kernel.resolve_pick()
	return true


## Evidence-harness hook: drops the tracked enemies and in-flight projectiles
## without starting a new run, so a stage can measure one spawned role alone.
func debug_clear_enemies() -> void:
	for enemy in _enemies:
		enemy.queue_free()
	_enemies.clear()
	for projectile in get_tree().get_nodes_in_group(&"enemy_projectile"):
		projectile.queue_free()


func reset_run() -> void:
	for enemy in _enemies:
		enemy.queue_free()
	_enemies.clear()
	for projectile in get_tree().get_nodes_in_group(&"enemy_projectile"):
		projectile.queue_free()
	_player.global_position = player_spawn
	_player.velocity = Vector3.ZERO
	_player.facing = 1
	_combat.reset()
	_director.reset()
	kernel.reset()
	_next_target_id = 10
	_end_frame = -1
	_offer_emitted = false
	runs_completed += 1
	_director.log_event(&"encounter", &"encounter_reset", 0, 0, runs_completed)
	run_reset.emit()
	_start_run()


func _start_run() -> void:
	_buff_seed = (buff_seed_base + runs_completed) if buff_seed_base > 0 else (randi() % 1000000 + 1)
	buff = BuffKernel.new(BuffPool.pool(), _buff_seed)
	_offer_emitted = false
	_director.log_event(&"buff", &"buff_seed", 0, 0, _buff_seed)
	kernel.start()
	kernel.wave_start_pending = false
	_begin_wave()


func _begin_wave() -> void:
	var roles: Array = wave_roles[kernel.wave_index]
	for i in roles.size():
		debug_spawn(roles[i], spawn_offsets[i % spawn_offsets.size()])
	_director.log_event(&"encounter", &"wave_start", 0, 0, kernel.wave_index + 1)


## Spawns one enemy of `role` at `at` and registers it with the encounter.
## The wave loop uses it; the T-023 evidence stage uses it to spawn a single
## role outside a wave. Returns null when the role has no scene mapped.
func debug_spawn(role: String, at: Vector3) -> Grunt:
	var scene: PackedScene = enemy_scenes.get(role) as PackedScene
	if scene == null:
		push_error("WaveEncounter: missing enemy scene for role '%s'" % role)
		return null
	var enemy: Grunt = scene.instantiate()
	enemy.tuning = tuning
	enemy.player_path = NodePath("../../Player")
	enemy.director_path = NodePath("../../CombatDirector")
	enemy.target_id = _next_target_id
	_next_target_id += 1
	enemy.spawn_position = at
	enemy.position = at
	enemy.name = "Enemy_%s_%d" % [role, enemy.target_id]
	add_child(enemy)
	_enemies.append(enemy)
	return enemy


func _end_run(won: bool) -> void:
	_end_frame = _director.sim_frame
	if won:
		wins += 1
		_director.log_event(&"encounter", &"encounter_win")
	else:
		losses += 1
		_director.log_event(&"encounter", &"encounter_lose")
	run_ended.emit(won)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"encounter_reset"):
		reset_run()
