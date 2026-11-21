# T-029 Implementation Plan — PlayerStats + Character Sheet + UI Theme

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `PlayerStats` the single runtime source of player numbers, and ship a paused ESC character sheet built on a code-generated HD-2D theme with a self-checked pixel font.

**Architecture:** `PlayerStats` is a pure `RefCounted` kernel over the immutable `combat_tuning.tres` base; `PlayerCombat` is the only writer that pushes effective values into `Health`, `AttackState`, `DodgeState`, `TempoFatigue` and `player.speed`. The sheet is a `CanvasLayer` that pauses the tree and renders only from `PlayerStats`, so it cannot claim a number combat does not use. Theme and font live in code so the texel/pixel laws stay machine-checkable.

**Tech Stack:** Godot 4.7.2 GDScript (typed), headless `SceneTree` tests with exit codes, Node.js zero-dependency law checks (`tools/*.mjs`).

**Spec:** `docs/phase-d/UI_PROGRESSION_SPEC.md` (approved 2026-11-21)

## Global Constraints

- Godot exe: `"C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"` — never `_console.exe`.
- Physics tick 60/s; no `delta` float timing for combat windows.
- Runtime reads player numbers **only** via `PlayerStats`; `combat_tuning.tres` is base-only and never mutated at runtime.
- Input only through InputMap actions; no hardcoded keys in gameplay code.
- UI text integer-pixel positions; panel geometry multiples of 4; font sizes multiples of 7 (m5x7 glyph height).
- Test scripts `extends SceneTree` print `CHECK PASS/FAIL`, use **exactly one** `quit()` per path.
- After adding a `class_name`, run `--headless --path . --import` before tests (global class cache).
- Stage files by path (never `git add -A`); commit `.uid` files with new scripts; never commit `.godot/`.
- Commits: `feat(T-029): …` / `fix(T-029): …` / `docs(T-029): …`, English imperative, ≤72 chars.
- Branch for this plan: `phase-d/t029-player-stats-sheet` (already checked out).

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `scripts/combat/combat_tuning.gd` | modify | add `player_move_speed` (base for stats) |
| `scripts/combat/combat_tuning.tres` | modify | pin `player_move_speed = 4.0` |
| `scripts/combat/player_stats.gd` | create | pure stat kernel (base ⊕ modifiers) |
| `scripts/combat/player_combat.gd` | modify | own `stats`, stop reading stat fields from tuning, push effective values |
| `scripts/phase_a/player_controller.gd` | modify | speed is pushed from stats, no longer scene-owned |
| `tools/check_stat_source.mjs` | create | machine law: only `player_stats.gd` reads stat fields |
| `tests/test_player_stats.gd` | create | kernel unit test + negative control |
| `assets/ui/fonts/m5x7.ttf` | create | pixel font (public domain, ASSET_LOG) |
| `assets/ASSET_LOG.md` | create | asset provenance |
| `scripts/ui/ui_copy.gd` | create | every UI string, single list for coverage test |
| `scripts/ui/hd2d_theme.gd` | create | code-generated Theme (palette, StyleBoxFlat, font) |
| `tests/test_theme.gd` | create | theme law test |
| `tests/test_font_coverage.gd` | create | glyph coverage + negative control |
| `project.godot` | modify | InputMap action `toggle_character_sheet` (Escape) |
| `scripts/ui/character_sheet.gd` | create | paused sheet, renders from PlayerStats |
| `tests/test_character_sheet.gd` | create | pause wiring + "panel does not lie" |
| `scenes/phase_c/grove_arena.tscn` | modify | mount CharacterSheet |
| `scenes/ui/capture_sheet.tscn` + `scripts/ui/capture_sheet.gd` | create | L3 evidence (box-diff, lit, control) |
| `docs/phase-d/UI_PROGRESSION_SPEC.md` | modify | sync §3.3 speed row with implementation |
| `docs/DECISIONS.md`, `docs/STATE.md` | modify | D-021…D-024, phase state |

---

### Task 1: `PlayerStats` kernel + `player_move_speed` base

**Files:**
- Modify: `scripts/combat/combat_tuning.gd` (add group after "Light attack" block, before line 15)
- Modify: `scripts/combat/combat_tuning.tres` (one line)
- Create: `scripts/combat/player_stats.gd`
- Test: `tests/test_player_stats.gd`

**Interfaces:**
- Produces: `class_name PlayerStats extends RefCounted`; `_init(tuning: CombatTuning)`; `signal changed`; getters `light_damage() -> int`, `player_max_hp() -> int`, `light_startup_frames() -> int`, `light_active_frames() -> int`, `light_recovery_frames() -> int`, `light_combo_hits() -> int`, `combo_window_frames() -> int`, `light_reach() -> float`, `move_speed() -> float`, `dodge_speed() -> float`, `dodge_total_frames() -> int`, `dodge_iframe_frames() -> int`, `fatigue_free_swings() -> int`, `fatigue_step_frames() -> int`, `fatigue_max_frames() -> int`, `fatigue_decay_frames() -> int`; mutators `add_modifier(source: StringName, ops: Dictionary)`, `remove_modifier(source: StringName)`, `clear_modifiers()`, `active_modifiers() -> Array[Dictionary]`.
- Modifier key convention: `"<stat_key>_add"` / `"<stat_key>_mult"` (e.g. `light_damage_add`, `light_damage_mult`). Composition: `floor((base + Σadd) × Πmult)`, integers clamp at 1, floats at 0.1.

- [ ] **Step 1: Write the failing test**

`tests/test_player_stats.gd`:

