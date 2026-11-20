# Phase A — Art Spec tạm (đo từ scene thật)

**Trạng thái: user xác nhận bằng văn bản 2026-11-20 (Gate 4).** Nguồn: `scenes/phase_a/phase_a_playground.tscn`, `scripts/phase_a/placeholder_textures.gd`, `scripts/phase_a/camera_rig.gd`, `scripts/phase_a/aim_marker.gd`, `scripts/phase_a/occlusion_fader.gd`. Chỉ sinh asset AI hàng loạt SAU khi doc này được xác nhận (Master Prompt mục 10).

## 1. Kích thước nhân vật & canvas

- Canvas/frame placeholder: **24×32 px** (code-gen, `make_player_sprite`).
- `pixel_size = 0.05` → **chiều cao world = 32 × 0.05 = 1.6 u**; **rộng = 24 × 0.05 = 1.2 u**.
- Visible bounds (vùng opaque): khoảng x∈[6,18], y∈[1,31] trong canvas 24×32; phần còn lại trong suốt.
- Filtering: **NEAREST** (`texture_filter = 1` trên Sprite3D và material); alpha_cut = DISCARD.

## 2. Foot pivot & hướng nhìn

- **Foot pivot = hàng dưới cùng của canvas (y=31)**. Player `CharacterBody3D` origin tại y=0 (mặt đất); `Sprite3D` con đặt y=0.8 với centered mặc định → nửa cao 0.8 → feet chạm đúng y=0.
- Billboard = FIXED_Y (sprite luôn đứng thẳng, quay quanh trục Y).
- **Facing hiện tại: chỉ L/R** (`flip_h`). Hướng dọc chưa thể hiện → **đề xuất cho asset thật: sprite 4 hướng (down/up/left/right)**, mỗi hướng một frame riêng; giữ foot pivot nhất quán. Đây là giới hạn placeholder, không phải lỗi control (G1.2 facing-dọc Not Run).

## 3. Pixel density & luật pixel-grid

- 1 texel = 0.05 world unit (pixel_size 0.05).
- **Đo thật T-006 (2026-11-20, `evidence/pixel/`, OPERATIONAL_DEFINITIONS §12):** persp FOV35 = **4.458 × 2.785 px/texel**; ortho size 10 = 3.600 × 2.249; ortho size 9 = 4.000 × 2.499. **Aspect mọi config = 0.6247** (texel bị nén dọc do billboard FIXED_Y + camera nghiêng 51.34°) → chưa thỏa luật "1 texel = 1 px vuông". Ước lượng "≈1.5 px/texel" ghi trước đây là sai, đã thay bằng số đo.
- Integer scale chỉ khả thi với **ortho** (size = H × pixel_size / scale: 720p → 36/18/12/9 cho 1/2/3/4 px mỗi texel). Persp có px/texel đổi theo độ sâu → không integer toàn cục.
- Camera snap (`snap_to_pixel`) khóa world crawl với ortho (residual −95%); thêm visual snap của sprite (`visual_snap`, T-007) khóa cả sprite: `anchor_dev` = `sprite_dev` = 0.0000, residual 0 px. **Gói D-008 Accepted** (user chọn "Ortho + giữ FIXED_Y" 2026-11-20): luật pixel-grid nay là **mật độ texel cố định 4.000 × 2.499 px**, không yêu cầu texel vuông.
- Import: texture code-gen `ImageTexture` (không asset ngoài, không import settings ngoài); palette chung trong `PlaceholderTextures.PALETTE`.

## 4. Collision footprint (tách khỏi visual)

- `CapsuleShape3D` **radius 0.35, height 1.6** → footprint đường kính **0.7 u**, hẹp hơn visual rộng 1.2 u (visual tràn ra ngoài collision có chủ đích).
- Physics layers: 1 = world (StaticBody), 2 = player (mask 1). Xem AGENTS.md / D-005.

## 5. Camera & aim & occlusion (baseline thử)

- Camera follow **snap** (smoothing 0), offset **(0, 10, 8)**; `snap_to_pixel = true` (D-007 Accepted).
- Projection mặc định: **orthographic, `texel_scale = 4`** → size 9 tại 720p (tự theo viewport height). Perspective FOV 35 chỉ còn là chế độ so sánh qua phím P (D-007 Accepted).
- Aim: ray camera → **ground plane y=0**; reticle quad phẳng code-gen.
- Occlusion: **fade vật che alpha 0.25** trên ray camera→player & camera→aim (D-006).

## 6. Việc còn mở trước khi sinh asset hàng loạt

- Pixel-grid đã chốt (D-007/D-008 Accepted, T-007): ortho scale 4 + camera snap + sprite visual snap + FIXED_Y.
- Chốt bộ hướng sprite (đề xuất 4 hướng) + frame size thật cho nhân vật/quái.
- Xác nhận palette cuối + nguồn asset (free-license) trước khi thay placeholder.