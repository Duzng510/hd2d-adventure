# PROJECT STATE
Cập nhật: 2026-11-20 (Project Day 2) | Commit: 331eff7 (T-020 tasks 1–2) | Branch: `phase-c/t020-ranged-projectile` (T-020)

## Phase hiện tại
Phase B — Combat Prototype (bắt đầu 2026-11-20). Phase A thoát theo **D-009 waiver**: gates 1–5 đạt (D-007/D-008 Accepted; lưới pixel khóa, anchor_dev = sprite_dev = 0, residual 0 px); L4 playtest Phase A **Not Run** — cảm nhận gom vào L4 Phase B cùng build. **T-008 DONE**: gate definitions Phase B (B1–B7, D1–D3) user xác nhận 2026-11-20; COMBAT_SPEC APPROVED; `combat_tuning.tres` + physics layers 3–6 + InputMap combat sẵn sàng; D-010 mouse snapshot. **T-009 DONE**: kernel thuần logic (AttackState/InputBuffer/DodgeState/Health/HitRegistry) + test 92 checks; negative control fail đúng 3 check duplicate (exit 1). **T-010 DONE**: player combat (hitbox/hurtbox Area3D, mouse-snapshot hitbox, swing arc, hitstop, combat log CSV, F1 overlay) — log in-scene 1 hit/1 damage cho 1 swing, hit trong active window, hitstop +3 tick; 5 ảnh evidence đã xem. **T-011 DONE**: Grunt AI thuần logic (idle→chase→telegraph→active→recovery, alert event, telegraph lock-in) + node (chase, telegraph visual, damage player, death); test 16 checks; capture 6 ảnh: telegraph 20 frame đúng tuning, 1 hit/attack, player→Grunt 1 hit/1 damage, player death log. **T-012 DONE**: encounter loop (thắng/thua/reset R sau 120 tick, 10 run liên tiếp headless) + HUD HP trạng thái; 4 ảnh HUD đã xem; capture có `encounter_win` (3 đòn, frame 90) → reset 210 → `encounter_lose` 542. **T-013**: Playtest Brief sẵn sàng (`docs/phase-b/PLAYTEST_BRIEF.md`) — chờ user L4. **T-014 DONE**: automated gate B2/B3/D Passed với negative controls (B2: 12 swing 1 hit/damage, kernel 98 checks; B3: 10 trial alert 0 tick, telegraph 1.292, wall_min 0.350; D1–D3 đủ evidence); B4.1/4.2 đạt, B4.3 chờ L4; ẩn placeholder telegraph quanh player trước L4. **T-015 DONE**: L4 session 13 run liền (11 W hợp lệ, 2 run user cố ý đứng yên bị loại, 12 reset, 0 SCRIPT ERROR) + dodge run riêng (20 Space, W) — B1/B4/B5/B6 Passed; B7 Incomplete vì B7.3 **Not Run** (chưa test spam thuần, user chưa muốn thêm cơ chế); Phase B exit chưa đạt. **T-016 DONE**: harness spam 10 run — **10/10 W**, 87 tick/run, mỗi run ăn 1 hit mà không chết; passive control 10/10 L (332 tick/run) → **B7.3 Fail, B7 Failed**. **D-012 waiver (MP 8.6)**: user duyệt thoát Phase B 2026-11-20 — B7 giữ Failed; cơ chế GDD 6.8.7 ở backlog, B7.3 phải test lại khi cơ chế được thêm. **Phase C kickoff (T-017)**: user chốt scope 2026-11-20 — 3 vai trò (Grunt + Swarm + Ranged), mini-boss 2 phase, reward shortcut + hồi máu; `docs/phase-c/OPERATIONAL_DEFINITIONS.md` (C1–C3, E1–E5, D1–D3) **CONFIRMED** 2026-11-20 (user "y"); D-013 ghi scope. **T-018 DONE**: arena `scenes/phase_c/grove_arena.tscn` (player + camera + 3 trụ fade + Gate placeholder) + wave kernel thuần logic (3 wave 5/4/1, pause 60 tick, reset, win/lose) + `WaveEncounter`/`WaveHUD` + Grunt scene tái dùng AI T-011; harness 10 run full wave flow `runs=10 wins=10 losses=0 max_wave=3 reset_checks=true ticks=10292` exit 0 (negative exit 1); cổng/reward còn placeholder (T-022). **T-020 DONE**: Ranged + projectile — kite band 3.5–7.0 m, ngoài max không engage/bắn, telegraph 24 (≥ floor 18), active 4, recovery 30, projectile 6 m/s/lifetime 120 tick/damage 8; wave 2 = 2 Swarm + 2 Ranged, reset clear projectile; log `projectile_fire/hit/despawn` (+`damage`) theo attack_id; harness `run_t020_ranged` `checks=14 failures=0` exit 0, negative (range gate 100 m) `fires=2` → ASSERT E2.1 exit 1; regression t018 `runs=10 wins=10 max_wave=3 ticks=6902`, t019 `runs=3 wins=3 swarms=3 ticks=2072`.

