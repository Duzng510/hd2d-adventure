# T-031 Implementation Plan — floating damage numbers

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the damage the player just dealt as a floating number over the enemy that took it — readable over a 600+ horde, never inside a telegraph band, toggleable from the ESC sheet — without touching the combat schema or any existing harness behaviour.

**Architecture:** `DamageNumbersKernel` is a pure slot model (merge, expiry, pool, jitter, rise, alpha — all tick-driven) so the laws are testable headless. `DamageNumbers` is a thin `CanvasLayer` view that projects the kernel's world points to integer screen pixels and enforces the decal-clearance law. Exactly one hook is added to production combat code: `PlayerCombat._resolve_hits()` next to the existing `damage` log line. The layer opts itself in by existing in the scene (`damage_numbers_path` defaults to empty, so harnesses and scenes without it silently skip). The ESC sheet owns the information toggle.

**Tech Stack:** Godot 4.7.2 typed GDScript; physics-frame timing at 60 tick/s; headless `SceneTree` tests with negative controls; renderer-mode capture scenes (`--fixed-fps 60`) for L3 evidence; `Hd2dTheme`/`UiCopy` as the only style and copy sources.

**Spec:** `docs/phase-d/UI_PROGRESSION_SPEC.md` §4 (damage numbers), §5 (sheet toggle), §7 (UI laws), §8 (DG1–DG5). Branch: `phase-d/t031-damage-numbers`, cut from `main` after PR #25 merged T-030 (which owns `CharacterSheet` and `SHEET_SIZE`, both extended here).

## Global Constraints

- Godot exe: `"C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"` — never the `_console.exe` wrapper. In bash, `GODOT="C:/Users/My Lenovo/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"`.
- Timing is physics frames (60 tick/s) in `_physics_process`; no float `delta` for the merge window, lifetime, or rise.
- Texel law D-008: every damage-number screen position is an **integer pixel** (rounded from `Camera3D.unproject_position`), and the random offset lives on an **8 px grid** and never points downward (spec §4).
- One hook only: `player_combat.gd`. `CombatDirector`, `combat_log.gd`, the CSV schema and every enemy script stay **unmodified** — E1–E5 must keep grading unchanged (spec §4).
- No second source of truth: runtime player numbers keep flowing through `PlayerStats`; `node tools/check_stat_source.mjs` must stay clean and `--selftest` must stay red-capable.
- Defaults must keep every existing harness green: `damage_numbers_path` defaults to `NodePath("")` (no layer → no numbers, no crash); existing scenes other than `grove_arena.tscn` are not modified; the arena's gameplay logic is untouched.
- UI: all copy from `UiCopy` (the coverage gate scans it automatically); styles from `Hd2dTheme`; font sizes multiples of 16; panel geometry multiples of 4; damage numbers `#ffffff` with a 2 px black outline (spec §7 palette).
- Labels come from a fixed 24-slot pool — zero `Label` allocation after `_ready` (Intel UHD, no GC mid-horde).
- The toggle is an **information** toggle (session variable, no save), never a feel-effect switch (spec §9.4).
- Tests: exactly one `quit()` per path; stage by explicit path; commit every new `.gd` with its `.uid`; never commit `.godot/` or `.superpowers/`; never `git add -A`.
- Do not stage or revert the user's dirty paths: `docs/phase-c/evidence/t023/evidence_report.*`, `docs/phase-c/evidence/t027/session5/`, `assets/ui/fonts/vt323.ttf.import`. Because `tools/run_evidence.mjs` rewrites the t023 report, the E1–E5 regression runs are executed as the seven scenes directly instead (Task 5).
- L4 belongs to the user; AI scores nothing subjective.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `scripts/ui/damage_numbers_kernel.gd` | create | pure slots: merge ≤6 tick, life 33 tick, pool 24, 8 px jitter, rise, alpha |
| `tests/test_damage_numbers_kernel.gd` | create | the four laws above + seeded determinism + negative control |
| `scripts/ui/damage_numbers.gd` | create | `CanvasLayer` view: pool of Labels, world→integer-px projection, decal clearance, toggle |
| `scripts/ui/hd2d_theme.gd` | modify | `DAMAGE`/`DAMAGE_OUTLINE`/`DAMAGE_OUTLINE_PX`/`DAMAGE_FONT_SIZE`; `SHEET_SIZE` growth |
| `tests/test_theme.gd` | modify | damage-number style laws + the new sheet geometry |
| `tests/test_damage_numbers.gd` | create | view law test with a real `Camera3D`: integer px, no allocation, merge, toggle, clearance |
| `scripts/combat/player_combat.gd` | modify | `damage_numbers_path` + one call in `_resolve_hits` |
| `scenes/phase_c/grove_arena.tscn` | modify | mount `DamageNumbers` below `WaveHUD`, wire the PlayerCombat path |
| `scripts/phase_c/t031_numbers_driver.gd` | create | L2 flow evidence: 1 shown per damage log, pool ceiling, toggle law, negatives |
| `scenes/phase_c/run_t031_numbers.tscn` | create | the harness scene |
| `scripts/ui/ui_copy.gd` | modify | toggle copy, wave status row |
| `scripts/ui/character_sheet.gd` | modify | "Số sát thương" toggle row; wave row states; pre-`_ready` guards (T-030 debt) |
| `tests/test_character_sheet.gd` | modify | toggle roundtrip, session persistence, geometry gate |
| `scripts/phase_c/wave_hud.gd` | modify | `BUFF_PENDING` state text (T-030 debt, reuses approved copy) |
| `scripts/ui/capture_damage_numbers.gd` + `scenes/ui/capture_damage_numbers.tscn` | create | L3: band diff, 0 px telegraph overlap, lit pixels, text truth |
| `docs/DECISIONS.md` | modify | D-027 (damage-number laws + clearance law) |
| `docs/STATE.md` | modify | T-031 DONE, refreshed counts |
| `docs/phase-d/UI_PROGRESSION_SPEC.md` | modify | §7 sheet size if it grows (only if measured) |

---

### Task 1: DamageNumbersKernel (pure laws)

**Files:**
- Create: `scripts/ui/damage_numbers_kernel.gd`
- Test: `tests/test_damage_numbers_kernel.gd`

**Interfaces:**
- `class_name DamageNumbersKernel extends RefCounted`
  - `const POOL_SIZE := 24`, `const LIFE_TICKS := 33`, `const MERGE_TICKS := 6`, `const JITTER_STEP_PX := 8`, `const JITTER_MAX_STEPS := 3`, `const RISE_PX := 24`
  - `_init(seed_value: int = 0)`
  - `spawn(target_id: int, amount: int, point: Vector3, tick: int) -> int` → slot index; merges into a live slot of the same target when its age < `MERGE_TICKS`, otherwise takes a free slot or evicts the oldest.
  - `slot(index: int) -> Dictionary` → `{}` when empty, else `{"target_id": int, "amount": int, "point": Vector3, "jitter": Vector2i, "born": int}`
  - `sweep(tick: int) -> void` (frees expired slots), `active_count() -> int`, `slot_count() -> int`, `reset() -> void`
  - `static func rise_px(age: int) -> int`, `static func alpha(age: int) -> float`, `static func snap_screen_px(screen: Vector2) -> Vector2i`

- [ ] **Step 1: Write the failing test**

`tests/test_damage_numbers_kernel.gd`:

