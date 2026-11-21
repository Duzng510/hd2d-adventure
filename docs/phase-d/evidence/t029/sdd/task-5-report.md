# T-029 Task 5 — Report: mount in arena, L3 evidence, docs, full regression, push

**Status: DONE** — pushed `phase-d/t029-player-stats-sheet` to origin (upstream set).

| Commit | Subject |
|---|---|
| `e5e9816` | `feat(T-029): mount the sheet in the arena with L3 evidence` (7 files, +132/−1) |
| `aa257f0` | `docs(T-029): record D-021..D-024 and Phase D state` (3 files, +54/−12) |

Branch base: `9011481`. `docs/phase-c/evidence/t023/evidence_report.{json,md}` and
`docs/phase-c/evidence/t027/session5/` were left unstaged (modified/untracked before this task; the T-023
pair is rewritten timing-only by every `run_evidence` cycle).

## 1. Mount (Step 1)

`scenes/phase_c/grove_arena.tscn`: `load_steps` 37→38, `[ext_resource ... character_sheet.gd id="18_sheet"]`,
and a `CharacterSheet` (`CanvasLayer`) node **after** `WaveHUD` (last CanvasLayer in the tree, so it draws over
the HUD; `Reward` that follows is a `Node3D`). No other scene line changed.

Proof it does not pause at load:

```
"$GODOT" --headless --path . --import                                     IMPORT_EXIT=0
"$GODOT" --headless --path . res://scenes/phase_c/grove_arena.tscn --quit-after 120   ARENA_EXIT=0
1,encounter,wave_start,0,0,1        # the wave ticked ⇒ world never paused
```

## 2. Capture driver (Step 2)

New: `scenes/ui/capture_sheet.tscn` + `scripts/ui/capture_sheet.gd` (+ `.uid`), verbatim per brief
(`PANEL_BAND Rect2(0.30,0.27,0.40,0.46)`, `PANEL_MIN_DIFF 40`, `LIT_MIN_PIXELS 500`, settle via
`RenderingServer.frame_post_draw`, band diff, `OS.get_cmdline_user_args().has("negative")`). Driver disables
`WaveEncounter.set_physics_process(false)` in `_ready` so the spawn-radius wave never starts.

## 3. Captures (Step 3) — images opened and inspected

```
"$GODOT" --path . res://scenes/ui/capture_sheet.tscn --fixed-fps 60 --resolution 1280x720
SHOT sheet_closed (230134 lit px)
SHOT sheet_open   (230134 lit px)
CHECK PASS P29.1 both frames captured
CHECK PASS P29.2 the arena really rendered, not a black frame (lit px 230134 / 230134)
CHECK PASS P29.3 the sheet open/closed differs (153600 px in the panel band, need >= 40)
checks=3 failures=0 band_diff=153600 lit=[230134, 230134]
PASS t029_sheet_capture
POS_EXIT=0

"$GODOT" --path . res://scenes/ui/capture_sheet.tscn --fixed-fps 60 --resolution 1280x720 -- negative
CHECK PASS P29.2 ... (lit px 230130 / 230130)
CHECK PASS P29.3 control: one pose twice changes 0 px in the panel band (got 0)
checks=3 failures=0 band_diff=0 lit=[230130, 230130]
PASS t029_sheet_capture (control)
NEG_EXIT=0
```

`band_diff = 153600 = 480 × 320` exactly: the band's remainder (16 px side margins, 11 rows top/bottom) is
untouched arena, i.e. the sheet replaced precisely the panel rect and nothing else — the sheet is genuinely
drawn **over** the arena, not a black frame.

Visual review (3 PNGs read at 1×, plus a temporary 2× nearest zoom of the panel that was inspected and deleted):
- panel centred on 1280×720 (x 400–880, y 200–520), all three margins symmetric;
- no clipped text: widest row `MỆT NHỊP free 3 · +4 tick · trần 12 · decay 6` ends ~150 px inside the border;
- VT323 crisp: at 2× nearest every stem is a hard 2×2 block, no antialias halo, no subpixel smear;
- palette readable: dark `#12161c` panel, `#d9b26a` title/labels, `#e8e4da` values; WaveHUD stays readable at
  the top, the sheet covers the arena centre only.
- **Nothing was changed after seeing the captures** (no constant adjusted, no re-capture needed).

## 4. Docs (Steps 4–5)

- `docs/DECISIONS.md` — D-021…D-024 appended after D-020 (chronological house style, each with
  Decision / Reason / Bằng chứng / Rủi ro / Không đổi / Xác nhận của user). Recorded real numbers:
  player_stats 16 checks (neg 6/16), kernel 107, `stat-source clean: 68 scripts` at law commit → **72** now,
  selftest `violations=1 allowed_hit=0`, coverage 79 glyphs / cmap 567, theme 9, sheet 8/8 (neg 1/8),
  L3 `band_diff=153600` control 0 px, evidence suite `runs=7 negatives=7 ids=17 failures=0 seconds=109`.
  D-024 records **VT323 + OFL 1.1 + ASSET_LOG + coverage gate** and states m5x7 was rejected (17 missing
  glyphs), not chosen. D-023 states honestly that its buff numbers are HYPOTHESIS with no measurements yet.
