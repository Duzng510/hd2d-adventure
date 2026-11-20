# Phase A — Định nghĩa vận hành (Operational Definitions)

**Trạng thái: user xác nhận 2026-11-20 (T-001). G1–G3 đã đánh giá; quy tắc occlusion nay Accepted (D-006).**
Nguồn: GDD 0.7.1 mục 12 (Phase A). Tài liệu này định nghĩa checklist quan sát nhị phân và cách chụp bằng chứng cho từng mục. Không đặt tolerance số tùy ý khi scene và camera thật chưa tồn tại.

## 0. Quy tắc chung

- Mỗi check đánh giá **pass/fail bằng quan sát nhị phân** theo tiêu chí ghi sẵn dưới đây; không gộp nhiều check thành một kết luận chung.
- Bằng chứng visual phải chụp từ **renderer thật** (không headless) và được xem thật; ghi kèm điều kiện: Godot version, scene, resolution, cấu hình camera (projection/FOV/góc), cấu hình máy, ngày.
- Sai lệch đo được (px, frame, ms) ghi dạng **dữ liệu**, không tự kết luận pass/fail theo ngưỡng số chưa được duyệt.
- Sau prototype có thể **đề xuất tolerance**; chỉ dùng làm gate khi user duyệt và ghi vào `DECISIONS.md`.
- Pixel shimmer, pivot polish, FPS: đo và ghi **Known Issues** nếu không ảnh hưởng khả năng đánh giá. Phase A không phải polish gate.
- Check chưa chạy ghi **Not Run**; bị chặn ghi **Blocked** kèm lý do. Kết quả điền vào bảng mục 6.

## 1. Gate 1 — Movement & camera

**Setup:** scene thử có player placeholder, vật cản, sàn có lưới/mốc để quan sát hướng và vị trí. Camera theo cấu hình đang thử. Input qua InputMap. Debug log vị trí/vận tốc theo physics frame bật sẵn.

| ID | Tình huống | Cách thực hiện | Pass khi (quan sát nhị phân) |
|---|---|---|---|
| G1.1 | Đi thẳng | Giữ một hướng di chuyển ~3 s trên sàn trống | Hướng di chuyển khớp hướng input suốt quãng đi; không trôi ngang (vị trí ngang ổn định so với lưới); foot pivot không giật cục |
| G1.2 | Rẽ 90° | Đang đi, đổi hướng vuông góc | Hướng sprite đổi khớp hướng di chuyển; không trượt/quán tính ngoài thông số accel đã ghi (accel = 0 thì đổi hướng tức thì) |
| G1.3 | Chạy sát vật cản | Đi sát tường/vật cản ~3 s | Không xuyên qua vật cản; không jitter vị trí; camera không giật làm mất kiểm soát |
| G1.4 | Đổi hướng nhanh | Đảo hướng liên tiếp ~5 lần trong ~2 s | Mỗi lần input đều được đọc đúng hướng; không mất điều khiển, không kẹt trạng thái |

**Bằng chứng:** video hoặc chuỗi ảnh cho từng tình huống + log vị trí/vận tốc theo frame. Ghi pass/fail **từng tình huống**. Fail: ghi hiện tượng + bước tái hiện; không sửa vội ngoài phạm vi task.

## 2. Gate 2 — Mouse aim

**Setup:** marker debug hiện tại điểm tia từ camera (`project_ray_origin`/`project_ray_normal`) cắt mặt phẳng ngắm. Con trỏ hệ thống hiện rõ trong ảnh chụp.

| ID | Vị trí con trỏ | Pass khi |
|---|---|---|
| G2.1 | Tâm màn hình | Marker trùng con trỏ trong ảnh chụp |
| G2.2 | Gần rìa trái | Như trên |
| G2.3 | Gần rìa phải | Như trên |
| G2.4 | Gần rìa trên | Như trên |
| G2.5 | Gần rìa dưới | Như trên |

- Sai lệch (nếu có): **đo px từ ảnh chụp**, ghi vào bảng dữ liệu kèm vị trí.
- **Chưa đặt ngưỡng px pass/fail.** Sau prototype đề xuất tolerance → user duyệt → mới thành gate.
- **Bằng chứng:** 5 ảnh chụp (thấy cả con trỏ lẫn marker), bảng offset px theo vị trí.