```gdscript
extends SceneTree

## T-031: the floating-number laws, tested without a renderer. Merge sums inside
## 6 ticks, the pool is a hard 24, the jitter sits on an 8 px grid and never
## points down, and everything is reproducible from the seed.

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	# On -- negative the merge window is forced to zero, so the merge laws below
	# must go red instead of passing on a chain that never formed.
	var merge_window := 0 if _negative else DamageNumbersKernel.MERGE_TICKS
	var kernel := DamageNumbersKernel.new(1234)
	_check(kernel.slot_count() == DamageNumbersKernel.POOL_SIZE,
		"the pool is fixed at %d slots" % DamageNumbersKernel.POOL_SIZE)
	_check(kernel.active_count() == 0, "nothing is alive before the first hit")

	var first := kernel.spawn(7, 13, Vector3(0, 1, 0), 100)
	_check(kernel.active_count() == 1, "one hit takes one slot")
	_check(int(kernel.slot(first)["amount"]) == 13, "the slot carries the amount")
	var jitter := kernel.slot(first)["jitter"] as Vector2i
	_check(jitter.x % 8 == 0 and jitter.y % 8 == 0,
		"jitter sits on the 8 px grid (%s)" % jitter)
	_check(jitter.y <= 0, "jitter never displaces downward (%s)" % jitter)
	_check(absi(jitter.x) <= 24 and absi(jitter.y) <= 24,
		"jitter stays inside 3 steps (%s)" % jitter)

	# The second hit lands one tick before the window closes: a correct kernel
	# merges, and the -- negative zeroed window must refuse to.
	var again := kernel.spawn(7, 13, Vector3(0, 1, 0), 100 + maxi(merge_window - 1, 0))
	_check(again == first and int(kernel.slot(first)["amount"]) == 26,
		"T31.m same target inside the window merges (sum %d, slot %d/%d)"
		% [int(kernel.slot(first)["amount"]), again, first])
	_check(kernel.active_count() == 1, "the merge did not take a second slot")
	var late := kernel.spawn(7, 5, Vector3(0, 1, 0), 140)
	_check(late != first and int(kernel.slot(late)["amount"]) == 5,
		"a hit 40 ticks later opens its own chain (slot %d)" % late)

	kernel.reset()
	for i in 30:
		kernel.spawn(100 + i, 10, Vector3(i, 1, 0), 200 + i)
	_check(kernel.active_count() == DamageNumbersKernel.POOL_SIZE,
		"the pool never grows past %d (active %d)"
		% [DamageNumbersKernel.POOL_SIZE, kernel.active_count()])
	var oldest_gone := true
	for i in kernel.slot_count():
		if int(kernel.slot(i)["target_id"]) == 100:
			oldest_gone = false
	_check(oldest_gone, "the oldest slot is the one that gets evicted")

	kernel.reset()
	var born := kernel.spawn(9, 7, Vector3.ZERO, 500)
	kernel.sweep(500 + DamageNumbersKernel.LIFE_TICKS - 1)
	_check(not kernel.slot(born).is_empty(),
		"a number is still alive on its last tick")
	kernel.sweep(500 + DamageNumbersKernel.LIFE_TICKS)
	_check(kernel.slot(born).is_empty() and kernel.active_count() == 0,
		"the number is gone after 0.55 s (33 ticks)")

	var ages_ok := true
	var previous := 9999
	for age in DamageNumbersKernel.LIFE_TICKS:
		var rise := DamageNumbersKernel.rise_px(age)
		var a := DamageNumbersKernel.alpha(age)
		ages_ok = ages_ok and rise >= 0 and rise <= DamageNumbersKernel.RISE_PX \
			and a <= 1.0 and a >= 0.0 and a <= float(previous)
		previous = int(a * 1000)
	_check(ages_ok, "rise stays in 0..24 px and alpha never rises back up")
	_check(DamageNumbersKernel.rise_px(0) == 0
		and DamageNumbersKernel.rise_px(DamageNumbersKernel.LIFE_TICKS - 1)
			== DamageNumbersKernel.RISE_PX,
		"the climb spans the whole life")
	_check(DamageNumbersKernel.alpha(0) == 1.0
		and DamageNumbersKernel.alpha(DamageNumbersKernel.LIFE_TICKS - 1) < 0.1,
		"readable at birth, faded at death")

	for pair in [[Vector2(100.4, 200.6), Vector2i(100, 201)],
			[Vector2(-0.6, -3.4), Vector2i(-1, -3)],
			[Vector2(100.0, 200.0), Vector2(100, 200)]]:
		_check(DamageNumbersKernel.snap_screen_px(pair[0] as Vector2) == pair[1] as Vector2i,
			"projection snaps to whole pixels (%s -> %s)" % [pair[0], pair[1]])
	var snapped := DamageNumbersKernel.snap_screen_px(Vector2(37.62, 91.18))
	_check(DamageNumbersKernel.snap_screen_px(Vector2(snapped)) == snapped,
		"the pixel snap is idempotent")

	var a_seq := _jitter_sequence(4242)
	var b_seq := _jitter_sequence(4242)
	var c_seq := _jitter_sequence(9001)
	_check(a_seq == b_seq, "same seed -> same jitter sequence (reproducible evidence)")
	_check(a_seq != c_seq, "a different seed moves the sequence")
	print("JITTER seed4242=%s seed9001=%s" % [a_seq, c_seq])

	_finish()


func _jitter_sequence(seed_value: int) -> Array:
	var kernel := DamageNumbersKernel.new(seed_value)
	var drawn: Array = []
	for i in DamageNumbersKernel.POOL_SIZE:
		kernel.spawn(200 + i, 1, Vector3.ZERO, i * 100)
		drawn.append(kernel.slot(i)["jitter"])
	return drawn


func _finish() -> void:
	if _failures == 0:
		print("PASS test_damage_numbers_kernel: %d checks%s"
			% [_checks, " (negative)" if _negative else ""])
		quit(0)
	else:
		print("FAIL test_damage_numbers_kernel: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `"$GODOT" --headless --path . -s res://tests/test_damage_numbers_kernel.gd`
Expected: `Compile Error: Identifier "DamageNumbersKernel" not found` and a non-zero exit — the class does not exist yet.

- [ ] **Step 3: Write the kernel**

`scripts/ui/damage_numbers_kernel.gd`:

```gdscript
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
```

- [ ] **Step 4: Run L1 + the test, positive and negative**

Run: `"$GODOT" --headless --path . --import`
Run: `"$GODOT" --headless --path . --check-only --script res://scripts/ui/damage_numbers_kernel.gd`
Run: `"$GODOT" --headless --path . -s res://tests/test_damage_numbers_kernel.gd`
Expected: exit 0, `PASS test_damage_numbers_kernel: <N> checks`.
Run: `"$GODOT" --headless --path . -s res://tests/test_damage_numbers_kernel.gd -- negative`
Expected: exit 1 with `T31.m same target inside the window merges` red — the merge check must be the one that fails, and `active_count() == 1` too. If the negative comes back green the ruler is dead; fix the check before moving on.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/damage_numbers_kernel.gd scripts/ui/damage_numbers_kernel.gd.uid \
  tests/test_damage_numbers_kernel.gd tests/test_damage_numbers_kernel.gd.uid
