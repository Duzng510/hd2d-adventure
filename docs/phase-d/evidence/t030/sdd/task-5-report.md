# T-030 Task 5 — Report: card-copy polish, D-025, full regression, push

**Status: DONE** — branch `phase-d/t030-wave-buff-choice`, pushed to origin.

| Commit | Subject | Files |
|---|---|---|
| `d98735d` | `feat(T-030): shorten buff card copy` | 5 files, +12/−7 (2 scripts + 3 evidence PNGs) |
| `c72f220` | `docs(T-030): record D-025 and buff flow state` | 2 files, +20/−7 (DECISIONS, STATE) |

## 1. Copy polish (review ruling from Task 4)

### Measurement, not estimate

The card is 160 px wide with `CARD_INSET = 8` on both sides, so the label area is **144 px**. VT323 at
16 px advances **6.4 px/glyph** (`Font.get_string_size`, hinting/subpixel off) ⇒ **22.5 glyphs per line**.
Measured with a real `Label` (theme from `Hd2dTheme.build()`, `AUTOWRAP_WORD_SMART`, width 144):

- the shipped `ĐỔI LẠI HỒI ĐÒN +3 TICK` = 24 glyphs / 148 px ⇒ wrapped to `ĐỔI LẠI HỒI ĐÒN +3` / `TICK`
  (the exact review bug);
- the prefix alone (`ĐỔI LẠI `) costs **51 px**, leaving 14 glyphs — no informative cost fits after it.
  So the prefixes became their own line; body strings only had to fit 144 px.

### Changes

`scripts/ui/ui_copy.gd` — every gain/cost body now one measured line (width at 16 px in brackets):

| Const | Old | New |
|---|---|---|
| `BUFF_HEAVY_EDGE_GAIN` | `SÁT THƯƠNG +30%` | unchanged (96 px) |
| `BUFF_HEAVY_EDGE_COST` | `HỒI ĐÒN +3 TICK` | unchanged (96 px) |
| `BUFF_QUICK_RHYTHM_GAIN` | `HỒI ĐÒN -3 · COMBO +4 TICK` | `HỒI ĐÒN -3 · COMBO +4` (134 px) |
| `BUFF_QUICK_RHYTHM_COST` | `SÁT THƯƠNG -10% · MỆT SỚM HƠN` | `SÁT THƯƠNG -10%` ⏎ `MỆT SỚM` (deliberate 2 lines, see below) |
| `BUFF_ROOT_ARMOR_GAIN` | `MÁU TỐI ĐA +40` | unchanged (90 px) |
| `BUFF_ROOT_ARMOR_COST` | `CHẠY CHẬM 12%` | unchanged (84 px) |
| `BUFF_SLOW_BREATH_GAIN` | `MIỄN MỆT +2 · HỒI MỆT NHANH` | `MIỄN MỆT +2, HỒI NHANH` (142 px, comma buys the line) |
| `BUFF_SLOW_BREATH_COST` | `HỒI ĐÒN +2 TICK` | unchanged (96 px) |
| `BUFF_LONG_REACH_GAIN` | `TẦM ĐÁNH +0.4 M` | unchanged (96 px) |
| `BUFF_LONG_REACH_COST` | `RA ĐÒN CHẬM 2 TICK` | `RA ĐÒN CHẬM 2` (84 px) |
| `BUFF_FOURTH_HOOK_GAIN` | `COMBO +1 ĐÒN` | unchanged (77 px) |
| `BUFF_FOURTH_HOOK_COST` | `CỬA SỔ COMBO -4 TICK` | `CỬA SỔ COMBO -4` (95 px) |

`scripts/ui/buff_choice.gd` (`present()`, 2 lines): the `LỢI` / `ĐỔI LẠI` prefixes are concatenated with
`"\n"` instead of `" "` — same labels, same fonts, same palette, no new nodes and no size changes. This is
the "label stacking" option the brief allowed; it is genuinely cheaper than shrinking every cost to 14
glyphs, and it is required because `ĐỔI LẠI ` alone is 51/144 px.