## Build: chạy được? (có/không) — cách chạy
Có (scene load được). Scene chính: `res://scenes/phase_a/phase_a_playground.tscn`. **Chạy không cần mở editor: `run.bat` ở root, hoặc VSCode Ctrl+Shift+B (task "godot: run game", `.vscode/tasks.json`)**; phím trong game: WASD di chuyển, chuột aim, LMB đánh (combo 3 hit), Space né, R reset encounter, F1 hitbox/hurtbox, P đổi persp/ortho, L frame log. HUD: HP player/Grunt + trạng thái (ĐANG ĐÁNH / THẮNG / THUA). L2 Passed: headless `--quit-after 120`, EXIT=0, không lỗi. Visual G1–G3 + lighting đã xem thật (Vulkan 1.4.323 Forward+ / Intel UHD, 1280×720).

## Tiến độ MVS
MVS-AC1…8 (GDD mục 0, PROPOSED): chưa kiểm chứng — chưa có build chơi được.

## Tính năng (implemented / mức validation)
- Bootstrap `project.godot` (Forward+) + docs: L1 Passed (`--import` EXIT=0).
- T-001 định nghĩa vận hành gate Phase A: user xác nhận 2026-11-20.
- T-002 scene Phase A (XZ, camera follow + toggle P, sprite placeholder code-gen, movement WASD, HUD + frame log L):
  - L1 Passed: 7 script `--check-only` EXIT=0.
  - L2 Passed: headless load 120 frame EXIT=0, không lỗi.
  - L3 Passed: `test_movement_model` EXIT=0 (6 groups, 100 reversals); negative control mirror EXIT=1 (harness bắt được sai số).
  - Visual G1–G3: Not Run (cần renderer thật).
- T-005 capture + đánh giá G1 (renderer thật, input mô phỏng InputMap):
  - L3 Passed G1.1–G1.4 về movement/camera: drift z=0, rẽ tức thì không trượt, dừng đúng mặt tường z=−2.4000 (không xuyên/jitter), 5 đảo hướng facing flip đúng, camera snap không giật. CSV 601 frame + 7 PNG đã xem.
  - Not Run: facing dọc (placeholder chỉ L/R), shimmer (cần video). Feel chờ L4.
  - Evidence: `docs/phase-a/evidence/g1/`; kết quả: OPERATIONAL_DEFINITIONS mục 6 + 8.
- T-003a aim marker + đánh giá G2 (renderer thật, warp chuột 5 vị trí):
  - L1 Passed (6 script), L2 Passed (load sạch sau sửa `unproject_position`), L3 `test_aim_model` PASS 6 checks + negative control FAIL exit 1.
  - G2 math pass: offset `unproject_position(aim)` vs mouse = 0 mọi điểm. Visual: center/right/top/bottom pass; **left FAIL visibility** (reticle bị Block che) → chuyển G3.
  - Evidence: `docs/phase-a/evidence/g2/`; kết quả: OPERATIONAL_DEFINITIONS mục 6 + 9.
- T-003b occlusion rule + đánh giá G3 (renderer thật, 3 zone before/after):
  - L1 Passed, L2 Passed (sau sửa `get_viewport().world_3d` + lazy collect group), capture EXIT=0.
  - Quy tắc **fade vật che** (alpha 0.25 trên ray camera→player & camera→aim), nhất quán 3 tình huống; telegraph/player/reticle không fade.
  - G3.1/3.2/3.3 Pass (before che khuất → after đọc rõ). G2.2 left đọc được khi bật fade.
  - Evidence: `docs/phase-a/evidence/g3/`; kết quả + quy tắc: OPERATIONAL_DEFINITIONS mục 6 + 10. Quy tắc PROPOSED chờ user chốt ở T-004.
