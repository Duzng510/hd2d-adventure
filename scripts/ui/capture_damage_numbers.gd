extends Node

## T-031 visual proof: the number really renders over the arena, it never touches
## the telegraph decal under its own target, and it says the damage the log
## carries. The two photographs are the same frozen pose with and without the
## readout, so the band diff can only be the number itself.
##
##   <GODOT> --path . res://scenes/ui/capture_damage_numbers.tscn --fixed-fps 60
##   ... -- negative    never attacks: no number, so the readout checks go red
##   ... -- low-anchor  clears the law through the production exports, so the
##                      number lands inside its own telegraph band (P31.4 red)

const EVIDENCE_DIR := "res://docs/phase-d/evidence/t031/"
## The number lands near the arena centre because the driver walks the player up
## to the spawned grunt. The band covers the enemy's screen area, not the HUD.
const NUMBERS_BAND := Rect2(0.30, 0.25, 0.40, 0.35)
const BAND_MIN_DIFF := 40
const LIT_MIN_PIXELS := 500
const TELEGRAPH_TIMEOUT := 900
const FOLLOW_OFFSET := 0.8

var _arena: Node
var _encounter: WaveEncounter
var _combat: PlayerCombat
var _player: PlayerController
var _director: CombatDirector
var _numbers: DamageNumbers
var _target: Grunt
var _decal: MeshInstance3D
var _mode := "normal"
var _damage_seen := false
var _logged_value := -1
var _logged_target := -1
var _shown_text := ""
var _number_rect := Rect2()
var _band := Rect2()
var _overlap := 0
var _save_ok := true
var _shots: Array = []
var _checks := 0
var _failures := 0


func _ready() -> void:
	# ALWAYS: the sequence pauses the tree to freeze the pose and still has to run.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena = get_node("../GroveArena")
	_encounter = _arena.get_node("WaveEncounter") as WaveEncounter
	_combat = _arena.get_node("Player/PlayerCombat") as PlayerCombat
	_player = _arena.get_node("Player") as PlayerController
	_director = _arena.get_node("CombatDirector") as CombatDirector
	_numbers = _arena.get_node("DamageNumbers") as DamageNumbers
	_encounter.set_physics_process(false)
	_encounter.debug_clear_enemies()
	_target = _encounter.debug_spawn("grunt", Vector3(1.2, 0.0, 0.6))
	_decal = _target.get_node("Telegraph") as MeshInstance3D
	_combat.aim_override_enabled = true
	_director.event_logged.connect(_on_damage)
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	_sequence.call_deferred()


func _sequence() -> void:
	await _settle()
	var args := OS.get_cmdline_user_args()
	if args.has("negative"):
		_mode = "negative"
	elif args.has("low-anchor"):
		_mode = "low-anchor"
		# The law is switched off through the shipped exports, not a test branch,
		# so this run proves the overlap check can actually fail.
		_numbers.anchor_min_m = 0.2
		_numbers.avoid_telegraph_band = false
	elif args.has("no-lift"):
		# The bare spec §4 anchor with the clearance law off: this is what measures
		# whether 1.1 m could have satisfied DG4 on its own.
		_mode = "no-lift"
		_numbers.avoid_telegraph_band = false
	print("MODE %s" % _mode)
	var waited := 0
	while waited < TELEGRAPH_TIMEOUT:
		await get_tree().physics_frame
		waited += 1
		# Balance is not on trial here: stand the player in range and keep the HP
		# topped so a death cannot end the run before the decal is measured.
		_combat.health.hp = _combat.health.max_hp
		_player.global_position = _target.global_position + Vector3(FOLLOW_OFFSET, 0.0, 0.0)
		_player.velocity = Vector3.ZERO
		_combat.aim_override_point = _target.global_position
		if not _decal.visible:
			continue
		if _mode == "negative":
			break
		if _combat.attack_phase() == AttackState.Phase.NONE:
			_combat.debug_request_attack()
		if _damage_seen:
			break
	_check(_decal.visible,
		"P31.0 the telegraph armed, so the overlap law was measured (waited %d ticks)" % waited)
	if _damage_seen:
		# Two physics frames: SceneTree emits physics_frame before the nodes run
		# _physics_process, so one only queues the draw.
		await get_tree().physics_frame
		await get_tree().physics_frame
		_measure()
	_check(_logged_value > 0 and not _shown_text.is_empty() and _number_rect.size.x > 0.0,
		"P31.1 a logged hit really drew a number (value %d, text [%s], box %s)"
		% [_logged_value, _shown_text, _number_rect])
	_check(_overlap == 0,
		"P31.4 the number box never touches the telegraph band (overlap %d px, box %s, band %s)"
		% [_overlap, _number_rect, _band])
	_shoot()


