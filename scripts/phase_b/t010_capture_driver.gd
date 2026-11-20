extends Node

## T-010 evidence: D1 hitbox overlay before/after + startup/active/recovery frames.
## Run with a real renderer:
## <GODOT> --path . res://scenes/phase_b/capture_t010.tscn --resolution 1280x720 --fixed-fps 60

const EVIDENCE_DIR := "res://docs/phase-b/evidence/t010/"

var _combat: PlayerCombat
var _director: CombatDirector
var _debug: DebugHitboxes


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var playground := get_node("../PhaseAPlayground")
	_combat = playground.get_node("Player/PlayerCombat")
	_director = playground.get_node("CombatDirector")
	_debug = playground.get_node("DebugHitboxes")
	_run()


func _run() -> void:
	for _i in 10:
		await get_tree().process_frame
	Input.warp_mouse(Vector2(1150, 360))
	for _i in 10:
		await get_tree().process_frame
	await _grab("d1_hitboxes_off.png")
	_debug.set_overlays_visible(true)
	await _grab("d1_hitboxes_on.png")
	_debug.set_overlays_visible(false)
	Input.action_press(&"light_attack")
	await get_tree().physics_frame
	Input.action_release(&"light_attack")
	await get_tree().physics_frame
	await _grab("swing_startup.png")
	while _combat.attack_phase() != AttackState.Phase.ACTIVE:
		await get_tree().physics_frame
	await _grab("swing_active.png")
	while _combat.attack_phase() != AttackState.Phase.RECOVERY:
		await get_tree().physics_frame
	await _grab("swing_recovery.png")
	while _combat.attack_phase() != AttackState.Phase.NONE:
		await get_tree().physics_frame
	await _grab("attack_end.png")
	_copy_log()
	print("T-010 capture done: 5 PNGs + combat_log.csv -> %s" % EVIDENCE_DIR)
	get_tree().quit(0)


func _grab(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(EVIDENCE_DIR + filename)


func _copy_log() -> void:
	var source := FileAccess.open(_director.log_path, FileAccess.READ)
	if source == null:
		print("T-010: cannot read ", _director.log_path)
		return
	var target := FileAccess.open(EVIDENCE_DIR + "combat_log.csv", FileAccess.WRITE)
	if target != null:
		target.store_string(source.get_as_text())
		target.close()
	source.close()