## 3. Gate 3 — Occlusion

**Setup:** 3 tình huống dựng sẵn trong scene thật; telegraph placeholder (vùng nguy hiểm giả) đặt gần player để kiểm tra độ đọc.

| ID | Tình huống | Pass khi |
|---|---|---|
| G3.1 | Vật che gần player | Player nhìn thấy đủ đọc; hướng nhìn đọc được; telegraph placeholder không bị che khuất |
| G3.2 | Tường giữa camera và player | Như trên |
| G3.3 | Mái hoặc tán cây che từ trên | Như trên |

- **Một quy tắc occlusion nhất quán** áp dụng cho cả 3 tình huống (ví dụ: làm mờ vật che / cutaway / ràng buộc góc camera). Ghi rõ quy tắc đã chọn; không xử lý tùy hứng từng vật.
- **Bằng chứng:** ảnh chụp mỗi tình huống (trước/sau khi áp quy tắc nếu có), mô tả quy tắc bằng lời.

## 4. Gate 4 — Art Spec tạm

Ghi thông số **đo từ scene thật** vào `docs/phase-a/ART_SPEC.md`:

- Chiều cao nhân vật theo world unit; sprite canvas/frame size; visible bounds.
- Foot pivot (vị trí neo chân); hướng nhìn và quy tắc đổi hướng.
- Pixel density (`pixel_size`), filtering (nearest), import settings.
- Collision footprint tách khỏi visual (kích thước shape thật).

**Pass khi:** doc đủ các mục trên **và user xác nhận bằng văn bản**. Chỉ sau đó mới sinh asset AI hàng loạt (Master Prompt mục 10).

## 5. Mục 5 — Ghi DECISIONS

Sau prototype, ghi vào `docs/DECISIONS.md`: kiến trúc không gian (XZ hay 3D thật), projection, camera behavior, cách ngắm bằng chuột, lỗi visual còn lại. Giữ đúng nhãn trạng thái (Proposed/Accepted/…); không tự nâng BASELINE/OPEN thành CONFIRMED.

## 6. Bảng tổng hợp kết quả (điền khi đánh giá)

| Check | Kết quả | Bằng chứng (link/đường dẫn) | Ghi chú |
|---|---|---|---|
| G1.1 | Pass | `evidence/g1/g1_1_f090.png`, `g1_1_f180.png` + `g1_log.csv` | Drift z = 0 suốt 180 frame; vx = 4 ổn định; camera snap không jitter |
| G1.2 | Pass (movement); facing dọc Not Run | `g1_2_f183.png`, `g1_2_f300.png` + csv | Đổi hướng tức thì ở f182, không trượt; placeholder chỉ L/R nên chưa đánh giá được facing khi đi dọc |
| G1.3 | Pass | `g1_3_f360.png`, `g1_3_f480.png` + csv | Dừng đúng z = −2.4000 (mặt tường −2.75 + r0.35), hằng số 159 frame, không xuyên/jitter |
| G1.4 | Pass | `g1_4_f540.png` + csv | 5 lần đảo hướng, facing flip đúng mỗi lần, không kẹt trạng thái |
| G2.1 | Pass (caveat) | `evidence/g2/g2_1_center.png` + `g2_log.csv` | Offset 0; reticle trùng crosshair tại tâm; player sprite che nửa vành reticle (readability note) |
| G2.2 | **Fail (visibility, fade OFF)** | `g2_2_left.png` + csv; đã giải bởi fade rule: `g3/g2_left_after_fade.png` (mục 10) | Offset số 0 (math đúng) nhưng reticle bị Block che khi chưa có rule; bật fade (mặc định) thì đọc được |
| G2.3 | Pass | `g2_3_right.png` + csv | Reticle trùng crosshair rìa phải, offset 0 |
| G2.4 | Pass | `g2_4_top.png` + csv | Reticle trùng crosshair rìa trên, offset 0 |
| G2.5 | Pass | `g2_5_bottom.png` + csv | Reticle trùng crosshair rìa dưới, offset 0 |
| G3.1 | Pass | `evidence/g3/g3_1_near_before.png` / `_after.png` + `g3_log.csv` | Trước: player sau Block bị che khuất; sau fade: player + telegraph đọc rõ, hướng đọc được |
| G3.2 | Pass | `g3_2_wall_before.png` / `_after.png` + csv | Trước: player sau Wall bị che; sau fade: player + telegraph đọc rõ |
| G3.3 | Pass | `g3_3_roof_before.png` / `_after.png` + csv | Trước: Roof che toàn bộ player/telegraph; sau fade: cả hai đọc rõ |
| Gate 4 | Pass | `docs/phase-a/ART_SPEC.md` | User xác nhận bằng văn bản 2026-11-20; đủ scale/canvas/pivot/hướng/pixel density/footprint |
| Mục 5 | Pass | `docs/DECISIONS.md` D-006, D-007, D-008 | Đã ghi không gian/projection/camera/aim/lỗi visual; D-007+D-008 vẫn Proposed chờ user chốt |
| Pixel-grid & shimmer (ngoài gate) | Measured | `evidence/pixel/` + mục 12 | T-006: đo 6 config, metric residual biết FAIL trước; không phải gate Phase A |

