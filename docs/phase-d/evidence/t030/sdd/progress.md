# SDD ledger — plan: docs/phase-d/PLAN_T030_buff_choice.md

Branch: `phase-d/t030-wave-buff-choice` (stacked on `phase-d/t029-player-stats-sheet`; PR rebases onto main after #24 merges).
Spec: `docs/phase-d/UI_PROGRESSION_SPEC.md` §5/§6 (APPROVED). Model selection: unavailable — dispatches inherit the session model.
Base for Task 1: `2be9c61` (plan commit).

## Pre-flight scan

| Pair / Task | Produces vs consumes | Finding |
|---|---|---|
| T1 → T2 | `BuffPool.pool()/index_of`, `BuffKernel.offer/take/picked_ids/reset` | encounter calls exactly these; clean |
| T1 → T3 | entry `title/gain/cost` | cards + sheet read those keys; clean |
| T2 → T3 | `buff_offer`, `apply_buff`, `buff_seed`, `set_buff_pick_enabled`, `debug_force_buff_pending` | names consistent; clean |
| T3 → T4 | `present`, `auto_pick`, `encounter_path` | harness/capture use these; clean |
| T4 → T5 | observed numbers | docs only; clean |
| T1 self | `not kernel.take(...).size() > 0` precedence bug | ruling |
| T1 self | Dictionary `==` semantics not relied on | ruling |
| T2 self | reset assertion wording | ruling |
| T2/T3 | `wave_encounter.gd` edited by both (debug helper) | allowed, noted |
| T3 self | test mounting via root + `set_encounter` vs arena child | ruling |
| T4 self | play_arena `load_steps` must grow when adding the 3rd ext_resource | ruling |

## Rulings (pre-flight)

- Ruling: T1 negative-id assertion becomes `kernel.take(&"no_such_buff").is_empty()` — the plan line's `not x.size() > 0` is a precedence trap in GDScript — cost if wrong: none (test-only).
- Ruling: T1 compares the taken entry by `id` (and ops key count), not Dictionary `==` — Godot Dictionary equality semantics must not carry a gate — cost if wrong: a weaker but honest assertion.
- Ruling: T2 reset assertion is "buff_pick_enabled survives reset" (scene-level opt-in), not the plan's convoluted `not … == false` line — cost if wrong: reset semantics mis-documented in the test.
- Ruling: if seeds 4242/4241 happen to produce the same offer, the implementer may switch the second seed and must record the chosen pair in the report (deterministic, not weakened) — cost if wrong: none.
- Ruling: T3's test parents BuffChoice to the arena with `encounter_path = "../WaveEncounter"`; `set_encounter` remains only as a fallback seam if parenting proves awkward — cost if wrong: test-only coupling.
- Ruling: T4 bumps `play_arena.tscn` `load_steps` 3→4 when adding the BuffChoice ext_resource — cost if wrong: scene fails to load loudly.
- Ruling: STATE ≤150-line rule stays pre-existing-broken; T-030 updates compactly — cost as ruled in T-029.

## Progress
Task 1: complete (commits 2be9c61..9ae9ae1, review clean)
Task 1: minor (deferred): pool-op law is per-entry not per-op (single wrong key masked; spec §6.2 says every op)
Task 1: minor (deferred): offer()/take() share dictionaries with the pool (latent mutation risk; consumers read-only)
Task 1: minor (deferred): different-seed assertion is probabilistic (4242/4241 differ today)
Task 1: minor (deferred): mini(3, remaining) assumes >=3 remain (holds for 2 picks/run)
Task 2: complete (commits 9ae9ae1..92ec838, review clean)
Task 2: minor (deferred): death detection suspended in BUFF_PENDING (UI pause covers; auto-pick gap ~0 ticks)
Task 2: minor (deferred): apply_buff docstring stricter than guard (windows snapshot at swing start)
Task 2: minor (deferred): SWING_BASE_LENGTH is a third copy of 1.4; test does not assert mesh length
Task 2: minor (deferred): reach written twice in _apply_stats; could fold into one helper
Task 2: minor (deferred): run_reset emits before _start_run; readers see previous seed on that signal
Task 2: minor (deferred): direct property assignment bypasses kernel copy (setter exists)
Task 2: minor (deferred): apply_buff lacks the null guard set_buff_pick_enabled has
Task 2: minor (deferred): encounter glue has no committed test until Task 4 harness
Task 2: minor (deferred): BUFF_PENDING never-advance has no fail-first twin at kernel level
Task 3: fix round 1/5 (1 addressed, 0 open - sheet now 480x352 with truthful constant; commits c0263b8..f0c3e9e)
Task 3: complete (commits 92ec838..f0c3e9e, review clean)
Task 3: minor (deferred): present() has no BUFF_PENDING precondition (capture must only frame, not pick)
Task 3: minor (deferred): empty offer would open an unclosable modal (unreachable with 6-buff pool)
Task 3: minor (deferred): ESC test has no positive control; buff-row check can be vacuous if first offer is long_reach
Task 3: minor (deferred): CARD_INSET duplicates GAP/2; PANEL_SIZE hardcodes 544x360
Task 3: minor (deferred): card_count/card_text bounds disagree; stale after close
Task 3: minor (deferred): no _exit_tree unpause / re-disable of pick-enabled on teardown
Task 3: minor (deferred): auto_pick ignores apply_buff false
Task 3: minor (deferred): keyboard Enter/focus untested until Task 4 L3/L4
Ruling: DECISIONS D-024/STATE still say 480x320 - Task 5 reconciles with a D-024 amendment note; historic plan/reports keep the old number. Cost if wrong: decision log contradicts the live constant.
Task 4: complete (commits f0c3e9e..c213f99, review clean)
Task 4: minor (deferred): T30.2 asserts mods_ok AND runs_ok (label vs meaning)
Task 4: minor (deferred): T30.3 duplicates T30.1 in normal mode
Task 4: minor (deferred): no-pick fault takes MAX_TICKS to red
Task 4: minor (deferred): L4 auto_pick gating has no automated coverage
Task 4: minor (deferred): card gain/cost copy wraps mid-phrase (fix assigned to Task 5, copy-only)
Task 4: minor (deferred): capture describes a synthetic WAVE 1 state without saying so
Task 4: minor (deferred): _grab ignores save errors; negative run rewrites buffs_closed.png
Task 4: minor (deferred): dmg/s caveat omits the teleport factor (17.5 not comparable to 4.8)
Task 4: minor (deferred): hardcoded "../BuffChoice" path instead of a const
Ruling: Task 5 includes the copy-only wrap fix in UiCopy (shorten gain/cost strings), re-runs coverage + capture, and views the new image. Cost if wrong: copy wording changes, tests assert titles only.
Task 5: fix round 1/5 (1 addressed, 0 open — "TICK" units restored in all short cost lines, T30.4 width law <=144 px enforced via shipped VT323 metrics, evidence recaptured at 1280x720 band_diff=195840/control 0; commits c72f220..69aa5fd)
Task 5: complete (commits c213f99..69aa5fd, review clean) — copy fit by measured 144 px (prefix lines), D-025 + D-024 note + STATE, full regression green, branch pushed
Task 5: minor (deferred, superseded): earlier 1152x648 capture note no longer applies; recapture at 1280x720 is committed
Ruling: copy fit is measured against the shipped font metrics and gated by T30.4 for every pool line (not just the 3 offered); cost if wrong: a copy/font drift fails the UI test loudly instead of shipping wrapped cards.
Final whole-branch review: base bfcaab8, head 69aa5fd; diff package .superpowers/sdd/PLAN_T030_buff_choice/review-bfcaab8..69aa5fd.diff (680c5c6 is PR #24's merge with tree equal to bfcaab8's, so the net delta is T-030 only).
Final review verdict: With fixes — Important: (1) DG2 test_buff_laws missing; (2) DG3 negatives are printer inversion only; (3) sheet lists buff titles but not gain/cost (spec §5). Triage fix-now: per-op pool law; DG3. Minor batch chosen: D-025 stale 16/17 count, quick-rhythm gain units, exact sheet/card geometry gate, stale T-029 sheet evidence. All other minors stay follow-ups (WaveHUD BUFF_PENDING, sheet wave status text, log-contract test, L4 auto_pick coverage, empty-offer guard, _exit_tree unpause, auto_pick false logging, capture save errors, synthetic-WAVE caption).
Ruling: sheet grows to 480x432 (4-grid) to carry name + LỢI/ĐỔI LẠI per active buff (max 2), per spec §5 + §7 "hộp sheet lớn lên theo nội dung"; content_minimum_size() gates the declared size; cost if wrong: sheet clips or wastes space, geometry test/capture catch it.
Ruling: DG3 gets real driver-level red paths (T30.5 forced BUFF_PENDING stall = missing resolve; T30.6 dirty-reset = buffs-not-reset-on-r) instead of production fault hooks; only the unmeasurable "no buff ⇒ dmg/s threshold" clause is amended in D-026; cost if wrong: gate wording narrows, behavior detectors still red on real regressions.
Ruling: quick-rhythm gain becomes two TICK lines ("HỒI ĐÒN -3 TICK" / "COMBO +4 TICK") — fits 144 px per line and removes mixed units; card capture is recaptured; cost if wrong: copy-only.
Fix round 2/5 dispatched: brief .superpowers/sdd/PLAN_T030_buff_choice/final-fix-brief.md, implementer report final-fix-report.md.
Fix round 2/5 result: commits c92f079..6ed704d (laws/per-op kernel, sheet name+gain/cost at 480x432 with content gate, T30.5/T30.6 driver negatives, D-026, recaptured evidence). Full regression: 23/23 suites exit 0, 0 SCRIPT ERROR; stat-source clean 77 + selftest violations=1 allowed_hit=0; harness normal 6/6 and negative/stall/dirty-reset exit 1 with T30.3/T30.5/T30.6 red; L3 sheet band_diff 207360 (480x432) / buffs 195840 / controls 0; images sheet_open + buffs_open + controls viewed by controller.
Scoped re-review (69aa5fd..6ed704d): findings 1-5 and 7 closed; finding 6 partial (STATE line 5 + T-030 narrative still carried pre-fix counts). New minors: body_text/content_minimum_size pre-_ready null guard, per-buff pairing test could pass cross-wired, unknown-key sentinel has no committed negative. Implementer concerns adjudicated acceptable (stall collateral reds, one-shot dirty fixture, 98->99 glyph count).
Ruling: STATE stale counts corrected in a docs-only commit (99 glyphs, theme 15, kernel 32, sheet 14, 23/23); no code change after the reviewed head. Cost if wrong: docs drift only.
Ruling: the three new minors are parked for the T-031 cleanup (no current caller for the pre-ready guard; the L3 image proves per-buff pairing today; the sentinel path was proven while building). Cost if wrong: weaker future regression net, no runtime risk.
Final validation on the integration tree: 23/23 unit suites exit 0, 0 SCRIPT ERROR; stat-source clean 77 + selftest; docs-only delta after the reviewed code head. Plan complete; SDD reports archived to docs/phase-d/evidence/t030/sdd/ and this scratch workspace removed.