```gdscript
extends SceneTree

## T-029: PlayerStats is the single runtime stat source; base numbers mirror
## combat_tuning and modifiers compose add-before-multiply with a floor.

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	var tuning := CombatTuning.new()
	var stats := PlayerStats.new(tuning)

	_check(stats.light_damage() == 10, "base damage mirrors tuning")
	_check(stats.player_max_hp() == 100, "base hp mirrors tuning")
	_check(stats.light_startup_frames() == 4 and stats.light_active_frames() == 3
		and stats.light_recovery_frames() == 10, "base swing frames mirror tuning")
	_check(is_equal_approx(stats.move_speed(), 4.0), "base move speed comes from tuning")
	_check(is_equal_approx(stats.light_reach(), 1.4), "base reach mirrors tuning")
	_check(stats.light_combo_hits() == 3 and stats.combo_window_frames() == 10,
		"base combo mirrors tuning")
	_check(stats.fatigue_free_swings() == 3 and stats.fatigue_step_frames() == 4
		and stats.fatigue_max_frames() == 12 and stats.fatigue_decay_frames() == 6,
		"base fatigue mirrors tuning")

	stats.add_modifier(&"heavy_edge", {&"light_damage_add": 2.0, &"light_damage_mult": 1.5})
	# add first, multiply after: (10 + 2) * 1.5 = 18. The wrong order gives 17.
	_check(stats.light_damage() == (17 if _negative else 18),
		"adds apply before multipliers (got %d)" % stats.light_damage())

	stats.add_modifier(&"quick_rhythm", {&"light_damage_mult": 0.9})
	_check(stats.light_damage() == (15 if _negative else 16),
		"modifiers multiply together: floor((10+2)*1.5*0.9) = 16 (got %d)" % stats.light_damage())

	stats.add_modifier(&"heavy_edge", {&"light_damage_mult": 2.0})
	# Re-adding a source replaces it. Stacking would give floor(10*1.5*2*0.9) = 27 here
	# only if the old 1.5 survived; replacement gives floor(10*2*0.9) = 18.
	_check(stats.light_damage() == (27 if _negative else 18),
		"re-adding the same source replaces it instead of stacking (got %d)"
		% stats.light_damage())

	stats.remove_modifier(&"heavy_edge")
	_check(stats.light_damage() == (10 if _negative else 9),
		"removing a source restores its share: floor(10*0.9) = 9 (got %d)" % stats.light_damage())

	stats.clear_modifiers()
	_check(stats.light_damage() == 10, "clear wipes every modifier")

	stats.add_modifier(&"floor_probe", {&"light_damage_add": -500.0})
	_check(stats.light_damage() == (0 if _negative else 1),
		"damage clamps at 1, never 0 or negative")
	stats.clear_modifiers()

	var changes := [0]
	stats.changed.connect(func() -> void: changes[0] += 1)
	stats.add_modifier(&"probe", {&"light_damage_mult": 1.3})
	stats.remove_modifier(&"probe")
	stats.remove_modifier(&"missing")
	_check(changes[0] == (3 if _negative else 2),
		"changed fires per real mutation only (got %d)" % changes[0])

	var hp_stats := PlayerStats.new(CombatTuning.new())
	hp_stats.add_modifier(&"root_armor", {&"player_max_hp_add": 40.0,
		&"player_move_speed_mult": 0.88})
	_check(hp_stats.player_max_hp() == 140, "hp add lands on the base")
	_check(is_equal_approx(hp_stats.move_speed(), 3.52), "move speed multiplies the base")

	if _failures == 0:
		print("PASS test_player_stats: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_player_stats: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
```

- [ ] **Step 2: Run to verify it fails**

Run: `"$GODOT" --headless --path . --import` then `"$GODOT" --headless --path . -s res://tests/test_player_stats.gd`
Expected: FAIL — `PlayerStats` identifier not found / parse error (exit non-zero).

- [ ] **Step 3: Add the tuning base**

`scripts/combat/combat_tuning.gd`, insert after line 13 (`light_reach`), before the fatigue group:

```gdscript
@export_group("Player movement")
@export var player_move_speed: float = 4.0
```

`scripts/combat/combat_tuning.tres`, add one line next to `light_reach = 1.4`:

```
player_move_speed = 4.0
```

- [ ] **Step 4: Implement `scripts/combat/player_stats.gd`**

```gdscript
class_name PlayerStats
extends RefCounted

## T-029: single runtime source of player stats. combat_tuning.tres stays the
## immutable base; modifiers arrive keyed by source and compose add-then-mult.

signal changed

var _base: CombatTuning
var _modifiers: Array[Dictionary] = []


func _init(tuning: CombatTuning) -> void:
	_base = tuning


func add_modifier(source: StringName, ops: Dictionary) -> void:
	var entry := {"source": source, "ops": ops.duplicate()}
	for i in _modifiers.size():
		if _modifiers[i]["source"] == source:
			_modifiers[i] = entry
			changed.emit()
			return
	_modifiers.append(entry)
	changed.emit()


func remove_modifier(source: StringName) -> void:
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i]["source"] == source:
			_modifiers.remove_at(i)
			changed.emit()
			return


func clear_modifiers() -> void:
	if _modifiers.is_empty():
		return
	_modifiers.clear()
	changed.emit()


func active_modifiers() -> Array[Dictionary]:
	return _modifiers.duplicate(true)


func light_damage() -> int:
	return _int(&"light_damage", _base.light_damage)


func player_max_hp() -> int:
	return _int(&"player_max_hp", _base.player_max_hp)


func light_startup_frames() -> int:
	return _int(&"light_startup_frames", _base.light_startup_frames)


func light_active_frames() -> int:
	return _int(&"light_active_frames", _base.light_active_frames)


func light_recovery_frames() -> int:
	return _int(&"light_recovery_frames", _base.light_recovery_frames)


func light_combo_hits() -> int:
	return _int(&"light_combo_hits", _base.light_combo_hits)


func combo_window_frames() -> int:
	return _int(&"combo_window_frames", _base.combo_window_frames)


func fatigue_free_swings() -> int:
	return _int(&"fatigue_free_swings", _base.fatigue_free_swings)


func fatigue_step_frames() -> int:
	return _int(&"fatigue_step_frames", _base.fatigue_step_frames)


func fatigue_max_frames() -> int:
	return _int(&"fatigue_max_frames", _base.fatigue_max_frames)


func fatigue_decay_frames() -> int:
	return _int(&"fatigue_decay_frames", _base.fatigue_decay_frames)


func dodge_total_frames() -> int:
	return _int(&"dodge_total_frames", _base.dodge_total_frames)


func dodge_iframe_frames() -> int:
	return _int(&"dodge_iframe_frames", _base.dodge_iframe_frames)


func light_reach() -> float:
	return _value(&"light_reach", _base.light_reach, 0.1)


func move_speed() -> float:
	return _value(&"player_move_speed", _base.player_move_speed, 0.1)


func dodge_speed() -> float:
	return _value(&"dodge_speed", _base.dodge_speed, 0.1)


func _int(key: StringName, base: int) -> int:
	return int(floor(_value(key, float(base), 1.0)))


func _value(key: StringName, base: float, min_value: float) -> float:
	var add := 0.0
	var mult := 1.0
	for entry in _modifiers:
		var ops: Dictionary = entry["ops"]
		add += float(ops.get(StringName(str(key, "_add")), 0.0))
		mult *= float(ops.get(StringName(str(key, "_mult")), 1.0))
	return maxf((base + add) * mult, min_value)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `"$GODOT" --headless --path . --import` then `"$GODOT" --headless --path . -s res://tests/test_player_stats.gd`
