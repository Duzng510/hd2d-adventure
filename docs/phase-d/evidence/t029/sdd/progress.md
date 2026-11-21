# SDD ledger — plan: docs/phase-d/PLAN_T029_stats_sheet.md

Branch: `phase-d/t029-player-stats-sheet` (no worktree; project convention is one branch per task in the main worktree, AGENTS.md).
Spec: `docs/phase-d/UI_PROGRESSION_SPEC.md` (approved 2026-11-21 — read).
Model selection: unavailable in this harness — every dispatch inherits the session model (Qoder CLI integration note recorded).
Base for Task 1: `d5113fb` (plan commit).

## Pre-flight scan

| Pair / Task | Produces vs consumes | Finding |
|---|---|---|
| T1 → T2 | PlayerStats getter names | T2 edits call exactly the names T1 defines; clean |
| T2 → T4 | `combat.stats`, hp via Callable | sheet consumes `set_sources(stats, hp Callable, encounter)`; clean |
| T3 → T4 | `Hd2dTheme.GAP=16`, `UI_FONT_SIZE=14`, `UiCopy.*` | `GAP / 2`, `+7`, const names all match; clean |
| T4 → T5 | sheet mount paths `../Player/PlayerCombat`, `../WaveEncounter` | both are children of GroveArena; clean |
| T1 self | test values vs implementation | negative stacking value 27 is arithmetically 32 → ruling |
| T4 self | spec §5 "exactly one grab_focus" vs plan code | plan code omitted it → ruling |
| T4 self | damage assertion `contains("10")` also matches the cycle row | ruling |
| T4 self | `_ready`-only source resolution vs child ready order | ruling |
| T5 self | STATE ≤150 lines vs current 179 | ruling |
| all | shared files | no two tasks edit the same file; only T2 touches player_combat.gd |

## Rulings (pre-flight)

- Ruling: T1 negative-control stacking value corrected 27 → 32 (comment must show stacking arithmetic) — the inverted control should name what it would catch — cost if wrong: a misleading test comment.
- Ruling: `CharacterSheet.open()` calls `_close.grab_focus()` — spec §5 requires exactly one initial focus — cost if wrong: focus lands on Close, trivially changed.
- Ruling: T4 damage assertions must match the full formatted row: `"10  (0.59 dmg/tick)"` before the buff and `"13  (0.76 dmg/tick)"` after — bare `"10"` also matches the cycle row — cost if wrong: a format change breaks the test visibly.
- Ruling: `CharacterSheet.open()` retries source resolution when `_stats == null` — grove_arena child ready order is not guaranteed to put PlayerCombat first — cost if wrong: a null-safe no-op.
- Ruling: STATE.md is updated compactly; T-029 does not force-trim it to ≤150 lines because it already exceeds that (pre-existing) — cost: the rule stays violated until a docs-cleanup task.