git commit -m "feat(T-031): add the damage number slot laws as a pure kernel"
```

---

### Task 2: DamageNumbers view + theme laws

**Files:**
- Create: `scripts/ui/damage_numbers.gd`
- Modify: `scripts/ui/hd2d_theme.gd` (append the damage-number constants)
- Test: `tests/test_damage_numbers.gd`
- Modify: `tests/test_theme.gd`

**Interfaces:**
- Consumes: `DamageNumbersKernel` (Task 1), `Hd2dTheme`, `PixelGrid.ortho_px_per_unit/persp_px_per_unit`.
- Produces (Tasks 3–5 rely on these exact names):
  - `class_name DamageNumbers extends CanvasLayer`, `signal shown(target_id: int, amount: int, total: int)`
  - `@export var seed_value: int = 0`, `@export var anchor_min_m: float = 1.1`, `@export var avoid_telegraph_band: bool = true`
  - `func show_hit(receiver: Node3D, target_id: int, amount: int) -> void`
  - `func set_enabled(flag: bool) -> void`, `func is_enabled() -> bool`, `func reset() -> void`
  - probes: `func label_count() -> int`, `func active_count() -> int`, `func slot_text(index: int) -> String`, `func slot_rect(index: int) -> Rect2`, `func slot_target_id(index: int) -> int` (`-1` when the slot is free), `func label_instance_ids() -> Array`
  - statics shared with the L3 capture: `static func aabb_corners(xform: Transform3D, aabb: AABB) -> PackedVector3Array`, `static func projected_bbox(points: PackedVector3Array, camera: Camera3D) -> Rect2`
  - `Hd2dTheme.DAMAGE := Color("#ffffff")`, `Hd2dTheme.DAMAGE_OUTLINE := Color("#000000")`, `Hd2dTheme.DAMAGE_OUTLINE_PX := 2`, `Hd2dTheme.DAMAGE_FONT_SIZE := 32`

- [ ] **Step 1: Add the theme constants (they are the test's vocabulary)**

Append to `scripts/ui/hd2d_theme.gd` after the existing consts:

```gdscript
## T-031: floating damage numbers. 32 px is the title cell (a multiple of the
## 16 px terminal grid) so the number reads across a horde without resampling.
const DAMAGE := Color("#ffffff")
const DAMAGE_OUTLINE := Color("#000000")
const DAMAGE_OUTLINE_PX := 2
const DAMAGE_FONT_SIZE := 32
```

- [ ] **Step 2: Write the failing view test**

`tests/test_damage_numbers.gd`:

```gdscript
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
	# and waits exactly one physics frame. A headless frame can carry up to eight
	# catch-up ticks, so no check may depend on how long a number has been alive.
	var receiver := _make_receiver(Vector3(1.0, 0.0, 0.0), false)
	root.add_child(receiver)
	await process_frame
	numbers.show_hit(receiver, 3, 13)
	numbers.show_hit(receiver, 3, 13)
	numbers.show_hit(receiver, 4, 9)
	await physics_frame
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
	await physics_frame
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
```

Notes for the implementer:

- The view's probes (`slot_target_id`, `label_instance_ids`, `slot_rect`) exist because the tests *and* the L3 capture need to read what was drawn without reaching into private fields. Reflection (`numbers.get("_labels")`) is not acceptable in the shipped test.
- If `unproject_position` turns out not to work under `--headless`, keep the camera assertion red and report it — do not quietly re-mock the projection. The clearance law then moves to L3 only and Task 5's capture becomes its gate; say so in the report.

- [ ] **Step 3: Write the view**

`scripts/ui/damage_numbers.gd`:

```gdscript
class_name DamageNumbers
extends CanvasLayer

## T-031: the floating damage numbers. The kernel owns when a number lives and
## what it says; this node only turns a world point into an integer pixel box and
## keeps that box out of the telegraph decal under the target's feet.

signal shown(target_id: int, amount: int, total: int)

## Spec §4 anchor: above the receiver's origin (its feet), below its head.
const DEFAULT_ANCHOR_M := 1.1
## Rounding slack when converting a required pixel lift into world metres.
const LIFT_EPSILON_M := 0.01

## 0 keeps the jitter sequence fixed, which is what makes the capture repeatable.
@export var seed_value: int = 0
@export var anchor_min_m: float = DEFAULT_ANCHOR_M
## The clearance law can be switched off to prove the ruler works; the negative
## control in the L3 capture does exactly that.
@export var avoid_telegraph_band: bool = true

var _kernel: DamageNumbersKernel
var _root: Control
var _labels: Array[Label] = []
var _tick := 0
var _enabled := true
var _height_px := 0


func _ready() -> void:
	_kernel = DamageNumbersKernel.new(seed_value)
	_root = Control.new()
	_root.name = "Numbers"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Hd2dTheme.build()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	for i in DamageNumbersKernel.POOL_SIZE:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override(&"font_color", Hd2dTheme.DAMAGE)
		label.add_theme_color_override(&"font_outline_color", Hd2dTheme.DAMAGE_OUTLINE)
		label.add_theme_constant_override(&"outline_size", Hd2dTheme.DAMAGE_OUTLINE_PX)
		label.add_theme_font_size_override(&"font_size", Hd2dTheme.DAMAGE_FONT_SIZE)
		label.visible = false
		_root.add_child(label)
		_labels.append(label)


func _physics_process(_delta: float) -> void:
	_tick += 1
	_kernel.sweep(_tick)
	_render()


func show_hit(receiver: Node3D, target_id: int, amount: int) -> void:
	if not _enabled or amount <= 0:
		return
	var point := receiver.global_position + Vector3(0.0, anchor_min_m, 0.0)
	point = _clear_decal(receiver, point)
	var index := _kernel.spawn(target_id, amount, point, _tick)
	var total := int(_kernel.slot(index)["amount"])
	shown.emit(target_id, amount, total)


func set_enabled(flag: bool) -> void:
	_enabled = flag
	if not flag:
		_kernel.reset()
		_hide_all()


func is_enabled() -> bool:
	return _enabled


func reset() -> void:
	_kernel.reset()
	_hide_all()


func label_count() -> int:
	return _labels.size()


func active_count() -> int:
	return _kernel.active_count()


func slot_text(index: int) -> String:
	return _labels[index].text


## The pool is a law, so the tests and the capture verify the instances stayed
## the same objects instead of trusting a count.
func label_instance_ids() -> Array:
	var ids: Array = []
	for label in _labels:
		ids.append(label.get_instance_id())
	return ids


func slot_target_id(index: int) -> int:
	var entry := _kernel.slot(index)
	return -1 if entry.is_empty() else int(entry["target_id"])


## The box is the label's measured minimum, not its layout size: a Control inside
## a CanvasLayer is only sorted on a drawn frame, and both the tests and the
## capture need the number's extent on the tick it was placed.
func slot_rect(index: int) -> Rect2:
	var label := _labels[index]
	if not label.visible:
		return Rect2()
	return Rect2(label.position, label.get_combined_minimum_size())


static func aabb_corners(xform: Transform3D, aabb: AABB) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in 8:
		var corner := Vector3(
			aabb.position.x if (i & 1) == 0 else aabb.end.x,
			aabb.position.y if (i & 2) == 0 else aabb.end.y,
			aabb.position.z if (i & 4) == 0 else aabb.end.z)
		points.append(xform * corner)
	return points


static func projected_bbox(points: PackedVector3Array, camera: Camera3D) -> Rect2:
	if camera == null or points.is_empty():
		return Rect2()
	var band := Rect2()
	for i in points.size():
		var screen := camera.unproject_position(points[i])
		band = Rect2(screen, Vector2.ZERO) if i == 0 else band.expand(screen)
	return band


