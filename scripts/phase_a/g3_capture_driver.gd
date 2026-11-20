extends Node

## G3 occlusion gate capture. Per zone: teleport player, shoot with fade OFF
## (before) then ON (after), log active_fades. Also rechecks G2 left aim with
## fade ON. Real renderer required:
## <GODOT> --path . res://scenes/phase_a/capture_g3.tscn --resolution 1280x720 --fixed-fps 60

const EVIDENCE_DIR := "res://docs/phase-a/evidence/g3/"
const SETTLE := 6

const ZONES := [
	["g3_1_near", Vector3(-4, 0, 0.5)],
	["g3_2_wall", Vector3(4, 0, -3.6)],
	["g3_3_roof", Vector3(0, 0, 0)],
]

var _player: PlayerController
var _fader: OcclusionFader
var _log: FileAccess


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	_player = get_node("../PhaseAPlayground/Player")
	_fader = get_node("../PhaseAPlayground/OcclusionFader")
	_log = FileAccess.open(EVIDENCE_DIR + "g3_log.csv", FileAccess.WRITE)
	_log.store_line("tag,phase,active_fades")
	await _run()


func _run() -> void:
	for _k in 10:
		await get_tree().process_frame
	for zone in ZONES:
		_player.global_position = zone[1]
		_player.velocity = Vector3.ZERO
		_fader.enabled = false
		await _settle()
		await _shot(zone[0] + "_before")
		_log.store_line("%s,before,%d" % [zone[0], _fader.active_fades])
		_fader.enabled = true
		await _settle()
		await _shot(zone[0] + "_after")
		_log.store_line("%s,after,%d" % [zone[0], _fader.active_fades])
	Input.warp_mouse(Vector2(40, 360))
	await _settle()
	await _shot("g2_left_after_fade")
	_log.store_line("g2_left,after_fade,%d" % _fader.active_fades)
	_log.close()
	print("G3 capture done: 3 zones before/after + g2 left recheck at %s" % EVIDENCE_DIR)
	get_tree().quit(0)


func _settle() -> void:
	for _k in SETTLE:
		await get_tree().process_frame


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(EVIDENCE_DIR + tag + ".png")