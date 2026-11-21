# Task 3 Report — BuffChoice modal + sheet integration

**Status:** DONE
**Commit:** `c0263b8` — `feat(T-030): add the buff chooser and sheet hooks`
**Branch:** `phase-d/t030-wave-buff-choice` (stacked on `92ec838`)

## Files

| File | Action |
|---|---|
| `scripts/ui/buff_choice.gd` (+`.uid`) | created — CanvasLayer modal, opt-in on mount, auto_pick, stagger |
| `scripts/ui/character_sheet.gd` | modified — ESC suppression in BUFF_PENDING, pool titles, wave + seed rows |
| `scripts/ui/ui_copy.gd` | modified — `SHEET_SEED` |
| `scripts/phase_c/wave_encounter.gd` | modified — `debug_force_buff_pending()` |
| `tests/test_buff_choice.gd` (+`.uid`) | created — 16 checks + negative control |

7 files staged (+381/−1). `grove_arena.tscn` untouched. Pre-existing dirty files
(`assets/ui/fonts/vt323.ttf.import`, `docs/phase-c/evidence/t023/*`, untracked
`t027/session5/`) left untouched and unstaged.

## TDD RED

`<GODOT> --headless --path . -s res://tests/test_buff_choice.gd`

```
SCRIPT ERROR: Parse Error: Identifier "BuffChoice" not declared in the current scope.
   at: GDScript::reload (res://tests/test_buff_choice.gd:29)
SCRIPT ERROR: Parse Error: Cannot infer the type of "choice" variable because the value doesn't have a set type.
SCRIPT ERROR: Parse Error: Identifier "BuffChoice" not declared in the current scope.
   at: GDScript::reload (res://tests/test_buff_choice.gd:78)
ERROR: Failed to load script "res://tests/test_buff_choice.gd" with error "Parse error".
```

Exit: **1**.

## TDD GREEN

`<GODOT> --headless --path . -s res://tests/test_buff_choice.gd`

```
1,buff,buff_seed,0,0,635280
1,encounter,wave_start,0,0,1
14,buff,buff_pick,0,0,4
15,buff,buff_pick,0,0,3
PASS test_buff_choice: 16 checks
```

Exit: **0**.

Negative (`... -s res://tests/test_buff_choice.gd -- negative`):

```
FAIL: presenting the offer pauses the world
12,buff,buff_pick,0,0,4
FAIL: the pick landed on PlayerStats exactly once
14,buff,buff_pick,0,0,3
FAIL: auto pick applies the first card through the encounter
FAIL test_buff_choice: 3/16 checks failed
```

Exit: **1** — intended inversions only.

Note: the first green attempt failed 1/10 because the test's signal-capture
lambda reassigned a local (`emitted = offers`), which GDScript captures by
value. Fixed in the test by mutating the array (`emitted.append_array`); product
code was not involved.

## Mounting approach (ruling 2)

`arena.add_child(choice)` with `choice.encounter_path = NodePath("../WaveEncounter")`
set before `add_child`. The default NodePath resolution in `_ready` is exercised
for real; **no `set_encounter()` seam was added or needed**. After adding the
arena the test awaits `physics_frame` + one `process_frame` (the `physics_frame`
signal fires before `_physics_process`, so the extra frame is what guarantees
`_start_run()` built `buff`), then calls `encounter.debug_force_buff_pending()`.
`present()` is never called directly by the test: the cards are filled from the
emitted `buff_offer` (captured by a one-shot connection), and the offer title is
asserted on each card.

## Controller rulings applied

1. `debug_force_buff_pending()` lives on `WaveEncounter`: guards `buff == null`
   with `push_error` + return, otherwise sets `kernel.state = BUFF_PENDING`,
   `_offer_emitted = true`, emits `buff_offer(buff.offer())`.
2. Arena child mounting via `../WaveEncounter`; no fallback seam.
3. `encounter_path` set before `add_child`; BuffChoice never added to the root.
4. Card content asserted from the emitted offer; `present()` not exercised directly.
5. Sheet rows are null-safe (`SHEET_PLACEHOLDER` when encounter/kernel null);
   buff ids map through `BuffPool.pool()` titles with raw-id fallback; wave row
   is `UiCopy.HUD_WAVE_PROGRESS % [wave_index + 1, wave_count()]`; seed row is
   `str(buff_seed())`; `SHEET_SEED := "SEED"` added.
6. ESC suppressed only when `_encounter != null and _encounter.kernel != null and
   state == BUFF_PENDING`; `test_character_sheet` (null encounter) stays green.
7. Three 160×220 `Button`s in an `HBoxContainer`; internal VBox of title
   (ACCENT) / gain (TEXT) / cost (COST) labels, all `MOUSE_FILTER_IGNORE`;
   card 0 focused on open; panel is a themed `PanelContainer` centered with
   half-size anchors (544×360: 3·160 + 4·16 wide, title 32 + wave 16 + cards
   220 + hint 16 + 3·8 separations + 32 margins tall); stagger 0.05 s × i,
   0.12 s ease-out scale 0.9→1 + fade, tween `TWEEN_PAUSE_PROCESS`.
8. `auto_pick` applies `offers[0]["id"]` on the signal with no pause and no UI.
9. `present()` fills cards → visible → pause → focus; `_pick()` applies via
   `encounter.apply_buff` then closes + unpauses; a false return leaves the
   panel open.
10. Font coverage passes; no missing glyphs.

## Validation

