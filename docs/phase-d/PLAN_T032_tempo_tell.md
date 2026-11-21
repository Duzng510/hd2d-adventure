# T-032 Implementation Plan — tempo tell on the self-marker ring

**Goal:** Make the T-027 tempo cost *visible*. The player currently pays +4/8/12 recovery ticks without any signal that the swing got slower (D-019 accepted risk 3). T-032 draws the paid tier as a pale-cyan arc inside the existing feet ring, so the message is read where the player already looks, and nothing else changes.

**Architecture:** `TempoFatigue.level()` is derived from `frames()` (never from `_chain`), so the display can never lead or disagree with the cost. `PlayerCombat` refreshes the level once per physics frame and emits `fatigue_level_changed` **only on transition**. `GroveArena` — which already owns the ring node (T-026) — holds four pre-generated textures and swaps `albedo_texture`. `PlaceholderTextures.make_self_marker(diameter, level)` gains one optional parameter; `level == 0` is byte-identical to today's texture, which is what keeps the T-026 evidence valid.

**Tech Stack:** Godot 4.7.2 typed GDScript; physics-frame timing (60 tick/s); headless `SceneTree` suites auto-discovered by `tools/run_tests.mjs`; renderer-mode capture scene for L3; `PixelGrid`/texel law D-008 (1 texel = 0.05 m).

**Spec:** debt carried in `docs/DECISIONS.md` D-019 ("rủi ro được chấp nhận" item 3) and `docs/STATE.md` *Next* item 1. Branch `phase-d/t032-tempo-tell`, cut from `main` at `4d92622` (after D-028 repo hygiene). New decision: **D-029**.

## Global Constraints

- Godot exe: `"C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"` — never the `_console.exe` wrapper. In bash: `GODOT="C:/Users/My Lenovo/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"`.
- **No behaviour change.** `combat_tuning.tres` untouched; `frames()` untouched; `AttackState`, hitboxes, enemy AI, telegraphs untouched. `test_combat_kernel` must stay at **107 checks** and `node tools/run_evidence.mjs` at `failures=0` with the same E1–E5 verdicts. The law `fatigue_decay < fatigue_max` (D-023) is not re-litigated here.
- **One source of the number.** `level()` is computed inside `TempoFatigue`; the view only maps an `int` to pixels. `node tools/check_stat_source.mjs` stays clean and `--selftest` stays red-capable.
- **Meaning collisions (D-017):** the ring keeps `PALETTE.tunic` green (position). The tell uses one **new** palette entry `"tempo"`, deliberately not `aim` yellow (reticle), not `TELEGRAPH_COLOR` orange `(1.0,0.55,0.2)` (enemy telegraph), not the red hit-flash on `_sprite.modulate`.
- **Pixel-grid lock (D-008):** the marker quad stays 0.9 m → 18 texels; the arc lives on whole texels inside `d ≤ 6` so it never merges with the ring band (`7 ≤ d ≤ 9`) or the four diagonal notches at `d = 8`.
- **No per-frame allocation:** 4 textures built once at `_ready`; the runtime path is a single `albedo_texture` assignment per transition. Dev box is Intel UHD.
- `no_depth_test` + `render_priority = 10` stay as T-026 set them (TDD: the tell must survive a boss body standing over the player, and that property is re-measured, not assumed).
- Ring is **not** rebuilt as a second node: one quad, two messages on two channels (colour = position, arc = tempo).
- `@export var show_tempo_tell := true` in `grove_arena.gd`, same family as `show_self_marker` — the escape hatch if L4 finds it noisy.
- Defaults keep other scenes green: `make_self_marker(diameter)` (one arg) still compiles everywhere and returns the T-026 texture.
- Tests: exactly one `quit()` per path; negative mode reads `OS.get_cmdline_user_args().has("negative")`. Stage by explicit path, never `git add -A`; commit every new `.gd`/`.tscn` with its `.uid`; never commit `.godot/`.
- Do not touch the user's dirty evidence paths (`docs/phase-c/evidence/t023/evidence_report.*`, `docs/phase-c/evidence/t027/session5/`); run E1–E5 as scenes if `run_evidence.mjs` would rewrite them.
- L4 belongs to the user. Whether a player *learns* the cadence from the tell is not answerable by code, log, or AI analysis (MASTER_PROMPT 8.1).

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `scripts/combat/tempo_fatigue.gd` | modify | `level()` + `level_max()` derived from `frames()` |
| `tests/test_tempo_fatigue.gd` | modify | tier↔cost identity, ceiling, decay step-down, dodge wipe, negative |
| `scripts/combat/player_combat.gd` | modify | `fatigue_level()` / `fatigue_level_max()` probes + `fatigue_level_changed` (edge-only) |
| `scripts/phase_a/placeholder_textures.gd` | modify | `PALETTE.tempo`; `make_self_marker(diameter, level := 0)` inner arc |
| `tests/test_self_marker_art.gd` | create | art laws: level 0 byte-identical to T-026, one slot = 1/3 turn, arc ⊂ `d ≤ 6`, whole texels |
| `scripts/phase_c/grove_arena.gd` | modify | 4 textures at load, `show_tempo_tell`, connect signal, texture swap |
| `scripts/phase_c/t032_tell_driver.gd` + `scenes/phase_c/run_t032_tell.tscn` | create | L2: mash vs paced level trace, emits == transitions, tell-off path |
| `scripts/ui/capture_tempo_tell.gd` + `scenes/ui/capture_tempo_tell.tscn` | create | L3: per-level box diff ≥40 px, control 0 px, lit pixels, occlusion kept |
| `docs/DECISIONS.md` | modify | D-029 |
| `docs/STATE.md` | modify | T-032 row + *Next* item 1 struck |