## Progress
Task 1: complete (commits d5113fb..c007775, review clean)
Task 1: minor (deferred): tests/test_player_stats.gd:40 comment arithmetic wrong — replacement gives floor(10*2.0*0.9)=18, not floor((10+2)*2.0*0.9)
Task 1: minor (deferred): per-call StringName allocations in PlayerStats._value (harmless at current read rates)
Task 1: minor (deferred): active_modifiers(), dodge_* getters, clear_modifiers no-emit path unasserted
Task 1: minor (deferred): tests construct CombatTuning.new() instead of loading combat_tuning.tres (pre-existing pattern)
Task 2: fix round 1/5 (2 addressed, 0 open - shared-tuning mutation, spec §3.2 item 3; commits d7e462e..7d1d6bf)
Task 2: complete (commits c007775..7d1d6bf, review clean)
Task 2: minor (deferred): T-027 negative baseline now rests on CombatTuning.new() == .tres defaults (66/66 verified today); .duplicate() would be safer
Task 2: minor (deferred): t027 driver hardcodes GroveArena/Player/PlayerCombat path
Task 2: minor (deferred): spec §3.3 stale line refs (54→56, 210→219, 150→154) and "guard is_dead()" wording
Task 2: minor (deferred): _apply_stats never clamps hp when max shrinks (plan-mandated; no shrink buff exists yet - carry to T-030)
Task 2: minor (deferred): stats.changed → _apply_stats path unexercised by any test
Task 3: BLOCKED at font gate (m5x7 missing 17 Vietnamese glyphs incl. Ơ/Ư/U+1EA0 block + em dash); nothing committed
Ruling: user chose "find another pixel font"; VT323 (Google Fonts, OFL 1.1) verified by raw cmap parse: 568 codepoints, all 17 missing glyphs + full ASCII present — replaces m5x7. UI_FONT_SIZE 16 (8x16 terminal grid), new TITLE_FONT_SIZE 32; m5x7.ttf deleted (never committed). Cost if wrong: if VT323 renders blurry at 16px in L3, bump to 32 (Task 5 capture decides).
Ruling: theme-font law changes from "% 7" to "% 16" (native grid of the shipped font). Cost if wrong: law follows a font swap and must be updated with it.
Task 3: fix round 1/5 (1 addressed, 0 open - HUD copy routed through UiCopy; commits 8a8664e..1a30d03)
Task 3: complete (commits 7d1d6bf..1a30d03, review clean)
Task 3: minor (deferred): WaveHUD still outside the theme/palette (restyle needs L3 + decision - Task 5 triage)
Task 3: minor (deferred): load_dynamic_font bypasses the import; allow_system_fallback=true would mask missing glyphs (gate reads cmap directly)
Task 3: minor (deferred): font-size checks self-satisfying; COST unused in build(); HUD_PLAYER/WAVE/ENEMIES consts unreferenced
Task 3: minor (deferred): stale m5x7 text in spec/plan docs - Task 5 must fix spec §7/D-024 to VT323 + 16 px law
Task 3: minor (deferred): DebugHUD / combat_hud / title_screen copy still outside UiCopy (pre-existing)
Ruling: CharacterSheet.process_mode = PROCESS_MODE_ALWAYS (plan's WHEN_PAUSED would mean the sheet never processes input while unpaused, so ESC could never open it). Spec §5 must be synced in Task 5. Cost if wrong: sheet processes while unpaused (it is hidden then, negligible).
Ruling: sheet title uses Hd2dTheme.TITLE_FONT_SIZE (32), not UI_FONT_SIZE + 7 (m5x7-era arithmetic). Cost if wrong: title looks one step larger, trivially changed.
Task 4: complete (commits 1a30d03..9011481, review clean)
Task 4: minor (deferred): _current_hp() invalid-callable fallback renders max/max (unreachable today)
Task 4: minor (deferred): open() with unresolved sources pauses onto a placeholder sheet
Task 4: minor (deferred): buff row shows raw snake_case modifier ids (T-030 adds display names)
Task 4: minor (deferred): negative control inverts exactly one check (plan-mandated)
Task 4: minor (deferred): source-retry branch verified only by the Task 5 arena mount
Task 4: minor (deferred): refresh() assumes _build_ui ran; _encounter/_encounter_path dead until T-030
Task 4: minor (deferred): centering proven only on a 64x64 headless viewport; L3 decides
Task 5: complete (commits 9011481..aa257f0, review clean)
Task 5: minor (deferred): DECISIONS lit range cites 230128 not present in any recorded run
Task 5: minor (deferred): capture P29.1 unfalsifiable + lit threshold low (inherited capture_title pattern)
Task 5: minor (deferred): save_png failure not counted; negative run overwrites sheet_closed.png
Task 5: minor (deferred): DECISIONS "17 glyph + em dash" wording (16 letters + em dash = 17)
Task 5: minor (deferred): "mounted last" wording vs Reward Node3D after it
Task 5: minor (deferred): report line-count slip 179→183 (+5 net)
Task 5: minor (deferred): "Đang làm (≤2)" now 6 rows (pre-existing pattern)
Final review: With fixes (1 Critical C1 spec buff keys, 4 Important I1 reach, I2 live tempo/dodge refresh, I3 imported font, I4 tres parity, M3 reset/clamp)
Final fix wave: complete (commit aa257f0..5808cb8, re-review: all findings addressed, no new Critical/Important)
Final parked (with rulings):
- Ruling: spec:57 general rule sentence is wrong for move_speed (key player_move_speed) while its own example is right — park; T-030 kickoff fixes it before authoring buffs. Cost if wrong: a future op key invented from the rule silently no-ops (pool rows are correct).
- Ruling: SwingArc mesh does not resize with reach (visible arc 1.4 m at x=0.7) — T-030 must resize the arc when long_reach ships. Cost if wrong: hitbox reaches 0.4 m past the drawn arc.
- Ruling: STATE check counts/lit range went stale in the fix wave (16/9 → 33/13; 230128) — park for T-030 kickoff docs. Cost if wrong: status doc understates test counts until then.
- Ruling: font coverage test uses raw load_dynamic_font while the theme uses the imported FontFile — coverage is still a real cmap check; park. Cost if wrong: two font paths to keep in sync.
- Ruling: negative capture run overwrites sheet_closed.png so closed/control are byte-identical — already-deferred capture-runner quirk; park. Cost if wrong: committed control pair less illustrative.
