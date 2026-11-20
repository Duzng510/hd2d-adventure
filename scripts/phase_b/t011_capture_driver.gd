extends Node

## T-011 evidence: telegraph (with overlay), active hit, recovery, player death.
## Run with a real renderer:
## <GODOT> --path . res://scenes/phase_b/capture_t011.tscn --resolution 1280x720 --fixed-fps 60

const EVIDENCE_DIR := "res://docs/phase-b/evidence/t011/"

var _player_combat: PlayerCombat
var _grunt: Grunt
var _director: CombatDirector
var _debug: DebugHitboxes


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var playground := get_node("../PhaseAPlayground")
	_player_combat = playground.get_node("Player/PlayerCombat")
	_grunt = playground.get_node("Grunt")
	_director = playground.get_node("CombatDirector")
	_debug = playground.get_node("DebugHitboxes")
	_run()


func _run() -> void:
	for _i in 10:
		await get_tree().process_frame
	_player_combat.aim_override_enabled = true
	while _grunt.ai_state() != GruntAI.State.TELEGRAPH:
		await get_tree().physics_frame
	for _i in 3:
		await get_tree().physics_frame
	await _grab("telegraph.png")
	_debug.set_overlays_visible(true)
	await _grab("telegraph_hitbox_overlay.png")
	_debug.set_overlays_visible(false)
	_player_combat.aim_override_point = _grunt.global_position
	Input.action_press(&"light_attack")
	await get_tree().physics_frame
	Input.action_release(&"light_attack")
	while _player_combat.attack_phase() != AttackState.Phase.ACTIVE:
		await get_tree().physics_frame
	await _grab("player_attack_hit.png")
	while _player_combat.attack_phase() != AttackState.Phase.NONE:
		await get_tree().physics_frame
	while _grunt.ai_state() != GruntAI.State.ACTIVE:
		await get_tree().physics_frame
	await _grab("active_hit.png")
	while _grunt.ai_state() != GruntAI.State.RECOVERY:
		await get_tree().physics_frame
	await _grab("recovery.png")
	while not _player_combat.is_dead():
		await get_tree().physics_frame
	await _grab("player_dead.png")
	_copy_log()
	print("T-011 capture done: 6 PNGs + combat_log.csv -> %s" % EVIDENCE_DIR)
	get_tree().quit(0)


func _grab(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(EVIDENCE_DIR + filename)


func _copy_log() -> void:
	var source := FileAccess.open(_director.log_path, FileAccess.READ)
	if source == null:
		print("T-011: cannot read ", _director.log_path)
		return
	var target := FileAccess.open(EVIDENCE_DIR + "combat_log.csv", FileAccess.WRITE)
	if target != null:
		target.store_string(source.get_as_text())
		target.close()
	source.close()
