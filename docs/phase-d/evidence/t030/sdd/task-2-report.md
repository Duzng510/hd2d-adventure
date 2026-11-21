# Task 2 Report — BUFF_PENDING flow + encounter buff API + SwingArc reach sync

**Status:** DONE
**Commit:** `92ec838` — `feat(T-030): add BUFF_PENDING flow and arc reach sync`
**Branch:** `phase-d/t030-wave-buff-choice` (stacked on `9ae9ae1`)

## Files

| File | Action |
|---|---|
| `scripts/phase_c/wave_kernel.gd` | modified — `BUFF_PENDING` enum + flag + `resolve_pick()` |
| `scripts/phase_c/wave_encounter.gd` | modified — buff kernel ownership, seed roll/log, `buff_offer`, `apply_buff`, `set_buff_pick_enabled` |
| `scripts/combat/player_combat.gd` | modified — `SWING_BASE_LENGTH` + SwingArc stretch in `_apply_stats()` |
| `tests/test_wave_kernel.gd` | modified — 5 new checks (21 total), negative control unchanged |
| `tests/test_stats_live.gd` | modified — 3 arc checks (18 total), negative control unchanged |
| `docs/phase-d/UI_PROGRESSION_SPEC.md` | **no edit needed** — §3.1 op-key sentence was already corrected in Task 1 (`git show 9ae9ae1`); verified current text matches the required rule |

5 files staged, **+107/−1**. `grove_arena.tscn` untouched. Pre-existing dirty files
(`assets/ui/fonts/vt323.ttf.import`, `docs/phase-c/evidence/t023/*`, untracked
`t027/session5/`) left untouched and unstaged.

## TDD RED

### Wave kernel (Step 1 before Step 2)

`<GODOT> --headless --path . -s res://tests/test_wave_kernel.gd`

```
SCRIPT ERROR: Parse Error: Cannot find member "BUFF_PENDING" in base "WaveKernel.State".
   at: GDScript::reload (res://tests/test_wave_kernel.gd:73)
SCRIPT ERROR: Parse Error: Cannot find member "BUFF_PENDING" in base "WaveKernel.State".
   at: GDScript::reload (res://tests/test_wave_kernel.gd:76)
ERROR: Failed to load script "res://tests/test_wave_kernel.gd" with error "Parse error".
```

Exit: **1** (a failed `-s` load exits 1; re-verified with a scratch parse-error
script. The RED command itself was piped through `tail`, so the code was measured
separately, not inferred.)

### Stats live arc (Step 3 before Step 4)

`<GODOT> --headless --path . -s res://tests/test_stats_live.gd`

```
FAIL: reach_add stretches the SwingArc with the hitbox (x=0.70 scale=1.0000)
FAIL test_stats_live: 1/18 checks failed
```

Exit: **1** — the default/no-restore arc checks already passed (authored 0.7/1.0);
only the stretch check was red, exactly the missing behaviour.

## TDD GREEN

| Command | Result |
|---|---|
| `test_wave_kernel` | `checks=21 failures=0` / `PASS test_wave_kernel`, exit 0 |
| `test_wave_kernel -- negative` | exit 1 (`alive enemies keep FIGHTING`, `pause_remaining = pause_frames`, `pause not elapsed yet`, `pause elapsed -> FIGHTING`, `final wave active` fail — intended) |
| `test_stats_live` | `PASS test_stats_live: 18 checks`, exit 0 |
| `test_stats_live -- negative` | exit 1 (`live tempo uses the buffed free swings (fatigue 0)` — intended) |

## Controller rulings applied

1. Reset check is `_check(on.state == WaveKernel.State.INACTIVE and on.buff_pick_enabled,
   "reset returns to INACTIVE and keeps the scene-level opt-in")`. The kernel keeps the
   flag out of `reset()`; the encounter re-applies it only through `set_buff_pick_enabled`.
2. Enum is `{ INACTIVE, FIGHTING, PAUSED, BUFF_PENDING, WON, LOST }`. Grepped before
   committing: every consumer compares named constants (`WaveKernel.State.*` in
   drivers/HUD/encounter/tests); no `.tscn`/`.tres`/`.json`/`.csv`/`.md`/`tools/`
   reference serializes a wave state int.
3. `_start_run()` order is exactly: compute seed → `BuffKernel.new(BuffPool.pool(), seed)`
   → `_offer_emitted = false` → log `buff/buff_seed` (value = seed) → `kernel.start()`
   → `kernel.wave_start_pending = false` → `_begin_wave()`. Seed =
   `buff_seed_base + runs_completed` when `buff_seed_base > 0`, else
   `randi() % 1000000 + 1`. `reset_run()` also sets `_offer_emitted = false` before it
   calls `_start_run()` (belt-and-braces per the brief).