---

### Task 1: `level()` in the kernel

**Interfaces:**
- `TempoFatigue.level() -> int` — `frames() / step_frames` (integer division), so `level()*step ≤ frames() < (level+1)*step` holds for **any** tuning, including a cap that is not a multiple of the step.
- `TempoFatigue.level_max() -> int` — `max_frames / step_frames` (= 3 today, never hardcoded downstream).

- [ ] Step 1: extend `tests/test_tempo_fatigue.gd` with checks that fail first: `level() == 0` through the free allowance; `level()` 1/2/3 on the 4th/5th/6th swing; `level()` stays `level_max()` when the chain keeps running; one `tick_idle()` period drops exactly one tier; `clear()` → 0. Add the identity check `fatigue.level() * STEP == fatigue.frames()` at every point of the existing mash walk.
- [ ] Step 2: run → red (method missing). `"…Godot…exe" --headless --path . -s res://tests/test_tempo_fatigue.gd`.
- [ ] Step 3: implement `level()` / `level_max()` in `tempo_fatigue.gd`.
- [ ] Step 4: run → green, check count printed; then `negative` mode must exit 1 on a tier check (extend the existing `_negative` fork, do not add a second quit path).
- [ ] Step 5: `"…exe" --headless --path . --check-only --script res://scripts/combat/tempo_fatigue.gd` exit 0.

### Task 2: edge-only signal on `PlayerCombat`

- [ ] Step 1: `signal fatigue_level_changed(level: int)`; `var _tell_level := 0`; `_refresh_tempo_tell()` called once from `_physics_process` (not from the four `_tempo` call sites — the decay path must not be missed) that emits only when `_tempo.level() != _tell_level`.
- [ ] Step 2: read-only probes `fatigue_level()` and `fatigue_level_max()` next to the existing `fatigue_frames()` (line 316).
- [ ] Step 3: L1 `--check-only` on `player_combat.gd`; regression `test_combat_kernel` **107 checks** exit 0 and `test_stats_live` exit 0.

### Task 3: the arc in the texture