Check with the real `BuffChoice` mounted on the real arena (temporary probe, deleted): every title is
1 line; every gain cell is 2 lines (prefix + 1 body line); every cost cell is 2 lines except
`NHỊP GỌN` = 3 lines (prefix + the two deliberate cost lines). No label wrapped beyond its intended
line count.

**Deviation from the brief's copy:** the brief's `SÁT THƯƠNG -10% · MỆT SỚM` is 25 glyphs / **161 px** and
`MIỄN MỆT +2 · HỒI NHANH` is 23 glyphs / **148 px** — both physically over 144 px, even before the prefix.
`MIỄN MỆT +2, HỒI NHANH` fits on one line (142 px, verified `get_line_count() == 1`).
`SÁT THƯƠNG -10% · MỆT SỚM` cannot be shortened without dropping either "10%" or "sớm", so the constant
carries an explicit break between the two costs; it is a deliberate two-line cost, not a mid-phrase wrap.

### Re-run (font + chooser)

```
test_font_coverage            PASS 3 checks, 98 glyphs, cmap 567        exit 0
test_font_coverage -- negative FAIL 1/3 (control detector alive)        exit 1 (intended)
test_buff_choice              PASS 16 checks                            exit 0
test_buff_choice -- negative  FAIL 3/16 (pause / pick lands / auto)     exit 1 (intended)
```

## 2. New L3 capture

```
"$GODOT" --path . res://scenes/ui/capture_buffs.tscn --fixed-fps 60
SHOT buffs_closed (186349 lit px)
SHOT buffs_open   (186349 lit px)
CHECK PASS P30.1 both frames captured
CHECK PASS P30.2 the arena really rendered, not a black frame (lit px 186349 / 186349)
CHECK PASS P30.3 the chooser open/closed differs (195840 px in the panel band, need >= 40)
CHECK PASS P30.4 the three cards carry the pool titles (3 cards, title[0]=RÌU SÉT)
checks=4 failures=0 band_diff=195840 lit=[186349, 186349]     CAP_EXIT=0

... -- negative
CHECK PASS P30.1 / P30.2
CHECK PASS P30.3 control: one pose twice changes 0 px in the panel band (got 0)
CHECK PASS P30.4 control: the chooser never opened and holds no cards
checks=4 failures=0 band_diff=0                                CAPNEG_EXIT=0
```

`band_diff = 195840 = 544 × 360` exactly, i.e. the changed rectangle is the panel and nothing else.

**Opened `docs/phase-d/evidence/t030/buffs_open.png` with Read.** What I saw: three cards
(`RÌU SÉT`, `NHỊP GỌN`, `GIÁP RỄ`) over the arena; each card shows title, a `LỢI` line, the gain, an
`ĐỔI LẠI` line and the cost. Card 1: `SÁT THƯƠNG +30%` / `HỒI ĐÒN +3 TICK`; card 2:
`HỒI ĐÒN -3 · COMBO +4` / `SÁT THƯƠNG -10%` / `MỆT SỚM`; card 3: `MÁU TỐI ĐA +40` / `CHẠY CHẬM 12%`.
No mid-phrase wrap, no text touching the card border, no clipped line, panel centered, VT323 crisp.
Card 2 is the only card whose cost takes two lines, and that split is between the two costs.