- T-004 Art Spec + DECISIONS + lighting fix + run file:
  - `docs/phase-a/ART_SPEC.md` (đo từ scene thật) — **user xác nhận 2026-11-20 = Gate 4**.
  - DECISIONS: **D-006 Accepted** (XZ-plane, aim ground y=0, fade 0.25); **D-007 Proposed** (persp FOV35 + snap; ortho thử qua P; chốt sau L4).
  - Lighting: scene `ambient_light_source` 2→3 (SKY). Capture `evidence/lighting/after_center.png` đã xem: mặt khuất + bóng hết đen tuyền (đối chiếu `g2/g2_1_center.png` trước-fix). L1/L2 sạch, capture EXIT=0.
  - Run file: `run.bat` + `.vscode/tasks.json` (Ctrl+Shift+B) — chạy game không mở editor.
- T-006 pixel-grid + shimmer harness (branch `phase-a/t006-pixel-grid`):
  - `scripts/phase_a/pixel_grid.gd` (math thuần) + `tests/test_pixel_grid.gd`: L3 PASS 17 checks, negative control `-- negative` FAIL exit 1.
  - `camera_rig.gd`: thêm `pixel_size`, `snap_to_pixel` (mặc định tắt, giữ hành vi G1–G3), `apply_mode()`, `px_per_unit()`. `debug_hud.gd`: thêm dòng readout texel/aspect/snap.
  - `capture_pixel.tscn` + `pixel_capture_driver.gd`: 6 config × 24 frame, CSV 144 dòng + 18 PNG (đã xem). L1 5 script EXIT=0, L2 playground EXIT=0, capture EXIT=0.
  - Kết quả: texel aspect 0.6247 mọi config (FIXED_Y + camera nghiêng); ortho9 = 4.000 px/texel ngang; snap khóa world crawl ortho (residual 7406→347) nhưng không cứu persp (18013→18681) và gây sprite crawl (player_dev 0→0.3334). OPERATIONAL_DEFINITIONS §12; D-008 Proposed.
- T-007 implement D-008 Accepted (user chọn "Ortho + giữ FIXED_Y"):
  - `camera_rig.gd`: ortho mặc định + `texel_scale = 4` (size tự theo viewport), `snap_to_pixel = true`, `process_priority = -1`, xử lý resize. `player_controller.gd`: `visual_snap` lượng tử hóa vị trí hiển thị sprite về integer px, logic giữ nguyên.
  - Capture 7 config vào `evidence/pixel_t007/` (21 PNG đã xem + CSV 168 dòng); metric sửa sang đo sprite thay vì logic origin.
  - Kết quả: config đủ gói `anchor_dev = sprite_dev = 0.0000`, residual 0 px; thiếu visual snap sprite crawl 0.3334 → metric fail-first. OPERATIONAL_DEFINITIONS §13. L1 3 script + L2 + L3 exit 0, capture exit 0.
- T-009 combat kernel (`scripts/combat/`):
  - `attack_state.gd` (frame convention startup/active/recovery, combo window + cap), `input_buffer.gd` (expiry theo tick), `dodge_state.gd` (i-frame window), `health.gd`, `hit_registry.gd` (1 hit/swing/target, `enforce` để negative control).
  - `tests/test_combat_kernel.gd`: 92 checks — ranh giới frame, combo, buffer, iframe, health, 100 swing 0 duplicate; `-- negative` fail đúng 3 check registry. L1 6 script exit 0; L3 positive exit 0, negative exit 1.
- T-011 Grunt (`scripts/combat/grunt_ai.gd` logic thuần + `grunt.gd` node):
  - AI: idle→chase→telegraph→active→recovery, `alert` là event, telegraph lock-in hướng/duration; state/frame test headless 16 checks (+ negative telegraph 1 frame → exit 1).
  - Node: chase tới attack range, telegraph visual (quad + body tint), đòn theo hướng snapshot, damage player (bỏ qua i-frame), player flash đỏ, death log + khóa input. Player→Grunt damage qua receiver fallback (hit/damage 10, 1 hit/swing).
  - Evidence `docs/phase-b/evidence/t011/` (6 PNG đã xem): telegraph (có overlay), active hit (player flash), recovery, player attack hit (Grunt flash trắng), player dead; CSV: telegraph 42→65 (20f + hitstop), attack 7 lần mỗi lần 1 hit, death frame 336.
  - Validation: L1 5 script exit 0; L2 exit 0; L3 16 checks exit 0 / negative exit 1; capture exit 0.