**Geometry (0.9 m → 18×18 texels, `center = 8.5`, `radius = 9`):**
- Ring band `7 ≤ d ≤ 9` (unchanged), diagonal notches at `d = 8` (unchanged).
- Tell band `5 ≤ d ≤ 6`; a slot spans `TAU / slots` starting at top, clockwise. Slots = `level_max()`.
- Clockwise angle from top: `ang := fposmod(atan2(x - center, -(y - center)), TAU)` → 0 at 12 o'clock, growing clockwise.
- A texel is `tempo`-coloured when `5 ≤ d ≤ 6` **and** `ang < TAU * level / slots`, with `slots == level_max()` (3 today). Level 0 therefore paints nothing.

- [ ] Step 1: write `tests/test_self_marker_art.gd` (fails first): `make_self_marker(0.9, 0)` equals `make_self_marker(0.9)` equals the current texture pixel-for-pixel; each level adds strictly more `tempo`-coloured texels than the one before; no `tempo` texel where `d < 4` or `d > 7` (gap to the band); texel count `== 18`; `PALETTE.tempo` is not `tunic`/`aim`/`outline`.
- [ ] Step 2: add `PALETTE.tempo = Color8(150, 200, 235)` and the `level` parameter; default keeps every existing caller on the T-026 art.
- [ ] Step 3: suite green; new suite is picked up automatically → `run_tests.mjs` prints `26/26 suites green`.
- [ ] Step 4: `"…exe" --headless --path . --import` exit 0.

### Task 4: arena wiring

- [ ] Step 1: `_add_self_marker()` already builds a local `StandardMaterial3D` on its own `QuadMesh` (not a shared resource), so keep that material reference and set `material.albedo_texture`. When `show_tempo_tell`, build `_tell_textures[0..level_max]` once and connect `$Player/PlayerCombat.fatigue_level_changed` → swap the texture; when false, keep exactly the single T-026 texture and make no connection.
- [ ] Step 2: clamp the incoming level to `level_max()` in the consumer (view law, not a second calculation of the cost).
- [ ] Step 3: L1 on `grove_arena.gd`; L2 arena smoke `"…exe" --headless --path . res://scenes/phase_c/play_arena.tscn --quit-after 120` exit 0, no `SCRIPT ERROR`.

### Task 5: L2 flow evidence — DONE

`t032_tell_driver.gd` + `scenes/phase_c/run_t032_tell.tscn` (script on the **root**, so `_enter_tree` can set the export/tuning before the arena readies). Three bots, sampled on every physics frame:

- `T32.0` all three cadences still deal damage — the tell is not a nerf.
- `T32.1` the tier **charged at the swing decision**: mash = ceiling (3), paced = none (0), loose = one (1).
- `T32.1b` a paced player still *reads* tired mid-recovery (1), and the middle bot never sits on the ceiling (2). The mechanic's promise is about the decision instant, not about every tick — the first version of this check demanded tier 0 all through a paced run and was wrong, not the tell.
- `T32.2` every frame: `level == frames / step`, with `step` read through `PlayerStats` so `check_stat_source.mjs` stays clean.
- `T32.3` `emits == transitions` (41 == 41) with zero repeated levels. Two false alarms were fixed in the harness, not the gate: per-loop sampling missed the reset tick between runs, and the last edge lands one frame after the sample that saw it, so the stream is allowed to settle before the count.
- `T32.3b` the ring material really holds a different texture at the ceiling tier.
- `T32.4` mode `tell-off`: arena connects nothing, the cost is still charged (tier 3), the art never swaps — the export hides the drawing only.
- `T32.5` a synthesized dodge (`Input.action_press`) drops the tier 3 → 0 within a tick.
- Rulers that must go red: `-- negative` (free allowance 100000) → `T32.1`/`T32.1b`/`T32.3` red, exit 1; `-- broken-wire` (arena consumer disconnected) → `T32.3b` red, exit 1. `-- trace` prints the EMIT/TRACE streams for review.