## 7. Trình tự thực hiện (theo GDD mục 12)

(1) Kiến trúc không gian XZ/3D → (2) camera projection & behavior → (3) sprite scale/visible bounds/pivot trong camera thật → (4) movement/input orientation → (5) mouse aim, marker, collision → (6) readability, occlusion, khả năng combat.

Các lựa chọn P0 phụ thuộc nhau: thử nhanh và điều chỉnh theo evidence; lựa chọn thử đầu tiên không phải quyết định vĩnh viễn.

## 8. Kết quả đánh giá G1 (2026-11-20, AI-observed)

**Điều kiện:** Godot 4.7.2.stable, Vulkan 1.4.323 Forward+, Intel UHD Graphics, 1280×720, `--fixed-fps 60`, camera perspective FOV 35 offset (0,10,8), follow snap. Input **mô phỏng qua InputMap action** (không phải phím vật lý). 601 physics frame. Bằng chứng: `docs/phase-a/evidence/g1/` (7 PNG đã xem thật + `g1_log.csv`).

**Dữ liệu chính:**
- G1.1: z = 0.0000 mọi frame (drift ngang = 0); x tăng đều 0.0667/frame (= 4 u/s ÷ 60).
- G1.2: f181 vx=4 → f182 vx=0, vz=−4 (đổi hướng tức thì, accel 0); x đóng băng 12.0, không overshoot.
- G1.3: z giảm tới −2.4000 (f322) rồi hằng số tới f480; vx/vz = 0 khi tiếp xúc → không xuyên, không jitter.
- G1.4: vx đổi dấu mỗi 24 frame; facing flip 1↔−1 khớp mỗi lần đảo (f506, 530, 554, 578).
- Camera: cam_x/cam_z bám player + offset chính xác trong từng đoạn; hằng số khi player dừng → không giật.

**Giới hạn / Known Issues (không chặn G1 movement):**
1. **Ambient/shadow đen tuyệt đối: ĐÃ SỬA (T-004, 2026-11-20).** Nguyên nhân xác minh: `ambient_light_source=2` (COLOR) + `ambient_light_color` mặc định đen → đổi 3 (SKY). Xem mục 11 + `evidence/lighting/after_center.png`.
2. **Placeholder facing chỉ L/R:** không thể hiện hướng dọc → G1.2 phần "sprite đổi hướng khớp" khi đi dọc = Not Run. Đánh giá lại sau Art Spec (Gate 4).
3. **Shimmer/crawl pixel:** chưa đánh giá (ảnh tĩnh không kết luận được; cần video). Not Run.
4. **Latency 1 frame** từ `action_press` tới chuyển động đầu (f1 press → f2 move): một phần do thứ tự node (player process trước driver). Diagnostic; Phase B combat log đo chính thức.
5. **Feel/responsiveness:** chờ L4 human playtest; dữ liệu trên không thay thế cảm giác chơi.

## 9. Kết quả đánh giá G2 (2026-11-20, AI-observed)