- T-010 player combat (`scripts/combat/player_combat.gd` + scene):
  - Hitbox/hurtbox `Area3D` layers 3/5 (player) + TrainingDummy layer 6; hitbox xoay theo **mouse snapshot** (D-010), damage query bằng shape/transform thật gated active tick; swing arc + dummy flash; hitstop 3 tick qua `CombatDirector` (max policy); combat log CSV `user://combat_log.csv` (in stdout + flush).
  - Evidence `docs/phase-b/evidence/t010/`: 5 PNG đã xem (D1 off/on, startup/active/recovery/end) + CSV: 1 hit + 1 damage/1 swing, hit frame 27 trong active 26–32 (hitstop kéo dài 3 tick).
  - Validation: L1 9 script exit 0; L2 playground exit 0; L3 kernel 97 checks exit 0, negative exit 1; capture renderer thật exit 0.
- T-016 B7.3 spam test (`scenes/phase_b/run_b7_spam.tscn`, `scripts/phase_b/b7_spam_driver.gd`):
  - Spam thuần 10 run (attack khi phase NONE, không dodge/move): 10/10 W, 87 tick/run, 30 hit player→Grunt, 10 hit Grunt→player, 0 player death; `evidence/b7/spam_combat_log.csv` + `spam_summary.txt`.
  - Passive control: 10/10 L, 332 tick/run, exit 0 (win detection không thể xanh vô điều kiện).
  - Kết luận: B7.3 Fail; B7 Failed; Phase B exit chưa đạt. Cần đúng một cơ chế (GDD 6.8 mục 7) hoặc waiver MP 8.6.
- T-015 L4 results (`docs/phase-b/evidence/b5`, `b7`):
  - Session 13 run: 11 W/2 L (2 L do user cố ý đứng yên → loại khỏi B5), 12 reset, engine log 0 SCRIPT ERROR; B5 Passed.
  - User chấm gộp Resp 4/5, Read 4/5 (11 run, mean 4.0); a/b/c 11/11 mỗi câu (33/33); x/n = 5/5 hit trong run hợp lệ (user báo hiểu 19/19 toàn session) → B1/B4/B6 Passed.
  - Dodge run riêng: 20 Space, 3 hit gây ra, 2 hit nhận, W → B7.1 Passed; 11 run thắng áp sát → B7.2 Passed (user-reported).
  - B7.3 Not Run: chưa test spam thuần; 11 run không Space nhưng user báo né bằng WASD; chưa thêm cơ chế theo ý user. Phase B exit chưa đạt (xem OPERATIONAL_DEFINITIONS §14).
- T-014 automated gate evidence (`scripts/phase_b/b2_swing_driver.gd`, `b3_trial_driver.gd`, `b3_capture_driver.gd`):
  - B2.2: 12 swing trong scene, Grunt reset mỗi swing → mỗi `attack_id` đúng 1 hit + 1 damage target 1 (value 10); negative tắt registry → 3 hit/damage mỗi swing, exit 1. `evidence/b2/` (CSV + summary).
  - B2.1: kernel test thêm `Health(30)` reset mỗi swing → 98 checks exit 0; negative fail 4/98 (duplicate + HP reset), exit 1.
  - B3: 10 trial độc lập — alert 0 tick sau khi vào detect range; telegraph tại 1.2917 ≤ 1.3; damage chỉ trong range; wall chase 240 tick min clearance 0.350, player_min 3.100; negative (attack_range=8) exit 1. `evidence/b3/` (CSV, summary, 2 PNG đã xem).
  - Ẩn `Player/Telegraph` placeholder Phase A (luôn hiện quanh player) để L4 không nhầm với telegraph Grunt; chỉ đổi visual.
  - B4.1 từ t011 CSV: active_start − telegraph_start = 20 (attack 1 = 23 do hitstop); B4.2 ảnh t011 đã xem; B4.3 chờ L4. D1/D2/D3 đủ evidence. Chi tiết: OPERATIONAL_DEFINITIONS §13.