### Task 6: L3 capture (renderer mode, not `--headless`)

`"…exe" --path . res://scenes/ui/capture_tempo_tell.tscn --fixed-fps 60 --quit-after 1`, 1280×720, box = 80 px around the player's feet (the T-026 ruler, reused so the two tasks measure the same thing):
- `P32.L` level 0 vs 1, 1 vs 2, 2 vs 3: `band_diff ≥ 40 px` each step. Measured on the grid (not predicted): the shipped arc paints **12 texels per tier** (cumulative 0/12/24/36, `test_self_marker_art` 11 checks green), i.e. ≈192 screen px at 4 px/texel — 4.8× the gate, so a result near 40 px means the arc geometry is wrong, not that the tell is weak.
- `P32.C` control: same pose, same level, second capture → `0 px`.
- `P32.S` lit-pixel check so an empty control cannot pass green (lesson P26.3).
- `P32.O` boss body placed over the player at each level: the arc still changes pixels inside the box → the tell inherits `no_depth_test`, it is not silently occluded.
- `P32.D` damage numbers (T-031) at the same tick: count overlap of tempo texels with the number labels' box — the two readouts must not sit on each other.
- Dump PNGs to `docs/phase-d/evidence/t032/` and **view them**; a green diff without a looked-at image is `IMPLEMENTED`, not `DONE`.

### Task 7: regression, docs, push

- [ ] `node tools/run_tests.mjs` → `26/26 suites green`; `test_combat_kernel` still 107.
- [ ] `node tools/check_stat_source.mjs` clean + `--selftest` red-capable.
- [ ] `node tools/run_evidence.mjs` → `failures=0` (B7.3 expectation unchanged: still 10/10 wins — the tell does not alter the cost).
- [ ] Draft D-029 (Decision / Reason / Bằng chứng / Rủi ro / Không đổi / Xác nhận) recording: level derived from `frames()` as the anti-drift law, the ring-as-carrier choice with the four rejected channels, the reserved `tempo` colour, and that L4 is still owed.
- [ ] `docs/STATE.md`: T-032 row under *Đang làm* with the measured numbers, strike *Next* item 1, add the L4 debt ("tell có giúp người chơi đổi nhịp hay không — chưa đo").
- [ ] Commit per task (`feat(T-032): …`, `docs(T-032): …`), push the branch once validation is green; no push on red.

## Acceptance criteria ↔ level

| AC | Statement | Level |
|---|---|---|
| AC1 | Each paid tier is visibly different from the previous one on the ring | L3 `P32.L` ≥40 px/step + L4 user sign-off on the images |
| AC2 | The tell reads the same number the mechanic charges — one source | L2 `T32.2`, `test_tempo_fatigue` identity, `check_stat_source` |
| AC3 | No combat change: cadence, damage, enemy behaviour, existing gates | L2 `test_combat_kernel` 107, `run_evidence failures=0`, `T32.0` |
| AC4 | Readable under a boss body and switchable off | L3 `P32.O`, L2 `T32.4` |
| AC5 | A player learns to pace from it | **L4 only — not claimable by this plan** |

## Risks & limits

1. The ring already means "where am I"; adding an arc risks diluting both. Mitigated by channel separation (colour vs shape) and re-measured in `P32.O`; if L4 says the position read got worse, that is a D-029 risk to reopen, not a silent fix.
2. A tell without sound may still be unreadable mid-horde — 600+ enemies and damage numbers compete for the same feet region (`P32.D` measures it, does not assume it).
3. `level()` floors `frames()`, so a cap that is not a multiple of the step would display a tier slightly earlier than the full cost lands. Current tuning (12/4) has no gap; the identity check pins whatever tuning becomes true.
4. Nothing here makes mashing worse or better. If the goal is behaviour change rather than legibility, that is a tuning task with its own L4 protocol — out of scope by D-019.
