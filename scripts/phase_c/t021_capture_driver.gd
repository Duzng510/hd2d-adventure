extends Node

## T-021 evidence: boss idle + the four telegraphs (smash, lunge, phase switch,
## sweep). Run with a real renderer:
## <GODOT> --path . res://scenes/phase_c/capture_t021.tscn --resolution 1280x720 --fixed-fps 60

const BOSS_SCENE := preload("res://scenes/combat/boss.tscn")
const EVIDENCE_DIR := "res://docs/phase-c/evidence/t021/"

var _arena: Node3D
var _director: CombatDirector
var _combat: PlayerCombat
var _player: PlayerController
var _boss: Boss


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	_arena = get_node("../GroveArena")
	_director = _arena.get_node("CombatDirector")
	_combat = _arena.get_node("Player/PlayerCombat")
	_player = _arena.get_node("Player")
	_arena.get_node("WaveEncounter").process_mode = Node.PROCESS_MODE_DISABLED
	_boss = BOSS_SCENE.instantiate() as Boss
	_boss.name = "T021Boss"
	_arena.add_child(_boss)
	_boss.set_physics_process(false)
	_run()


func _run() -> void:
	_set_player(Vector3(0.0, 0.0, 3.0))
	for _i in 5:
		await get_tree().physics_frame
	# Reference shot must show the boss with no live telegraph at all.
	print("idle state=%s frozen=%s" % [
		GruntAI.State.keys()[_boss.ai_state()], str(not _boss.is_physics_processing()),
	])
	(_boss.get_node("Telegraph") as MeshInstance3D).visible = false
	await _grab("idle.png")
	_boss.set_physics_process(true)
	await _capture_attack(BossAI.Attack.SMASH, Vector3(0.0, 0.0, 1.5), "smash_telegraph.png")
	await _capture_attack(BossAI.Attack.LUNGE, Vector3(0.0, 0.0, 3.5), "lunge_telegraph.png")
	await _capture_switch("phase_switch_telegraph.png")
	await _capture_attack(BossAI.Attack.SWEEP, Vector3(0.0, 0.0, 2.0), "sweep_telegraph.png", false)
	_copy_log()
	print("T-021 capture done: 5 PNGs + combat_log.csv -> %s" % EVIDENCE_DIR)
	get_tree().quit(0)


func _capture_attack(kind: int, player_at: Vector3, filename: String, do_reset: bool = true) -> void:
	if do_reset:
		_boss.reset()
		_combat.health.reset()
	_boss.global_position = Vector3.ZERO
	_set_player(player_at)
	var attempts := 0
	while attempts < 8:
		attempts += 1
		while _boss.ai_state() != GruntAI.State.TELEGRAPH:
			await get_tree().physics_frame
		if _boss.attack_kind() == kind:
			await _grab(filename)
			return
		while _boss.ai_state() != GruntAI.State.RECOVERY:
			await get_tree().physics_frame
		_combat.health.hp = _combat.health.max_hp
		_boss.global_position = Vector3.ZERO
	_set_player(player_at)
	print("T-021: attack kind %d never observed" % kind)


func _capture_switch(filename: String) -> void:
	_boss.reset()
	_combat.health.reset()
	_boss.global_position = Vector3.ZERO
	_set_player(Vector3(0.0, 0.0, 2.0))
	while _boss.ai_state() != GruntAI.State.TELEGRAPH:
		await get_tree().physics_frame
	_boss.apply_hit(150)
	while _boss.attack_kind() != BossAI.Attack.SWITCH:
		await get_tree().physics_frame
	_combat.health.hp = _combat.health.max_hp
	await _grab(filename)


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
		print("T-021: cannot read ", _director.log_path)
		return
	var target := FileAccess.open(EVIDENCE_DIR + "combat_log.csv", FileAccess.WRITE)
	if target != null:
		target.store_string(source.get_as_text())
		target.close()
	source.close()
