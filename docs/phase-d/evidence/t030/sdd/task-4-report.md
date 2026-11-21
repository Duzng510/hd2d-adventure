# T-030 Task 4 — Report: arena wiring, 10-run buff harness, L3 evidence

**Status: DONE**

| Commit | Subject |
|---|---|
| `0d5db1d` | `feat(T-030): wire buff picks into the arena with evidence` (11 files, +295/−1) |
| `c213f99` | `fix(T-030): name both flags in the T30.2 check label` (1 file, +2/−1) |

Both on `phase-d/t030-wave-buff-choice`.

## 1. Wiring

- `scenes/phase_c/play_arena.tscn`: `load_steps` 3→4, `[ext_resource ... buff_choice.gd id="3_buffs"]`,
  `BuffChoice` (`CanvasLayer`) appended after `L4PlayDriver`. `encounter_path` stays default
  (`../GroveArena/WaveEncounter`), which resolves from `L4Play/BuffChoice`.
- `scripts/phase_c/l4_play_driver.gd`: at the end of `_ready`, `get_node_or_null("../BuffChoice") as BuffChoice`;
  if non-null and `_auto`, `auto_pick = true`. No other change to the driver. Normal and passive play keep UI mode.
- Proof of the gating (temporary probe, deleted, not committed):

```
-- bot mode:  PROBE auto_pick=true  pick_enabled=true auto=true
-- play mode: PROBE auto_pick=false pick_enabled=true auto=false
```

## 2. Harness `run_t030_buffs` (10 seeded runs, `buff_seed_base = 4242`)

```
"$GODOT" --headless --path . res://scenes/phase_c/run_t030_buffs.tscn --fixed-fps 60
runs=10 wins=10 picks=20 mods_ok=true dmg=5200 hits=558 fight_ticks=17848 dmg_per_s=17.5
phase_c_baseline=4.8
CHECK PASS T30.0 runs==10 wins==10 (10/10) and every run banked both picks (runs_ok=true)
CHECK PASS T30.1 picks==20 (picks=20)
CHECK PASS T30.2 mods_ok: exactly 2 active modifiers before each reset (mods_ok=true runs_ok=true)
CHECK PASS T30.3 picks_total == 20 (got 20)
checks=4 failures=0
PASS t030_buffs: buff picks in the wave flow      RUN_EXIT=0     (0 SCRIPT ERROR)

... -- negative
CHECK PASS T30.0 / T30.1 / T30.2
CHECK FAIL T30.3 picks_total == 0 on -- negative (got 20)
checks=4 failures=1                               NEG_EXIT=1     (intended red)
```

Per run, before `reset_run()`: `buff.picked_ids().size() == 2` and
`stats.active_modifiers().size() == 2`; the reset then clears both, so a missed pick cannot hide behind the
next run. Damage/hits come from the `CombatDirector.event_logged` tap (`player`/`damage` summed,
`player`/`hit` counted), not re-derived from enemy HP.

**dmg/s reading:** 17.5 vs the Phase C baseline 4.8. The denominator is every FIGHTING/PAUSED/BUFF_PENDING
tick across all 10 runs; the numerator is buffed damage with HP topped up every tick. It is a flow-survival
number, not a feel measurement, and the brief sets no threshold on 4.8. 5200 dmg / 558 hits = 9.3 dmg per hit.

## 3. L3 capture `capture_buffs`

```
"$GODOT" --path . res://scenes/ui/capture_buffs.tscn --fixed-fps 60 --resolution 1280x720
SHOT buffs_closed (230130 lit px)
SHOT buffs_open   (230130 lit px)
CHECK PASS P30.1 both frames captured
CHECK PASS P30.2 the arena really rendered, not a black frame (lit px 230130 / 230130)
CHECK PASS P30.3 the chooser open/closed differs (195840 px in the panel band, need >= 40)
CHECK PASS P30.4 the three cards carry the pool titles (3 cards, title[0]=RÌU SÉT)
checks=4 failures=0 band_diff=195840 lit=[230130, 230130]        CAP_EXIT=0

... -- negative
CHECK PASS P30.1 / P30.2
CHECK PASS P30.3 control: one pose twice changes 0 px in the panel band (got 0)
CHECK PASS P30.4 control: the chooser never opened and holds no cards
checks=4 failures=0 band_diff=0                                   CAPNEG_EXIT=0
```

`band_diff = 195840 = 544 × 360` exactly: the diff is precisely the panel rect and nothing else in
`Rect2(0.18, 0.22, 0.64, 0.56)` moved. `buffs_control.png` is byte-identical to `buffs_closed.png` (`cmp`).
The driver settles 3× `RenderingServer.frame_post_draw` for the closed grab and 3× for the open grab, with a
20-frame wait after `present()` because the card stagger tween runs 0.05 s delays + 0.12 s (≈13 frames) on a
paused-tree tween; without the wait the capture would photograph half-faded cards.