- T-012 encounter loop (`scripts/combat/encounter_manager.gd`, `combat_hud.gd`):
  - Win (Grunt HP 0) / lose (player chết) → HUD banner, auto-reset sau 120 tick; R reset ngay (input, vị trí, HP, AI, phase, buffer/combo, registry, hitstop); log `encounter_win/lose/reset` (value = run index).
  - `run_t012_cycles.tscn` (headless 10 run): `runs=10 wins=0 losses=10 reset_checks=true ticks=4521` exit 0; negative (HP=0 sau reset) → `reset_checks=false` exit 1.
  - `capture_t012.tscn` (renderer thật): 4 PNG đã xem (fighting 100/30, win 0/30 THẮNG, after-reset 100/30, lose 0/100 THUA) + CSV win frame 90, reset 210, lose 542.
  - Capture dùng hook `debug_request_attack()` (đẩy input vào buffer đúng `_combat_frame`) vì press/release quanh `await physics_frame` không tới `_physics_process`; hook + `aim_override_*` mặc định off, ghi COMBAT_SPEC §11.
  - Validation: L1 2 script exit 0; L2 cycles exit 0; capture exit 0.
- T-008 Phase B khởi động (user duyệt thoát Phase A; D-009 waiver):
  - `docs/phase-b/OPERATIONAL_DEFINITIONS.md` (B1–B7, D1–D3, taxonomy, rubric) — **user xác nhận 2026-11-20**; `docs/combat/COMBAT_SPEC.md` APPROVED (v2 khóa frame convention, hitstop, input priority, log semantics; D-010 mouse snapshot).
  - `CombatTuning` + `combat_tuning.tres` (authoritative, HYPOTHESIS trong envelope GDD 6.4); InputMap LMB/Space/F1/R; physics layers 3–6 (AGENTS + D-005).
  - L1 2 script + L3 test 16 checks + L2 playground exit 0; commit f8288c4 + 943a691.
- T-018 Arena + wave encounter (`scripts/phase_c/`, `scenes/phase_c/`, `scenes/combat/grunt.tscn`):
  - `wave_kernel.gd` logic thuần: `State` INACTIVE/FIGHTING/PAUSED/WON/LOST, 3 wave (mặc định 5/4/1), pause 60 tick giữa wave, `wave_start_pending`, `reset()`, player chết → LOST; `test_wave_kernel.gd` 16 checks (negative bỏ qua alive_count exit 1).
  - `wave_encounter.gd`: spawn wave khi player vào `trigger_radius` quanh `player_spawn`, log `wave_start` (value 1-based) tại tick spawn, R reset, win/lose + auto-reset 120 tick; `wave_hud.gd`: HP player, wave, số enemy sống, trạng thái.
  - `grove_arena.tscn` (sàn 20×16 + tường + 3 trụ fade + Gate placeholder) + `grunt.tscn` (Grunt T-011 đóng gói scene, spawn runtime); `run_t018_cycles.tscn` harness aim/spam 10 run: `runs=10 wins=10 losses=0 max_wave=3 reset_checks=true ticks=10292` exit 0, negative `reset_checks=false` exit 1.
  - Validation: L1 `--import` + 4 script exit 0; L2 grove arena 120 frame exit 0; L3 kernel + harness như trên; visual/feel chờ L4.
- T-019 Swarm role + role-based composition (`scripts/combat/swarm.gd`, `scripts/phase_c/wave_encounter.gd`):
  - `swarm.gd` kế thừa Grunt qua hook tuning/`_log_entity`: HP 20, telegraph 18 (sàn GDD), active 4, recovery 20, damage 5, approach 3.125 (×1.25 Grunt), detect 6.0, attack_range 1.0; log entity `swarm`, cùng schema event với Grunt.
  - `wave_encounter.gd`: `enemy_scenes` role→scene + `wave_roles` role theo từng spawn, `wave_size()`/`enemies()`; wave 1 = 2 Grunt + 3 Swarm; wave 2/3 vẫn Grunt placeholder (chờ T-020/T-021).
  - Evidence: `tests/test_swarm_tuning.gd` 16 checks exit 0 (negative telegraph floor exit 1); `run_t019_swarm.tscn` 3 run `runs=3 wins=3 swarms=3 grunts=2 reset_checks=true` exit 0, negative (xóa mapping swarm) `runs=3 wins=2 swarms=0 grunts=2 reset_checks=false` exit 1; t018 regression `wins=10 max_wave=3 reset_checks=true` exit 0.
