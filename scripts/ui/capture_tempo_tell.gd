extends Node

## T-032 visual proof: each paid tier changes the ring by an amount a player can
## see, that change is confined to the ring, and it survives a boss body standing
## over the feet (the ring draws through geometry, so the tell inherits that).
## The last check puts a real damage number next to the tell and measures whether
## the two readouts ever sit on the same pixel.
##
##   <GODOT> --path . res://scenes/ui/capture_tempo_tell.tscn --fixed-fps 60
##   ... -- negative   ring depth-tested again: the boss hides the arc, so the
##                     per-tier diff collapses and the checks go red           -> exit 1

const EVIDENCE_DIR := "res://docs/phase-d/evidence/t032/"
## +Z is the camera side, so the frozen body projects down over the feet: the same
## staging T-026 used, which is what makes the ring here an occlusion proof.
const BOSS_OFFSET := Vector3(0.0, 0.0, 1.2)
## Swings aim north, away from the occluder, so nothing is hit during the ladder.
const WHIFF_AIM := Vector3(0.0, 0.0, -6.0)
const FEET_BOX := 80
const NEARBY_BOX := 200
## 12 texels per tier on the 18-texel ring (test_self_marker_art) is ~48 px across
## at 4 px/texel, so 40 px is the same floor T-026 and T-031 use.
const TIER_MIN_DIFF := 40
const LIT_MIN_PIXELS := 500
const MASH_GUARD := 400
const HIT_GUARD := 240

var _arena: Node3D
var _player: PlayerController
var _combat: PlayerCombat
var _encounter: WaveEncounter
var _numbers: DamageNumbers
var _marker: MeshInstance3D
var _material: StandardMaterial3D
var _boss: Node3D
var _negative := false
var _shots: Array = []
var _numbers_shot: Image = null
var _number_shown := false
var _checks := 0
var _failures := 0


func _ready() -> void:
	# ALWAYS: the ladder pauses the tree to freeze the pose and still has to run.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena = get_node("../GroveArena")
	_player = _arena.get_node("Player") as PlayerController
	_combat = _arena.get_node("Player/PlayerCombat") as PlayerCombat
	_encounter = _arena.get_node("WaveEncounter") as WaveEncounter
	_numbers = _arena.get_node("DamageNumbers") as DamageNumbers
	_marker = _arena.get_node("Player/SelfMarker") as MeshInstance3D
	_material = (_marker.mesh as QuadMesh).material as StandardMaterial3D
	_negative = OS.get_cmdline_user_args().has("negative")
	_stage()
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	_ladder.call_deferred()


func _stage() -> void:
	# Nothing in the neighbourhood may animate except the ring: no wave, no hits,
	# no numbers. The boss is a frozen body used only as an occluder.
	_player.global_position = Vector3(0.0, 0.0, 0.85)
	_player.velocity = Vector3.ZERO
	_encounter.set_physics_process(false)
	_encounter.debug_clear_enemies()
	_boss = _encounter.debug_spawn("boss", _player.global_position + BOSS_OFFSET)
	if _boss != null:
		_boss.set_process(false)
		_boss.set_physics_process(false)
	_combat.aim_override_enabled = true
	_combat.aim_override_point = _player.global_position + WHIFF_AIM
	_numbers.set_enabled(false)
	if _negative:
		_material.no_depth_test = false


func _ladder() -> void:
	if _boss == null:
		_report()
		return
	await _settle()
	var slots := _combat.fatigue_level_max()
	for tier in range(0, slots + 1):
		await _build_to(tier)
		_shots.append(await _grab("tier%d" % tier))
	# The control is a second frame of the same frozen pose at the same tier: the
	# tree stays paused, so a diff here can only be something that moves on its own.
	_shots.append(await _grab("control"))
	_numbers_shot = await _capture_number()
	_report()


func _build_to(tier: int) -> void:
	get_tree().paused = false
	var guard := 0
	while _combat.fatigue_level() < tier and guard < MASH_GUARD:
		guard += 1
		await get_tree().physics_frame
		if _combat.attack_phase() == AttackState.Phase.NONE:
			_combat.debug_request_attack()
	while _combat.attack_phase() != AttackState.Phase.NONE:
		await get_tree().physics_frame
	# Freeze before the shutter: with the tree paused nothing but the swapped ring
	# texture can differ between two frames, which is what P32.4 and P32.5 measure.
	get_tree().paused = true


## One real hit with the numbers layer back on, so the overlap check measures the
## two readouts as they actually coexist in play.
func _capture_number() -> Image:
	get_tree().paused = false
	_numbers.shown.connect(_on_number_shown)
	_numbers.set_enabled(true)
	_combat.aim_override_point = _boss.global_position
	var guard := 0
	while guard < HIT_GUARD and _combat.fatigue_level() < _combat.fatigue_level_max():
		guard += 1
		await get_tree().physics_frame
		if _combat.attack_phase() == AttackState.Phase.NONE:
			_combat.debug_request_attack()
	_number_shown = false
	while guard < HIT_GUARD and not _number_shown:
		guard += 1
		await get_tree().physics_frame
		if _combat.attack_phase() == AttackState.Phase.NONE:
			_combat.debug_request_attack()
	while _combat.attack_phase() != AttackState.Phase.NONE:
		await get_tree().physics_frame
	get_tree().paused = true
	_check(_number_shown, "P32.7a the hit landed and a number was published")
	return await _grab("numbers")


func _on_number_shown(_target_id: int, _amount: int, _total: int) -> void:
	_number_shown = true