Expected: `PASS test_player_stats: 16 checks`, exit 0.
Run: `"$GODOT" --headless --path . -s res://tests/test_player_stats.gd -- negative`
Expected: exit 1 (every `_negative` branch reports the wrong-order/stacking values).

- [ ] **Step 6: Commit**

```bash
git add scripts/combat/combat_tuning.gd scripts/combat/combat_tuning.tres \
  scripts/combat/player_stats.gd scripts/combat/player_stats.gd.uid \
  tests/test_player_stats.gd tests/test_player_stats.gd.uid
git commit -m "feat(T-029): add PlayerStats kernel over the tuning base"
```

---

### Task 2: Wire `PlayerStats` into combat + stat-source machine law

**Files:**
- Modify: `scripts/combat/player_combat.gd` (lines ~20, 45–70, 150–154, 210, 239, 245 plus two new methods)
- Modify: `scripts/phase_a/player_controller.gd:4` (speed no longer exported)
- Modify: `docs/phase-d/UI_PROGRESSION_SPEC.md` §3.3 speed row
- Create: `tools/check_stat_source.mjs`

**Interfaces:**
- Consumes: Task 1 `PlayerStats` API.
- Produces: `PlayerCombat.stats: PlayerStats` (public, read by the sheet); `PlayerCombat._apply_stats()` keeps `Health.max_hp`, `player.speed` in sync on `stats.changed`; swing windows re-read at `_start_attack`.

- [ ] **Step 1: Verify no scene overrides `speed`**

Run: `grep -rn "speed" scenes/ | grep -v uid`
Expected: no `speed =` property on Player nodes. If any exists, stop and report — the source-law needs that removed first.

- [ ] **Step 2: Edit `player_combat.gd`**

Add the field after line 20 (`var health: Health`):

```gdscript
var stats: PlayerStats
```

In `_ready()` replace `health = Health.new(tuning.player_max_hp)` with:

```gdscript
	stats = PlayerStats.new(tuning)
	health = Health.new(stats.player_max_hp())
```

Replace the `DodgeState` and `TempoFatigue` constructions to read stats:

```gdscript
	_dodge = DodgeState.new(stats.dodge_total_frames(), stats.dodge_iframe_frames())
	_tempo = TempoFatigue.new(
		stats.fatigue_free_swings(),
		stats.fatigue_step_frames(),
		stats.fatigue_max_frames(),
		stats.fatigue_decay_frames()
	)
```

After the `_tempo` block, add:

```gdscript
	stats.changed.connect(_apply_stats)
	_apply_stats()
```

In `_start_attack`, before `_attack.start(combo_index, fatigue)`:

```gdscript
	_attack.startup_frames = stats.light_startup_frames()
	_attack.active_frames = stats.light_active_frames()
	_attack.recovery_frames = stats.light_recovery_frames()
	_attack.combo_window_frames = stats.combo_window_frames()
	_attack.max_combo_hits = stats.light_combo_hits()
```

Replace `tuning.light_damage` (line ~210) with `stats.light_damage()`; replace both `tuning.dodge_speed` (lines ~239, ~245) with `stats.dodge_speed()`.

Add these methods next to `hp()`:

```gdscript
## Push effective stats into the live objects. Windows change on the next
## swing (spec §3.3); max HP grows with a matching heal.
func _apply_stats() -> void:
	var previous_max := health.max_hp
	health.max_hp = stats.player_max_hp()
	if health.max_hp > previous_max:
		health.heal(health.max_hp - previous_max)
	if _player != null:
		_player.speed = stats.move_speed()
```

- [ ] **Step 3: Edit `player_controller.gd`**

Replace line 4 with:

```gdscript
## Pushed by PlayerCombat from PlayerStats (T-029); never owned by the scene.
var speed: float = 4.0
```

- [ ] **Step 4: Sync the spec row**

In `docs/phase-d/UI_PROGRESSION_SPEC.md` §3.3, replace the last table row:

```
| `player_controller.gd:27` | `MovementModel.compute_velocity(input, stats.move_speed())` |
```

with:

```
| `player_combat.gd:_apply_stats` | đẩy `_player.speed = stats.move_speed()` (PlayerCombat đã là nơi ghi trạng thái player: facing, lock, override); controller không đọc stats để tránh đường đọc thứ hai |
```

- [ ] **Step 5: Write `tools/check_stat_source.mjs`**