**Điều kiện:** Godot 4.7.2.stable, Vulkan 1.4.323 Forward+, Intel UHD, 1280×720, `--fixed-fps 60`, camera perspective FOV 35 offset (0,10,8). Aim plane = ground y=0 (PROPOSED). Con trỏ mô phỏng bằng `Input.warp_mouse`; **cursor indicator đỏ vẽ screen-space trong HUD** (OS cursor không lọt vào ảnh capture). Reticle = quad phẳng code-gen trên đất. Bằng chứng: `docs/phase-a/evidence/g2/` (5 PNG đã xem thật + `g2_log.csv`). Test math: `tests/test_aim_model.gd` PASS (6 checks) + negative control mirror FAIL exit 1 (harness bắt được sai dấu).

**Dữ liệu (mouse → aim, offset px):**
| Điểm | Mouse (px) | Aim (x,z) | has_hit | offset px |
|---|---|---|---|---|
| center | 640,360 | 0.00, 0.00 | 1 | 0.00 |
| left | 40,360 | −6.73, 0.00 | 1 | 0.00 |
| right | 1240,360 | 6.73, 0.00 | 1 | 0.00 |
| top | 640,40 | 0.00, −5.92 | 1 | 0.00 |
| bottom | 640,680 | 0.00, 3.75 | 1 | 0.00 |

Offset = `camera.unproject_position(aim)` so với mouse → 0 mọi điểm: math ray→ground self-consistent. **Chưa đặt ngưỡng px pass/fail** (chờ user duyệt sau prototype).

**Quan sát visual từng điểm:**
- center/right/top/bottom: reticle amber trùng crosshair đỏ → Pass. Riêng center: player sprite (billboard đứng) che nửa trên vành reticle vì aim đúng chân player → readability note, không phải lỗi math.
- **left: Fail visibility.** Điểm ngắm (−6.73,0,0) nằm sau Block (x∈[−5,−3], y∈[0,3], z∈[1,3]) dọc ray camera→đất (ray đụng block ở t≈0.70–0.74 < 1). Reticle trên đất bị block che nên KHÔNG thấy trong ảnh; chỉ thấy crosshair đỏ trên mặt block. Math đúng (offset 0) nhưng marker không đọc được → **đây là vấn đề occlusion, chuyển Gate 3** (quy tắc nhất quán phải làm marker/player đọc được sau vật che).

**Known Issues / ghi chú (không chặn math G2):**
1. **Reticle bị geometry cao che** (left) — động lực chính cho quy tắc occlusion G3. Cân nhắc: fade vật che, hoặc nâng reticle/render-order, hoặc ràng buộc góc camera.
2. **Reticle dưới chân player bị sprite che một phần** (center) — readability khi ngắm vào chính mình; cân nhắc render reticle trước/sau sprite hoặc offset nhẹ.
3. **fps HUD = 2 trong ảnh G2** là artifact capture dày (mỗi điểm cách ~7 frame, chụp ngay sau stall `save_png` CPU), KHÔNG phải perf game (G1 capture thưa cho fps 60). Đo fps thật ở L4 playtest; không dùng số này kết luận perf.
4. Ambient/shadow đen tuyệt đối: đã sửa ở T-004 (mục 11), không còn là Known Issue mở.

## 10. Kết quả đánh giá G3 + quy tắc occlusion (2026-11-20, AI-observed)

**Điều kiện:** Godot 4.7.2.stable, Vulkan 1.4.323 Forward+, Intel UHD, 1280×720, `--fixed-fps 60`, camera perspective FOV 35 offset (0,10,8) follow player. Bằng chứng: `docs/phase-a/evidence/g3/` (7 PNG đã xem thật: 3 cặp before/after + `g2_left_after_fade.png`, `g3_log.csv`).

**Quy tắc occlusion đã chọn (Accepted — D-006, user duyệt 2026-11-20):**
**Fade vật che.** Mỗi physics frame, raycast từ camera tới (a) tâm player và (b) điểm aim; occluder world (layer 1) trúng ray → giảm `albedo_color.a` của material xuống **0.25**; các vật không trúng ray restore về 1.0. **Một quy tắc nhất quán** cho cả 3 tình huống và cho cả aim reticle. Player sprite, telegraph decal và reticle **không** bị fade. Implement: `scripts/phase_a/occlusion_fader.gd` (group `fadeable` = Wall/Block/Roof).