func _settle() -> void:
	# A physics tick is not a drawn frame (lesson P26.3): wait for presentation or
	# the capture reads an empty image and every diff becomes meaningless.
	for _i in 3:
		await RenderingServer.frame_post_draw


func _grab(label: String) -> Image:
	await _settle()
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(EVIDENCE_DIR + "t032_%s.png" % label)
	if err != OK:
		push_error("capture_tempo_tell: cannot write %s (%d)" % [label, err])
	return image


func _report() -> void:
	_check(_shots.size() == 5 and _numbers_shot != null,
		"P32.1 six frames captured (%d + numbers)" % _shots.size())
	if _shots.size() < 5 or _numbers_shot == null:
		_finish()
		return
	var lit_min := 999999
	for shot in _shots:
		lit_min = mini(lit_min, _nonblack(shot))
	_check(lit_min >= LIT_MIN_PIXELS, "P32.2 every frame really rendered (lit px %d)" % lit_min)
	var weakest := 999999
	var leak := 0
	for i in range(1, 4):
		var changed := _box_diff(_shots[i - 1], _shots[i])
		var outside := _nearby_only_diff(_shots[i - 1], _shots[i])
		print("DIAG pair %d->%d inside=%d outside=%d" % [i - 1, i, changed, outside])
		if outside > 0:
			_dump_mask(_shots[i - 1], _shots[i], "%d_%d" % [i - 1, i])
		weakest = mini(weakest, changed)
		leak += outside
	_check(weakest >= TIER_MIN_DIFF,
		"P32.3 each paid tier moves the ring at least %d px (weakest step %d)" % [TIER_MIN_DIFF, weakest])
	_check(leak == 0,
		"P32.4 the tell stays on the ring: %d px changed outside the %d px feet box" % [leak, FEET_BOX])
	_check(_box_diff(_shots[3], _shots[4]) == 0,
		"P32.5 control: the same frozen tier changes 0 px (%d)" % _box_diff(_shots[3], _shots[4]))
	_check(_combat.fatigue_level() == _combat.fatigue_level_max(),
		"P32.6 the ladder really climbed to the ceiling tier (%d of %d)"
			% [_combat.fatigue_level(), _combat.fatigue_level_max()])
	_verify_number_clearance()
	_finish()


## The tell lives at the player's feet and the numbers over the enemy they hit,
## but a body standing between camera and player puts both in the same neighbourhood.
func _verify_number_clearance() -> void:
	var ring := _changed_set(_shots[2], _shots[3])
	var number := _changed_set(_shots[3], _numbers_shot)
	var overlap := 0
	for key in ring:
		if number.has(key):
			overlap += 1
	_check(number.size() >= TIER_MIN_DIFF,
		"P32.7 the damage number really appeared in the neighbourhood (%d px, so P32.8 cannot pass on nothing)"
			% number.size())
	_check(overlap == 0,
		"P32.8 no pixel is shared by the tier arc and a damage number (overlap=%d)" % overlap)


func _box_diff(before: Image, after: Image) -> int:
	return _changed_in_box(before, after, FEET_BOX)


func _nearby_only_diff(before: Image, after: Image) -> int:
	# Anything that moved in the 200 px neighbourhood but not inside the 80 px
	# feet box belongs to something other than the ring.
	var total := _changed_in_box(before, after, NEARBY_BOX)
	return total - _changed_in_box(before, after, FEET_BOX)


func _changed_in_box(before: Image, after: Image, box: int) -> int:
	if before == null or after == null:
		return 0
	var center := _feet_screen()
	var changed := 0
	for y in range(int(center.y) - box / 2, int(center.y) + box / 2):
		for x in range(int(center.x) - box / 2, int(center.x) + box / 2):
			if x < 0 or y < 0 or x >= before.get_width() or y >= before.get_height():
				continue
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				changed += 1
	return changed


func _changed_set(before: Image, after: Image) -> Dictionary:
	var set := {}
	var center := _feet_screen()
	for y in range(int(center.y) - NEARBY_BOX / 2, int(center.y) + NEARBY_BOX / 2):
		for x in range(int(center.x) - NEARBY_BOX / 2, int(center.x) + NEARBY_BOX / 2):
			if x < 0 or y < 0 or x >= before.get_width() or y >= before.get_height():
				continue
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				set["%d,%d" % [x, y]] = true
	return set


func _feet_screen() -> Vector2:
	var camera := _arena.get_node("CameraRig") as Camera3D
	return camera.unproject_position(_player.global_position + Vector3(0.0, 0.05, 0.0))


## A red-on-grey map of every changed pixel. When a locality check goes red the
## picture shows which neighbour moved; the count alone does not.
func _dump_mask(before: Image, after: Image, label: String) -> void:
	var mask := Image.create(before.get_width(), before.get_height(), false, Image.FORMAT_RGB8)
	mask.fill(Color(0.05, 0.05, 0.08))
	for y in before.get_height():
		for x in before.get_width():
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				mask.set_pixel(x, y, Color(1.0, 0.1, 0.1))
	mask.save_png(EVIDENCE_DIR + "t032_diff_%s.png" % label)


static func _nonblack(img: Image) -> int:
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).get_luminance() > 0.01:
				n += 1
	return n


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)


func _finish() -> void:
	print("checks=%d failures=%d mode=%s" % [_checks, _failures, "negative" if _negative else "normal"])
	print("%s capture_tempo_tell%s" % ["PASS" if _failures == 0 else "FAIL", " (control)" if _negative else ""])
	get_tree().quit(0 if _failures == 0 else 1)