- `docs/phase-d/UI_PROGRESSION_SPEC.md` — every m5x7 mention replaced (header line, §2 D-024 bullet, §7 font,
  §7 coverage, §9 risk 1, §10 checkbox → `vt323.ttf`); §7 size sentence now "bội số 16 px (16/32)"; §5 pause
  sentence now `PROCESS_MODE_ALWAYS` + one clause saying WHY (`WHEN_PAUSED` would never hear ESC while the
  game runs). Structure untouched.
- `docs/STATE.md` — header branch line, "Phase hiện tại" appended with Phase D open + T-029 numbers, build
  line now lists ESC, "Đang làm" → T-031 NEXT + T-029 DONE (history rows kept), "DONE gần đây" + T-029 and the
  oldest row (T-020) dropped to hold ≤5, Known issues + 2 T-029 lines (HYPOTHESIS buff/DPS, UI debt) and the
  stale DECISIONS index note. 179 → 183 lines: still over the 150 budget (pre-existing), not force-trimmed.

## 5. Full regression (Step 6)

| Command | Result |
|---|---|
| `"$GODOT" --headless --path . --import` | exit 0 |
| `node tools/check_stat_source.mjs` | `stat-source clean: 72 scripts`, exit 0 |
| `node tools/check_stat_source.mjs --selftest` | `selftest PASS violations=1 allowed_hit=0`, exit 0 |
| `node tools/run_evidence.mjs` | `EVIDENCE e1-e5 passed runs=7 negatives=7 ids=17 failures=0 seconds=109`, exit 0 |
| 19 × `tests/test_*.gd` | `SUITES=19 ANY_FAIL=0` |
| `grove_arena.tscn --quit-after 120` | exit 0, 0 `SCRIPT ERROR` |
| `capture_title.tscn --quit-after 5` | exit 0, 0 `SCRIPT ERROR` |

Suite detail: player_stats 16, combat_kernel 107, combat_tuning 16, grunt_ai 16, tempo_fatigue 15,
title_entry 14, theme 9, character_sheet 8, font_coverage `3 checks, 79 glyphs, font cmap=567`,
wave_kernel / reward_kernel / boss_* / ranged_* / swarm / aim_model / movement_model / pixel_grid PASS.

## 6. Files changed

```
docs/DECISIONS.md                        +37   (D-021..D-024)
docs/STATE.md                            +15/−? (Phase D, T-029, known issues)
docs/phase-d/UI_PROGRESSION_SPEC.md      ±14   (m5x7→VT323, 7→16 px, WHEN_PAUSED→ALWAYS)
scenes/phase_c/grove_arena.tscn          +4/−1 (CharacterSheet mount, load_steps 38)
scenes/ui/capture_sheet.tscn             new
scripts/ui/capture_sheet.gd (+ .uid)     new
docs/phase-d/evidence/t029/sheet_closed.png
docs/phase-d/evidence/t029/sheet_open.png
docs/phase-d/evidence/t029/sheet_control.png
```

`.import` sidecars for the PNGs are ignored by `.gitignore` (`docs/**/*.import`), so the evidence commit is
PNG-only, matching `docs/phase-d/evidence/t028/`.

## 7. Self-review

1. **Spec coverage** — §3.1/§3.2 → T1/T2, §3.3 → T2, §5 sheet/ESC/pause/focus → T4 + §5 doc fix here,
   §7 theme/font/palette/coverage → T3 with VT323, §8 DG1/DG2/DG4 (sheet part) → this task. DG3/DG5 and the
   damage-number toggle remain T-030/T-031.
2. **No invented numbers** — every figure above comes from a command run in this session; the D-023 entry
   says explicitly that its numbers are unmeasured.
3. **Laws intact** — panel 480×320 and card 160×220 (multiples of 4), font sizes 16/32, integer px offsets,
   no tuning/physics-layer/engine change, `check_stat_source` clean.
4. **Sheet closed & non-pausing at load** — proven by `wave_start` in the headless arena run and by all arena
   harnesses inside `run_evidence` staying green.
5. **Staging discipline** — explicit paths only; `.godot/`, `.superpowers/`, `docs/phase-c/evidence/*` untouched.

## 8. Concerns

1. **`STATE.md` is 183 lines vs the 150 budget** (pre-existing breach; this task adds 4 net lines). A docs
   trim task is still owed.
2. **`DECISIONS.md` index table stops at D-013** while entries run to D-024 — pre-existing; recorded in
   STATE Known issues instead of half-fixing it here.
3. **`docs/phase-d/PLAN_T029_stats_sheet.md` still contains the historical m5x7 plan/diff text** (it is the
   approved plan artifact, not the spec); left as history, no code or decision depends on it.
4. **Spec header still reads `Trạng thái: PROPOSED`** although the user approved it via chat (out of the
   amended scope); worth one line in a later docs pass.
5. **Pause ownership** (from Task 4): `open()` writes `get_tree().paused` without a stack — T-030/T-031 need a
   pause owner before adding a second overlay.
6. `run_evidence.mjs` rewrote `docs/phase-c/evidence/t023/evidence_report.{json,md}` (timing only); left
   unstaged by instruction, so those two files stay dirty in the worktree.
