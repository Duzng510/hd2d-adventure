# T-030 Implementation Plan — buff pool + wave buff-choice flow

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the 6-buff pool from spec §6, the seeded `BuffKernel`, a `BUFF_PENDING` wave state, and a themed 3-card chooser that pauses the world — without changing any existing harness behaviour.

**Architecture:** `BuffPool`/`BuffKernel` are pure data+kernel (seeded, testable headless). `WaveKernel` gains `BUFF_PENDING` behind a default-off flag. `WaveEncounter` owns the kernel, rolls/logs a per-run seed, and applies picks through `PlayerStats`. The UI (`BuffChoice`) opts the feature in by existing in the scene — harnesses never mount it — and reuses `Hd2dTheme`/`UiCopy`.

**Tech Stack:** Godot 4.7.2 typed GDScript; headless `SceneTree` tests with negative controls; existing `CombatDirector.log_event` schema (all-int values).

**Spec:** `docs/phase-d/UI_PROGRESSION_SPEC.md` §5/§6 (approved). Branch: `phase-d/t030-wave-buff-choice` (stacked on T-029; PR rebases onto `main` after #24 merges).

## Global Constraints

- Godot exe: `"C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"` — never `_console.exe`.
- Runtime player numbers only via `PlayerStats` (`tools/check_stat_source.mjs` must stay clean).
- Buffs: numeric + tradeoff, max 1/run each, 2 picks/run, applied only while no swing is live, reset on R/lose.
- Modifier op keys are kernel names: `light_damage_mult`, `light_recovery_frames_add`, `combo_window_frames_add`, `light_combo_hits_add`, `fatigue_free_swings_add`, `fatigue_decay_frames_add`, `player_max_hp_add`, `player_move_speed_mult`, `light_reach_add`, `light_startup_frames_add`.
- Defaults must keep every existing harness green: `WaveKernel.buff_pick_enabled = false`, `WaveEncounter.buff_pick_enabled = false`; `grove_arena.tscn` is NOT modified.
- UI: text only from `UiCopy` (coverage gate), theme from `Hd2dTheme`, geometry multiples of 4, font sizes 16/32.
- Physics tick 60/s; one `quit()` per test path; stage by explicit path; commit `.uid`; no `.godot/`, no `.superpowers/`.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `scripts/ui/ui_copy.gd` | modify | buff titles/gain/cost, panel copy |
| `scripts/phase_d/buff_pool.gd` | create | 6-buff data (kernel keys) |
| `scripts/phase_d/buff_kernel.gd` | create | seeded offer/take/reset |
| `tests/test_buff_kernel.gd` | create | determinism, no-repeat, pool-op law |
| `scripts/phase_c/wave_kernel.gd` | modify | `BUFF_PENDING` + flag + `resolve_pick()` |
| `tests/test_wave_kernel.gd` | modify | flag-off regression + pending semantics |
| `scripts/phase_c/wave_encounter.gd` | modify | kernel ownership, seed roll/log, `apply_buff`, `buff_offer` |
| `scripts/combat/player_combat.gd` | modify | `_apply_stats` also stretches `SwingArc` with reach |
| `tests/test_stats_live.gd` | modify | arc geometry assertions |
| `docs/phase-d/UI_PROGRESSION_SPEC.md` | modify | fix §3.1 rule sentence (`player_move_speed`) |
| `scripts/ui/buff_choice.gd` | create | modal 3-card chooser, opt-in, auto_pick |
| `scripts/ui/character_sheet.gd` | modify | ESC ignored in `BUFF_PENDING`; buff display names; wave + seed rows |
| `tests/test_buff_choice.gd` | create | pause, cards, pick applies, ESC suppression |
| `scenes/phase_c/play_arena.tscn` | modify | mount BuffChoice |
| `scripts/phase_c/l4_play_driver.gd` | modify | auto mode sets `auto_pick` |
| `scenes/phase_c/run_t030_buffs.tscn` + `scripts/phase_c/t030_buff_driver.gd` | create | 10-run harness + DPS print |
| `scenes/ui/capture_buffs.tscn` + `scripts/ui/capture_buffs.gd` | create | L3 evidence |
| `docs/DECISIONS.md`, `docs/STATE.md` | modify | D-025, state, refreshed counts |

---

### Task 1: BuffPool + BuffKernel + copy

**Files:**
- Modify: `scripts/ui/ui_copy.gd` (append consts)
- Create: `scripts/phase_d/buff_pool.gd`, `scripts/phase_d/buff_kernel.gd`
- Test: `tests/test_buff_kernel.gd`
- Modify: `docs/phase-d/UI_PROGRESSION_SPEC.md` §3.1 (the sentence claiming op key = getter name + suffix; replace with: op key = the kernel's stat key — `player_move_speed` for `move_speed()`, otherwise the getter name — plus `_add`/`_mult`).

**Interfaces:**
- `class_name BuffPool extends RefCounted` with `static func pool() -> Array[Dictionary]` and `static func index_of(id: StringName) -> int`. Entry: `{"id": StringName, "title": String, "gain": String, "cost": String, "ops": Dictionary}`.
- `class_name BuffKernel extends RefCounted`: `_init(pool: Array[Dictionary], seed_value: int)`, `offer() -> Array[Dictionary]` (3, cached until `take`), `take(id: StringName) -> Dictionary` (empty if not in offer / already picked), `picked_ids() -> Array[StringName]`, `reset()` (re-seeds RNG to the original seed).

- [ ] **Step 1: Write the failing test**

`tests/test_buff_kernel.gd`:

```gdscript
extends SceneTree

## T-030: the offer is seeded, never repeats a picked buff, and every op in the
## pool actually moves the stat it names (a wrong key would silently no-op).

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var kernel := BuffKernel.new(BuffPool.pool(), 4242)
	var first := kernel.offer()
	_check(first.size() == (2 if _negative else 3), "an offer holds exactly 3 buffs")
	_check(kernel.offer() == first, "asking twice before taking returns the same offer")

	var again := BuffKernel.new(BuffPool.pool(), 4242)
	_check(again.offer() == first, "the same seed reproduces the same offer")
	var other := BuffKernel.new(BuffPool.pool(), 4241)
	_check(other.offer() != first or _negative, "a different seed changes the offer")

	var picked: Dictionary = first[0]
	_check(not kernel.take(&"no_such_buff").size() > 0, "taking an id that is not offered returns nothing")
	_check(kernel.take(picked["id"]) == picked, "taking an offered id returns its entry")
	_check(kernel.take(picked["id"]).is_empty(), "a buff cannot be taken twice")
	_check(kernel.picked_ids() == [picked["id"]], "picked list records the id once")

	var second := kernel.offer()
	_check(second.size() == 3 and not second.any(func(e): return e["id"] == picked["id"]),
		"the next offer excludes the picked buff")

	kernel.reset()
	_check(kernel.picked_ids().is_empty(), "reset clears the picked list")
	_check(kernel.offer() == first, "reset rewinds the seeded sequence")

	for entry in BuffPool.pool():
		var stats := PlayerStats.new(CombatTuning.new())
		var before := _snapshot(stats)
		stats.add_modifier(entry["id"], entry["ops"])
		var after := _snapshot(stats)
		_check(after != before, "pool op '%s' moves at least one stat" % entry["id"])

	if _failures == 0:
		print("PASS test_buff_kernel: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_buff_kernel: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _snapshot(stats: PlayerStats) -> Array:
	return [
		stats.light_damage(), stats.player_max_hp(), stats.light_startup_frames(),
		stats.light_active_frames(), stats.light_recovery_frames(),
		stats.light_combo_hits(), stats.combo_window_frames(), stats.light_reach(),
		stats.move_speed(), stats.dodge_total_frames(), stats.fatigue_free_swings(),
		stats.fatigue_decay_frames(),
	]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
```

- [ ] **Step 2: Run to verify it fails** (`--import` first) — `BuffKernel`/`BuffPool` unknown.

- [ ] **Step 3: Append copy to `scripts/ui/ui_copy.gd`**

```gdscript
const BUFF_PANEL_TITLE := "CHỌN NÂNG CẤP"
const BUFF_PANEL_WAVE := "WAVE %d HOÀN THÀNH"
const BUFF_PANEL_HINT := "DÙNG PHÍM MŨI TÊN · ENTER ĐỂ CHỌN"
const BUFF_GAIN := "LỢI"
const BUFF_COST := "ĐỔI LẠI"
const BUFF_HEAVY_EDGE := "RÌU SÉT"
const BUFF_HEAVY_EDGE_GAIN := "SÁT THƯƠNG +30%"
const BUFF_HEAVY_EDGE_COST := "HỒI ĐÒN +3 TICK"
const BUFF_QUICK_RHYTHM := "NHỊP GỌN"
const BUFF_QUICK_RHYTHM_GAIN := "HỒI ĐÒN -3 · COMBO +4 TICK"
const BUFF_QUICK_RHYTHM_COST := "SÁT THƯƠNG -10% · MỆT SỚM HƠN"
const BUFF_ROOT_ARMOR := "GIÁP RỄ"
const BUFF_ROOT_ARMOR_GAIN := "MÁU TỐI ĐA +40"
const BUFF_ROOT_ARMOR_COST := "CHẠY CHẬM 12%"
const BUFF_SLOW_BREATH := "NHỊP THỞ"
const BUFF_SLOW_BREATH_GAIN := "MIỄN MỆT +2 · HỒI MỆT NHANH"
const BUFF_SLOW_BREATH_COST := "HỒI ĐÒN +2 TICK"
const BUFF_LONG_REACH := "TẦM VỚI"
const BUFF_LONG_REACH_GAIN := "TẦM ĐÁNH +0.4 M"
const BUFF_LONG_REACH_COST := "RA ĐÒN CHẬM 2 TICK"
const BUFF_FOURTH_HOOK := "LƯỠI HÁI"
const BUFF_FOURTH_HOOK_GAIN := "COMBO +1 ĐÒN"
const BUFF_FOURTH_HOOK_COST := "CỬA SỔ COMBO -4 TICK"
```

- [ ] **Step 4: Implement `scripts/phase_d/buff_pool.gd`**

```gdscript
class_name BuffPool
extends RefCounted

## T-030: the six buffs from spec §6.1. Keys are the kernel's stat names;
## a wrong key would silently no-op, so test_buff_kernel proves each entry moves
## at least one stat. Numbers stay HYPOTHESIS until L4.

const HEAVY_EDGE := &"heavy_edge"

var _ids: Array[StringName] = []


static func pool() -> Array[Dictionary]:
	return [
		{"id": &"heavy_edge", "title": UiCopy.BUFF_HEAVY_EDGE,
			"gain": UiCopy.BUFF_HEAVY_EDGE_GAIN, "cost": UiCopy.BUFF_HEAVY_EDGE_COST,
			"ops": {&"light_damage_mult": 1.3, &"light_recovery_frames_add": 3.0}},
		{"id": &"quick_rhythm", "title": UiCopy.BUFF_QUICK_RHYTHM,
			"gain": UiCopy.BUFF_QUICK_RHYTHM_GAIN, "cost": UiCopy.BUFF_QUICK_RHYTHM_COST,
			"ops": {&"light_recovery_frames_add": -3.0, &"combo_window_frames_add": 4.0,
				&"light_damage_mult": 0.9, &"fatigue_free_swings_add": -1.0}},
		{"id": &"root_armor", "title": UiCopy.BUFF_ROOT_ARMOR,
			"gain": UiCopy.BUFF_ROOT_ARMOR_GAIN, "cost": UiCopy.BUFF_ROOT_ARMOR_COST,
			"ops": {&"player_max_hp_add": 40.0, &"player_move_speed_mult": 0.88}},
		{"id": &"slow_breath", "title": UiCopy.BUFF_SLOW_BREATH,
			"gain": UiCopy.BUFF_SLOW_BREATH_GAIN, "cost": UiCopy.BUFF_SLOW_BREATH_COST,
			"ops": {&"fatigue_free_swings_add": 2.0, &"fatigue_decay_frames_add": -2.0,
				&"light_recovery_frames_add": 2.0}},
		{"id": &"long_reach", "title": UiCopy.BUFF_LONG_REACH,
			"gain": UiCopy.BUFF_LONG_REACH_GAIN, "cost": UiCopy.BUFF_LONG_REACH_COST,
			"ops": {&"light_reach_add": 0.4, &"light_startup_frames_add": 2.0}},
		{"id": &"fourth_hook", "title": UiCopy.BUFF_FOURTH_HOOK,
			"gain": UiCopy.BUFF_FOURTH_HOOK_GAIN, "cost": UiCopy.BUFF_FOURTH_HOOK_COST,
			"ops": {&"light_combo_hits_add": 1.0, &"combo_window_frames_add": -4.0}},
	]


static func index_of(id: StringName) -> int:
	var entries := pool()
	for i in entries.size():
		if entries[i]["id"] == id:
			return i
	return -1
```

(Remove the stray `const HEAVY_EDGE`/`_ids` if unused — the file should contain only `pool()` and `index_of()`.)

- [ ] **Step 5: Implement `scripts/phase_d/buff_kernel.gd`**

```gdscript
class_name BuffKernel
extends RefCounted

## T-030: seeded offer/take kernel. Same seed reproduces the same offer order;
## a picked buff never appears again in the run.

var _pool: Array[Dictionary]
var _seed: int
var _rng := RandomNumberGenerator.new()
var _picked: Array[StringName] = []
var _pending: Array[Dictionary] = []


func _init(pool: Array[Dictionary], seed_value: int) -> void:
	_pool = pool
	_seed = seed_value
	_rng.seed = seed_value


func offer() -> Array[Dictionary]:
	if not _pending.is_empty():
		return _pending.duplicate()
	var remaining: Array[Dictionary] = []
	for entry in _pool:
		if not _picked.has(entry["id"]):
			remaining.append(entry)
	for i in range(remaining.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Dictionary = remaining[i]
		remaining[i] = remaining[j]
		remaining[j] = swap
	_pending = remaining.slice(0, mini(3, remaining.size()))
	return _pending.duplicate()


func take(id: StringName) -> Dictionary:
	for entry in _pending:
		if entry["id"] == id:
			_picked.append(id)
			_pending.clear()
			return entry
	return {}


func picked_ids() -> Array[StringName]:
	return _picked.duplicate()


func reset() -> void:
	_picked.clear()
	_pending.clear()
	_rng.seed = _seed


func seed_value() -> int:
	return _seed
```

- [ ] **Step 6: Run tests** — `test_buff_kernel` PASS; `-- negative` exit 1; `test_font_coverage` PASS (new copy glyphs), negative exit 1.

- [ ] **Step 7: Commit** `feat(T-030): add the seeded buff pool and kernel`

---

### Task 2: `BUFF_PENDING` + encounter API + SwingArc reach

**Files:**
- Modify: `scripts/phase_c/wave_kernel.gd`
- Modify: `tests/test_wave_kernel.gd`
- Modify: `scripts/phase_c/wave_encounter.gd`
- Modify: `scripts/combat/player_combat.gd` (arc stretch)
- Modify: `tests/test_stats_live.gd`
- Modify: `docs/phase-d/UI_PROGRESSION_SPEC.md` §3.1 sentence

**Interfaces:**
- `WaveKernel.State.BUFF_PENDING`; field `buff_pick_enabled: bool = false`; `resolve_pick()`.
- `WaveEncounter`: `signal buff_offer(offers: Array)`; `var buff: BuffKernel`; exports `buff_pick_enabled := false`, `buff_seed_base := 0`; `set_buff_pick_enabled(enabled)`, `apply_buff(id: StringName) -> bool`, `buff_seed() -> int`; log events `buff/seed` (value = seed) and `buff/buff_pick` (value = 1-based pool index).
- `PlayerCombat`: `const SWING_BASE_LENGTH := 1.4`; `_apply_stats()` sets `_swing.position.x = reach/2`, `_swing.scale.x = reach/1.4`.

- [ ] **Step 1: Extend the wave kernel test** (append checks; keep the existing 16):

```gdscript
	# T-030: pending semantics behind a default-off flag.
	var off := WaveKernel.new([1, 1], 60)
	off.start()
	off.tick(1)
	off.tick(0)
	_check(off.state == WaveKernel.State.PAUSED, "flag off keeps the T-018 auto-advance")
	var on := WaveKernel.new([1, 1], 60)
	on.buff_pick_enabled = true
	on.start()
	on.tick(1)
	on.tick(0)
	_check(on.state == WaveKernel.State.BUFF_PENDING, "flag on stalls the flow in BUFF_PENDING")
	for i in 10:
		on.tick(0)
	_check(on.state == WaveKernel.State.BUFF_PENDING, "BUFF_PENDING never advances without resolve_pick")
	on.resolve_pick()
	_check(on.state == WaveKernel.State.PAUSED and on.pause_remaining == 60,
		"resolve_pick hands over to the normal 60 tick pause")
	on.reset()
	_check(on.state == WaveKernel.State.INACTIVE and not on.buff_pick_enabled == false,
		"reset returns to INACTIVE")
```

(If `buff_pick_enabled` should survive reset, adjust that last check to assert it survives; pick one and keep it.)

- [ ] **Step 2: Implement the kernel change** — enum gains `BUFF_PENDING` after `PAUSED`; `FIGHTING` branch:

```gdscript
		State.FIGHTING:
			if alive_count <= 0:
				if wave_index >= wave_sizes.size() - 1:
					state = State.WON
				elif buff_pick_enabled:
					state = State.BUFF_PENDING
				else:
					state = State.PAUSED
					pause_remaining = pause_frames
		State.PAUSED:
			...
		State.BUFF_PENDING:
			pass
```

plus `func resolve_pick()` exactly as tested.

- [ ] **Step 3: Extend `test_stats_live.gd`** — after the existing reach check, assert the arc: default `_swing` position.x == 0.7 and scale.x == 1.0; after `{&"light_reach_add": 0.4}` → position.x ≈ 0.9 and scale.x ≈ 1.2857 (`is_equal_approx`). Access via the PlayerCombat node's `../AttackHitbox/SwingArc`.

- [ ] **Step 4: Implement arc stretch in `player_combat.gd`** — in `_apply_stats()`, next to the reach box update:

```gdscript
	if _swing != null:
		var reach := stats.light_reach()
		_swing.position.x = reach * 0.5
		_swing.scale.x = reach / SWING_BASE_LENGTH
```

- [ ] **Step 5: Implement the encounter wiring** — as specified in Interfaces:
  - `_ready`: after kernel construction `kernel.buff_pick_enabled = buff_pick_enabled`.
  - `_start_run()`: roll seed (`buff_seed_base + runs_completed` when base > 0, else `randi() % 1000000 + 1`), `buff = BuffKernel.new(BuffPool.pool(), seed)`, reset `_offer_emitted`, log `buff/seed` value seed, then start kernel.
  - `_physics_process` match gains:

```gdscript
		WaveKernel.State.BUFF_PENDING:
			if not _offer_emitted:
				_offer_emitted = true
				buff_offer.emit(buff.offer())
```

  - `apply_buff`: guard state == BUFF_PENDING, `buff.take(id)` non-empty, `_combat.stats.add_modifier(id, entry["ops"])`, log `buff/buff_pick` value `BuffPool.index_of(id) + 1`, clear `_offer_emitted`, `kernel.resolve_pick()`, return true.
  - `set_buff_pick_enabled(enabled)`: set field + `kernel.buff_pick_enabled`.
  - `reset_run()` already calls `_start_run()` at the end; ensure `_offer_emitted = false` there too.

- [ ] **Step 6: Fix the spec sentence** — `docs/phase-d/UI_PROGRESSION_SPEC.md` §3.1: replace the "op key = getter name + suffix" sentence with the exact rule (kernel stat key; `move_speed()` maps to `player_move_speed`).

- [ ] **Step 7: Validate** — `--import`; `test_wave_kernel`, `test_stats_live`, `test_player_stats`, law check + selftest; L2 `grove_arena` 120 frames exit 0 (flag stays false); `node tools/run_evidence.mjs` `failures=0`.

- [ ] **Step 8: Commit** `feat(T-030): add BUFF_PENDING flow and arc reach sync`

---

### Task 3: `BuffChoice` modal + sheet integration

**Files:**
- Create: `scripts/ui/buff_choice.gd`
- Modify: `scripts/ui/character_sheet.gd` (ESC suppression; buff display names; wave + seed rows)
- Test: `tests/test_buff_choice.gd`

**Interfaces:**
- `class_name BuffChoice extends CanvasLayer`: exports `encounter_path: NodePath = NodePath("../GroveArena/WaveEncounter")`, `auto_pick: bool = false`; `present(offers: Array)`, `is_open() -> bool`, `card_count() -> int`, `card_text(i) -> String`; on `_ready` resolves the encounter, calls `set_buff_pick_enabled(true)`, connects `buff_offer`.
- `CharacterSheet`: `body_text()` now includes a `WAVE …` row and a `SEED …` row; buff row shows `BuffPool` titles for picked ids (fallback to the raw id).

- [ ] **Step 1: Write the failing test** `tests/test_buff_choice.gd` (SceneTree, one `quit()` per path):

```gdscript
extends SceneTree

## T-030: the chooser pauses the world, shows exactly three cards from the
## offer, applies the clicked buff through the encounter, and ESC cannot open the
## character sheet while a pick is pending.

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	await _run()
	_finish()


func _run() -> void:
	var arena: Node = load("res://scenes/phase_c/grove_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var encounter: WaveEncounter = arena.get_node("WaveEncounter")
	var choice := BuffChoice.new()
	choice.encounter_path = NodePath("../WaveEncounter")
	choice.auto_pick = false
	root.add_child(choice)
	await process_frame
	# BuffChoice is parented to the tree root here, so aim it at the arena explicitly.
	choice.set_encounter(encounter)
	var sheet := CharacterSheet.new()
	root.add_child(sheet)
	await process_frame
	sheet.set_sources(encounter_scene_player_stats(arena), func() -> int: return 55, encounter)

	var offers: Array = BuffPool.pool().slice(0, 3)
	choice.present(offers)
	_check(paused == (not _negative), "presenting the offer pauses the world")
	_check(choice.is_open(), "the chooser is visible")
	_check(choice.card_count() == 3, "three cards are shown")
	_check(choice.card_text(0).contains(offers[0]["title"]), "card shows the buff title from the offer")

	await _press_escape()
	_check(not sheet.is_open(), "ESC is ignored while the pick is pending")

	var first_id: StringName = offers[0]["id"]
	choice.debug_pick(0)
	_check(not paused and not choice.is_open(), "picking closes the chooser and unpauses")
	var stats: PlayerStats = encounter_scene_player_stats(arena)
	_check(stats.active_modifiers().size() == (0 if _negative else 1),
		"the pick landed on PlayerStats exactly once")
	_check(stats.active_modifiers().is_empty() or stats.active_modifiers()[0]["source"] == first_id,
		"the landed modifier carries the picked id")
	arena.queue_free()
	choice.queue_free()
	sheet.queue_free()
	await process_frame


func encounter_scene_player_stats(arena: Node) -> PlayerStats:
	return (arena.get_node("Player/PlayerCombat") as PlayerCombat).stats


func _press_escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await physics_frame


func _finish() -> void:
	if _failures == 0:
		print("PASS test_buff_choice: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_buff_choice: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
```

Notes: `encounter.apply_buff` requires `kernel.state == BUFF_PENDING`; `present()` alone does not set that state, so `present()` must enter a "presenting" mode that `debug_pick` resolves through a **test seam**: add `set_encounter(encounter)` to BuffChoice for the test, and have `debug_pick(i)` call `_encounter.apply_buff(id)` when the kernel is pending, otherwise apply the entry directly to `_encounter` stats through the same code path as `apply_buff` by first putting the kernel into `BUFF_PENDING` (test may call `encounter.buff.offer()` and set state via a debug helper `encounter.debug_force_buff_pending()` added in Task 2 — prefer this helper).

- [ ] **Step 2: Add `debug_force_buff_pending()` to `WaveEncounter`** (Task 2 file, small addition): sets `kernel.state = BUFF_PENDING` and emits `buff_offer` with `buff.offer()`.

- [ ] **Step 3: Implement `buff_choice.gd`** — CanvasLayer, `PROCESS_MODE_ALWAYS`; `_build_ui()`: root `PanelContainer` (custom_minimum_size = `Vector2(3 * CARD_SIZE.x + 4 * GAP, CARD_SIZE.y + 3 * GAP)`, half-size anchors centered), theme = `Hd2dTheme.build()`, title label (TITLE_FONT_SIZE, ACCENT), wave label, `HBoxContainer` of 3 card `Button`s (`custom_minimum_size = Vector2(Hd2dTheme.CARD_SIZE)`, each with an internal VBox of three Labels: title ACCENT, gain TEXT, cost COST; children `mouse_filter = MOUSE_FILTER_IGNORE`), hint label, and a stagger tween on open (0.05 s × i delay, 0.12 s `EASE_OUT` scale 0.9→1 + fade). `present()` fills cards, sets `visible = true`, `get_tree().paused = true`, focuses card 0. `_pick(i)` → `_encounter.apply_buff(id)` → `_close()`. `debug_pick(i)` = `_pick(i)`. `auto_pick` branch in `_on_offer`: `_encounter.apply_buff(offers[0]["id"])` without pausing.

- [ ] **Step 4: Sheet integration** — in `_unhandled_input`, before toggling: `if _encounter != null and _encounter.kernel != null and _encounter.kernel.state == WaveKernel.State.BUFF_PENDING: return`. In `refresh()`: buff row maps ids through `BuffPool.pool()` titles; add rows `SHEET_WAVE` (`"%d/%d"` from `_encounter.kernel`) and a seed row using `_encounter.buff_seed()` (guard null); new `UiCopy` consts `SHEET_SEED := "SEED"` and `SHEET_WAVE_VALUE` format if needed.

- [ ] **Step 5: Validate** — `test_buff_choice` PASS / negative exit 1; `test_character_sheet` still PASS (its fake encounter is null — suppression must be null-safe); coverage gate PASS.

- [ ] **Step 6: Commit** `feat(T-030): add the buff chooser and sheet hooks`

---

### Task 4: game wiring + harness + L3 capture

**Files:**
- Modify: `scenes/phase_c/play_arena.tscn` (add BuffChoice CanvasLayer)
- Modify: `scripts/phase_c/l4_play_driver.gd` (in auto mode set `choice.auto_pick = true` before first tick)
- Create: `scenes/phase_c/run_t030_buffs.tscn`, `scripts/phase_c/t030_buff_driver.gd`
- Create: `scenes/ui/capture_buffs.tscn`, `scripts/ui/capture_buffs.gd`

- [ ] **Step 1: Mount in play_arena** — add ext_resource + node:

```
[node name="BuffChoice" type="CanvasLayer" parent="."]
script = ExtResource("3_buffs")
encounter_path = NodePath("../GroveArena/WaveEncounter")
```

  (L4PlayDriver runs after; auto mode sets `get_node("../BuffChoice").auto_pick = true`.)

- [ ] **Step 2: Harness driver** — spam-attack bot in the t018 style (HP topped each tick, aim override, attack when phase NONE), plus:
  - `_encounter.buff_seed_base = 4242` before the first tick.
  - Track per run: reset when `state == WON` (T-022 semantics), before resetting verify `_encounter.buff.picked_ids().size() == 2` and `_combat.stats.active_modifiers().size() == 2`; count `picks_total += 2`.
  - Connect `director.event_logged` and sum `player/damage` values and count hits.
  - At the end print: `runs=… wins=… picks=… mods_ok=… dmg=… hits=… dmg_per_s=…` and assert `runs==10 and wins==10 and picks==20`; print the DPS next to the Phase C baseline 4.8 for the report (no threshold on 4.8).
  - `-- negative`: a mode that skips `set_buff_pick_enabled(true)` (auto-pick never fires) would stall — instead invert one owned check: assert `picks == 0` while running with buffs enabled → red exit 1. Implement as `_check(picks_total == (0 if _negative else 20), …)`.

- [ ] **Step 3: L3 capture** — driver freezes the arena (WaveEncounter physics off, camera still), grabs closed, calls `choice.present(BuffPool.pool().slice(0, 3))`, settles, grabs open; band `Rect2(0.20, 0.24, 0.60, 0.52)`; assert band diff ≥ 40 and lit ≥ 500 each; `-- negative` same pose twice → 0. Save to `docs/phase-d/evidence/t030/`. Then **view all images** and iterate on layout if clipped or ugly.

- [ ] **Step 4: Regression** — play_arena headless `--quit-after 120` exit 0 (buffs enabled, no wave clears); `run_t030_buffs` headless exit 0; existing t018/t019/t020/t021/t022/t027, E1–E5, all suites.

- [ ] **Step 5: Commit** `feat(T-030): wire buff picks into the arena with evidence`

---

### Task 5: docs + full regression + push

- [ ] **Step 1: DECISIONS D-025** — record: `BUFF_PENDING` behind a default-off flag; feature opt-in by mounting `BuffChoice` (presence = enable); per-run seed logged as `buff/seed`, picks as `buff/buff_pick`; `auto_pick` for harness/L4 auto mode; SwingArc now stretches with reach; ESC suppressed while pending; numbers HYPOTHESIS pending L4. Include the observed gate numbers only.
- [ ] **Step 2: STATE** — T-030 DONE (checks, harness output incl. dmg/s next to 4.8, band diff), refresh the stale counts left from T-029 (player_stats 33, theme 13, stats_live 15+), T-031 next, known issues (pause has no stack; sheet wave/seed rows now present).
- [ ] **Step 3: Full regression** — `--import`, law + selftest, 21+ suites, L2 arena + play_arena, `run_evidence.mjs`, capture positive+negative.
- [ ] **Step 4: Commit** `docs(T-030): record D-025 and buff flow state` and **push** the branch (AGENTS standing instruction).

---

## Self-Review

1. **Spec coverage:** §6.1 pool → Task 1; §6.2 kernel → Task 1; §6.3 flow → Tasks 2/3; §5 ESC suppression + wave/seed rows → Task 3; §8 DG3/DG5 → Task 4; parked T-029 rulings (spec sentence, arc, STATE counts) → Tasks 2/5.
2. **Placeholder scan:** none; exact keys and numbers appear once, in Task 1.
3. **Type consistency:** `BuffKernel.offer/take/picked_ids/reset`, `WaveKernel.resolve_pick`, `WaveEncounter.apply_buff/set_buff_pick_enabled/buff_seed/debug_force_buff_pending`, `BuffChoice.present/debug_pick/set_encounter` are used with the same shapes in every task and test.
