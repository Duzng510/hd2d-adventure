# T-030 final-review fix wave — report

Status: **DONE** (no push, no subagents; controller owns image verdicts)

Base: branch `phase-d/t030-wave-buff-choice`, base HEAD `69aa5fd`.
Godot: `C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` (inner exe, never `_console`).
All commands run from repo root. `node tools/run_evidence.mjs` was **not** run (it rewrites the user-dirty t023 reports); the affected tests/harnesses were run directly instead.

## Findings closed

- **Important 1 (DG2)** — new `tests/test_buff_laws.gd`: all 21 one/two-buff combos, one check per combo asserting `fatigue_decay_frames() < fatigue_max_frames()` and all 10 frame/cap getters >= 1, plus a built-in `bad_law` mutation proof. **22 checks**.
- **Important 2 (DG3)** — `scripts/phase_c/t030_buff_driver.gd`: added `T30.5` stall detector (consecutive `BUFF_PENDING` ticks > `STALL_TICKS := 600`), `T30.6` reset-clean detector (checked at each run boundary, right after `reset_run()` and before the new run can pick), plus driver-level `-- stall` and `-- dirty-reset` fault fixtures. `-- negative` kept as the printer-red control.
- **Important 3 (spec §5)** — sheet now renders `SHEET_BUFF_LINE` ("%s — LỢI: %s\nĐỔI LẠI: %s") per carried modifier from the `BuffPool` entry; quick-rhythm gain became `"HỒI ĐÒN -3 TICK\nCOMBO +4 TICK"`.
- **Fix-now triage** — per-op pool law in `tests/test_buff_kernel.gd` (each of the 15 op occurrences applied alone must move its named getter; resolver sentinel `null` for unknown keys fails the check); DG3 as above.
- **Cheap minors** — D-025 count corrected (`test_buff_choice` 16 -> 17, negative 3/17); quick-rhythm gain carries `TICK` on both lines; sheet geometry now exact (`SHEET_SIZE == Vector2i(480, 432)`, `CARD_SIZE == Vector2i(160, 220)` asserted, plus `content_minimum_size()` gate); t029 sheet evidence recaptured after the sheet grew.

## Task 1 — `tests/test_buff_laws.gd` (new)

```
<GODOT> --headless --path . -s res://tests/test_buff_laws.gd
PASS test_buff_laws: 22 checks        exit 0
```
(21 combos: 6 one-buff + 15 two-buff, + 1 mutation proof `bad_law` with `fatigue_decay_frames_add: 12.0`.)

## Task 2 — per-op pool law (`tests/test_buff_kernel.gd`)

```
<GODOT> --headless --path . -s res://tests/test_buff_kernel.gd
PASS test_buff_kernel: 32 checks      exit 0     (17 previous + 15 per-op)
<GODOT> --headless --path . -s res://tests/test_buff_kernel.gd -- negative
FAIL test_buff_kernel: 1/32 checks failed   exit 1   (red = "an offer holds exactly 3 buffs", not a per-op check)
```
Note: the resolver initially lacked the `light_combo_hits` case; the null sentinel caught it (`FAIL: op 'light_combo_hits_add' in 'fourth_hook' moves its own getter`) before the fix — the unknown-key path is proven non-vacuous. All 10 pool keys are covered: `light_damage_mult`, `light_recovery_frames_add`, `combo_window_frames_add`, `fatigue_free_swings_add`, `player_max_hp_add`, `player_move_speed_mult`, `fatigue_decay_frames_add`, `light_reach_add`, `light_startup_frames_add`, `light_combo_hits_add`.

## Task 3 — sheet name + gain/cost, geometry

Files: `scripts/ui/ui_copy.gd`, `scripts/ui/character_sheet.gd`, `scripts/ui/hd2d_theme.gd`, `tests/test_character_sheet.gd`, `tests/test_theme.gd`, `scripts/ui/capture_sheet.gd`.

- Buff list is a `VBoxContainer`; empty -> one `SHEET_NONE` label; otherwise one label per modifier with pool title/gain/cost (internal `\n` in gain/cost replaced by `" · "`); old labels removed and `free()`d, never `queue_free()`d, so `body_text()` cannot report stale content.
- Wave row shows `SHEET_PLACEHOLDER` when encounter null **or** kernel state `INACTIVE`; otherwise `HUD_WAVE_PROGRESS` (no status text).
- `content_minimum_size()` = column `get_combined_minimum_size()` + `Vector2(GAP*2, GAP*2)`.

Measured with two buffs (heavy_edge + long_reach) after `await process_frame`:

```
SHEET content_minimum_size=(343.0, 414.0) sheet_size=(480.0, 432.0)
PASS test_character_sheet: 14 checks   exit 0
<GODOT> ... test_character_sheet.gd -- negative -> FAIL 1/14   exit 1  ("opening pauses the world")
```
**Chosen `SHEET_SIZE := Vector2i(480, 432)`** — content minimum 414 <= 432, so no propagation to a taller 4-grid was needed.