```js
#!/usr/bin/env node
// T-029 law: only player_stats.gd may read player stat fields from tuning.
// Runtime code must go through PlayerStats so buffs have exactly one effect path.

import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const STAT_KEYS = [
  'light_damage', 'player_max_hp', 'player_move_speed',
  'light_startup_frames', 'light_active_frames', 'light_recovery_frames',
  'light_combo_hits', 'combo_window_frames', 'light_reach',
  'dodge_speed', 'dodge_total_frames', 'dodge_iframe_frames',
  'fatigue_free_swings', 'fatigue_step_frames', 'fatigue_max_frames',
  'fatigue_decay_frames',
];
const BANNED = new RegExp(`tuning\\.(${STAT_KEYS.join('|')})\\b`);
const ALLOWED = new Set(['scripts/combat/player_stats.gd', 'scripts/combat/combat_tuning.gd']);

function walk(dir, out = []) {
  for (const name of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, name.name);
    if (name.isDirectory()) walk(path, out);
    else if (name.name.endsWith('.gd')) out.push(path);
  }
  return out;
}

function scan(sources) {
  const violations = [];
  for (const [path, text] of sources) {
    if (ALLOWED.has(path)) continue;
    text.split('\n').forEach((line, i) => {
      if (BANNED.test(line)) violations.push(`${path}:${i + 1}: ${line.trim()}`);
    });
  }
  return violations;
}

if (process.argv.includes('--selftest')) {
  // The checker must flag a violation and must leave a non-stat read alone.
  const dirty = scan(new Map([
    ['scripts/combat/sample.gd', 'var d := tuning.light_damage\nvar h := tuning.hitstop_frames'],
  ]));
  const clean = scan(new Map([
    ['scripts/combat/player_stats.gd', 'var d := tuning.light_damage'],
  ]));
  const ok = dirty.length === 1 && clean.length === 0;
  console.log(`selftest ${ok ? 'PASS' : 'FAIL'} violations=${dirty.length} allowed_hit=${clean.length}`);
  process.exit(ok ? 0 : 1);
}

const files = walk('scripts');
const violations = scan(new Map(files.map((p) => [p.split('\\').join('/'), readFileSync(p, 'utf8')])));
if (violations.length > 0) {
  for (const v of violations) console.error(v);
  console.error(`stat-source violations: ${violations.length}`);
  process.exit(1);
}
console.log(`stat-source clean: ${files.length} scripts`);
```

- [ ] **Step 6: Run the law check and regressions**

```bash
node tools/check_stat_source.mjs            # expect: stat-source clean
node tools/check_stat_source.mjs --selftest # expect: selftest PASS, exit 0
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://tests/test_combat_kernel.gd
"$GODOT" --headless --path . -s res://tests/test_tempo_fatigue.gd
"$GODOT" --headless --path . res://scenes/phase_c/grove_arena.tscn --quit-after 120
node tools/run_evidence.mjs
```

Expected: law clean; kernel 107 checks PASS; tempo PASS; L2 exit 0; E1–E5 `failures=0`.

- [ ] **Step 7: Commit**

```bash
git add scripts/combat/player_combat.gd scripts/phase_a/player_controller.gd \
  tools/check_stat_source.mjs docs/phase-d/UI_PROGRESSION_SPEC.md
git commit -m "feat(T-029): route player stats through PlayerStats only"
```

---

### Task 3: m5x7 font + code-generated theme + coverage gate

**Files:**
- Create: `assets/ui/fonts/m5x7.ttf`, `assets/ASSET_LOG.md`
- Create: `scripts/ui/ui_copy.gd`, `scripts/ui/hd2d_theme.gd`
- Test: `tests/test_theme.gd`, `tests/test_font_coverage.gd`

**Interfaces:**
- Produces: `class_name Hd2dTheme extends RefCounted` with consts `PANEL`, `BORDER`, `ACCENT`, `TEXT`, `COST`, `FONT_PATH`, `UI_FONT_SIZE` (14), `SHEET_SIZE` (Vector2i(480, 320)), `CARD_SIZE` (Vector2i(160, 220)) and `static func build() -> Theme`.
- Produces: `class_name UiCopy extends RefCounted` — all UI strings as consts (sheet copy now; T-030/031 append).

- [ ] **Step 1: Obtain the font (external download — ask if blocked)**

Use WebFetch on `https://managore.itch.io/m5x7` to find the download URL, then:

```bash
mkdir -p assets/ui/fonts
curl -L -o assets/ui/fonts/m5x7.ttf "<URL from the author page>"
sha256sum assets/ui/fonts/m5x7.ttf
```

If itch.io requires a browser session, stop and ask the user to place `m5x7.ttf` at that path manually. Do not substitute another font.

- [ ] **Step 2: Record provenance**

`assets/ASSET_LOG.md`:

```markdown
# ASSET LOG

| Ngày | Asset | Nguồn | Công cụ | Giấy phép |
|---|---|---|---|---|
| 2026-11-21 | `assets/ui/fonts/m5x7.ttf` | Daniel Linssen — https://managore.itch.io/m5x7 | tải trực tiếp (sha256 ghi kèm khi tải) | Public domain (tác giả công bố dùng tự do; xác nhận trên trang nguồn) |
```

Append the actual sha256 to the row when downloaded.

- [ ] **Step 3: Write the failing font coverage test**

`tests/test_font_coverage.gd`:

```gdscript
extends SceneTree

## T-029: every glyph the UI can draw must exist in the shipped pixel font.
## Missing diacritics would render tofu boxes in play; only a machine check
## keeps that from shipping silently.

const FONT_PATH := "res://assets/ui/fonts/m5x7.ttf"
const CONTROL_CHAR := 0x4E00  # CJK ideograph: must be absent from m5x7

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var negative := OS.get_cmdline_user_args().has("negative")
	var font := FontFile.new()
	_check(font.load_dynamic_font(FONT_PATH) == OK, "font file loads")
	var copy: Dictionary = (load("res://scripts/ui/ui_copy.gd") as GDScript).get_script_constant_map()
	var seen := {}
	var missing: Array[String] = []
	for value in copy.values():
		if typeof(value) != TYPE_STRING:
			continue
		var text := value as String
		for i in text.length():
			var code := text.unicode_at(i)
			if code <= 32 or seen.has(code):
				continue
			seen[code] = true
			if not font.has_char(code):
				missing.append("%s(U+%04X)" % [String.chr(code), code])
	_check(missing.is_empty(), "every UI glyph renders (missing: %s)" % [missing])
	# Control: the detector must be able to report a missing glyph.
	_check(font.has_char(CONTROL_CHAR) == negative,
		"control: coverage detector alive (has CJK = %s, expected %s)"
		% [font.has_char(CONTROL_CHAR), negative])
	if _failures == 0:
		print("PASS test_font_coverage: %d checks, %d glyphs" % [_checks, seen.size()])
		quit(0)
	else:
		print("FAIL test_font_coverage: %d/%d checks failed (missing: %s)"
			% [_failures, _checks, missing])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
```

