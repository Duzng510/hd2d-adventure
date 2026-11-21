# Task 1 Report — BuffPool + seeded BuffKernel + buff copy

**Status:** DONE
**Commit:** `9ae9ae1` — `feat(T-030): add the seeded buff pool and kernel`
**Branch:** `phase-d/t030-wave-buff-choice`

## Files

| File | Action |
|---|---|
| `scripts/ui/ui_copy.gd` | modified — 23 buff panel/buff consts appended |
| `scripts/phase_d/buff_pool.gd` | created — `pool()` + `index_of()` only |
| `scripts/phase_d/buff_kernel.gd` | created — seeded offer/take/picked_ids/reset |
| `tests/test_buff_kernel.gd` | created — 17 checks + negative control |
| `docs/phase-d/UI_PROGRESSION_SPEC.md` | modified — §3.1 op-key rule corrected |

`.uid` files for the three new scripts committed with them. Nothing else staged;
pre-existing dirty files (`docs/phase-c/evidence/t023/*`, untracked `t027/session5/`)
left untouched and uncommitted.

## TDD RED

Command: `--headless --path . -s res://tests/test_buff_kernel.gd` (after `--import`, exit 0)
Exit: **1**

```
SCRIPT ERROR: Parse Error: Identifier "BuffPool" not declared in the current scope.
   at: GDScript::reload (res://tests/test_buff_kernel.gd:13)
SCRIPT ERROR: Parse Error: Identifier "BuffKernel" not declared in the current scope.
   at: GDScript::reload (res://tests/test_buff_kernel.gd:13)
...
ERROR: Failed to load script "res://tests/test_buff_kernel.gd" with error "Parse error".
```

## TDD GREEN

After appending UiCopy consts and adding `buff_pool.gd` / `buff_kernel.gd`
(`--import` exit 0), same command:

```
PASS test_buff_kernel: 17 checks
```
Exit: **0**

Negative control (`... -s res://tests/test_buff_kernel.gd -- negative`):

```
FAIL: an offer holds exactly 3 buffs
FAIL test_buff_kernel: 1/17 checks failed
```
Exit: **1** (intended failure — offer-size gate trips).

## Controller rulings applied

1. Negative-id check is `_check(kernel.take(&"no_such_buff").is_empty(), …)`.
2. Taken entry compared by `id` + ops key count (`taken.get("id", &"") == picked["id"]
   and (taken["ops"] as Dictionary).size() == (picked["ops"] as Dictionary).size()`);
   no Dictionary `==` carries the take gate. (`offer()`-vs-`offer()` determinism
   checks stay as the brief wrote them — they passed without modification.)
3. **Seed pair kept: 4242 / 4241** — they produce different offers, so no switch
   was needed. Probe output:
   - `seed 4242 -> ["quick_rhythm", "heavy_edge", "long_reach"]`
   - `seed 4241 -> ["root_armor", "long_reach", "quick_rhythm"]`
   (scratch probe script was deleted; no `.uid` left behind)
4. `buff_pool.gd` contains only `static func pool()` and `static func index_of()` —
   no `HEAVY_EDGE`/`_ids` dead code.

## Validation

| Gate | Result |
|---|---|
| `--import` | exit 0 |
| `test_buff_kernel` | PASS 17 checks, exit 0 |
| `test_buff_kernel -- negative` | exit 1 |
| `test_font_coverage` | PASS 3 checks, **97 glyphs**, cmap 567, control U+4E00 present=false, exit 0 |
| `test_font_coverage -- negative` | exit 1 |
| `node tools/check_stat_source.mjs` | `stat-source clean: 74 scripts`, exit 0 |
| `node tools/check_stat_source.mjs --selftest` | PASS violations=1 allowed_hit=0, exit 0 |
| `--check-only` ui_copy / buff_pool / buff_kernel / test_buff_kernel | all exit 0 |

## Spec fix (§3.1)

Old sentence claimed op key = getter name + suffix. Replaced with: op key = the
kernel stat key + `_add`/`_mult`; getter name otherwise, with `move_speed()`
mapping to `player_move_speed` (`player_move_speed_mult`). One-line diff.

## Self-review / concerns

- Deliberate deviation: the brief's kernel snippet included an unused
  `seed_value()` accessor; the brief's own interface list omits it and the plan
  has `WaveEncounter.buff_seed()` owning the run seed, so it was left out
  (dead-code discipline, same spirit as ruling 4). Trivial to re-add in Task 2
  if that task turns out to want it.
- `offer()`/`take()` return shallow duplicates: entries share the pool
  dictionaries. Tasks 2-4 only read `id`/`ops` (`PlayerStats.add_modifier`
  duplicates ops internally), so no mutation path exists today.
- `mini(3, remaining.size())` yields fewer than 3 cards once fewer than 3 buffs
  remain; spec only allows 2 picks/run, so offers are always 3 in practice.
- Font gate grew 79 → 97 glyphs (all buff copy); VT323 covers them, no BLOCKED.
- `assets/ui/fonts/vt323.ttf.import` appeared modified after `--import` but
  `git diff` shows no content change (line-ending/stat churn); left unstaged.
- No STATE/DECISIONS edits here — D-025 and state updates belong to Task 5.