func _render() -> void:
	for i in _labels.size():
		var entry := _kernel.slot(i)
		var label := _labels[i]
		if entry.is_empty():
			label.visible = false
			continue
		var screen := _project(entry["point"] as Vector3)
		if screen == null:
			label.visible = false
			continue
		var age := _tick - int(entry["born"])
		var offset := entry["jitter"] as Vector2i
		var position := DamageNumbersKernel.snap_screen_px(screen as Vector2) + offset
		position.y -= DamageNumbersKernel.rise_px(age)
		label.position = Vector2(position)
		label.text = str(int(entry["amount"]))
		label.modulate = Color(1, 1, 1, DamageNumbersKernel.alpha(age))
		label.visible = true


func _hide_all() -> void:
	for label in _labels:
		label.visible = false


func _project(point: Vector3) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	return camera.unproject_position(point)


## D-027 law: the number's box never overlaps the decal band that is visible
## under its target. The lift is resolved once, in world metres along the camera
## up axis, so the number keeps tracking the enemy as the camera follows the
## player instead of being pinned to a stale screen y.
func _clear_decal(receiver: Node3D, point: Vector3) -> Vector3:
	if not avoid_telegraph_band:
		return point
	var decal := receiver.get_node_or_null("Telegraph") as MeshInstance3D
	if decal == null or not decal.visible:
		return point
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return point
	var screen := _project(point)
	if screen == null:
		return point
	var band := projected_bbox(aabb_corners(decal.global_transform, decal.get_aabb()), camera)
	var bottom := (screen as Vector2).y + float(_label_height_px())
	var need := bottom - band.position.y
	if need <= 0.0:
		return point
	var per_unit := _px_per_unit(camera, point)
	if per_unit <= 0.0:
		return point
	return point + camera.global_transform.basis.y * (ceilf(need / per_unit) + LIFT_EPSILON_M)


## The font cell is the floor: a label whose theme has not sorted yet still gets a
## clearance that matches what will actually be drawn.
func _label_height_px() -> int:
	if _height_px <= 0:
		_height_px = maxi(int(_labels[0].get_combined_minimum_size().y),
			Hd2dTheme.DAMAGE_FONT_SIZE)
	return _height_px


func _px_per_unit(camera: Camera3D, point: Vector3) -> float:
	var height := get_viewport().get_visible_rect().size.y
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return PixelGrid.ortho_px_per_unit(height, camera.size)
	return PixelGrid.persp_px_per_unit(height, camera.fov,
		camera.global_position.distance_to(point))
```

- [ ] **Step 4: Run L1 + the view test, positive and negative**

Run: `"$GODOT" --headless --path . --import`
Run: `"$GODOT" --headless --path . --check-only --script res://scripts/ui/damage_numbers.gd`
Run: `"$GODOT" --headless --path . -s res://tests/test_damage_numbers.gd`
Expected: exit 0, `PASS test_damage_numbers: <N> checks`.
Run: `"$GODOT" --headless --path . -s res://tests/test_damage_numbers.gd -- negative`
Expected: exit 1 with the clearance check (`T31.c` / "the number box ends above the telegraph band") red.

Append to `tests/test_theme.gd` (before the final `_failures` branch) and re-run:

```gdscript
	# T-031: the numbers are UI too, so their style lives in the theme, not in the
	# node that draws them.
	_check(Hd2dTheme.DAMAGE_FONT_SIZE % 16 == 0,
		"damage number size stays a multiple of the 16 px glyph cell")
	_check(Hd2dTheme.DAMAGE == Color("#ffffff"), "damage numbers use the approved white")
	_check(Hd2dTheme.DAMAGE_OUTLINE_PX >= 2 and Hd2dTheme.DAMAGE_OUTLINE_PX <= 4,
		"the damage outline stays inside the HUD outline range")
	_check(Hd2dTheme.DAMAGE_OUTLINE != Hd2dTheme.TEXT, "the outline stays distinct from body text")
```

Run: `"$GODOT" --headless --path . -s res://tests/test_theme.gd` → exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/damage_numbers.gd scripts/ui/damage_numbers.gd.uid \
  scripts/ui/damage_numbers_kernel.gd scripts/ui/hd2d_theme.gd \
  tests/test_damage_numbers.gd tests/test_damage_numbers.gd.uid tests/test_theme.gd
git commit -m "feat(T-031): draw damage numbers through a fixed label pool"
```

---

### Task 3: one hook into combat + arena mount + L2 flow evidence

**Files:**
- Modify: `scripts/combat/player_combat.gd` (`@export` block, `_ready`, `_resolve_hits`)
- Modify: `scenes/phase_c/grove_arena.tscn`
- Create: `scripts/phase_c/t031_numbers_driver.gd`, `scenes/phase_c/run_t031_numbers.tscn`

**Interfaces:**
- Consumes: `DamageNumbers.show_hit(receiver: Node3D, target_id: int, amount: int)`, `signal DamageNumbers.shown`, `DamageNumbers.active_count()/label_count()/set_enabled()`, `WaveEncounter.debug_spawn/debug_clear_enemies/nearest_alive_position`, `PlayerCombat.debug_request_attack()/aim_override_*`.
- Produces: `PlayerCombat.damage_numbers_path` export (default empty) — every scene that does not set it keeps its current behaviour, which is what keeps the 24 existing harnesses green.

- [ ] **Step 1: Write the failing harness driver**

`scripts/phase_c/t031_numbers_driver.gd`:

```gdscript
extends Node

## T-031 evidence: the display path is wired to the damage path, one shown number
## per logged damage line, with the pool and the toggle holding under a spam
## phase. This measures the plumbing, not balance (the staging teleports the
## player next to the target, same as the T-030 harness).
##
##   <GODOT> --headless --path . res://scenes/phase_c/run_t031_numbers.tscn --fixed-fps 60
##   ... -- negative : the hook is unwired, so T31.1 and T31.5 go red (exit 1)
##   ... -- spam     : 30 live chains forced at the view, ceiling + instances (exit 0)
##
## The -- negative fault is injected here at driver level, never as a flag inside
## PlayerCombat (T-030 precedent: DG3 negatives live in the driver).

const FOLLOW_OFFSET := 0.8
const STALK_TICKS := 600
const BATCH_SIZE := 8
const SPAM_TARGETS := 30
## The synthetic load starts after the toggle window closes, so T31.3 and T31.4
## cannot mask each other.
const SPAM_FROM := 330
const TARGET_LOG_HITS := 24
const TOGGLE_FROM := 200
const TOGGLE_TICKS := 60

var _arena: Node
var _encounter: WaveEncounter
var _combat: PlayerCombat
var _player: PlayerController
var _director: CombatDirector
var _numbers: DamageNumbers
var _negative := false
var _spam := false
var _damage_events := 0
var _damage_total := 0
var _shown_events := 0
var _shown_total := 0
var _amounts_ok := true
var _pending_amount := -1
var _ceiling_ok := true
var _stable_labels := true
var _label_ids: Array = []
var _window_damage := 0
var _window_shown := 0
var _tick := 0
var _checks := 0
var _failures := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_negative = args.has("negative")
	_spam = args.has("spam")
	_arena = get_node("../GroveArena")
	_encounter = _arena.get_node("WaveEncounter") as WaveEncounter
	_combat = _arena.get_node("Player/PlayerCombat") as PlayerCombat
	_player = _arena.get_node("Player") as PlayerController
	_director = _arena.get_node("CombatDirector") as CombatDirector
	_numbers = _arena.get_node("DamageNumbers") as DamageNumbers
	if _negative:
		# Driver-level fault: unwire the layer the way a scene without the mount
		# would, instead of teaching PlayerCombat a test flag.
		_combat._numbers = null
	_encounter.set_physics_process(false)
	_combat.aim_override_enabled = true
	_director.event_logged.connect(_observe)
	_numbers.shown.connect(_on_shown)
	_label_ids = _numbers.label_instance_ids()
	_respawn_batch(BATCH_SIZE if not _spam else SPAM_TARGETS)
	_run()