```
<GODOT> --headless --path . -s res://tests/test_theme.gd
PASS test_theme: 15 checks            exit 0     (exact SHEET_SIZE/CARD_SIZE assertions added)
```

`capture_sheet.gd`: `PANEL_BAND := Rect2(0.30, 0.18, 0.40, 0.64)`; normal mode applies heavy_edge + long_reach ops to the arena player's `PlayerCombat.stats` before pressing ESC; P29.4 asserts the opened sheet's `body_text()` contains a gain and a cost string. Negative mode stays pose-identical.

## Task 4 — DG3 behavioral negatives (`scripts/phase_c/t030_buff_driver.gd`)

Harness commands and full tails:

**normal** — exit **0**
```
runs=10 wins=10 picks=20 mods_ok=true dmg=5200 hits=558 fight_ticks=17848 dmg_per_s=17.5
phase_c_baseline=4.8
CHECK PASS T30.0 runs==10 wins==10 (10/10) and every run banked both picks (runs_ok=true)
CHECK PASS T30.1 picks==20 (picks=20)
CHECK PASS T30.2 mods_ok: exactly 2 active modifiers before each reset (mods_ok=true runs_ok=true)
CHECK PASS T30.3 picks_total == 20 (got 20)
CHECK PASS T30.5 buff flow never stalls in BUFF_PENDING (stalled=false pending_ticks=0)
CHECK PASS T30.6 modifiers cleared after reset (reset_clean=true)
checks=6 failures=0
PASS t030_buffs: buff picks in the wave flow
```

**`-- negative`** — exit **1** (T30.3 red only)
```
runs=10 wins=10 picks=20 mods_ok=true dmg=5200 hits=558 fight_ticks=17848 dmg_per_s=17.5
CHECK PASS T30.0 ... T30.1 ... T30.2 ...
CHECK FAIL T30.3 picks_total == 0 on -- negative (got 20)
CHECK PASS T30.5 ...
CHECK PASS T30.6 ...
checks=6 failures=1
FAIL t030_buffs: buff picks in the wave flow
```

**`-- stall`** — exit **1** (T30.5 red + downstream runs/wins checks)
```
STALL run=0 pending_ticks=601
runs=0 wins=0 picks=0 mods_ok=true dmg=120 hits=12 fight_ticks=600 dmg_per_s=12.0
CHECK FAIL T30.0 runs==10 wins==10 (0/0) ...
CHECK FAIL T30.1 picks==20 (picks=0)
CHECK PASS T30.2 mods_ok: ...
CHECK FAIL T30.3 picks_total == 20 (got 0)
CHECK FAIL T30.5 buff flow never stalls in BUFF_PENDING (stalled=true pending_ticks=601)
CHECK PASS T30.6 modifiers cleared after reset (reset_clean=true)
checks=6 failures=4
FAIL t030_buffs: buff picks in the wave flow
```
T30.0/T30.1/T30.3 are the natural runs/wins/picks consequences of a flow that can never finish a run; T30.6 stays green.

**`-- dirty-reset`** — exit **1** (T30.6 red only)
```
runs=10 wins=10 picks=20 mods_ok=true dmg=5200 hits=558 fight_ticks=17848 dmg_per_s=17.5
CHECK PASS T30.0 ... T30.1 ... T30.2 ... T30.3 ... T30.5
CHECK FAIL T30.6 modifiers cleared after reset (reset_clean=false)
checks=6 failures=1
FAIL t030_buffs: buff picks in the wave flow
```

## Task 5/6 — docs

- `docs/DECISIONS.md`: **D-026** (Technical, Accepted, 2026-11-21) amends only DG3's unmeasurable "không apply buff ⇒ dmg/s < ngưỡng" clause; behavioral gate = T30.1 (`picks==20`) + flow assertions; records `stat-source-violation` via `check_stat_source.mjs --selftest`, missing resolve via T30.5, missing `clear_modifiers` / `buffs-not-reset-on-r` via T30.6. D-024 geometry note now 480×432 (T-030 buff detail rows). D-025 evidence updated to final counts (kernel 32, laws 22, choice 17 / negative 3/17, sheet 14 / negative 1/14, theme 15, 23/23 suites, sheet band_diff 207360, negative modes, quick-rhythm TICK on both lines, sheet 480×432 in evidence and risk (7)).
- `docs/phase-d/UI_PROGRESSION_SPEC.md`: §7 geometry 480×432 (buff rows noted; glyph count 98 -> 99 after the copy change); §8 DG3 row marked **AMENDED by D-026** with T30.5/T30.6/stat-source delivery.
- `docs/STATE.md`: header D-021…D-026; T-030 in-progress block, UI-debt line and DONE line carry 480×432, `test_buff_laws`, 23/23 suites (was 22/22), `negative`/`stall`/`dirty-reset`, sheet band_diff 207360; the "17.5 dmg/s not comparable to 4.8" note kept.