| Gate | Result |
|---|---|
| `--import` | exit 0 |
| L1 `--check-only` (buff_choice, character_sheet, ui_copy, wave_encounter, test_buff_choice) | all exit 0 |
| `test_buff_choice` / `-- negative` | PASS 16 checks exit 0 / exit 1 |
| `test_character_sheet` (null encounter) | PASS 8 checks exit 0 |
| `test_wave_kernel` | PASS 21 checks exit 0 |
| `test_buff_kernel` | PASS 17 checks exit 0 |
| `test_theme` | PASS 13 checks exit 0 |
| `test_stats_live` | PASS 18 checks exit 0 |
| `test_font_coverage` / `-- negative` | PASS 3 checks, 97 glyphs, 0 missing, exit 0 / exit 1 |
| `node tools/check_stat_source.mjs` | `stat-source clean: 75 scripts`, exit 0 |
| `node tools/check_stat_source.mjs --selftest` | `selftest PASS violations=1 allowed_hit=0`, exit 0 |
| L2 `grove_arena.tscn --quit-after 120` | exit 0 (flag stays false; log reaches `wave_start`) |

### Layout probe (scratch script, deleted before commit)

- `BuffChoice` panel: authored 544×360, combined min 544×360 — no growth,
  cards 160×220, text stack 144×204, card 0 text:
  `RÌU SÉT / LỢI SÁT THƯƠNG +30% / ĐỔI LẠI HỒI ĐÒN +3 TICK`.
- `CharacterSheet`: 9-row grid raises the panel to 480×349 against the authored
  `SHEET_SIZE` 480×320 (pre-T-030 content fit). PanelContainer grows, nothing is
  clipped, but the rect extends 29 px below the centered 320 box.

## Concerns

1. **Sheet height vs spec §7 (480×320):** the two new rows need 349 px. The
   `SHEET_SIZE` const was deliberately not changed (approved spec geometry, no
   ruling to resize); the sheet now grows 29 px downward. Needs a Task 5 doc/spec
   decision (or an L3 look) before it is called finished.
2. **Pause is a single boolean, not a stack.** Closing the chooser unpauses
   unconditionally; the same limitation exists on the sheet and is already on the
   plan's known-issues list.
3. **Keyboard accept path untested:** card focus is grabbed and Buttons use the
   built-in `ui_accept`, but the test only exercises `debug_pick`; no Enter/Space
   synthetic press is asserted.
4. **`auto_pick` ignores `apply_buff()` false** (offer always valid today), which
   mirrors the Task 2 deferred note about the auto-pick gap.
5. The stagger tween runs while the tree is paused via `TWEEN_PAUSE_PROCESS`;
   L3 motion was not captured in this task (Task 4 owns the capture).

---

## Review fix — truthful 480×352 (controller ruling: option a)

**Status:** DONE
**Commit:** `f0c3e9e` — `fix(T-030): make the sheet panel a truthful 480x352`
**Branch:** `phase-d/t030-wave-buff-choice` (stacked on `c0263b8`)

### What changed

| File | Change |
|---|---|
| `scripts/ui/hd2d_theme.gd` | `SHEET_SIZE` `Vector2i(480, 320)` → `Vector2i(480, 352)` (352 is on the 4 px grid); no other const touched |
| `docs/phase-d/UI_PROGRESSION_SPEC.md` §7 | geometry sentence 480×320 → 480×352 plus one clause: the sheet box grows with content and stays on the 4 px grid (T-030 added wave/seed rows) |

`character_sheet.gd` was not modified: it reads `SHEET_SIZE` for both
`custom_minimum_size` and the half-size anchor offsets, so the panel now
measures exactly 480×352 instead of growing from a 320 box. `grove_arena.tscn`,
`buff_choice.gd` and the card sizes are untouched. Pre-existing dirty files
(`assets/ui/fonts/vt323.ttf.import`, `docs/phase-c/evidence/t023/*`, untracked
`t027/session5/`) left unstaged.

### Geometry probe (scratch `tests/_probe_sheet_geometry.gd`, deleted before commit)

The headless root window is a fixed 64×64 regardless of `root.size` or
`--resolution`, so the sheet was mounted in a `SubViewport` sized 1280×720 to
give the anchors a real 720p canvas. Measured output:

```
viewport=(1280.0, 720.0)
custom_minimum_size=(480.0, 352.0)
combined_minimum_size=(480.0, 352.0)
panel_size=(480.0, 352.0)
panel_rect=[P: (400.0, 184.0), S: (480.0, 352.0)]
center_offset=(0.0, 0.0)
SHEET_SIZE=(480, 352)
```

Content no longer exceeds the authored box (combined min == custom min), and
the panel rect center equals the 1280×720 viewport center — offset 0 px, down
from the 14.5 px downward drift reported in review. No capture driver edited.
This is a headless layout probe only; L3 visual proof remains Task 4.

### Commands and results

| Command | Result |
|---|---|
| `<GODOT> --headless --path . --import` | exit **0** |
| `-s res://tests/test_theme.gd` | PASS 13 checks, exit **0** (grid law holds for 352) |
| `-s res://tests/test_character_sheet.gd` | PASS 8 checks, exit **0** |
| `-s res://tests/test_buff_choice.gd` | PASS 16 checks, exit **0** |
| `-s res://tests/test_buff_choice.gd -- negative` | 3 intended failures, exit **1** |
| `<GODOT> --headless --path . res://scenes/phase_c/grove_arena.tscn --quit-after 120` | exit **0**; log reaches `wave_start` |

Concern 1 from the section above is resolved by this ruling; remaining
concerns (pause boolean, keyboard accept, auto_pick gap, Task 4 L3) stand.