- [ ] **Step 4: Run it — expect missing glyphs on real Vietnamese copy**

Create `scripts/ui/ui_copy.gd` first with the sheet strings (Step 5 content), then:

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://tests/test_font_coverage.gd`
Expected: either PASS (font covers Vietnamese — proceed) or FAIL listing specific `U+XXXX` codes. **If FAIL: stop and report the list to the user** — do not swap fonts or silently strip diacritics (spec §7 requires a decision).

- [ ] **Step 5: Write `scripts/ui/ui_copy.gd` and `scripts/ui/hd2d_theme.gd`**

`ui_copy.gd`:

```gdscript
class_name UiCopy
extends RefCounted

## Every user-facing UI string lives here so the font coverage test can check
## each glyph the game may draw. T-030/T-031 append; nothing else hardcodes copy.

const SHEET_TITLE := "TRẠNG THÁI NHÂN VẬT"
const SHEET_HP := "MÁU"
const SHEET_DAMAGE := "SÁT THƯƠNG"
const SHEET_CYCLE := "CHU KỲ ĐÒN"
const SHEET_REACH := "TẦM VỚI"
const SHEET_COMBO := "COMBO"
const SHEET_DODGE := "NÉ"
const SHEET_FATIGUE := "MỆT NHỊP"
const SHEET_BUFFS := "BUFF ĐANG MANG"
const SHEET_NONE := "CHƯA CÓ BUFF"
const SHEET_WAVE := "WAVE"
const SHEET_CLOSE := "ĐÓNG"
const HUD_PLAYER := "PLAYER"
const HUD_WAVE := "WAVE"
const HUD_ENEMIES := "ENEMIES"
const HUD_FIGHT := "ĐANG ĐÁNH"
const HUD_NEXT := "WAVE TIẾP THEO"
const HUD_WIN := "THẮNG — R chơi lại"
const HUD_LOSE := "THUA — R chơi lại"
const HUD_GATE_OPEN := "CỔNG MỞ — SHRINE PHÍA BẮC"
const HUD_GATE_HEALED := "CỔNG MỞ — ĐÃ HỘI MÁU"
```

`hd2d_theme.gd`:

```gdscript
class_name Hd2dTheme
extends RefCounted

## T-029: code-generated HD-2D UI theme. No downloaded frames; StyleBoxFlat on
## a 4 px grid keeps the pixel discipline while the font carries the character.

const PANEL := Color("#12161c")
const BORDER := Color("#2c3542")
const ACCENT := Color("#d9b26a")
const TEXT := Color("#e8e4da")
const COST := Color("#c0695a")
const FONT_PATH := "res://assets/ui/fonts/m5x7.ttf"
const UI_FONT_SIZE := 14  # 2x the 7 px glyph height of m5x7
const SHEET_SIZE := Vector2i(480, 320)
const CARD_SIZE := Vector2i(160, 220)
const GAP := 16


static func build() -> Theme:
	var theme := Theme.new()
	var font := FontFile.new()
	if font.load_dynamic_font(FONT_PATH) == OK:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.hinting = TextServer.HINTING_NONE
		theme.default_font = font
	theme.default_font_size = UI_FONT_SIZE

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = BORDER
	panel.set_border_width_all(2)
	panel.set_content_margin_all(GAP)
	panel.anti_aliasing = false
	theme.set_stylebox(&"panel", &"PanelContainer", panel)

	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_color(&"font_color", &"Button", TEXT)
	theme.set_color(&"font_focus_color", &"Button", ACCENT)
	theme.set_color(&"font_hover_color", &"Button", ACCENT)

	var button := StyleBoxFlat.new()
	button.bg_color = PANEL
	button.border_color = BORDER
	button.set_border_width_all(2)
	button.set_content_margin_all(8)
	button.anti_aliasing = false
	theme.set_stylebox(&"normal", &"Button", button)
	var focus := button.duplicate() as StyleBoxFlat
	focus.border_color = ACCENT
	theme.set_stylebox(&"focus", &"Button", focus)
	return theme
```

- [ ] **Step 6: Write and run `tests/test_theme.gd`**

```gdscript
extends SceneTree

## T-029: the theme is the only style source; geometry obeys the grid laws.

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var theme := Hd2dTheme.build()
	_check(theme != null, "theme builds")
	_check(theme.default_font != null, "theme carries the pixel font")
	_check(theme.default_font_size % 7 == 0, "font size is a multiple of the 7 px glyph height")
	_check(Hd2dTheme.SHEET_SIZE.x % 4 == 0 and Hd2dTheme.SHEET_SIZE.y % 4 == 0,
		"sheet geometry sits on the 4 px grid")
	_check(Hd2dTheme.CARD_SIZE.x % 4 == 0 and Hd2dTheme.CARD_SIZE.y % 4 == 0,
		"card geometry sits on the 4 px grid")
	var panel := theme.get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	_check(panel != null and panel.bg_color == Hd2dTheme.PANEL, "panel stylebox uses the palette")
	_check(Hd2dTheme.ACCENT == Color("#d9b26a"), "accent is the approved gold")
	_check(Hd2dTheme.COST != Color("#d94a4a"), "cost red stays distinct from telegraph red")
	if _failures == 0:
		print("PASS test_theme: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_theme: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
```

Run:
```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://tests/test_theme.gd          # PASS, exit 0
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd  # PASS, exit 0
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd -- negative  # exit 1
```

- [ ] **Step 7: Commit**

```bash
git add assets/ASSET_LOG.md assets/ui/fonts/m5x7.ttf assets/ui/fonts/m5x7.ttf.import \
  scripts/ui/ui_copy.gd scripts/ui/ui_copy.gd.uid \
  scripts/ui/hd2d_theme.gd scripts/ui/hd2d_theme.gd.uid \
  tests/test_theme.gd tests/test_theme.gd.uid \
  tests/test_font_coverage.gd tests/test_font_coverage.gd.uid
git commit -m "feat(T-029): add m5x7 theme with a glyph coverage gate"
```