func _respawn_batch(count: int) -> void:
	_encounter.debug_clear_enemies()
	for i in count:
		_encounter.debug_spawn("grunt", Vector3(
			1.2 + float(i % 6) * 0.5, 0.0, float(i / 6) * 0.8 - 0.4))


func _run() -> void:
	while _tick < STALK_TICKS:
		await get_tree().physics_frame
		_tick += 1
		if _encounter.alive_count() == 0:
			_respawn_batch(BATCH_SIZE if not _spam else SPAM_TARGETS)
		_combat.health.hp = _combat.health.max_hp
		_attack_nearest()
		if _tick == TOGGLE_FROM:
			# The toggle has to shut the readout up while hits keep landing.
			_numbers.set_enabled(false)
		if _tick == TOGGLE_FROM + TOGGLE_TICKS:
			_numbers.set_enabled(true)
		if _spam and _tick > SPAM_FROM:
			_load_display_layer()
	print("damage_events=%d shown_events=%d damage_total=%d shown_total=%d window_damage=%d window_shown=%d ceiling_ok=%s stable_labels=%s labels=%d" % [
		_damage_events, _shown_events, _damage_total, _shown_total, _window_damage,
		_window_shown, str(_ceiling_ok), str(_stable_labels), _numbers.label_count()])
	_check(_damage_events >= TARGET_LOG_HITS,
		"T31.0 the harness really landed %d+ hits (got %d)" % [TARGET_LOG_HITS, _damage_events])
	_check(_shown_events == _damage_events,
		"T31.1 one shown number per logged damage line (shown %d, damage %d)"
		% [_shown_events, _damage_events])
	_check(_amounts_ok, "T31.2 every shown amount matches the damage value the log carries")
	_check(_ceiling_ok and _numbers.label_count() == DamageNumbersKernel.POOL_SIZE,
		"T31.3 the pool stays at %d slots and %d labels (labels %d)"
		% [DamageNumbersKernel.POOL_SIZE, DamageNumbersKernel.POOL_SIZE, _numbers.label_count()])
	_check(_window_damage > 0 and _window_shown == 0,
		"T31.4 the disabled window held %d real hits and showed %d numbers"
		% [_window_damage, _window_shown])
	_check(_shown_total == _damage_total,
		"T31.5 shown damage (%d) equals logged damage (%d)" % [_shown_total, _damage_total])
	_check(_stable_labels, "T31.6 the same %d label instances served every hit"
		% DamageNumbersKernel.POOL_SIZE)
	print("checks=%d failures=%d" % [_checks, _failures])
	print("%s t031_numbers: damage numbers track the damage path" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _attack_nearest() -> void:
	var target := _encounter.nearest_alive_position()
	_player.global_position = target + Vector3(FOLLOW_OFFSET, 0.0, 0.0)
	_player.velocity = Vector3.ZERO
	_combat.aim_override_point = target
	if _combat.attack_phase() == AttackState.Phase.NONE:
		_combat.debug_request_attack()


## Display-layer load, not a balance claim: 30 chains are opened faster than 24
## slots can hold, which is the only scene-level way to exercise eviction and
## prove no Label is ever allocated after _ready.
func _load_display_layer() -> void:
	var enemies := _encounter.enemies()
	for i in enemies.size():
		if enemies[i].hp() > 0:
			_numbers.show_hit(enemies[i], 900 + i, 5)
	if _numbers.active_count() > DamageNumbersKernel.POOL_SIZE:
		_ceiling_ok = false
	if _numbers.label_instance_ids() != _label_ids:
		_stable_labels = false


func _in_toggle_window() -> bool:
	# Strictly before the re-enable tick: a hit served after set_enabled(true) is
	# supposed to show, and counting it would make T31.4 red for the wrong reason.
	return _tick > TOGGLE_FROM and _tick < TOGGLE_FROM + TOGGLE_TICKS


func _observe(entity: StringName, event_name: StringName, _attack_id: int, _target_id: int, value: int) -> void:
	if entity != &"player" or event_name != &"damage":
		return
	_damage_events += 1
	_damage_total += value
	_pending_amount = value
	if _in_toggle_window():
		_window_damage += 1


func _on_shown(_target_id: int, amount: int, _total: int) -> void:
	_shown_events += 1
	_shown_total += amount
	if _in_toggle_window():
		_window_shown += 1
	if _pending_amount < 0 or amount != _pending_amount:
		_amounts_ok = false
	_pending_amount = -1


func _numbers_ids() -> Array:
	var ids: Array = []
	for label in _numbers.get("_labels"):
		ids.append(label.get_instance_id())
	return ids


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
```

Note: `_combat._numbers = null` is the one place this driver touches a private field, and it is deliberate — DG3 needs a red path for "the layer was never wired", and a production flag that can switch the feature off would be worse (T-030 precedent: `scripts/phase_c/t030_buff_driver.gd:75-82`).

- [ ] **Step 2: Run it to make sure it fails**

Create `scenes/phase_c/run_t031_numbers.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/phase_c/grove_arena.tscn" id="1_arena"]
[ext_resource type="Script" path="res://scripts/phase_c/t031_numbers_driver.gd" id="2_drv"]

[node name="RunT031Numbers" type="Node"]

[node name="GroveArena" parent="." instance=ExtResource("1_arena")]

[node name="T031NumbersDriver" type="Node" parent="."]
script = ExtResource("2_drv")
```

Run: `"$GODOT" --headless --path . res://scenes/phase_c/run_t031_numbers.tscn --fixed-fps 60`
Expected: exit non-zero — `DamageNumbers` is not in the arena yet, so `_arena.get_node("DamageNumbers")` errors and T31.1 fails with `shown 0`.

- [ ] **Step 3: Wire the one hook**

In `scripts/combat/player_combat.gd`:

```gdscript
## T-031: the floating numbers layer. Empty by default so harnesses and scenes
## without the layer keep running unchanged instead of crashing on a missing node.
@export var damage_numbers_path: NodePath = NodePath("")
```

after the other `@export` paths; `var _numbers: DamageNumbers` with the other privates; in `_ready()`:

```gdscript
	if damage_numbers_path != NodePath(""):
		_numbers = get_node_or_null(damage_numbers_path) as DamageNumbers
```

and inside `_resolve_hits()`, immediately after `_director.log_event(&"player", &"damage", _swing_id, target_id, applied)`:

```gdscript
			if applied > 0 and _numbers != null and receiver is Node3D:
				_numbers.show_hit(receiver as Node3D, target_id, applied)
```

`_resolve_hits` is the only production line that changes; `CombatDirector`, `combat_log.gd`, `Health` and every enemy script stay untouched (spec §4).

In `scenes/phase_c/grove_arena.tscn`: add the ext_resource for `res://scripts/ui/damage_numbers.gd`, set `damage_numbers_path = NodePath("../../DamageNumbers")` on the `PlayerCombat` node, and insert the layer **before** `WaveHUD` so the HUD keeps drawing above the numbers:

```
[node name="DamageNumbers" type="CanvasLayer" parent="."]
script = ExtResource("19_numbers")
```

- [ ] **Step 4: Run the harness positive, then both negatives**

Run: `"$GODOT" --headless --path . --import`
Run: `"$GODOT" --headless --path . res://scenes/phase_c/run_t031_numbers.tscn --fixed-fps 60`
Expected: exit 0, `checks=7 failures=0` with `damage_events>=24`, `window_damage>0`, `ceiling_ok=true stable_labels=true`.
Run: `... -- negative` → exit 1 with `T31.1` (shown 0 vs damage N) and `T31.5` (shown_total 0 vs logged total) red. Name the ids in the report; if the run still exits 0 the ruler is dead.
Run: `... -- spam` → exit 0 with `ceiling_ok=true stable_labels=true` and `labels=24`.

- [ ] **Step 5: Regression sweep**

Run the suites and harnesses the mount can touch (the layer now exists in `grove_arena.tscn`, which every Phase B/C harness instances):

```bash
"$GODOT" --headless --path . res://scenes/phase_c/grove_arena.tscn --quit-after 120
"$GODOT" --headless --path . res://scenes/phase_c/play_arena.tscn --quit-after 120
for s in combat_kernel stats_live player_stats wave_kernel tempo_fatigue title_entry; do
  "$GODOT" --headless --path . -s res://tests/test_$s.gd || echo "RED $s"
done
"$GODOT" --headless --path . res://scenes/phase_c/run_t018_cycles.tscn --fixed-fps 60
"$GODOT" --headless --path . res://scenes/phase_c/run_t021_boss.tscn --fixed-fps 60
"$GODOT" --headless --path . res://scenes/phase_c/run_t030_buffs.tscn --fixed-fps 60
node tools/check_stat_source.mjs
node tools/check_stat_source.mjs --selftest
```

Expected: every run exit 0 with no `SCRIPT ERROR` lines; `run_t030_buffs` keeps `runs=10 wins=10 picks=20 mods_ok=true`; `stat-source clean: <N> scripts` (N grows by the new files) and `--selftest` still `violations=1 allowed_hit=0`.

- [ ] **Step 6: Commit**

```bash
git add scripts/combat/player_combat.gd scenes/phase_c/grove_arena.tscn \
  scripts/phase_c/t031_numbers_driver.gd scripts/phase_c/t031_numbers_driver.gd.uid \
  scenes/phase_c/run_t031_numbers.tscn scripts/ui/damage_numbers.gd
git commit -m "feat(T-031): hook damage numbers into the damage path and mount the layer"
```

---

### Task 4: the sheet toggle, the wave state, and the T-030 debt in the sheet

**Files:**
- Modify: `scripts/ui/ui_copy.gd`
- Modify: `scripts/ui/character_sheet.gd`
- Modify: `scripts/ui/hd2d_theme.gd` (`SHEET_SIZE` only if the measurement says so)
- Modify: `scripts/phase_c/wave_hud.gd` (`BUFF_PENDING` label — parked T-030 finding)
- Test: `tests/test_character_sheet.gd` (extend), `tests/test_theme.gd` (geometry only if the size changes)

**Interfaces:**
- Consumes: `DamageNumbers.set_enabled()/is_enabled()` (Task 2), `WaveKernel.State.BUFF_PENDING`, `UiCopy.HUD_FIGHT/HUD_NEXT/HUD_WIN/HUD_LOSE/BUFF_PANEL_TITLE`.
- Produces: `CharacterSheet.set_damage_numbers(numbers: DamageNumbers) -> void`, `CharacterSheet.damage_numbers_path` export, `CharacterSheet.toggle_value_text() -> String` (probe for tests/capture).

- [ ] **Step 1: Append the copy**

```gdscript
## T-031: the damage-number readout is an information toggle (spec §5), so the
## state word is copy, not a symbol, and the coverage gate sees it.
const SHEET_TOGGLE := "SỐ SÁT THƯƠNG: %s"
const STATE_ON := "BẬT"
const STATE_OFF := "TẮT"
## Parked from T-030: "1/3" alone did not say whether the wave was fighting,
## parked for a pick, or over.
const SHEET_WAVE_ROW := "%d/%d (%s)"
```

- [ ] **Step 2: Extend the failing sheet test**

In `tests/test_character_sheet.gd`, inside `_run()` right after `sheet.set_sources(...)`:

```gdscript
	var numbers := DamageNumbers.new()
	root.add_child(numbers)
	await process_frame
	sheet.set_damage_numbers(numbers)
	_check(sheet.is_open() == false and numbers.is_enabled(),
		"the numbers layer starts enabled and the sheet stays closed")
	sheet.open()
	_check(sheet.toggle_value_text().contains(UiCopy.STATE_ON),
		"the sheet states the current toggle value")
	sheet.toggle_numbers()
	_check(not numbers.is_enabled() and numbers.active_count() == 0,
		"the sheet toggle really turns the readout off")
	_check(sheet.toggle_value_text().contains(UiCopy.STATE_OFF),
		"the label flips with the state")
	sheet.close()
	sheet.open()
	_check(not numbers.is_enabled() and sheet.toggle_value_text().contains(UiCopy.STATE_OFF),
		"the choice survives a close/reopen (session variable, not a save)")
	numbers.set_enabled(true)
	_check(sheet.toggle_value_text().contains(UiCopy.STATE_ON),
		"the sheet reads the state back from the layer, it does not cache it")
	numbers.queue_free()
	sheet.set_damage_numbers(null)
	await process_frame
```

Then extend the geometry gate at the end of the buff section so the new row is measured, and add the parked-guard regression:

```gdscript
	# T-030 debt: a sheet asked for its body before _ready must not crash.
	var cold := CharacterSheet.new()
	_check(cold.body_text() == "", "body_text before _ready returns empty, not an error")
	cold.free()
```

- [ ] **Step 3: Implement the sheet changes**

`scripts/ui/character_sheet.gd`:

- add `@export var damage_numbers_path: NodePath = NodePath("../DamageNumbers")`, `var _numbers: DamageNumbers`, `var _toggle: Button`.
- in `_build_ui()`, before the close button:

```gdscript
	_toggle = Button.new()
	_toggle.pressed.connect(toggle_numbers)
	column.add_child(_toggle)
	_refresh_toggle()
```

- add the public members:

```gdscript
func set_damage_numbers(numbers: DamageNumbers) -> void:
	_numbers = numbers
	_refresh_toggle()


## The state lives on the layer, so the sheet never has to remember it.
func toggle_numbers() -> void:
	if _numbers == null:
		return
	_numbers.set_enabled(not _numbers.is_enabled())
	_refresh_toggle()


func toggle_value_text() -> String:
	return "" if _toggle == null else _toggle.text


func _refresh_toggle() -> void:
	if _toggle == null:
		return
	var on := _numbers != null and _numbers.is_enabled()
	_toggle.text = UiCopy.SHEET_TOGGLE % [UiCopy.STATE_ON if on else UiCopy.STATE_OFF]
	_toggle.disabled = _numbers == null
```

- `_resolve_sources()` also resolves the layer:
  `_numbers = get_node_or_null(damage_numbers_path) as DamageNumbers` then `_refresh_toggle()` (the panel is built before sources resolve, so `_toggle` already exists).
- wave row in `refresh()`:

```gdscript
	_rows[&"wave"].text = UiCopy.SHEET_PLACEHOLDER
	if _encounter != null and _encounter.kernel != null \
			and _encounter.kernel.state != WaveKernel.State.INACTIVE:
		_rows[&"wave"].text = UiCopy.SHEET_WAVE_ROW % [
			_encounter.kernel.wave_index + 1, _encounter.kernel.wave_count(),
			_wave_state_text(_encounter.kernel.state)]
```

with the state text helper shared with the HUD wording:

```gdscript
func _wave_state_text(state: int) -> String:
	if _encounter != null and _encounter.kernel != null \
			and _encounter.kernel.state == WaveKernel.State.BUFF_PENDING:
		return UiCopy.BUFF_PANEL_TITLE
	match state:
		WaveKernel.State.PAUSED:
			return UiCopy.HUD_NEXT
		WaveKernel.State.WON:
			return UiCopy.HUD_WIN
		WaveKernel.State.LOST:
			return UiCopy.HUD_LOSE
	return UiCopy.HUD_FIGHT
```

- the parked null guards:

```gdscript
func body_text() -> String:
	if _rows.is_empty():
		return ""
	...


func content_minimum_size() -> Vector2:
	if _column == null:
		return Vector2(Hd2dTheme.SHEET_SIZE)
	...
```

- `open()` calls `_refresh_toggle()` next to `refresh()`.

- [ ] **Step 4: Measure the sheet and settle the geometry**

Run: `"$GODOT" --headless --path . -s res://tests/test_character_sheet.gd`
Read the printed `SHEET content_minimum_size=...`. If `min.y > 432`, set `Hd2dTheme.SHEET_SIZE := Vector2i(480, <ceil to the next multiple of 4 above min.y>)` and update the exact-value assertion in `tests/test_theme.gd` plus `docs/phase-d/UI_PROGRESSION_SPEC.md` §7 in the same commit. If it still fits, change nothing — and say so in the report. The gate must fail before the size moves; never move the size to make a check pass.

- [ ] **Step 5: The HUD BUFF_PENDING row (parked T-030 finding)**

`scripts/phase_c/wave_hud.gd` — add the missing state to the existing `match`:

```gdscript
		WaveKernel.State.BUFF_PENDING:
			state_text = UiCopy.BUFF_PANEL_TITLE
```

Run: `"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd` → exit 0, report the new glyph total (the copy adds `B Ậ T Ắ T 0 9 ( )` and reuses the rest; VT323 must cover them or the gate says so — do not swap fonts, do not drop diacritics without a recorded decision).
Run: `"$GODOT" --headless --path . -s res://tests/test_character_sheet.gd` and `... test_character_sheet.gd -- negative` → exit 0 / exit 1.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/ui_copy.gd scripts/ui/character_sheet.gd scripts/phase_c/wave_hud.gd \
  tests/test_character_sheet.gd tests/test_theme.gd tests/test_font_coverage.gd \
  scripts/ui/hd2d_theme.gd docs/phase-d/UI_PROGRESSION_SPEC.md
git commit -m "feat(T-031): toggle damage numbers from the character sheet"
```

(Only stage `hd2d_theme.gd`/the spec if Step 4 actually moved the geometry.)

---

### Task 5: L3 capture + decision record + full regression

**Files:**
- Create: `scripts/ui/capture_damage_numbers.gd`, `scenes/ui/capture_damage_numbers.tscn`
- Modify: `docs/DECISIONS.md` (D-027), `docs/STATE.md`
- Evidence: `docs/phase-d/evidence/t031/`

**Interfaces:**
- Consumes: `DamageNumbers.projected_bbox/aabb_corners/slot_rect/slot_target_id/slot_text/set_enabled/label_count`, `WaveEncounter.debug_spawn`, `PlayerCombat.debug_request_attack()`, `CombatDirector.event_logged`.

- [ ] **Step 1: Write the capture driver**

`scripts/ui/capture_damage_numbers.gd` — same shape as `scripts/ui/capture_buffs.gd` (`_settle()` on `RenderingServer.frame_post_draw`, `_lit_pixels()`, `_band_diff()`, one `quit()`), with these specifics:

```gdscript
const EVIDENCE_DIR := "res://docs/phase-d/evidence/t031/"
## The number lands near the arena centre because the driver walks the player up
## to the spawned grunt. The band covers the enemy's screen area, not the HUD.
const NUMBERS_BAND := Rect2(0.30, 0.25, 0.40, 0.35)
const BAND_MIN_DIFF := 40
const LIT_MIN_PIXELS := 500
const TELEGRAPH_TIMEOUT := 900
```

`_ready()`: `process_mode = PROCESS_MODE_ALWAYS`; grab `_arena`, `_encounter`, `_combat`, `_player`, `_numbers`; `_encounter.set_physics_process(false)`; `_encounter.debug_clear_enemies()`; `_encounter.debug_spawn("grunt", Vector3(1.2, 0.0, 0.6))`; `DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)`; then `await _sequence()`.

`_sequence()`:

1. `await _settle()`; report the mode: `negative` → never attack; `low-anchor` → `_numbers.anchor_min_m = 0.2` and `_numbers.avoid_telegraph_band = false`.
2. Walk in and wait for the decal: each tick, top the player HP, set `_player.global_position = target + Vector3(0.8, 0, 0)` and `_combat.aim_override_point = target`, and stop when the grunt's `Telegraph` child reports `visible == true` (bounded by `TELEGRAPH_TIMEOUT`; if it never arms, `P31.0` fails with "the telegraph never armed, so the overlap law was never measured" — an honest red, not a skip).
3. `_combat.debug_request_attack()` and wait for the first `damage` event for `entity == &"player"` (tap `event_logged`), remembering the `target_id` and `value`.
4. On the next tick read the live slot: `var index := _slot_for(target_id)` using `_numbers.slot_target_id(i)`; record `shown_text := _numbers.slot_text(index)`, `number_rect := _numbers.slot_rect(index)`, and the band `projected_bbox(<the decal's four world corners>, camera)` built **independently** of the view's 8-corner AABB path (that difference is the cross-check — say so in a comment).
5. `_check(overlap_area(number_rect, band) == 0, "P31.4 the number box never touches the telegraph band (overlap %d px, box %s, band %s)")`.
6. Freeze and photograph: `get_tree().paused = true`, `await _settle()`, `hit := _grab("numbers_hit")`; then `_numbers.set_enabled(false)`, `await _settle()`, `control := _grab("numbers_control")`, `again := _grab("numbers_control2")`; `P31.2` = band diff between the two control frames is 0; `P31.3` = hit vs control ≥ `BAND_MIN_DIFF` (0 with the `negative` mode, by construction, because no hit ever landed); `P31.5` = `shown_text == str(value)` in the normal mode.
7. Print `checks/failures/band_diff/overlap/lit`, then `get_tree().quit(0 if _failures == 0 else 1)`.
8. Every `image.save_png(...)` result must be surfaced (`SAVE FAILED` in the `SHOT` line, and a failed save counts as a check failure — the parked T-030 finding).

The parts that are not a copy of `scripts/ui/capture_buffs.gd`:

```gdscript
## Step 3-4: the tick the damage lands. The decal's own four ground corners are
## used here instead of the view's eight AABB corners on purpose: if the two
## derivations of the band disagreed, a green overlap check would prove nothing.
func _on_damage(entity: StringName, event_name: StringName, _id: int, target_id: int, value: int) -> void:
	if entity != &"player" or event_name != &"damage" or _armed:
		return
	_armed = true
	_logged_value = value
	_logged_target = target_id


func _measure() -> void:
	var camera := get_viewport().get_camera_3d()
	var index := _slot_of(_numbers, _logged_target)
	_number_rect = _numbers.slot_rect(index)
	_shown_text = _numbers.slot_text(index)
	var half := _decal.global_transform.basis.get_scale().x * 0.5
	var corners := PackedVector3Array([
		_decal.global_position + Vector3(-half, 0.0, -half),
		_decal.global_position + Vector3(half, 0.0, -half),
		_decal.global_position + Vector3(half, 0.0, half),
		_decal.global_position + Vector3(-half, 0.0, half)])
	_band = DamageNumbers.projected_bbox(corners, camera)
	_overlap = _overlap_px(_number_rect, _band)


static func _overlap_px(a: Rect2, b: Rect2) -> int:
	var inter := a.intersection(b)
	if inter.size.x <= 0.0 or inter.size.y <= 0.0:
		return 0
	return int(roundf(inter.size.x * inter.size.y))


## Step 6: freeze the pose, then photograph the same frame with and without the
## numbers, then the same frame twice with them off (the 0 px control).
func _shoot() -> void:
	get_tree().paused = true
	await _settle()
	var hit := _grab("numbers_hit")
	_numbers.set_enabled(false)
	await _settle()
	var control := _grab("numbers_control")
	var again := _grab("numbers_control2")
	get_tree().paused = false
	_report(hit, control, again)
```

`_grab()` must be the `capture_buffs.gd` version plus a save error folded into the failure count, and `_report()` prints `checks/failures/band_diff/overlap/lit` before quitting `0`/`1`.

- [ ] **Step 2: Create the scene and run it**

`scenes/ui/capture_damage_numbers.tscn` — the same three-node shape as `scenes/ui/capture_buffs.tscn`: root `CaptureDamageNumbers`, `GroveArena` instance, `CaptureDriver` (the arena already carries `DamageNumbers`, so nothing is mounted here).

```bash
"$GODOT" --path . res://scenes/ui/capture_damage_numbers.tscn --fixed-fps 60
"$GODOT" --path . res://scenes/ui/capture_damage_numbers.tscn --fixed-fps 60 -- negative
"$GODOT" --path . res://scenes/ui/capture_damage_numbers.tscn --fixed-fps 60 -- low-anchor
```

Expected: positive `checks=6 failures=0` exit 0; `-- negative` red on the "a hit really produced a number" check exit 1; `-- low-anchor` red on `P31.4` (nonzero overlap) exit 1. Screenshots land in `docs/phase-d/evidence/t031/` at 1280×720.

- [ ] **Step 3: View the evidence**

The controller (not the implementer) opens `numbers_hit.png`, `numbers_control.png` and `numbers_low_anchor.png` and confirms: the digits are legible in the VT323 face with a black outline, they sit above the enemy and above the orange disc, nothing overlaps the HUD row, and the control frames differ from the hit frame only in the number area. A PNG that was not looked at is not evidence.

- [ ] **Step 4: Record the decision and the state**

`docs/DECISIONS.md` — append **D-027 · Damage numbers (Technical, Accepted)** with: the single hook in `player_combat.gd`; the four laws (24 slots, 33 tick life, 6 tick merge, 8 px upward-only jitter, integer-px projection); the clearance law stated as "a number's box never overlaps the telegraph band visible under its target", implemented as a world-space lift so the anchor stays put when the camera moves; the reason spec §4's bare 1.1 m anchor could not satisfy DG4 by itself (measured: the disc's far edge projects about `r × 1.25` metres above the ground point, so a 1.1 m anchor lands inside its own band); the toggle being an information toggle, not a feel one (spec §9.4); and the measured evidence numbers (band diff, overlap px, checks, suite counts).

