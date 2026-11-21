class_name DamageNumbersKernel
extends RefCounted

## T-031: the laws behind the floating numbers, as pure tick math. Keeping them
## out of the node is what makes merge/expiry/pool testable headless and makes
## the view nothing more than projection plus drawing.

const POOL_SIZE := 24
## 0.55 s on the 60 tick physics clock (spec §7 motion budget).
const LIFE_TICKS := 33
## Hits landing on the same target inside this many ticks sum into one chain, so
## a multi-hit swing draws a single climbing number instead of a stack (spec §4).
const MERGE_TICKS := 6
const JITTER_STEP_PX := 8
const JITTER_MAX_STEPS := 3
const RISE_PX := 24

var _slots: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	# Pinned (not randomized) by default: the capture evidence and the L4 notes
	# have to be reproducible from the seed, like the buff offers are.
	_rng.seed = seed_value
	_slots.resize(POOL_SIZE)
	for i in POOL_SIZE:
		_slots[i] = {}


## Returns the slot that now holds this hit's total.
func spawn(target_id: int, amount: int, point: Vector3, tick: int) -> int:
	var index := _merge_slot(target_id, tick)
	if index >= 0:
		_slots[index]["amount"] = int(_slots[index]["amount"]) + amount
		return index
	index = _take_slot(tick)
	_slots[index] = {
		"target_id": target_id,
		"amount": amount,
		"point": point,
		"jitter": _roll_jitter(),
		"born": tick,
	}
	return index


func slot(index: int) -> Dictionary:
	return _slots[index]


func slot_count() -> int:
	return _slots.size()


func active_count() -> int:
	var n := 0
	for entry in _slots:
		if not entry.is_empty():
			n += 1
	return n


func sweep(tick: int) -> void:
	for i in _slots.size():
		if not _slots[i].is_empty() and tick - int(_slots[i]["born"]) >= LIFE_TICKS:
			_slots[i] = {}


func reset() -> void:
	for i in _slots.size():
		_slots[i] = {}


## The number climbs and fades; both are pure functions of age so the view never
## needs a tween that a headless test cannot step through.
static func rise_px(age: int) -> int:
	if age <= 0:
		return 0
	return int(roundf(float(RISE_PX) * minf(float(age), float(LIFE_TICKS - 1)) \
		/ float(LIFE_TICKS - 1)))


static func alpha(age: int) -> float:
	var fade_from := LIFE_TICKS * 2 / 3
	if age <= fade_from:
		return 1.0
	return clampf(1.0 - float(age - fade_from) / float(LIFE_TICKS - 1 - fade_from), 0.0, 1.0)


## Texel law D-008 for a world-anchored UI component: whole screen pixels only.
static func snap_screen_px(screen: Vector2) -> Vector2i:
	return Vector2i(int(roundf(screen.x)), int(roundf(screen.y)))


func _merge_slot(target_id: int, tick: int) -> int:
	for i in _slots.size():
		var entry := _slots[i]
		if entry.is_empty() or int(entry["target_id"]) != target_id:
			continue
		# The born tick is not refreshed: a chain keeps the original expiry, so a
		# steadily hit enemy cannot hold a label on screen forever.
		if tick - int(entry["born"]) < MERGE_TICKS:
			return i
	return -1


func _take_slot(tick: int) -> int:
	for i in _slots.size():
		if _slots[i].is_empty():
			return i
	var oldest := 0
	for i in _slots.size():
		if int(_slots[i]["born"]) < int(_slots[oldest]["born"]):
			oldest = i
	return oldest


func _roll_jitter() -> Vector2i:
	# y is drawn downward-negative: a number may shift up or sideways, never into
	# the ground where a telegraph decal lives (spec §4).
	return Vector2i(
		_rng.randi_range(-JITTER_MAX_STEPS, JITTER_MAX_STEPS) * JITTER_STEP_PX,
		-_rng.randi_range(0, JITTER_MAX_STEPS) * JITTER_STEP_PX)