---

### Task 4: `CharacterSheet` + InputMap action + pause test

**Files:**
- Modify: `project.godot` ([input] section)
- Create: `scripts/ui/character_sheet.gd`
- Test: `tests/test_character_sheet.gd`

**Interfaces:**
- Consumes: `PlayerStats` (Task 1/2), `Hd2dTheme`, `UiCopy`.
- Produces: `class_name CharacterSheet extends CanvasLayer`; `set_sources(stats: PlayerStats, hp_source: Callable, encounter: WaveEncounter = null)`; `open()`, `close()`, `refresh()`, `is_open() -> bool`, `body_text() -> String`.

- [ ] **Step 1: Add the InputMap action**

Insert immediately after the `[input]` line in `project.godot` (code `4194305` = Escape):

```
toggle_character_sheet={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

Verify: `grep -A1 "toggle_character_sheet" project.godot` shows the block; `--import` exit 0.

- [ ] **Step 2: Write the failing test**

`tests/test_character_sheet.gd`:

```gdscript
extends SceneTree

## T-029: ESC pauses the world, and the sheet shows the same numbers the combat
## code uses (no hand-written constants). It must also stay closed and
## non-pausing until asked, so headless drivers are never suspended.

var _checks: int = 0
var _failures: int = 0
var _negative: bool = false


func _initialize() -> void:
	_negative = OS.get_cmdline_user_args().has("negative")
	await _run()
	_finish()


func _run() -> void:
	var stats := PlayerStats.new(CombatTuning.new())
	var sheet := CharacterSheet.new()
	root.add_child(sheet)
	await process_frame
	sheet.set_sources(stats, func() -> int: return 77, null)
	_check(not paused and not sheet.visible,
		"the sheet starts closed and the game keeps running")

	sheet.open()
	_check(paused == (not _negative), "opening pauses the world")
	_check(sheet.body_text().contains("77/100"), "hp row reads current and effective max")
	_check(sheet.body_text().contains("10"), "damage row reads the effective damage")
	stats.add_modifier(&"heavy_edge", {&"light_damage_mult": 1.3})
	sheet.refresh()
	_check(sheet.body_text().contains("13"), "damage row follows a buff instead of a constant")
	sheet.close()
	_check(not paused and not sheet.visible, "closing releases the pause")

	await _press_escape()
	_check(paused and sheet.visible, "Escape through InputMap opens the sheet")
	await _press_escape()
	_check(not paused and not sheet.visible, "Escape again closes it")
	sheet.queue_free()
	await process_frame


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
		print("PASS test_character_sheet: %d checks" % _checks)
		quit(0)
	else:
		print("FAIL test_character_sheet: %d/%d checks failed" % [_failures, _checks])
		quit(1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)
```

- [ ] **Step 3: Run to verify it fails**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://tests/test_character_sheet.gd`
Expected: parse error — `CharacterSheet` not found.

- [ ] **Step 4: Implement `scripts/ui/character_sheet.gd`**

```gdscript
class_name CharacterSheet
extends CanvasLayer

## T-029: ESC opens a paused character sheet. Every number is read from
## PlayerStats/WaveEncounter, so the panel cannot claim a value combat does not
## use. Nodes are built in code so the theme stays the single style source.

@export var combat_path: NodePath = NodePath("../Player/PlayerCombat")
@export var encounter_path: NodePath = NodePath("../WaveEncounter")

var _stats: PlayerStats
var _hp_source: Callable = Callable()
var _encounter: WaveEncounter
var _open := false

var _panel: PanelContainer
var _rows: Dictionary = {}
var _buffs: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build_ui()
	visible = false
	var combat := get_node_or_null(combat_path) as PlayerCombat
	if combat != null and combat.stats != null:
		var hp := combat.health
		set_sources(combat.stats, func() -> int: return hp.hp,
			get_node_or_null(encounter_path) as WaveEncounter)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_character_sheet"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func set_sources(stats: PlayerStats, hp_source: Callable, encounter: WaveEncounter = null) -> void:
	_stats = stats
	_hp_source = hp_source
	_encounter = encounter
	if _open:
		refresh()


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	refresh()
	get_tree().paused = true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false


func refresh() -> void:
	if _stats == null:
		return
	_rows[&"hp"].text = "%d/%d" % [_current_hp(), _stats.player_max_hp()]
	var cycle := _stats.light_startup_frames() + _stats.light_active_frames() \
		+ _stats.light_recovery_frames()
	_rows[&"damage"].text = "%d  (%.2f dmg/tick)" % [
		_stats.light_damage(), float(_stats.light_damage()) / float(maxi(cycle, 1))]
	_rows[&"cycle"].text = "%d + %d + %d = %d tick" % [
		_stats.light_startup_frames(), _stats.light_active_frames(),
		_stats.light_recovery_frames(), cycle]
	_rows[&"reach"].text = "%.1f m" % _stats.light_reach()
	_rows[&"combo"].text = "%d đòn / cửa sổ %d tick" % [
		_stats.light_combo_hits(), _stats.combo_window_frames()]
	_rows[&"dodge"].text = "%.1f m/s · %d tick · i-frame %d" % [
		_stats.dodge_speed(), _stats.dodge_total_frames(), _stats.dodge_iframe_frames()]
	_rows[&"fatigue"].text = "free %d · +%d tick · trần %d · decay %d" % [
		_stats.fatigue_free_swings(), _stats.fatigue_step_frames(),
		_stats.fatigue_max_frames(), _stats.fatigue_decay_frames()]
	var mods := _stats.active_modifiers()
	if mods.is_empty():
		_buffs.text = UiCopy.SHEET_NONE
	else:
		var names: Array[String] = []
		for entry in mods:
			names.append(str(entry["source"]))
		_buffs.text = ", ".join(names)


func body_text() -> String:
	var parts: Array[String] = []
	for value in _rows.values():
		parts.append((value as Label).text)
	if _buffs != null:
		parts.append(_buffs.text)
	return "\n".join(parts)


func _current_hp() -> int:
	if _hp_source.is_valid():
		return int(_hp_source.call())
	return _stats.player_max_hp()


func _build_ui() -> void:
	theme = Hd2dTheme.build()
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(Hd2dTheme.SHEET_SIZE)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", Hd2dTheme.GAP / 2)
	_panel.add_child(column)

	var title := Label.new()
	title.text = UiCopy.SHEET_TITLE
	title.add_theme_color_override(&"font_color", Hd2dTheme.ACCENT)
	title.add_theme_font_size_override(&"font_size", Hd2dTheme.UI_FONT_SIZE + 7)
	column.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", Hd2dTheme.GAP)
	column.add_child(grid)
	_add_row(grid, &"hp", UiCopy.SHEET_HP)
	_add_row(grid, &"damage", UiCopy.SHEET_DAMAGE)
	_add_row(grid, &"cycle", UiCopy.SHEET_CYCLE)
	_add_row(grid, &"reach", UiCopy.SHEET_REACH)
	_add_row(grid, &"combo", UiCopy.SHEET_COMBO)
	_add_row(grid, &"dodge", UiCopy.SHEET_DODGE)
	_add_row(grid, &"fatigue", UiCopy.SHEET_FATIGUE)

	var buff_title := Label.new()
	buff_title.text = UiCopy.SHEET_BUFFS
	buff_title.add_theme_color_override(&"font_color", Hd2dTheme.ACCENT)
	column.add_child(buff_title)
	_buffs = Label.new()
	_buffs.text = UiCopy.SHEET_NONE
	column.add_child(_buffs)

	var close_button := Button.new()
	close_button.text = UiCopy.SHEET_CLOSE
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _add_row(grid: GridContainer, key: StringName, label_text: String) -> void:
	var name_label := Label.new()
	name_label.text = label_text
	grid.add_child(name_label)
	var value := Label.new()
	value.text = "-"
	grid.add_child(value)
	_rows[key] = value
```

