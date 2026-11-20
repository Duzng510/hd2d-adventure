# PROJECT STATE
Cập nhật: 2026-11-20 (Project Day 2) | Commit: 13db1e0 (repo first commit; toàn bộ file project đang untracked — user owns VCS, agent không commit)

## Phase hiện tại
Phase A — Visual & Camera Prototype. G1 pass (T-005); G2 math pass + 4/5 visual (T-003a); G3 pass cả 3 tình huống (T-003b); **T-004 DONE: Art Spec user xác nhận (Gate 4), D-006 Accepted (XZ/aim/fade), D-007 Proposed (projection), ambient đen đã sửa + xác nhận bằng ảnh**. Còn: chốt projection (D-007) + integer texel=1px, L4 playtest.

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

## Đang làm (≤2)
- (trống — chờ chọn task kế tiếp)

## Next (3–5)
- Chốt D-007 projection: user chạy run.bat, bấm P so persp/ortho; kèm quyết integer texel=1px (ART_SPEC §3) | Dep: user xem trực tiếp
- L4 human playtest feel (G1 movement + aim + occlusion fade) | Dep: build chơi được (run.bat), user chơi
- Duyệt MVS-AC1…8 + đặt ngưỡng MVS-AC2 | Dep: user
- (tuỳ chọn) Dọn 2 dòng cũ trong AGENTS.md ("Chưa có main scene", danh sách "Hiện có") | cần preview+y/n riêng

## Later (backlog theo phase)
Phase B combat prototype (GDD 6.8) → Phase D MVS (field Verdant Frontier + dungeon 2–3 phòng + reward). Phase C là stretch, không chặn MVS. Stretch 15–30 phút sau MVS.

## Chờ quyết định & Blockers
- MVS-AC1…8 đang PROPOSED — chờ user duyệt/sửa.
- Ngưỡng pass/fail playtest MVS-AC2 chưa đặt (GDD: lần đầu chỉ tạo baseline).

## Known issues
- Môi trường (có trước): `_console.exe` wrapper hỏng — dùng inner exe (AGENTS.md).
- `quit()` trong SceneTree script không dừng ngay; phải dùng if/else một quit (đã ghi AGENTS.md).
- **(G1) Ambient/shadow đen tuyệt đối: ĐÃ SỬA 2026-11-20 (T-004).** Nguyên nhân: `ambient_light_source=2` (COLOR) với `ambient_light_color` mặc định đen → đổi sang 3 (SKY). Xác nhận bằng `evidence/lighting/after_center.png` (mặt khuất hết đen).
- **(G1, mới) Placeholder facing chỉ L/R:** chưa thể hiện hướng dọc → G1.2 facing-dọc Not Run; đánh giá lại sau Art Spec.
- **(G1) Shimmer/crawl pixel:** Not Run — ảnh tĩnh không kết luận được, cần video.
- **(G1, diagnostic) Latency 1 frame** `action_press`→movement (một phần do thứ tự node player trước driver); Phase B combat log đo chính thức.
- **(G2, mới) Reticle bị geometry cao che** (left edge): điểm ngắm dưới đất sau Block không đọc được → G2.2 fail visibility; quy tắc occlusion G3 phải giải.
- **(G2, mới) Reticle dưới chân player bị sprite che một phần** (center): readability khi ngắm vào chính mình.
- **(G2, harness) fps HUD=2 trong ảnh G2** là artifact capture dày ngay sau stall save_png, không phải perf game; đo fps thật ở L4.
- **(G3, đánh đổi) Fade làm vật che ghostly** (mất cảm giác đặc); cần user chốt + cân nhắc outline khi fade. Ray đơn tâm player có thể sót che một phần.

## DONE gần đây (≤5)
- T-004 | Art Spec (Gate 4 user xác nhận) + D-006 Accepted/D-007 Proposed + lighting ambient fix + run.bat/.vscode | DONE 2026-11-20 — ambient hết đen (ảnh đối chiếu); run không cần editor.
- T-003b | Occlusion rule (fade) + đánh giá G3 | DONE 2026-11-20 — G3.1–3 Pass (before/after renderer thật); giải G2.2 left; quy tắc nay Accepted (D-006).
- T-003a | Aim marker + đánh giá G2 mouse aim | DONE 2026-11-20 — L1/L2/L3 Passed; G2 math pass (offset 0), 4/5 visual pass, left fail visibility → đã giải bởi fade.
- T-005 | Capture + đánh giá gate G1 movement (renderer thật) | DONE 2026-11-20 — L3 Passed G1.1–G1.4 movement/camera (AI-observed, 7 PNG + CSV); facing dọc/shimmer Not Run; 2 visual Known Issues mới.
- T-002 | Scene Phase A: XZ, camera, sprite, movement | DONE 2026-11-20 — L1/L2/L3 Passed (AI-observed).