## The tick the damage lands. The decal's own four ground corners are used here
## instead of the view's eight AABB corners on purpose: if the two derivations of
## the band disagreed, a green overlap check would prove nothing.
func _on_damage(entity: StringName, event_name: StringName, _id: int, target_id: int, value: int) -> void:
	if entity != &"player" or event_name != &"damage" or _damage_seen:
		return
	_damage_seen = true
	_logged_value = value
	_logged_target = target_id


func _measure() -> void:
	var camera := get_viewport().get_camera_3d()
	var index := _slot_of(_logged_target)
	_number_rect = _numbers.slot_rect(index)
	_shown_text = _numbers.slot_text(index)
	var mesh := _decal.mesh as QuadMesh
	var half := mesh.size.x * 0.5 * _decal.global_transform.basis.get_scale().x
	var corners := PackedVector3Array([
		_decal.global_position + Vector3(-half, 0.0, -half),
		_decal.global_position + Vector3(half, 0.0, -half),
		_decal.global_position + Vector3(half, 0.0, half),
		_decal.global_position + Vector3(-half, 0.0, half)])
	_band = DamageNumbers.projected_bbox(corners, camera)
	_overlap = _overlap_px(_number_rect, _band)


func _slot_of(target_id: int) -> int:
	for i in _numbers.label_count():
		if _numbers.slot_target_id(i) == target_id:
			return i
	return -1


static func _overlap_px(a: Rect2, b: Rect2) -> int:
	var inter := a.intersection(b)
	if inter.size.x <= 0.0 or inter.size.y <= 0.0:
		return 0
	return int(roundf(inter.size.x * inter.size.y))


## Each mode owns its whole triple: sharing numbers_control.png between runs
## would leave the file on disk from whichever mode ran last, so the hit frame
## and its control would not be the same pose.
func _prefix() -> String:
	match _mode:
		"low-anchor":
			return "numbers_low_anchor"
		"no-lift":
			return "numbers_no_lift"
		"negative":
			return "numbers_negative"
	return "numbers"


## Freeze the pose, then photograph the same frame with and without the numbers,
## then the same frame twice with them off (the 0 px control).
func _shoot() -> void:
	get_tree().paused = true
	await _settle()
	_shots.append(_grab(_prefix() + "_hit"))
	_numbers.set_enabled(false)
	await _settle()
	_shots.append(_grab(_prefix() + "_control"))
	_shots.append(_grab(_prefix() + "_control2"))
	_report()


func _report() -> void:
	var lit: Array = []
	for shot in _shots:
		lit.append(_lit_pixels(shot) if shot != null else 0)
	_check(_shots.size() == 3 and _save_ok and not _shots.has(null)
		and lit[0] >= LIT_MIN_PIXELS and lit[1] >= LIT_MIN_PIXELS
		and _band_diff(_shots[1], _shots[2]) == 0,
		"P31.2 three frames saved and rendered (lit %s) and one pose twice differs by 0 px" % [lit])
	var diff := _band_diff(_shots[0], _shots[1])
	if _mode == "negative":
		_check(diff == 0,
			"P31.3 with no hit there is no number: band diff is %d px, need 0" % diff)
	else:
		_check(diff >= BAND_MIN_DIFF,
			"P31.3 the number moves pixels it owns (%d px in the numbers band, need >= %d)"
			% [diff, BAND_MIN_DIFF])
	_check(_shown_text == str(_logged_value),
		"P31.5 the drawn text is the damage the log carries ([%s] vs %d)"
		% [_shown_text, _logged_value])
	print("checks=%d failures=%d mode=%s band_diff=%d overlap=%d lit=%s" % [
		_checks, _failures, _mode, diff, _overlap, lit])
	print("%s t031_capture%s" % ["PASS" if _failures == 0 else "FAIL",
		" (%s)" % _mode if _mode != "normal" else ""])
	get_tree().quit(0 if _failures == 0 else 1)


func _settle() -> void:
	for _i in 3:
		await RenderingServer.frame_post_draw


func _grab(label: String) -> Image:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(EVIDENCE_DIR + "%s.png" % label)
	if err != OK:
		_save_ok = false
	print("SHOT %s%s (%d lit px)" % [label, "" if err == OK else " SAVE FAILED",
		_lit_pixels(image)])
	return image


static func _lit_pixels(image: Image) -> int:
	var n := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).get_luminance() > 0.02:
				n += 1
	return n


static func _band_diff(a: Image, b: Image) -> int:
	var w := a.get_width()
	var h := a.get_height()
	var from := Vector2i(int(NUMBERS_BAND.position.x * w), int(NUMBERS_BAND.position.y * h))
	var to := Vector2i(int((NUMBERS_BAND.position.x + NUMBERS_BAND.size.x) * w),
		int((NUMBERS_BAND.position.y + NUMBERS_BAND.size.y) * h))
	var changed := 0
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				changed += 1
	return changed


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
