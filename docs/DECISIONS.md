# DECISIONS

Lịch sử quyết định. Quyết định bị thay thế đánh **Superseded**, không xóa.

## Chỉ mục

| ID | Date | Category | Decision | Status |
|---|---|---|---|---|
| D-001 | 2026-11-20 | Product | Combat real-time action RPG | Accepted |
| D-002 | 2026-11-20 | Technical | Godot 4.4+ (khóa 4.7.2.stable) + GDScript | Accepted |
| D-003 | 2026-11-20 | Technical | Input bàn phím + chuột, gamepad DEFERRED | Accepted |
| D-004 | 2026-11-20 | Technical | Renderer Forward+ làm baseline | Proposed |
| D-005 | 2026-11-20 | Technical | Physics layers: 1=world, 2=player, 3–6 combat (Phase B) | Proposed |
| D-006 | 2026-11-20 | Technical | Gameplay XZ-plane + aim ground y=0 + occlusion fade 0.25 | Accepted |
| D-007 | 2026-11-20 | Technical | Projection: ortho texel_scale 4 + camera snap (persp giữ qua P để so sánh) | Accepted |
| D-008 | 2026-11-20 | Technical | Khóa pixel-grid: ortho integer scale + camera snap + sprite visual snap; giữ FIXED_Y, mật độ texel cố định | Accepted |
| D-009 | 2026-11-20 | Workflow | Waiver thoát Phase A khi L4 Not Run (user duyệt) | Accepted |

---

## D-001 · 2026-11-20 · Product · Accepted

- **Decision:** Combat là real-time action RPG.
- **Reason:** Người dùng xác nhận 20/11/2026 (GDD mục 3): muốn trực tiếp điều khiển nhân vật, cảm nhận phản hồi khi tấn công/né, chủ động xử lý enemy.
- **Alternatives considered:** Turn-based — bị loại.
- **Consequences:** Prototype dùng để cải thiện implementation trong real-time, không chọn lại thể loại. Thiếu playtest/dữ liệu không phải bằng chứng bất khả thi. Ngoại lệ đề nghị xem xét lại chỉ theo Master Prompt 1.1; người dùng quyết định.

## D-002 · 2026-11-20 · Technical · Accepted

- **Decision:** Godot 4.4+ với GDScript (ưu tiên typed). Phiên bản khóa: **4.7.2.stable.official.ed1daf0bf** (xác minh `--version` ngày 2026-11-20).
- **Reason:** Engine + ngôn ngữ là CONFIRMED trong GDD mục 3.
- **Alternatives considered:** Không có phương án khác được ghi nhận trong GDD.
- **Consequences:** Exe không trên PATH, dùng inner exe (AGENTS.md); `.uid` commit cùng file gốc; test headless bằng script SceneTree built-in.

## D-003 · 2026-11-20 · Technical · Accepted

- **Decision:** Input chính bàn phím + chuột; gamepad DEFERRED.
- **Reason:** CONFIRMED trong GDD mục 3; phù hợp real-time action với ngắm chuột.
- **Alternatives considered:** Gamepad-first — để sau, không loại vĩnh viễn.
- **Consequences:** Mọi input đi qua InputMap action để thêm gamepad không phải viết lại. Binding mặc định tạm theo GDD 5.5 (WASD / LMB / RMB / Space / E), chưa phải Combat Spec chính thức.

## D-004 · 2026-11-20 · Technical · Proposed

- **Decision:** Renderer Forward+ làm implementation baseline (GDD mục 3).
- **Reason:** HD-2D cần ánh sáng/bóng/DoF có kiểm soát; Forward+ đủ tính năng nhất trên desktop.
- **Alternatives considered:** Compatibility — nhẹ hơn trên Intel UHD nhưng thiếu một số effect định hình HD-2D (volumetric fog, SSAO, TAA); chỉ đánh giá lại khi có evidence hoặc ràng buộc platform.
- **Consequences:** Máy dev iGPU (i5-13420H, Intel UHD): FPS phải đo thật ở Phase A, không giả định 60. Baseline ≠ user xác nhận; giữ Proposed tới khi user duyệt.

## D-005 · 2026-11-20 · Technical · Proposed

- **Decision:** Physics layers: 1 = world (sàn/tường/vật cản tĩnh), 2 = player body; Phase B (T-008) bổ sung 3 = player_attack, 4 = enemy_attack (hitbox `Area3D`), 5 = player_hurtbox, 6 = enemy_hurtbox. Player mask = world; world mask = 0; hitbox mask = layer hurtbox đối phương; hurtbox mask = 0.
- **Reason:** Collision đầu tiên xuất hiện ở T-002; Master Prompt 6.3 yêu cầu bảng layer/mask trong AGENTS.md; hitbox/hurtbox cần ở Phase B.
- **Alternatives considered:** Layer riêng cho hitbox/hurtbox — đã bổ sung ở Phase B (3–6); ShapeCast thủ công — loại vì Area3D chuẩn Godot, debug vẽ được (F1).
- **Consequences:** Thêm layer phải cập nhật bảng AGENTS.md và mọi consumer (bảng layer authoritative nằm ở AGENTS.md).

## D-006 · 2026-11-20 · Technical · Accepted