- T-020 Ranged + projectile (`scripts/combat/ranged_ai.gd`, `ranged.gd`, `projectile.gd`, `scenes/combat/ranged.tscn`, `projectile.tscn`):
  - `RangedAI extends GruntAI`: kite band [min 3.5, max 7.0], quá gần retreat, ngoài max advance/không engage, telegraph snapshot hướng, active start bắn đúng 1 projectile (`_on_active_start`).
  - `Ranged extends Grunt`: đọc `ranged_*` tuning, log entity `ranged`, `_move` theo `move_dir`; Grunt thêm factory `_create_ai()`, hook `_on_active_start()`, null-guard melee hitbox (hành vi Grunt/Swarm giữ nguyên).
  - `Projectile` Area3D: ray world (mask 1) + shape query player_hurtbox (mask 16), damage đúng 1 lần, despawn hit/wall/lifetime (value 1/2/3), hitstop như đòn khác; group `enemy_attack` + `enemy_projectile`.
  - `WaveEncounter`: wave 2 = 2 Swarm + 2 Ranged; `reset_run()` clear projectile; `CombatDirector.event_counts` cho harness đếm event.
  - Validation: `test_ranged_tuning` 23 checks exit 0 (negative telegraph floor exit 1); `test_ranged_ai` 16 checks exit 0 (negative bỏ range gate fail 4 assert exit 1); harness `run_t020_ranged` `checks=14 failures=0` exit 0, negative `fires=2` → ASSERT E2.1 exit 1; L2 arena 120 frame exit 0; t018/t019 regression + `test_combat_tuning`/`test_swarm_tuning`/`test_grunt_ai`/`test_combat_kernel`/`test_wave_kernel` xanh.

## Đang làm (≤2)
- (trống — T-020 DONE; tiếp theo T-021 Mini-boss 2 phase)

## Next (3–5)
- T-021 Mini-boss 2 phase → T-022 Reward | Dep: T-020 DONE
- T-023 Evidence E1–E5 automated + negative controls → T-024 L4 session 10 attempts | Dep: T-019…T-022
- B7.3 retest bằng harness spam khi cơ chế chống spam (GDD 6.8.7) được thêm | Dep: cơ chế được duyệt (D-012)
- Duyệt MVS-AC1…8 + đặt ngưỡng MVS-AC2 | Dep: user

## Later (backlog theo phase)
Phase C stretch (extended encounter, GDD mục 12) → Phase D MVS (field Verdant Frontier + dungeon 2–3 phòng + reward). Phase C không chặn MVS. Stretch 15–30 phút sau MVS.

## Chờ quyết định & Blockers
- MVS-AC1…8 đang PROPOSED — chờ user duyệt/sửa.
- Ngưỡng pass/fail playtest MVS-AC2 chưa đặt (GDD: lần đầu chỉ tạo baseline).

