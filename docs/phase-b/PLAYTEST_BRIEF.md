# PLAYTEST BRIEF — PHASE B (L4)

> Trạng thái: **sẵn sàng chơi** — chờ user chạy 10 encounter và gửi báo cáo theo mẫu §3.
> Build chơi: nhánh `phase-b/t014-gate-evidence` (nền T-012 `fd3a031`; T-014 thêm harness gate và ẩn placeholder telegraph quanh player — không đổi gameplay combat).
> Môi trường: Windows (i5-13420H / Intel UHD / 24 GB), 1280×720, Forward+ Vulkan (D-004 Proposed). Chưa có build Android/touch — cần bàn phím + chuột.

## 1. Cách chạy & điều khiển

Chạy `run.bat` ở root repo (double-click), hoặc VSCode `Ctrl+Shift+B` (task "godot: run game"). Không cần mở editor.

Nếu game báo hàng loạt `Parse Error: Identifier "..." not declared` sau khi chuyển branch: global class cache đang cũ (bị editor quét trên branch không có script combat). Chạy một lần `<GODOT> --headless --path . --import` rồi mở lại game; không phải lỗi gameplay.

| Phím | Tác dụng |
|---|---|
| WASD | Di chuyển |
| Chuột | Ngắm; hướng đánh được **snapshot tại lúc bắt đầu swing** (D-010), không bám chuột liên tục |
| LMB | Light attack (combo tối đa 3, buffer 6 tick) |
| Space | Dodge (i-frame 10/22 tick) |
| R | Reset encounter ngay |
| F1 | Toggle hitbox/hurtbox (debug, MP 6.4) |
| P | Đổi persp/ortho (debug, không cần chấm) |
| L | Frame log (debug, không cần chấm) |

HUD góc trên trái: dòng debug (frame/fps/aim) + `PLAYER hp/100 | GRUNT hp/30 | trạng thái` (ĐANG ĐÁNH / THẮNG — R chơi lại / THUA — R chơi lại).

**Thông số hiện tại (HYPOTHESIS, đọc từ `scripts/combat/combat_tuning.tres`):** player 100 HP, light 4 startup + 3 active + 10 recovery frame, 10 damage, reach 1.4; Grunt 30 HP, detect 6.0, approach 2.5, attack range 1.3, telegraph 20 frame (~333 ms), active 3, recovery 18, damage 15. Hệ quả: **3 đòn light trúng = thắng; 7 đòn Grunt trúng = thua.**

## 2. Cần thử gì (10 run hợp lệ)

Run hợp lệ (B5.1): bắt đầu từ trạng thái reset chuẩn, chơi bình thường, kết thúc ở thắng hoặc thua, reset đưa về trạng thái đầu cho run kế. Sau thắng/thua, game tự reset sau ~2 s (120 tick); R reset ngay. Run crash/kẹt/không vào encounter **không tính** — ghi riêng.

Chơi **một session liên tục** cho cả 10 run (log CSV ghi toàn session; game khởi động lại sẽ xoá log cũ). Phân bổ gợi ý:

- Run 1–4: chơi tự nhiên.
- Run 5–6: cố ý thắng bằng **dodge rồi phản công** (B7.1).
- Run 7–8: cố ý thắng bằng **áp sát / chen recovery**, hạn chế né (B7.2).
- Run 9–10: **spam thống nhất** — chỉ đánh liên tục, không né, không chờ (B7.3). Ghi thắng/thua từng run.

Sau **mỗi run** trả lời 3 câu có/không (B6.2): (a) nhận ra Grunt đang telegraph? (b) biết đòn đã trúng mình? (c) biết lúc nào có cửa phản công?

Ngoài ra: chấm Responsiveness và Readability 1–5 mỗi run (rubric §9 OPERATIONAL_DEFINITIONS); đếm số lần bị trúng `y` (có thể suy từ HP cuối run: `(100 − HP)/15`) và số lần **hiểu đúng lý do** `x` (đứng trong vùng active, né sớm/muộn, sai vị trí… — hit không hiểu lý do vẫn nằm trong `y`); ghi FPS quan sát trên HUD lúc combat (diagnostic D-004); chấm Fairness/Fun 1–5 toàn session (MP 9, không thuộc gate).

## 3. Mẫu báo cáo (copy và điền)

```
Build/commit: fd3a031
Ngày chơi:
Responsiveness trung bình: __ / Readability trung bình: __ (không cần làm tròn)
Fairness: __/5  Fun: __/5
FPS quan sát khi combat (HUD): ~__

| # | W/L | Cách chơi | Resp | Read | a | b | c | Hit nhận (y) | Hiểu lý do (x) | Ghi chú |
|---|-----|-----------|------|---|---|---|---|--------------|----------------|---------|
| 1 |     |           |      |      |   |   |   |              |                |         |
| 2 |     |           |      |      |   |   |   |              |                |         |
| 3 |     |           |      |      |   |   |   |              |                |         |
| 4 |     |           |      |      |   |   |   |              |                |         |
| 5 |     |           |      |      |   |   |   |              |                |         |
| 6 |     |           |      |      |   |   |   |              |                |         |
| 7 |     |           |      |      |   |   |   |              |                |         |
| 8 |     |           |      |      |   |   |   |              |                |         |
| 9 |     | spam      |      |      |   |   |   |              |                |         |
| 10|     | spam      |      |      |   |   |   |              |                |         |

Tổng hit hiểu lý do: x/y = __/__
Lỗi + bước tái hiện:
```

Gửi kèm file log: `%APPDATA%\Godot\app_userdata\hd2d-adventure\combat_log.csv` (mỗi lần mở game tạo log mới; nếu chơi nhiều session, gửi đủ các file kèm session tương ứng).

## 4. Lỗi đã biết — không tính là lỗi mới

- Player có thể đi xuyên thân Grunt (`collision_layer = 0`, D-005) — chờ chính L4 này đánh giá mức ảnh hưởng.
- Art placeholder: nhân vật/Grunt là khối hộp, telegraph là quad, không animation; đánh giá readability trên placeholder là chủ đích.
- Khung placeholder Phase A quanh player đã được ẩn (T-014); telegraph thật chỉ xuất hiện dưới Grunt.
- Ảnh evidence cũ có fps thấp là artifact `--fixed-fps` của capture, không phải FPS game.
- Aim snapshot: đổi hướng chuột giữa swing không đổi hướng đòn đang ra (D-010).

## 5. Sau khi có báo cáo

- Chuyển báo cáo thành task; chấm gate B1/B4.3/B5/B6/B7 từ form, ghép với evidence L3 sẵn có (B2/B3/B4.1–2/D1–2) trong OPERATIONAL_DEFINITIONS §11.
- Tuning: **đổi một tham số mỗi lần**, ghi trước/sau, chỉ dựa trên dữ liệu playtest/log (MP 9). Không suy luận cảm giác từ code.