- [ ] **Step 5: Run tests**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://tests/test_character_sheet.gd`
Expected: `PASS test_character_sheet: 8 checks`, exit 0.
Run with `-- negative`: exit 1.
**If `Escape through InputMap` fails** (push_input not reaching `_unhandled_input` while paused): replace `_press_escape` with `Input.action_press(&"toggle_character_sheet")` + `Input.action_release(...)` around a `process_frame`, run again, and note the swap in the commit body. Do not weaken the assertion.

- [ ] **Step 6: Commit**

```bash
git add project.godot scripts/ui/character_sheet.gd scripts/ui/character_sheet.gd.uid \
  tests/test_character_sheet.gd tests/test_character_sheet.gd.uid
git commit -m "feat(T-029): add the paused ESC character sheet"
```

---

### Task 5: Mount in arena, L3 evidence, docs, full regression, push

**Files:**
- Modify: `scenes/phase_c/grove_arena.tscn`
- Create: `scenes/ui/capture_sheet.tscn`, `scripts/ui/capture_sheet.gd`
- Modify: `docs/DECISIONS.md`, `docs/STATE.md`
- Create evidence dir: `docs/phase-d/evidence/t029/`

**Interfaces:**
- Consumes: everything above; `capture_title.gd` patterns (frame_post_draw settle, lit-pixel guard, band diff, negative control).

- [ ] **Step 1: Mount the sheet**

In `scenes/phase_c/grove_arena.tscn` add to the ext_resource list:

```
[ext_resource type="Script" path="res://scripts/ui/character_sheet.gd" id="18_sheet"]
```

and after the `WaveHUD` node block:

```
[node name="CharacterSheet" type="CanvasLayer" parent="."]
script = ExtResource("18_sheet")
```

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . res://scenes/phase_c/grove_arena.tscn --quit-after 120`
Expected: exit 0, no script errors, sheet closed (game does not pause).

- [ ] **Step 2: Create the capture scene and driver**

`scenes/ui/capture_sheet.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://scenes/phase_c/grove_arena.tscn" id="1_arena"]
[ext_resource type="Script" path="res://scripts/ui/capture_sheet.gd" id="2_drv"]

[node name="CaptureSheet" type="Node"]

[node name="GroveArena" parent="." instance=ExtResource("1_arena")]

[node name="CaptureSheetDriver" type="Node" parent="."]
script = ExtResource("2_drv")
```

`scripts/ui/capture_sheet.gd` (mirror of `capture_title.gd`):

```gdscript
extends Node

## T-029 visual proof: the sheet must really render (lit-pixel guard) and the
## open pose must differ from the closed one inside the panel band only.
##   <GODOT> --path . res://scenes/ui/capture_sheet.tscn --fixed-fps 60
##   ... -- negative   same pose twice: control must report 0 px

const EVIDENCE_DIR := "res://docs/phase-d/evidence/t029/"
const PANEL_BAND := Rect2(0.30, 0.27, 0.40, 0.46)
const PANEL_MIN_DIFF := 40
const LIT_MIN_PIXELS := 500

var _shots: Array = []
var _checks := 0
var _failures := 0


func _ready() -> void:
	# The wave must not start: player spawn sits inside the trigger radius.
	var arena := get_node("../GroveArena")
	arena.get_node("WaveEncounter").set_physics_process(false)
	_capture.call_deferred()


func _capture() -> void:
	await _settle()
	var negative := OS.get_cmdline_user_args().has("negative")
	_shots.append(_grab("sheet_closed"))
	if negative:
		_shots.append(_grab("sheet_control"))
	else:
		await _press_escape()
		_shots.append(_grab("sheet_open"))
	_report(negative)


func _settle() -> void:
	for _i in 3:
		await RenderingServer.frame_post_draw


func _press_escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _grab(label: String) -> Image:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(EVIDENCE_DIR + "%s.png" % label)
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
	var from := Vector2i(int(PANEL_BAND.position.x * w), int(PANEL_BAND.position.y * h))
	var to := Vector2i(int((PANEL_BAND.position.x + PANEL_BAND.size.x) * w),
		int((PANEL_BAND.position.y + PANEL_BAND.size.y) * h))
	var changed := 0
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				changed += 1
	return changed


func _report(negative: bool) -> void:
	_check(_shots.size() == 2 and _shots[0] != null and _shots[1] != null,
		"P29.1 both frames captured")
	if _shots.size() < 2:
		print("checks=%d failures=%d" % [_checks, _failures])
		print("FAIL t029_sheet_capture")
		get_tree().quit(1)
		return
	var lit := [_lit_pixels(_shots[0]), _lit_pixels(_shots[1])]
	_check(lit[0] >= LIT_MIN_PIXELS and lit[1] >= LIT_MIN_PIXELS,
		"P29.2 the arena really rendered, not a black frame (lit px %d / %d)" % lit)
	var diff := _band_diff(_shots[0], _shots[1])
	if negative:
		_check(diff == 0,
			"P29.3 control: one pose twice changes 0 px in the panel band (got %d)" % diff)
	else:
		_check(diff >= PANEL_MIN_DIFF,
			"P29.3 the sheet open/closed differs (%d px in the panel band, need >= %d)"
			% [diff, PANEL_MIN_DIFF])
	print("checks=%d failures=%d band_diff=%d lit=%s" % [_checks, _failures, diff, lit])
	print("%s t029_sheet_capture%s" % ["PASS" if _failures == 0 else "FAIL",
		" (control)" if negative else ""])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("CHECK PASS %s" % label)
		return
	_failures += 1
	print("CHECK FAIL %s" % label)
```