`docs/STATE.md` — T-031 DONE line with the real numbers, the Phase D table row, and the refreshed suite totals (25 suites). If Task 4 moved `SHEET_SIZE`, update the same sentences that still say 480×432.

- [ ] **Step 5: Full regression**

```bash
GODOT="C:/Users/My Lenovo/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
for t in tests/test_*.gd; do
  "$GODOT" --headless --path . -s "res://$t" >/tmp/t031_suite.log 2>&1 \
    || echo "RED $t"
done
node tools/check_stat_source.mjs && node tools/check_stat_source.mjs --selftest
for s in run_t018_cycles run_t019_swarm run_t020_ranged run_t021_boss run_t022_reward \
         run_t023_onehit run_t023_flow run_t027_tempo run_t030_buffs run_t031_numbers; do
  "$GODOT" --headless --path . "res://scenes/phase_c/$s.tscn" --fixed-fps 60 >/dev/null 2>&1 \
    || echo "RED $s"
done
"$GODOT" --headless --path . res://scenes/phase_c/grove_arena.tscn --quit-after 120
"$GODOT" --headless --path . res://scenes/phase_c/play_arena.tscn --quit-after 120
```

Expected: no `RED` lines, `25/25` suites exit 0, `stat-source clean` + selftest red-capable, and zero `SCRIPT ERROR` in the L2 runs. Do **not** run `node tools/run_evidence.mjs` — it rewrites `docs/phase-c/evidence/t023/evidence_report.*`, which is the user's dirty work; the seven E-harness scenes above are the same commands that tool issues, and running them directly is the substitution to name in the report.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/capture_damage_numbers.gd scripts/ui/capture_damage_numbers.gd.uid \
  scenes/ui/capture_damage_numbers.tscn \
  docs/DECISIONS.md docs/STATE.md docs/phase-d/evidence/t031