- **Decision:** Gameplay trên mặt phẳng XZ (player `velocity.y = 0`, trọng lực không áp dụng ở Phase A); aim = ray camera cắt **ground plane y = 0**; vật cản che khuất bị **fade albedo alpha 0.25** khi chặn ray camera→player-center hoặc camera→aim.
- **Reason:** User duyệt bằng văn bản (y) ngày 2026-11-20 sau evidence G1/G2/G3. G1 chứng minh drift z=0, dừng tường chính xác; G2 offset aim=0 ở cả 5 điểm nhưng G2.2 trái Fail do Block che reticle; G3 fade giải quyết cả 3 tình huống che và đồng thời gỡ G2.2 (`g3/g2_left_after_fade.png`).
- **Alternatives considered:** Aim theo hit collider (bám mặt vật thể) — phức tạp hơn, chưa cần; không fade (giữ vật che opaque) — làm mất reticle/player, bị loại qua G2.2 Fail.
- **Consequences:** Player/telegraph/reticle không bao giờ fade; group `fadeable` = Wall/Block/Roof. Single center-ray có thể sót che khuất một phần; alpha 0.25 cho cảm giác "ghost" (tradeoff đã ghi ở OPERATIONAL_DEFINITIONS §10). Cảm nhận fade cần L4 playtest.

## D-007 · 2026-11-20 · Technical · Accepted

- **Decision:** Projection chính thức **orthographic**, `texel_scale = 4` → `size = viewport_height × pixel_size / 4` (9 tại 720p, tự theo resolution); camera follow snap (smoothing 0) + `snap_to_pixel = true`, offset (0,10,8). Perspective FOV 35 giữ làm chế độ so sánh qua phím **P**.
- **Reason:** User chọn bằng văn bản ngày 2026-11-20: **"Ortho + giữ FIXED_Y"** sau evidence T-006. Đo thật: persp không thể integer px/texel toàn cục (4.458 tại player, 4.062 tại điểm xa hơn) và camera snap không giảm shimmer persp (residual 18013→18681 px); ortho khóa được world crawl (T-006 −95%, T-007 = 0).
- **Alternatives considered:** Perspective + chỉnh pixel_size — loại vì px/texel đổi theo độ sâu; SubViewport low-res + integer upscale — loại vì mất chi tiết diorama 3D của HD-2D; ortho + full billboard cho texel vuông — user chọn giữ FIXED_Y thay thế.
- **Consequences:** Mật độ texel cố định **4.000 × 2.499 px** (aspect 0.6247) là chủ đích, không phải lỗi (D-008). Mất chiều sâu phối cảnh của diorama; cảm nhận cuối cùng đánh giá ở L4. Follow smoothing >0 vẫn để dành tinh chỉnh feel sau playtest.
- **Evidence:** T-006/T-007, OPERATIONAL_DEFINITIONS §12–13, `evidence/pixel/`, `evidence/pixel_t007/`.

## D-008 · 2026-11-20 · Technical · Accepted

- **Decision:** Gói khóa pixel-grid gồm 4 phần, nay đủ: (1) ortho integer scale (`texel_scale`); (2) camera snap theo pixel màn hình (`snap_to_pixel`); (3) visual snap của sprite tách khỏi logic position (`visual_snap`, lượng tử hóa vị trí hiển thị về integer px); (4) **giữ billboard FIXED_Y** và sửa luật pixel-grid từ "texel vuông" thành **"mật độ texel cố định, nhất quán mọi frame"** (4.000 × 2.499 px tại scale 4).
- **Reason:** User chốt "Ortho + giữ FIXED_Y" ngày 2026-11-20. Đo T-006 cho thấy thiếu phần nào luật vỡ phần đó; T-007 chứng minh đủ 3 phần kỹ thuật thì `anchor_dev` = `sprite_dev` = 0.0000 suốt 24 frame và residual 0 px. Texel vuông bị loại vì phải đổi cách đặt sprite (full billboard nghiêng theo camera, ảnh hưởng bóng/đổ bóng) — user ưu tiên sprite đứng thẳng của diorama.
- **Alternatives considered:** Full billboard / mặt phẳng nghiêng khớp pitch cho texel vuông — user không chọn; chấp nhận crawl — loại vì phá luật pixel-grid; SubViewport low-res — xem D-007.
- **Consequences:** (1)(2)(3) implement ở T-007 và là mặc định của scene; visual snap dịch sprite ≤0.5 px màn hình (~0.004 u), foot pivot vẫn chạm đất (ảnh T-007 đã xem). Hàng dọc texel vẫn lẻ px (2.499) nhưng **hằng số** nên không crawl. Asset hàng loạt hết chặn về mặt pixel; vẫn chờ chốt bộ hướng sprite + palette (ART_SPEC §6).

## D-009 · 2026-11-20 · Workflow · Accepted

- **Decision:** Cho phép chuyển Phase A → Phase B khi L4 human playtest của build Phase A chưa chạy (Not Run).
- **Reason:** User duyệt bằng văn bản ngày 2026-11-20: "ok push branch hiện tại và tạo branch mới và duyệt thoát Phase A, lên plan Phase B đi". Phase A gates 1–5 đạt: G1–G3 trên renderer thật (ảnh đã xem), Gate 4 Art Spec user xác nhận, Gate 5 DECISIONS đủ (D-006/D-007/D-008 Accepted). L4 không nằm trong gate bắt buộc của GDD Phase A; cảm nhận camera/movement/pixel sẽ thu trong L4 Phase B trên cùng build.
- **Alternatives considered:** Chạy L4 Phase A trước khi sang B — user bỏ qua để không chặn combat prototype; ở lại Phase A chờ playtest — bị loại.
- **Consequences:** L4 Phase A giữ nguyên **Not Run** (không thành Passed). Rủi ro chấp nhận: feel camera/movement chưa được người chơi xác nhận; giảm thiểu bằng L4 Phase B (build tích lũy) và tinh chỉnh theo playtest.
- **Scope:** Chỉ áp dụng cho bước chuyển Phase A→B; không miễn gate nào của Phase B; MVS-AC1…8 vẫn chờ user duyệt riêng.