4. `apply_buff()`: rejects unless state is `BUFF_PENDING` and `buff.take(id)` is non-empty;
   applies `_combat.stats.add_modifier(id, entry["ops"])`, then logs
   `buff/buff_pick` with `value = BuffPool.index_of(id) + 1` (success path only), then
   `_offer_emitted = false`, then `kernel.resolve_pick()`, returns true.
5. `_physics_process` gained a standalone `WaveKernel.State.BUFF_PENDING:` arm that
   emits `buff_offer(buff.offer())` once behind `_offer_emitted` and does nothing else
   (death check and tick are not run in this state).
6. `const SWING_BASE_LENGTH := 1.4`; `_apply_stats()` guards `_swing != null` and sets
   `position.x = reach * 0.5`, `scale.x = reach / SWING_BASE_LENGTH` from
   `stats.light_reach()`. Default 1.4 reproduces the authored `x=0.7`, `scale=1.0`
   exactly (test-proven).

The brief's event name `buff/seed` is superseded by ruling 3/4: rows are
`buff,buff_seed` and `buff,buff_pick` (entity `buff`).

`resolve_pick()` additionally ignores calls outside `BUFF_PENDING` (e.g. a stale UI
click after reset); the tested valid path is unchanged.

## Validation

| Gate | Result |
|---|---|
| `--import` | exit 0 |
| `test_wave_kernel` / `-- negative` | PASS 21 checks exit 0 / exit 1 |
| `test_stats_live` / `-- negative` | PASS 18 checks exit 0 / exit 1 |
| `test_player_stats` | PASS 33 checks exit 0 |
| `test_buff_kernel` | PASS 17 checks exit 0 |
| `node tools/check_stat_source.mjs` | `stat-source clean: 74 scripts`, exit 0 |
| `node tools/check_stat_source.mjs --selftest` | `selftest PASS violations=1 allowed_hit=0`, exit 0 |
| L1 `--check-only` (wave_kernel, wave_encounter, player_combat, test_wave_kernel, test_stats_live) | all exit 0 |
| L2 `grove_arena.tscn --quit-after 120` | exit 0; log tail `1,buff,buff_seed,0,0,396930` then `1,encounter,wave_start,0,0,1` |
| `node tools/run_evidence.mjs` | `EVIDENCE e1-e5 passed runs=7 negatives=7 ids=17 failures=0 seconds=131`, exit 0 |

### Extra probe for the encounter wiring (deleted, not committed)

`tests/_tmp_t030_probe.gd` exercised the arena end-to-end: default flag off,
`set_buff_pick_enabled(true)` reaches the kernel, `buff_seed_base = 4242` →
first reset run seed 4243 and a `buff_seed` log row, cleared wave parks in
`BUFF_PENDING`, exactly one `buff_offer` of 3 across many ticks, unoffered id
rejected with no modifier, valid pick lands one `PlayerStats` modifier with the
picked id + one `buff_pick` row whose value is the 1-based pool index + state
`PAUSED(60)`, second pick of the same window rejected, reset → seed 4244,
modifiers/picked list cleared, `FIGHTING`. Result: `PROBE PASS: 20 checks`,
exit 0. File and any `.uid` removed; working tree clean of probe artifacts.

## Self-review / concerns

- `buff` is only constructed in `_start_run()`, so it is null before the first run
  triggers (`buff_seed()` returns 0 until then). Task 3's `debug_force_buff_pending()`
  and the sheet seed/buff rows must guard the null.
- Every run start now writes a `buff_seed` row even when picks are disabled. That is
  the spec §6.2 reproducibility requirement; no harness asserts total log rows
  (`run_evidence` green).
- The offer is emitted on the first tick **in** `BUFF_PENDING`, i.e. one tick after
  the FIGHTING→BUFF_PENDING flip (matches the brief's match-arm; in UI mode the world
  pauses on the signal, so it is the transition tick). Headless pollers must await one
  extra tick after observing the state (the probe initially tripped on this — probe
  fixed, code unchanged).
- A failed `apply_buff(id)` (id not in the current offer) leaves the flow pending with
  `_offer_emitted = true`; the chooser must only present offered ids (Task 3).
- `WaveHUD` still prints the default `HUD_FIGHT` label in `BUFF_PENDING`; the modal
  covers the paused world. Not touched here (scope hygiene; Task 3 owns UI state).
- No in-repo regression test for `WaveEncounter.apply_buff` until Task 3/4; the
  deleted probe is this task's evidence.
- `assets/ui/fonts/vt323.ttf.import` still shows modified from earlier `--import`
  runs; content diff is import metadata churn, left unstaged as in Task 1.