**Viewport note:** the brief's command does not pass `--resolution`; this machine's Godot default window is
**1152×648**, while Task 4's evidence was captured with `--resolution 1280x720`. The UI is a `CanvasLayer`
drawn 1:1 in screen space, so the panel is still exactly 544×360, the text size is unchanged and
`band_diff` is the same 195840. The committed PNGs are therefore 1152×648. If a pixel-comparable
1280×720 baseline is required, re-run with `--resolution 1280x720` (would need a third commit; not done
to keep the task's two-commit rule).

## 3. Full regression (real output)

| Check | Result | Exit |
|---|---|---|
| `--headless --path . --import` | 0 `SCRIPT ERROR` | 0 |
| `node tools/check_stat_source.mjs` | `stat-source clean: 77 scripts` | 0 |
| `... --selftest` | `selftest PASS violations=1 allowed_hit=0` | 0 |
| `test_aim_model` | AIM MODEL TEST PASS (6 checks) | 0 |
| `test_boss_ai` | PASS test_boss_ai | 0 |
| `test_boss_tuning` | PASS test_boss_tuning | 0 |
| `test_buff_choice` | PASS 16 checks | 0 |
| `test_buff_kernel` | PASS 17 checks | 0 |
| `test_character_sheet` | PASS 8 checks | 0 |
| `test_combat_kernel` | PASS 107 checks | 0 |
| `test_combat_tuning` | PASS 16 checks | 0 |
| `test_font_coverage` | PASS 3 checks, 98 glyphs, cmap 567 | 0 |
| `test_grunt_ai` | PASS 16 checks | 0 |
| `test_movement_model` | TEST PASS (6 groups, 100 reversals) | 0 |
| `test_pixel_grid` | PIXEL GRID TEST PASS | 0 |
| `test_player_stats` | PASS 33 checks | 0 |
| `test_ranged_ai` | PASS test_ranged_ai | 0 |
| `test_ranged_tuning` | PASS test_ranged_tuning | 0 |
| `test_reward_kernel` | PASS test_reward_kernel | 0 |
| `test_stats_live` | PASS 18 checks | 0 |
| `test_swarm_tuning` | PASS test_swarm_tuning | 0 |
| `test_tempo_fatigue` | PASS 15 checks | 0 |
| `test_theme` | PASS 13 checks | 0 |
| `test_title_entry` | PASS 14 checks | 0 |
| `test_wave_kernel` | `checks=21 failures=0`, PASS | 0 |
| L2 `grove_arena` 120 frame | 0 `SCRIPT ERROR` | 0 |
| L2 `play_arena` 120 frame | 0 `SCRIPT ERROR` | 0 |
| `run_t030_buffs` | `runs=10 wins=10 picks=20 mods_ok=true dmg=5200 hits=558 fight_ticks=17848 dmg_per_s=17.5`, `checks=4 failures=0` | 0 |
| `run_t030_buffs -- negative` | T30.0–T30.2 pass, `CHECK FAIL T30.3 picks_total == 0 … (got 20)` | 1 (intended) |
| `run_t018_cycles` | `runs=10 wins=10 losses=0 max_wave=3 reset_checks=true ticks=16751` | 0 |
| `run_t019_swarm` | `runs=3 wins=3 swarms=3 grunts=2 reset_checks=true ticks=5026` | 0 |
| `run_t020_ranged` | `checks=14 failures=0` | 0 |
| `run_t021_boss` | `checks=41 failures=0` | 0 |
| `run_t022_reward` | `checks=14 failures=0` | 0 |
| `run_t027_tempo` | `checks=5 failures=0` | 0 |
| `node tools/run_evidence.mjs` | `runs=7 negatives=7 ids=17 failures=0 seconds=140` | 0 |
| `capture_buffs` | `checks=4 failures=0 band_diff=195840`, control `0 px` | 0 / 0 |

22/22 suites, zero `SCRIPT ERROR` in every run. All positive gates green; the two intended negatives
(font-coverage control, buff-choice `-- negative`) and the harness negative are red only where designed.

## 4. Docs

- **DECISIONS D-025** (Technical, Accepted): `BUFF_PENDING` behind `buff_pick_enabled` default false;
  opt-in by mounting `BuffChoice` (presence = enable); per-run seed logged `buff/buff_seed`, picks logged
  `buff/buff_pick` = 1-based pool index; `auto_pick` shared by the T-030 harness and L4 bot mode; ESC
  ignored while pending; `SwingArc` stretches with reach (`reach / 1.4`); card copy budget 144 px; all buff
  numbers HYPOTHESIS until L4. Evidence section carries only the observed numbers.
- **D-024 amendment note:** sheet is now **480×352** (content growth: WAVE/SEED rows), still a 4-px
  multiple and still 4 columns; spec §7 already records 480×352. The historic 480×320 stays for trace.
- **STATE:** header/branch updated; T-030 DONE paragraph with counts, harness caveat (17.5 dmg/s is a
  teleport + top-HP survival number, **not comparable** to the 4.8 L4 baseline), capture numbers,
  `run_evidence`; T-031 next; stale T-029-era counts refreshed (`player_stats` 33, `theme` 13,
  `stats_live` 18, 22/22 suites, font 98 glyphs); known issues add plain-bool pause (no stack), shortened
  card copy (with the deliberate two-line cost), 480×352 sheet; DONE list trimmed to 5 entries (T-021 moved out).

## 5. Files

- `scripts/ui/ui_copy.gd`, `scripts/ui/buff_choice.gd` — copy + prefix line.
- `docs/phase-d/evidence/t030/buffs_closed.png`, `buffs_open.png`, `buffs_control.png` — re-captured.
- `docs/DECISIONS.md` — D-025 + D-024 note.
- `docs/STATE.md` — T-030 DONE, T-031 next, counts, known issues.

Untouched/unstaged (pre-existing): `assets/ui/fonts/vt323.ttf.import`,
`docs/phase-c/evidence/t023/evidence_report.{json,md}` (rewritten by `run_evidence`),
untracked `docs/phase-c/evidence/t027/session5/`, and `.superpowers/`.

## 6. Concerns

1. **Copy deviations are physics-driven**, not taste: two of the brief's strings are wider than the
   144 px text area (161 px and 148 px). One uses a comma (fits at 142 px), the other a deliberate
   line break between two costs. All other strings match the brief.
2. **Capture resolution changed** to 1152×648 because the brief's command omits `--resolution 1280x720`
   (Task 4 used it). Panel/text geometry is unchanged; only the window is smaller.
3. **17.5 dmg/s must not be used as a balance number** — the harness teleports the player next to the
   target and tops HP every tick. L4 has to measure the real buffed DPS.
4. `auto_pick` (the L4 path) only has harness coverage; there is no test that a real L4 bot run picks
   correctly through it.
5. Spec §7 still says "hiện 79 glyph"; coverage is now 98. Out of this task's scope, recorded here so it
   is not lost.
6. Pause remains a plain bool (no stack); `BuffChoice` and `CharacterSheet` cannot collide today only
   because ESC is swallowed during `BUFF_PENDING`. T-031 must not add a third concurrent modal without
   fixing that.

## Fix round (review finding, commit 69aa5fd)

**Status: DONE** — branch `phase-d/t030-wave-buff-choice`, pushed `c72f220..69aa5fd`.

### 1. Units restored

| Const | Shipped before | Restored | Width at 16 px VT323 |
|---|---|---|---|
| `BUFF_LONG_REACH_COST` | `RA ĐÒN CHẬM 2` | `RA ĐÒN CHẬM 2 TICK` | 115.2 px (18 glyphs) |
| `BUFF_FOURTH_HOOK_COST` | `CỬA SỔ COMBO -4` | `CỬA SỔ COMBO -4 TICK` | 128.0 px (20 glyphs) |

Both are one line inside the 144 px body budget, so the panel no longer mixes units with
`HỒI ĐÒN +3 TICK` / `HỒI ĐÒN +2 TICK`.

### 1b. Typo ruling

The ruling asked to replace `HỒI ĐỒN` (Đ + U+1ED2) with `HỒI ĐÒN` (Đ + U+00D2) everywhere in
`scripts/ui/ui_copy.gd`. A codepoint scan of the file (and of `d98735d^` and HEAD) found **0**
occurrences of Đ followed by U+1ED2 — the code already used U+00D2 (only `HỒI` legitimately uses
U+1ED2). The typo existed only in this report's rendered strings; those 5 occurrences are corrected
here, no code change was needed.

### 2. Width law in `tests/test_buff_choice.gd`

`_check_copy_width()` loads `res://assets/ui/fonts/vt323.ttf` as `FontFile`, walks every
`BuffPool.pool()` `title`/`gain`/`cost` (split on the deliberate `\n`), and asserts
`font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Hd2dTheme.UI_FONT_SIZE).x <= 144.0`.
Label: `T30.4 every card line fits the 144 px text area`. One `quit()` per path is kept.

```
COPY widest line 142.0 px: MIỄN MỆT +2, HỒI NHANH
PASS test_buff_choice: 17 checks                                  exit 0
FAIL test_buff_choice: 3/17 checks failed (existing inverted     exit 1 (intended)
  pause / pick-landed / auto checks)
```

Positive and negative both exercise the new check; the negative still exits 1 through the existing
inverted checks, not the width check.

### 3. Re-capture at 1280x720

```
"$GODOT" --path . res://scenes/ui/capture_buffs.tscn --fixed-fps 60 --resolution 1280x720
SHOT buffs_closed (230118 lit px) / SHOT buffs_open (230118 lit px)
CHECK PASS P30.1 ... P30.4 (title[0]=RÌU SÉT)
checks=4 failures=0 band_diff=195840 lit=[230118, 230118]        CAP_EXIT=0

... -- negative
SHOT buffs_closed (230128 lit px) / SHOT buffs_control (230128 lit px)
checks=4 failures=0 band_diff=0                                  CAPNEG_EXIT=0
```

**Opened `docs/phase-d/evidence/t030/buffs_open.png` (1280×720) with Read.** What I saw: three cards
(`RÌU SÉT`, `NHỊP GỌN`, `GIÁP RỄ`), each with title, `LỢI` line, gain, `ĐỔI LẠI` line, cost. Card 1:
`SÁT THƯƠNG +30%` / `HỒI ĐÒN +3 TICK`; card 2: `HỒI ĐÒN -3 · COMBO +4` / `SÁT THƯƠNG -10%` / `MỆT
SỚM`; card 3: `MÁU TỐI ĐA +40` / `CHẠY CHẬM 12%`. No truncation, no clipping, no mid-phrase wrap;
the restored `TICK` strings are not among the first three offered here, so T30.4 is what guards them.

### 4. Docs

- `docs/STATE.md`: dropped the stale "sheet prints raw snake_case ids" issue (repurposed to "đã hiện
  tên pool kể từ T-030"); T-029 paragraph `**72** hiện tại` → `**77** hiện tại`; T-030
  `buff_choice` counts 16 → 17 (negative 3/17); card-copy known issue notes the restored TICK units
  and the T30.4 width law.
- `docs/phase-d/UI_PROGRESSION_SPEC.md`: coverage "hiện 79 glyph" → "hiện 98 glyph".

### 5. Re-run

```
--headless --path . --import                                      exit 0
test_font_coverage          PASS 3 checks, 98 glyphs, cmap 567    exit 0
test_font_coverage -- negative  FAIL 1/3 (control)                exit 1 (intended)
test_buff_choice            PASS 17 checks                        exit 0
test_buff_choice -- negative  FAIL 3/17                           exit 1 (intended)
capture_buffs 1280x720      checks=4 failures=0 band_diff=195840  exit 0
capture_buffs -- negative   checks=4 failures=0 band_diff=0       exit 0
L2 grove_arena 120 frames   0 SCRIPT ERROR                        exit 0
```

Commit `69aa5fd fix(T-030): keep card units and measure copy width` (7 files: UiCopy, test, 3
evidence PNGs, STATE, spec), pushed `c72f220..69aa5fd`.
