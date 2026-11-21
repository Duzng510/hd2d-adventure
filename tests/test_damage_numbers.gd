extends SceneTree

## T-031: the view's promises — whole-pixel placement, no allocation per hit,
## one box per merged chain, a toggle that really hides, and a number that never
## sits inside the telegraph decal of its own target. A real Camera3D stands in
## for the rig so the projection law is exercised, not mocked away.

const ORTHO_SIZE := 9.0
const ANCHOR_Y := 1.1

var _checks: int = 0
var _failures := 0
var _negative := false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ORTHO_SIZE
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0, 10, 8))
	root.add_child(camera)
	camera.make_current()
	await process_frame
	var numbers := DamageNumbers.new()
	numbers.seed_value = 7
	root.add_child(numbers)
	await process_frame
	_check(camera.is_current(), "the test camera really became current")
	# A live projection check, not a typeof() that is true by signature: the
	# ortho camera must move a higher world point upward on screen.
	var probe_low := camera.unproject_position(Vector3(0, 0, 0))
	var probe_high := camera.unproject_position(Vector3(0, ANCHOR_Y, 0))
	_check(probe_high.y < probe_low.y,
		"the camera projects: a higher world point sits higher on screen (%.1f vs %.1f)"
		% [probe_high.y, probe_low.y])

	# Every asserted group spawns its hits back to back (they then share one tick)
	# and waits for a render pass. SceneTree emits physics_frame *before* the nodes
	# run _physics_process, so one await only proves the hit was queued; a headless
	# frame can also carry catch-up ticks, so no check may depend on how long a
	# number has been alive.
	var receiver := _make_receiver(Vector3(1.0, 0.0, 0.0), false)
	root.add_child(receiver)
	await process_frame
	numbers.show_hit(receiver, 3, 13)
	numbers.show_hit(receiver, 3, 13)
	numbers.show_hit(receiver, 4, 9)
	await _drawn()
	var chain := _slot_of(numbers, 3)
	var other := _slot_of(numbers, 4)
	_check(chain >= 0 and other >= 0 and chain != other,
		"two targets hold two chains (slot %d / %d)" % [chain, other])
	_check(numbers.slot_text(chain) == "26",
		"the same target on one tick merges into one number (%s)" % numbers.slot_text(chain))
	_check(numbers.slot_text(other) == "9", "the other target keeps its own total")
	_check(_count_of(numbers, 3) == 1, "the merge took exactly one slot")
	var rect := numbers.slot_rect(chain)
	_check(rect.size.x > 0.0 and rect.size.y > 0.0, "the label has a measured box (%s)" % rect)
	_check(rect.position.x == roundf(rect.position.x) \
		and rect.position.y == roundf(rect.position.y),
		"the label sits on whole pixels (%s)" % rect.position)
	var projected := camera.unproject_position(receiver.global_position \
		+ Vector3(0, ANCHOR_Y, 0))
	var jitter_limit := float(DamageNumbersKernel.JITTER_MAX_STEPS \
		* DamageNumbersKernel.JITTER_STEP_PX)
	_check(absf(rect.position.x - roundf(projected.x)) <= jitter_limit \
		and rect.position.y <= roundf(projected.y),
		"the box stays inside the jitter range and never below the anchor (%s vs %s)"
		% [rect.position, projected])
	var ids := numbers.label_instance_ids()
	for i in 12:
		numbers.show_hit(receiver, 20 + i, 5)
	await physics_frame
	_check(numbers.label_instance_ids() == ids,
		"no label is allocated after _ready (%d instances)" % ids.size())
	_check(numbers.label_count() == DamageNumbersKernel.POOL_SIZE,
		"the view draws exactly the pool it was given")

	# Clearance law: the same target with a visible telegraph decal.
	# -- negative turns the law off through the production exports, so the check
	# below goes red because the number really sits in the band — not because a
	# test-only branch was added to the view.
	if _negative:
		numbers.avoid_telegraph_band = false
		numbers.anchor_min_m = 0.2
	var armed := _make_receiver(Vector3(3.0, 0.0, 0.0), true)
	root.add_child(armed)
	await process_frame
	numbers.show_hit(armed, 55, 10)
	await _drawn()
	var armed_index := _slot_of(numbers, 55)
	_check(armed_index >= 0, "the armed target got a number")
	var decal := armed.get_node("Telegraph") as MeshInstance3D
	var band := DamageNumbers.projected_bbox(
		DamageNumbers.aabb_corners(decal.global_transform, decal.get_aabb()), camera)
	var number_rect := numbers.slot_rect(armed_index)
	_check(number_rect.size.x > 0.0,
		"T31.c clearance is measured on a number that is really drawn (%s)" % number_rect)
	_check(number_rect.position.y + number_rect.size.y <= band.position.y + 0.5,
		"the number box ends above the telegraph band (box %s, band top %.1f)"
		% [number_rect, band.position.y])

	numbers.set_enabled(false)
	_check(not numbers.is_enabled() and numbers.active_count() == 0,
		"disabling hides every number at once")
	numbers.show_hit(receiver, 6, 10)
	_check(numbers.active_count() == 0, "a disabled layer swallows hits instead of queuing them")
	numbers.set_enabled(true)
	numbers.show_hit(receiver, 6, 10)
	_check(numbers.active_count() == 1, "re-enabling draws again (session toggle, not a restart)")
	numbers.reset()
	_check(numbers.active_count() == 0, "reset clears the board")

	numbers.queue_free()
	receiver.queue_free()
	armed.queue_free()
	await process_frame
	_finish()


## SceneTree emits physics_frame before the nodes get their _physics_process
## (measured: after one await the slot is alive but nothing is drawn yet), so
## reaching a render pass takes a second frame boundary.
func _drawn() -> void:
	await physics_frame
	await physics_frame


## A bare Node3D is not enough: the hit receiver is a body with a visible mesh,
## and the decal is the child node the view looks up by name.
func _make_receiver(at: Vector3, with_decal: bool) -> Node3D:
	var body := Node3D.new()
	body.position = at
	if with_decal:
		var decal := MeshInstance3D.new()
		decal.name = "Telegraph"
		decal.mesh = QuadMesh.new()
		(decal.mesh as QuadMesh).size = Vector2(1.6, 1.6)
		decal.rotation_degrees = Vector3(-90, 0, 0)
		decal.position = Vector3(0, 0.03, 0)
		body.add_child(decal)
	return body


func _slot_of(numbers: DamageNumbers, target_id: int) -> int:
	for i in numbers.label_count():
		if numbers.slot_target_id(i) == target_id:
			return i
	return -1


func _count_of(numbers: DamageNumbers, target_id: int) -> int:
	var n := 0
	for i in numbers.label_count():
		if numbers.slot_target_id(i) == target_id:
			n += 1
	return n


func _finish() -> void:
	if _failures == 0:
		print("PASS test_damage_numbers: %d checks%s"
			% [_checks, " (negative)" if _negative else ""])
		quit(0)
	else:
		print("FAIL test_damage_numbers: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