**Images opened with Read (all three):**
- centered: panel x 368–912, y 180–540 in 1280×720, equal margins;
- three 160×220 cards, focus border `#d9b26a` on card 1, cost lines `#c0695a`, body `#e8e4da`;
- no clipped text: `RÌU SÉT / LỢI SÁT THƯƠNG +30% / ĐỔI LẠI HỒI ĐÒN +3 TICK`,
  `NHỊP GỌN / LỢI HỒI ĐÒN -3 · COMBO +4 TICK / ĐỔI LẠI SÁT THƯƠNG -10% · MỆT SỚM HƠN`,
  `GIÁP RỄ / LỢI MÁU TỐI ĐA +40 / ĐỔI LẠI CHẠY CHẬM 12%`; every line ends inside its card border;
- VT323 crisp: hard-edged stems, no antialias halo, accents (Ọ, Ấ, Ễ, ƯƠ) rendered;
- **no layout constant was changed**: the observed defects are none; the long cost lines wrap at a phrase
  boundary (`+3 / TICK`, `SÁT THƯƠNG / -10% · MỆT SỚM HƠN`) which is legible and would need a wider card or
  a smaller font — both Task-3 panel decisions, out of scope here.

Evidence files committed: `docs/phase-d/evidence/t030/buffs_{closed,open,control}.png`
(`docs/**/*.import` sidecars stay ignored).

## 4. Regression (real exits)

| Command | Result |
|---|---|
| `--headless --path . --import` | exit 0 |
| `test_player_stats` | PASS 33 checks |
| `test_character_sheet` | PASS 8 checks |
| `test_buff_kernel` | PASS 17 checks |
| `test_wave_kernel` | PASS |
| `test_stats_live` | PASS 18 checks |
| `test_buff_choice` | PASS 16 checks |
| `test_buff_choice -- negative` | exit 1, 3/16 red (intended) |
| `check_stat_source.mjs` | `stat-source clean: 77 scripts`, exit 0 |
| `check_stat_source.mjs --selftest` | `selftest PASS violations=1 allowed_hit=0`, exit 0 |
| L2 `grove_arena.tscn --quit-after 120` | exit 0, 0 SCRIPT ERROR, `wave_start` row present |
| L2 `play_arena.tscn --quit-after 120` | exit 0, 0 SCRIPT ERROR, `wave_start` row present |
| `play_arena.tscn --fixed-fps 60 -- auto` | exit 0, 8/8 P25 checks, 3600 ticks, no stall with the chooser mounted |
| `run_t018_cycles / t019 / t020 / t021_boss / t022_reward / t027_tempo` | all exit 0 |
| `node tools/run_evidence.mjs` | `EVIDENCE e1-e5 passed runs=7 negatives=7 ids=17 failures=0 seconds=146`, exit 0 |

`run_evidence` rewrote `docs/phase-c/evidence/t023/evidence_report.{json,md}` (already modified before this
task); left unstaged, as were `assets/ui/fonts/vt323.ttf.import` and `docs/phase-c/evidence/t027/session5/`.

## 5. Files

```
scenes/phase_c/play_arena.tscn          +4/−1  (BuffChoice mount, load_steps 4)
scripts/phase_c/l4_play_driver.gd       +5     (bot-mode auto_pick)
scenes/phase_c/run_t030_buffs.tscn      new
scripts/phase_c/t030_buff_driver.gd     new (+ .uid)
scenes/ui/capture_buffs.tscn            new
scripts/ui/capture_buffs.gd             new (+ .uid)
docs/phase-d/evidence/t030/buffs_closed.png
docs/phase-d/evidence/t030/buffs_open.png
docs/phase-d/evidence/t030/buffs_control.png
```

## 6. Concerns / notes

1. **dmg_per_s is not a feel claim.** 17.5 vs 4.8 differs in both numerator (two buffs per run) and
   denominator (pauses and buff waits included, HP topped every tick). Reported for the record only.
2. **`play_arena -- auto` never cleared a wave** (6 hits in 3600 ticks: the L4 bot is a probe rig, not a
   closing bot), so the play-mount pick is not exercised by that selftest. The wiring itself was proven by the
   temporary probe above (`auto_pick=true` only in bot mode) and by `run_t030_buffs`, which mounts the same
   `BuffChoice` and banked 20 picks.
3. **Card cost lines wrap mid-phrase** on the 160 px cards; legible, not clipped, left as authored in Task 3.
4. The capture pauses the tree via `present()` and quits without closing; the documented trap (freeing an open
   chooser) does not apply to a quit, and no mid-run reset exists in this driver.
5. `T30.0` is an extra check (runs/wins + per-run pick banking) beyond the three named in the brief; `T30.2`
   reports `mods_ok`/`runs_ok` together and `T30.3` carries the negative inversion. Self-review caught the
   first version printing only `mods_ok` while also failing on `runs_ok`; `c213f99` fixes the label and the
   harness was re-run after it (output above is from the fixed build).
