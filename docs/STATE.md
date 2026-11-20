# PROJECT STATE
Cập nhật: 2026-11-20 (Project Day 2) | Commit: 52f5b5c (T-007) | Branch: `phase-b/t008-combat-definitions` (T-008)

## Phase hiện tại
Phase B — Combat Prototype (bắt đầu 2026-11-20). Phase A thoát theo **D-009 waiver**: gates 1–5 đạt (D-007/D-008 Accepted; lưới pixel khóa, anchor_dev = sprite_dev = 0, residual 0 px); L4 playtest Phase A **Not Run** — cảm nhận gom vào L4 Phase B cùng build. T-008: định nghĩa vận hành gate Phase B (**chờ user xác nhận**) + COMBAT_SPEC + `combat_tuning.tres` + physics layers 3–6 + InputMap combat.

## Build: chạy được? (có/không) — cách chạy
Có (scene load được). Scene chính: `res://scenes/phase_a/phase_a_playground.tscn`. **Chạy không cần mở editor: `run.bat` ở root, hoặc VSCode Ctrl+Shift+B (task "godot: run game", `.vscode/tasks.json`)**; phím trong game: WASD di chuyển, chuột aim, P đổi persp/ortho, L frame log. L2 Passed: headless `--quit-after 120`, EXIT=0, không lỗi. Visual G1–G3 + lighting đã xem thật (Vulkan 1.4.323 Forward+ / Intel UHD, 1280×720).

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

## Đang làm (≤2)
- T-008 | Gate definitions Phase B + COMBAT_SPEC + tuning resource + physics layers 3–6 | IMPLEMENTED — chờ user xác nhận định nghĩa gate | AC: user xác nhận trước khi chấm; L1/L3 xanh | Dep: —

## Next (3–5)
- T-009 combat kernel (attack timeline/combo window/buffer/dodge i-frame/health/hit registry) + fail-first tests | Dep: T-008
- T-010 player combat (hitbox/hurtbox, swing visual, hit-stop, combat log CSV, F1 debug hitbox) | Dep: T-009
- T-011 Grunt AI (detect→approach→telegraph ≥18 frame) + player damage/death | Dep: T-009
- T-012 encounter manager (win/lose/reset R, 10 run liên tiếp, HUD HP, FPS combat) | Dep: T-010, T-011
- T-013 Playtest Brief + L4 Phase B (10 encounter, rubric MP 9) + tuning 1 tham số/lần | Dep: T-012, user
- Duyệt MVS-AC1…8 + đặt ngưỡng MVS-AC2 (không chặn Phase B) | Dep: user

## Later (backlog theo phase)
Phase C stretch (extended encounter, GDD mục 12) → Phase D MVS (field Verdant Frontier + dungeon 2–3 phòng + reward). Phase C không chặn MVS. Stretch 15–30 phút sau MVS.

## Chờ quyết định & Blockers
- Định nghĩa vận hành gate Phase B (`docs/phase-b/OPERATIONAL_DEFINITIONS.md`) PROPOSED — cần user xác nhận **trước khi** đánh giá gate.
- MVS-AC1…8 đang PROPOSED — chờ user duyệt/sửa.
- Ngưỡng pass/fail playtest MVS-AC2 chưa đặt (GDD: lần đầu chỉ tạo baseline).

## Known issues
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
- T-007 | Implement D-008 Accepted: ortho scale 4 mặc định + camera snap + sprite visual snap | DONE 2026-11-20 — lưới khóa world+sprite (dev 0.0000, residual 0); 21 PNG đã xem; D-007/D-008 Accepted.
- T-006 | Đo pixel-grid + shimmer 6 config, harness residual biết FAIL trước | DONE 2026-11-20 (branch phase-a/t006-pixel-grid) — L1/L2/L3 Passed, 18 PNG đã xem; D-007 có số liệu, D-008 Proposed.
- T-004 | Art Spec (Gate 4 user xác nhận) + D-006 Accepted/D-007 Proposed + lighting ambient fix + run.bat/.vscode | DONE 2026-11-20 — ambient hết đen (ảnh đối chiếu); run không cần editor.
- T-003b | Occlusion rule (fade) + đánh giá G3 | DONE 2026-11-20 — G3.1–3 Pass (before/after renderer thật); giải G2.2 left; quy tắc nay Accepted (D-006).
- T-005 | Capture + đánh giá gate G1 movement (renderer thật) | DONE 2026-11-20 — L3 Passed G1.1–G1.4 movement/camera (AI-observed, 7 PNG + CSV); facing dọc/shimmer Not Run; 2 visual Known Issues mới.