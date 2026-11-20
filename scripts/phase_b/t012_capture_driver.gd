extends Node

## T-012 evidence: HUD fighting, victory banner, post-reset state, defeat banner.
## Run with a real renderer:
## <GODOT> --path . res://scenes/phase_b/capture_t012.tscn --resolution 1280x720 --fixed-fps 60

const EVIDENCE_DIR := "res://docs/phase-b/evidence/t012/"

var _player: PlayerController
var _combat: PlayerCombat
var _grunt: Grunt
var _manager: EncounterManager
var _director: CombatDirector


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var playground := get_node("../PhaseAPlayground")
	_player = playground.get_node("Player")
	_combat = playground.get_node("Player/PlayerCombat")
	_grunt = playground.get_node("Grunt")
	_manager = playground.get_node("EncounterManager")
	_director = playground.get_node("CombatDirector")
	_run()


func _run() -> void:
	for _i in 10:
		await get_tree().process_frame
	await _grab("hud_fighting.png")
	_combat.aim_override_enabled = true
	var guard := 0
	while _grunt.hp() > 0 and guard < 1200:
		guard += 1
		_combat.aim_override_point = _grunt.global_position
		var distance := _player.global_position.distance_to(_grunt.global_position)
		if _combat.attack_phase() == AttackState.Phase.NONE and distance <= 1.4:
			_combat.debug_request_attack()
		await get_tree().physics_frame
	for _i in 3:
		await get_tree().physics_frame
	await _grab("hud_win.png")
	while _manager.encounter_state() != EncounterManager.State.FIGHTING:
		await get_tree().physics_frame
	await _grab("hud_after_reset.png")
	while not _combat.is_dead():
		await get_tree().physics_frame
	await _grab("hud_lose.png")
	_copy_log()
	print("T-012 capture done: 4 PNGs + combat_log.csv -> %s" % EVIDENCE_DIR)
	get_tree().quit(0)


func _grab(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(EVIDENCE_DIR + filename)


func _copy_log() -> void:
	var source := FileAccess.open(_director.log_path, FileAccess.READ)
	if source == null:
		print("T-012: cannot read ", _director.log_path)
		return
	var target := FileAccess.open(EVIDENCE_DIR + "combat_log.csv", FileAccess.WRITE)
	if target != null:
		target.store_string(source.get_as_text())
		target.close()
	source.close()