## Task 7 — evidence recapture (L3, real renderer 1280×720, `--fixed-fps 60`)

| Command | checks / exit | band_diff | lit |
|---|---|---|---|
| `capture_sheet.tscn` | checks=4 failures=0 / exit 0 | **207360** (= 480×432 px) | 230130 / 230130 |
| `capture_sheet.tscn -- negative` | checks=3 failures=0 / exit 0 | **0** | 230128 / 230128 |
| `capture_buffs.tscn` | checks=4 failures=0 / exit 0 | **195840** (= 544×360 px) | 230125 / 230125 |
| `capture_buffs.tscn -- negative` | checks=4 failures=0 / exit 0 | **0** | 230124 / 230124 |

P29.4 PASS ("the opened sheet renders a buff gain and its cost"); P30.4 PASS (3 cards carry pool titles). Images written to `docs/phase-d/evidence/t029/sheet_{closed,control,open}.png` and `docs/phase-d/evidence/t030/buffs_{closed,control,open}.png`. Not claimed as visually approved — the controller views them.

## Task 8 — validation summary

- L1 `--check-only` for all 9 touched/new scripts: **9/9 exit 0** (ui_copy, character_sheet, hd2d_theme, capture_sheet, t030_buff_driver, test_buff_laws, test_buff_kernel, test_character_sheet, test_theme). `--headless --import` exit 0 (generated `tests/test_buff_laws.gd.uid`).
- All 23 unit suites via `-s res://tests/<file>.gd`: **23/23 exit 0** (buff_kernel 32, buff_laws 22, buff_choice 17, character_sheet 14, theme 15, wave_kernel 21, player_stats 33, stats_live 18, font_coverage 3 checks / 99 glyphs, combat_kernel 107, tempo 15, title_entry 14, plus the remaining tuning/AI/model suites).
- Negative modes re-run: `test_buff_kernel -- negative` exit 1 (1/32), `test_character_sheet -- negative` exit 1 (1/14), `test_font_coverage -- negative` exit 1 (1/3); `test_buff_choice` normal exit 0 (17).
- `node tools/check_stat_source.mjs` -> `stat-source clean: 77 scripts` exit 0; `--selftest` -> `selftest PASS violations=1 allowed_hit=0` exit 0.
- L2 `res://scenes/phase_c/play_arena.tscn --quit-after 120` exit 0, no `SCRIPT ERROR`.
- `node tools/run_evidence.mjs` deliberately not run (dirty t023 reports are user-owned).

## Commits (branch `phase-d/t030-wave-buff-choice`)

1. `c92f079` feat(T-030): gate buff stat laws and every pool op — test_buff_laws(.gd/.uid), test_buff_kernel
2. `7299418` feat(T-030): show buff gains and tradeoffs in the sheet — ui_copy, character_sheet, hd2d_theme, capture_sheet, test_character_sheet, test_theme, recaptured t029 PNGs
3. `4a38ddd` fix(T-030): add behavioral stall and dirty-reset negatives — t030_buff_driver
4. `6ed704d` docs(T-030): close final gate findings and recapture evidence — spec, DECISIONS, STATE, t030 PNGs

Not pushed. User-dirty paths untouched and unstaged: `docs/phase-c/evidence/t023/evidence_report.*`, `docs/phase-c/evidence/t027/session5/`, `assets/ui/fonts/vt323.ttf.import`.

## Deviations / notes

1. **Dirty-reset fixture cleanup (needed):** the injected `dirty_fixture` is removed immediately after the T30.6 detector read. Without that, the stray modifier survived into the next run's WON accounting (`picks=18`, extra reds on T30.0/T30.1/T30.2/T30.3), which violates the brief's "red on T30.6 only". The removal is a one-shot fixture cleanup in the driver, not a production change.
2. **`-- stall` collateral reds:** a stalled flow cannot complete runs, so T30.0/T30.1/T30.3 are red as natural runs/wins/picks consequences alongside T30.5; T30.6 stays green. Recorded in D-026 risk (2).
3. **Spec glyph count:** §7 said 98 glyphs; the new `SHEET_BUFF_LINE` copy makes it 99 (measured by `test_font_coverage`), so the number was corrected in the same docs unit.
4. `.uid` for the new test was generated with `--headless --import` and committed with the script.
5. Sheet evidence recapture reused the T-029 capture scene (per brief); band 207360 exactly equals 480×432 px, confirming the whole panel sits inside `PANEL_BAND`.
