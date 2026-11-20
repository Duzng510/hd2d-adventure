extends Node

## T-022 evidence: gate closed blocking the exit, gate open with the shrine ring,
## shrine healed. Run with a real renderer:
## <GODOT> --path . res://scenes/phase_c/capture_t022.tscn --resolution 1280x720 --fixed-fps 60

const EVIDENCE_DIR := "res://docs/phase-c/evidence/t022/"
const APPROACH := Vector3(0.0, 0.0, -4.5)

var _arena: Node3D
var _encounter: WaveEncounter
var _reward: Reward
var _director: CombatDirector
var _combat: PlayerCombat
var _player: PlayerController


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	_arena = get_node("../GroveArena")
	_encounter = _arena.get_node("WaveEncounter")
	_reward = _arena.get_node("Reward")
	_director = _arena.get_node("CombatDirector")
	_combat = _arena.get_node("Player/PlayerCombat")
	_player = _arena.get_node("Player")
	_run()


func _run() -> void:
	_encounter.reset_run()
	_walk_into_gate()
	await _grab("gate_closed.png")
	await _win()
	_release()
	_set_player(APPROACH)
	Input.action_press(&"move_up")
	while _player.global_position.z > -6.6:
		await get_tree().physics_frame
		_combat.health.hp = _combat.health.max_hp
	_release()
	await _grab("gate_open.png")
	_combat.health.apply_damage(60)
	while _combat.hp() < _combat.health.max_hp:
		await get_tree().physics_frame
	await _grab("shrine_healed.png")
	_copy_log()
	print("T-022 capture done: 3 PNGs + combat_log.csv -> %s" % EVIDENCE_DIR)
	get_tree().quit(0)


func _walk_into_gate() -> void:
	_set_player(APPROACH)
	Input.action_press(&"move_up")
	for _i in 60:
		await get_tree().physics_frame
		_combat.health.hp = _combat.health.max_hp
	_release()


func _win() -> void:
	var ticks := 0
	while _encounter.kernel.state != WaveKernel.State.WON and ticks < 1200:
		await get_tree().physics_frame
		ticks += 1
		if _encounter.kernel.state == WaveKernel.State.FIGHTING:
			for enemy in _encounter.enemies():
				if enemy.hp() > 0:
					enemy.apply_hit(9999)
	_combat.health.hp = _combat.health.max_hp


func _release() -> void:
	Input.action_release(&"move_up")


func _set_player(at: Vector3) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO


func _grab(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(EVIDENCE_DIR + filename)


func _copy_log() -> void:
	var source := FileAccess.open(_director.log_path, FileAccess.READ)
	if source == null:
		print("T-022: cannot read ", _director.log_path)
		return
	var target := FileAccess.open(EVIDENCE_DIR + "combat_log.csv", FileAccess.WRITE)
	if target != null:
		target.store_string(source.get_as_text())
		target.close()
	source.close()