- [ ] **Step 3: Capture and *look at* the images**

```bash
mkdir -p docs/phase-d/evidence/t029
"$GODOT" --path . res://scenes/ui/capture_sheet.tscn --fixed-fps 60 --resolution 1280x720
"$GODOT" --path . res://scenes/ui/capture_sheet.tscn --fixed-fps 60 --resolution 1280x720 -- negative
```

Expected: positive `checks=3 failures=0 band_diff>=40`; negative `band_diff=0`.
Then **open all three PNGs with the Read tool and actually look at them** (layout, font crispness, palette). If the sheet is ugly or clipped, iterate on layout constants and re-capture before claiming anything.

- [ ] **Step 4: Write D-021…D-024 into `docs/DECISIONS.md`**

Prepend after the file header, in the existing style (each entry: Decision / Reason / Bằng chứng / Rủi ro / Không đổi / Xác nhận của user):

- **D-021 · Phase D mở với UI/progression trước MVS field** — reason: throughput là nút thắt đã đo (D-018); buff damage là đòn bẩy trực tiếp; MVS-AC1…8 vẫn PROPOSED. User chọn "Mở Phase D, T-029..T-031" (chat, 2026-11-21).
- **D-022 · `PlayerStats` là nguồn runtime duy nhất** — base `combat_tuning.tres` (immutable), composition add-then-mult, floor, clamp ≥1; luật máy kiểm `tools/check_stat_source.mjs` + `--selftest`. User chọn "A — PlayerStats thuần".
- **D-023 · Buff model** — pool data 6 món, `BuffKernel` seed được, mỗi món 1 lần/run, 2 lần chọn/run (chỉ khi wave kết thúc không phải wave cuối), reset khi R/thua. User chọn "Số học + đánh đổi", "Reset khi R/thua", "Chặn + dừng world".
- **D-024 · UI layer** — Theme code-gen (`Hd2dTheme`), font m5x7 public domain (ASSET_LOG), cỡ chữ bội số 7, hình học bội số 4, coverage gate + negative control. User chọn "Code-gen + Godot Theme", "m5x7".

Each entry records the gate evidence from Steps 1–3 and Task 1–4 test counts (fill in the real numbers actually observed — never invented).

- [ ] **Step 5: Update `docs/STATE.md`**

- Mục "Phase hiện tại": thêm Phase D đang mở, T-029 DONE với số đo thật (checks, band_diff, exit codes).
- "Đang làm": T-031 kế tiếp.
- "DONE gần đây": thêm T-029 (giữ ≤5 mục).
- "Known issues": thêm "số buff/DPS là HYPOTHESIS — L4 quyết định" nếu chưa có; ghi nợ "toggle số sát thương chưa có (T-031)".
- Giữ file ≤150 dòng.

- [ ] **Step 6: Full regression**

```bash
"$GODOT" --headless --path . --import
node tools/check_stat_source.mjs
node tools/check_stat_source.mjs --selftest
node tools/run_evidence.mjs
for t in tests/test_*.gd; do "$GODOT" --headless --path . -s "res://$t"; done
"$GODOT" --headless --path . res://scenes/phase_c/grove_arena.tscn --quit-after 120
"$GODOT" --headless --path . res://scenes/ui/capture_title.tscn --quit-after 5   # sanity: title still loads
```

Expected: every exit 0; `run_evidence` prints `failures=0`; zero `SCRIPT ERROR` in stderr.

- [ ] **Step 7: Commit and push**

```bash
git add scenes/phase_c/grove_arena.tscn scenes/ui/capture_sheet.tscn \
  scripts/ui/capture_sheet.gd scripts/ui/capture_sheet.gd.uid \
  docs/phase-d/evidence/t029 docs/DECISIONS.md docs/STATE.md
git commit -m "feat(T-029): mount the sheet in the arena with L3 evidence"
git push -u origin phase-d/t029-player-stats-sheet
```

---

## Self-Review (run before handing off)

1. **Spec coverage:** §3.1 PlayerStats → Task 1; §3.2 laws + machine check → Task 2; §3.3 integration table → Task 2 (+ spec row sync); §5 sheet/ESC/pause/focus → Task 4; §7 theme/font/palette/coverage → Task 3; §8 DG1/DG2/DG3(partial)/DG4 → Tasks 1–5; damage-number toggle and DG3/DG5 belong to T-031/T-030 plans.
2. **Placeholder scan:** only external unknown is the font URL (Step 1 has a stop-and-ask path); DECISIONS entries require filling observed numbers, not invented ones.
3. **Type consistency:** `PlayerStats` getter names are used identically in `player_combat.gd`, `character_sheet.gd`, and both tests; `Hd2dTheme.SHEET_SIZE/CARD_SIZE/UI_FONT_SIZE/GAP` referenced consistently; `set_sources(stats, hp_source: Callable, encounter)` matches the test call shape.
