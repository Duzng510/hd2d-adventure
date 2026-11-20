# DECISIONS

Lịch sử quyết định. Quyết định bị thay thế đánh **Superseded**, không xóa.

## Chỉ mục

| ID | Date | Category | Decision | Status |
|---|---|---|---|---|
| D-001 | 2026-11-20 | Product | Combat real-time action RPG | Accepted |
| D-002 | 2026-11-20 | Technical | Godot 4.4+ (khóa 4.7.2.stable) + GDScript | Accepted |
| D-003 | 2026-11-20 | Technical | Input bàn phím + chuột, gamepad DEFERRED | Accepted |
| D-004 | 2026-11-20 | Technical | Renderer Forward+ làm baseline | Proposed |
| D-005 | 2026-11-20 | Technical | Physics layers: 1=world, 2=player | Proposed |
| D-006 | 2026-11-20 | Technical | Gameplay XZ-plane + aim ground y=0 + occlusion fade 0.25 | Accepted |
| D-007 | 2026-11-20 | Technical | Projection baseline: perspective FOV35 + snap follow (ortho thử qua P) | Proposed |

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

- **Decision:** Physics layers Phase A: 1 = world (sàn/tường/vật cản tĩnh), 2 = player body. Player mask = world; world mask = 0.
- **Reason:** Collision đầu tiên xuất hiện ở T-002; Master Prompt 6.3 yêu cầu bảng layer/mask trong AGENTS.md.
- **Alternatives considered:** Layer riêng cho hitbox/hurtbox — chưa cần, để Phase B khi combat xuất hiện.
- **Consequences:** Thêm layer phải cập nhật bảng AGENTS.md và mọi consumer.

## D-006 · 2026-11-20 · Technical · Accepted

- **Decision:** Gameplay trên mặt phẳng XZ (player `velocity.y = 0`, trọng lực không áp dụng ở Phase A); aim = ray camera cắt **ground plane y = 0**; vật cản che khuất bị **fade albedo alpha 0.25** khi chặn ray camera→player-center hoặc camera→aim.
- **Reason:** User duyệt bằng văn bản (y) ngày 2026-11-20 sau evidence G1/G2/G3. G1 chứng minh drift z=0, dừng tường chính xác; G2 offset aim=0 ở cả 5 điểm nhưng G2.2 trái Fail do Block che reticle; G3 fade giải quyết cả 3 tình huống che và đồng thời gỡ G2.2 (`g3/g2_left_after_fade.png`).
- **Alternatives considered:** Aim theo hit collider (bám mặt vật thể) — phức tạp hơn, chưa cần; không fade (giữ vật che opaque) — làm mất reticle/player, bị loại qua G2.2 Fail.
- **Consequences:** Player/telegraph/reticle không bao giờ fade; group `fadeable` = Wall/Block/Roof. Single center-ray có thể sót che khuất một phần; alpha 0.25 cho cảm giác "ghost" (tradeoff đã ghi ở OPERATIONAL_DEFINITIONS §10). Cảm nhận fade cần L4 playtest.

## D-007 · 2026-11-20 · Technical · Proposed

- **Decision:** Baseline projection thử: **perspective FOV 35**, camera follow **snap** (smoothing 0), offset (0,10,8), look_at player. Ortho (size 10) để so sánh trực tiếp qua phím **P** trong run file.
- **Reason:** Perspective cho chiều sâu diorama HD-2D; snap giữ camera bám chính xác để đo aim/drift. Ortho chưa kiểm chứng trên máy dev.
- **Alternatives considered:** Orthographic — khóa integer pixel (texel=1px) dễ hơn nhưng chưa đo; follow smoothing >0 — mượt hơn nhưng thêm latency, để dành tinh chỉnh feel ở L4.
- **Consequences:** Giữ **Proposed** tới khi user so sánh persp/ortho trực tiếp (P) và duyệt sau L4. Screen px/texel hiện ≈1.5 (không integer) → luật pixel-grid texel=1px còn mở, gắn với lựa chọn projection (ART_SPEC §3). Không tự nâng lên Accepted.