**Quan sát từng tình huống (before = fade OFF, after = fade ON):**
- G3.1 (player sau Block, vật che gần): before player khuất hoàn toàn, telegraph chỉ hở viền; after Block trong mờ → player + telegraph đọc rõ, hướng (mắt phải) đọc được. `active_fades` 0→1.
- G3.2 (player sau Wall, tường giữa): before player khuất; after Wall trong mờ → player + telegraph đọc rõ. 0→2.
- G3.3 (Roof canopy che từ trên): before Roof che toàn bộ player + telegraph; after Roof trong mờ → cả hai đọc rõ. 0→2.
- **G2.2 recheck:** warp chuột rìa trái với fade ON → reticle trái đọc được qua Block đã fade, trùng crosshair → **lỗi visibility G2.2 được giải bởi cùng quy tắc**. 0→2.

**Giới hạn / Known Issues:**
1. Fade làm vật che mất cảm giác "đặc" (ghostly) — đánh đổi readability player lấy độ đọc của chính vật che; cần user chốt ở Art Spec/DECISIONS. Cân nhắc thêm viền/outline khi fade để giữ hình khối.
2. Ray đơn tới tâm player có thể bỏ sót che khuất một phần (chỉ che chân/đầu); prototype chấp nhận, Phase B cân nhắc multi-ray hoặc fade theo khoảng cách.
3. Alpha-blend sort: vật fade trong suốt có thể lộ artifact sắp xếp khi nhiều vật chồng nhau; chưa thấy rõ ở 3 tình huống này, theo dõi thêm.
4. fps HUD dao động 1–34 trong ảnh G3 = artifact capture dày/sparse quanh stall save_png, không phải perf game; đo thật ở L4.
5. Ambient/shadow đen tuyệt đối: đã sửa ở T-004 (mục 11).
6. Feel/readability khi chơi thật chờ L4 human playtest.

## 11. Xác minh lighting fix (2026-11-20, T-004, AI-observed)

**Điều kiện:** Godot 4.7.2.stable, Vulkan 1.4.323 Forward+, Intel UHD, 1280×720, `--fixed-fps 60`, camera perspective FOV35 offset (0,10,8), chuột warp tâm (640,360). Scene `phase_a_playground.tscn` với `ambient_light_source = 3` (SKY, trước = 2 COLOR). Capture: `scenes/phase_a/capture_lighting.tscn` + `scripts/phase_a/lighting_check_driver.gd`, EXIT=0, không SCRIPT ERROR.