## Known issues
- (T-021) Wave 3 dùng grunt placeholder đến khi mini-boss thay composition.
- (T-011) Grunt body `collision_layer = 0` → player có thể đi xuyên Grunt; chưa đổi mask player (D-005) — đánh giá ở L4.
- (T-012) FPS combat chưa đo thật: số fps trên ảnh capture là artifact `--fixed-fps`; đo ở L4.
- (T-014) AI chase không pathfind: bị tường chặn đứng (không xuyên — B3.3 Passed); xem xét mức ảnh hưởng khi L4.
- (T-014) Đã ẩn `Player/Telegraph` placeholder Phase A (luôn hiện quanh player) — chỉ visual, không đổi logic/hitbox.
- (T-016) B7.3 Fail (đã waiver D-012): spam thuần thắng 10/10 run (~1.45 s/run) dù mỗi run ăn 1 hit; passive 10/10 thua. B7 giữ Failed; phải test lại B7.3 khi thêm cơ chế GDD 6.8.7.
- (T-018) DebugHitboxes build overlay một lần trong _ready → enemy spawn runtime chưa có overlay F1; xử lý ở T-023 trước khi chấm D1.
- (Môi trường) Chuyển branch bằng editor (ví dụ về `main` không có script combat) làm `.godot/global_script_class_cache.cfg` mất class_name → game báo Parse Error hàng loạt. Chạy `--headless --path . --import` một lần sau khi chuyển branch; không phải lỗi gameplay.
- (Phase A, D-009) L4 playtest build Phase A **Not Run** (được waiver thoát phase); gom vào L4 Phase B trên cùng build.
- Môi trường (có trước): `_console.exe` wrapper hỏng — dùng inner exe (AGENTS.md).
- `quit()` trong SceneTree script không dừng ngay; phải dùng if/else một quit (đã ghi AGENTS.md).
- **(G1) Ambient/shadow đen tuyệt đối: ĐÃ SỬA 2026-11-20 (T-004).** Nguyên nhân: `ambient_light_source=2` (COLOR) với `ambient_light_color` mặc định đen → đổi sang 3 (SKY). Xác nhận bằng `evidence/lighting/after_center.png` (mặt khuất hết đen).
- **(G1, mới) Placeholder facing chỉ L/R:** chưa thể hiện hướng dọc → G1.2 facing-dọc Not Run; đánh giá lại sau Art Spec.
- **(G1) Shimmer/crawl pixel: ĐÃ ĐO (T-006) + ĐÃ KHÓA (T-007).** Gói ortho scale 4 + camera snap + sprite visual snap cho anchor_dev = sprite_dev = 0.0000, residual 0 px. Cảm nhận khi chơi thật vẫn chờ L4.
- **(T-006→T-007, đóng) Sprite crawl do camera snap:** giải bằng `visual_snap` (lượng tử hóa vị trí hiển thị, logic nguyên); foot pivot lệch ≤0.004 u, ảnh đã xem.
- **(T-006, chủ đích) Texel aspect 0.6247 (4.000×2.499 px):** không còn là lỗi mở — user chọn giữ FIXED_Y, luật đổi thành mật độ cố định (D-008 Accepted).
- **(T-006, đóng) Perspective không integer px/texel toàn cục:** đóng bằng lựa chọn ortho (D-007 Accepted); persp chỉ còn là chế độ so sánh qua P.
- **(G1, diagnostic) Latency 1 frame** `action_press`→movement (một phần do thứ tự node player trước driver); Phase B combat log đo chính thức.
- **(G2, mới) Reticle bị geometry cao che** (left edge): điểm ngắm dưới đất sau Block không đọc được → G2.2 fail visibility; quy tắc occlusion G3 phải giải.
- **(G2, mới) Reticle dưới chân player bị sprite che một phần** (center): readability khi ngắm vào chính mình.
- **(G2, harness) fps HUD=2 trong ảnh G2** là artifact capture dày ngay sau stall save_png, không phải perf game; đo fps thật ở L4.
- **(G3, đánh đổi) Fade làm vật che ghostly** (mất cảm giác đặc); cần user chốt + cân nhắc outline khi fade. Ray đơn tâm player có thể sót che một phần.

## DONE gần đây (≤5)
- T-020 | Ranged + projectile + wave 2 composition + harness | DONE — `test_ranged_tuning` 23 checks, `test_ranged_ai` 16 checks (negative exit 1 cả hai); harness `checks=14 failures=0`, negative E2.1 exit 1; t018 10/10 wins ticks=6902; t019 3/3 wins ticks=2072.
- T-019 | Swarm role + role-based wave composition + harness | DONE — L3 swarm tuning 16 checks (negative telegraph floor exit 1); harness 3 run `runs=3 wins=3 swarms=3 grunts=2 reset_checks=true` exit 0, negative (thiếu swarm mapping) exit 1; t018 regression 10/10 wins, max_wave=3.
- T-018 | Arena + wave kernel + HUD + harness | DONE — L3 kernel 16 checks (negative exit 1); L2 10 run full wave flow (runs=10 wins=10 losses=0 max_wave=3 reset_checks=true ticks=10292, negative exit 1); gate placeholder chưa mở (T-022).
- T-017 | Phase C kickoff — gate doc C1–C3 + E1–E5 + scope 3 vai trò/boss 2 phase/shortcut+heal | DONE — user xác nhận "y"; D-013 Accepted.
- T-016 | B7.3 spam test | DONE — spam 10/10 W (87 tick/run, 1 hit nhận/run), passive 10/10 L (332 tick/run) → B7.3 Fail, B7 Failed; Phase B exit chưa đạt.