git commit -m "feat(T-031): capture damage number evidence and record D-027"
```

---

## Gates (spec §8, T-031 slice)

| Gate | How this plan closes it |
|---|---|
| **DG1** | `--check-only` on `damage_numbers_kernel.gd`, `damage_numbers.gd`, `t031_numbers_driver.gd`, `capture_damage_numbers.gd`, `character_sheet.gd`; `--import` exit 0. |
| **DG2** | `test_damage_numbers_kernel.gd` (merge/life/pool/jitter/snap/seeded), `test_damage_numbers.gd` (integer px, no allocation, clearance, toggle), extended `test_theme.gd`, `test_font_coverage.gd`, extended `test_character_sheet.gd`. |
| **DG3** | `test_damage_numbers_kernel.gd -- negative` (merge window forced to 0), `test_damage_numbers.gd -- negative` (clearance off), `run_t031_numbers.tscn -- negative` (hook unwired) and `-- spam` (ceiling), `capture_damage_numbers.tscn -- negative` and `-- low-anchor`. Every one must exit 1 and name the id that went red. |
| **DG4** | `scenes/ui/capture_damage_numbers.tscn` at 1280×720: band diff ≥ 40 px hit vs control on the same frozen pose, control-vs-control 0 px, lit pixels ≥ 500, number↔telegraph overlap **0 px**, and the printed number equals the logged damage. Images viewed by the controller. |
| **DG5** | `run_t031_numbers.tscn`: one `shown` per `damage` line, amounts equal, pool ceiling, disabled window silent. |

**Regression that must stay green:** the 24 pre-existing suites, `run_t018`–`run_t023`, `run_t027_tempo`, `run_t030_buffs` (`runs=10 wins=10 picks=20 mods_ok=true`), `test_title_entry`, `check_stat_source` + `--selftest`, and L2 `grove_arena`/`play_arena` at 120 frames with zero `SCRIPT ERROR`.

**L4 stays with the user.** When a playtest is scheduled, the bot modes exercise `set_enabled(false)` and the brief's Readability line asks whether the numbers help the player read their own damage — the AI reports measurements only.

## Known follow-ups (deliberately out of this plan)

- Damage numbers for damage the **player** takes (spec §1 puts it out of scope).
- Critical/variant styling — no crit damage exists yet in the damage path.
- Per-enemy anchor heights: the clearance law makes them unnecessary today; revisit only if a decal larger than the boss sweep (r 2.6) ships.
- Pause-stack semantics if a third modal layer ever appears (parked from T-030; still one `get_tree().paused` boolean).