**Đối chiếu trước/sau (đã xem thật):**
- Trước (`g2/g2_1_center.png`, ambient=2): mặt phải Block và mép trái Wall **đen tuyền (#000)**; bóng đổ đen cứng.
- Sau (`evidence/lighting/after_center.png`, ambient=3): các mặt khuất thành **xám-xanh nhạt** (được ambient SKY chiếu sáng), bóng đổ mềm xám-xanh; không còn vùng đen tuyệt đối. Sàn vẫn đọc rõ lưới.
- Ghi chú: ảnh sau có Roof fade trong suốt phủ lên player/telegraph (fader bật) làm sprite hơi nhạt màu — đây là tradeoff fade đã ghi mục 10, không phải lỗi ambient. fps HUD=1 trong ảnh sau = artifact capture (chụp ngay sau stall save_png), không phải perf game.

**Kết luận:** Known Issue ambient/shadow đen tuyệt đối **đóng**. Readability mặt khuất cải thiện; cảm nhận ánh sáng cuối cùng chờ L4 + Art Spec asset thật.

## 12. Kết quả đo pixel-grid + shimmer (2026-11-20, T-006, AI-observed)

**Điều kiện:** Godot 4.7.2.stable, Vulkan 1.4.323 Forward+, Intel UHD, 1280×720, `--fixed-fps 60`; scene `scenes/phase_a/capture_pixel.tscn` (instance playground + driver). Player chạy phải 4 u/s, 24 frame mỗi config, 6 config. Bằng chứng: `evidence/pixel/` (18 PNG đã xem thật + `pixel_log.csv`, 144 dòng). Math: `tests/test_pixel_grid.gd` PASS 17 checks; negative control `-- negative` FAIL exit 1 (fixture sai "texel vuông" bị bắt).

**Metric shimmer (residual):** giữa 2 frame liên tiếp, tịnh tiến frame B theo shift màn hình của điểm world cố định `ANCHOR (6,0,−2)` làm tròn về integer px, rồi diff với frame A; đếm pixel lệch > 8/255. Loại vùng HUD (0,0,1024,64) và hộp player ±180 px → residual chỉ đo **world tĩnh**. Ảnh `<config>_residual.png` = phần lệch ×4. **Metric chứng minh biết FAIL trước:** nosnap cho 7.406–18.013 px, snap cho 285–347 px; ảnh nosnap sáng rõ các đường lưới, ảnh snap lưới đen hoàn toàn.

| Config | px/unit | texel W×H (px) | aspect | anchor_dev (px) | residual (px) | player_dev (px) |
|---|---|---|---|---|---|---|
| persp_nosnap | 89.158 | 4.458×2.785 | 0.6247 | 0.4929 | 18013 | 0.0000 |
| persp_snap | 89.158 | 4.458×2.785 | 0.6247 | 0.4888 | 18681 | 0.0562 |
| ortho10_nosnap | 72.000 | 3.600×2.249 | 0.6247 | 0.4000 | 9038 | 0.0000 |
| ortho10_snap | 72.000 | 3.600×2.249 | 0.6247 | 0.0001 | 285 | 0.2000 |
| ortho9_nosnap | 80.000 | 4.000×2.499 | 0.6247 | 0.3334 | 7406 | 0.0000 |
| ortho9_snap | 80.000 | 4.000×2.499 | 0.6247 | 0.0000 | 347 | 0.3334 |

`anchor_dev` = biên độ lệch phần lẻ px của điểm world cố định so với frame đầu (wrap ±0.5). `player_dev` = lệch phần lẻ frame-kề-frame của gốc player. `engine_texel_w` trong CSV = đo trực tiếp bằng `unproject_position`, cross-validate module math.

**Kết luận từng mục:**
1. **Texel không vuông ở MỌI config** (aspect 0.6247 = cos 51.34°): hệ quả cấu trúc của billboard `FIXED_Y` + camera nghiêng 51.34°, độc lập projection. Muốn texel vuông phải đổi cách đặt sprite (full billboard, hoặc mặt phẳng nghiêng khớp pitch camera) — D-008.
2. **Integer scale chỉ khả thi với ortho:** ortho size 9 cho texel ngang đúng 4.000 px; persp cho 4.458 px tại player nhưng 4.062 px tại ANCHOR (engine đo) → px/texel đổi theo độ sâu, không thể integer toàn cục. `engine_texel_w` khớp math ở ortho (4.0000) và lệch ở persp (4.0616 vs 4.4579) → chính là bằng chứng ràng buộc cấu trúc.
3. **Camera snap khóa world crawl chỉ với ortho:** `anchor_fx` = 0.0000 mọi frame ở ortho9_snap; residual 7406→347 (−95%). Persp snap không giảm (18013→18681) vì px/unit đổi theo độ sâu.
4. **Snap đánh đổi sang sprite crawl:** `player_fx` nosnap hằng 0.0000 (camera bám đúng player nên sprite đứng yên trên màn hình); bật snap thành 0.3333/0.6667 luân phiên. Khóa lưới pixel đầy đủ cần **visual snap của sprite** tách khỏi logic position — chưa implement, D-008.
5. Residual ~300 px còn lại ở ortho_snap là viền reticle: reticle bám tia chuột nên dịch chuyển theo camera, không phải world tĩnh; không phải shimmer lưới.

**Giới hạn:** shimmer đo bằng số + ảnh residual, chưa phải video; cảm nhận crawl khi chơi thật chờ L4. Sprite crawl mới có số, chưa xác nhận thị giác. fps HUD trong ảnh capture là artifact capture dày, đo thật ở L4.