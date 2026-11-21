# T-032 A/B — tell bật vs tell tắt

Ngày đo: 2026-11-22 · Người chơi: user (1 người) · Build: `main` @ `2e58eff`
Lệnh: `node tools/l4_ab.mjs` (arm A = `play_arena.tscn`, arm B = `play_arena_notell.tscn`, 5 run/arm, R reset giữa các run)
Điểm: `node tools/score_l4.mjs docs/phase-d/evidence/t032/ab/<arm>/combat_log.csv --runs 5`

## Câu hỏi

Tell đã **nhìn thấy được** (L3: 144–148 px mỗi bậc, control 0 px) và user báo **đọc đúng nghĩa** ("có thấy, hiểu là mệt"). Câu hỏi còn lại của AC5 là hành vi: *cung xanh có khiến người chơi đổi nhịp* — cụ thể là né/ngừng bấm để trả bậc mệt — so với chính cơ chế đó mà không vẽ gì?

## Số đo

| Đo | A (tell bật) | B (tell tắt) |
|---|---|---|
| Run hợp lệ / win | 5 / 0 | 5 / 0 |
| Tổng đòn (action_start) | 374 | 337 |
| Đòn trả mệt (bậc 1+2+3) | 55% | 45% |
| Đòn ngồi trần 12 tick | 116 (31%) | 90 (27%) |
| Histogram bậc charged (0/4/8/12 tick) | 167 / 46 / 45 / 116 | 186 / 33 / 28 / 89 |
| Né-trả-mệt ngay sau đòn đã trả | 37 | 26 |
| Telegraph mở lúc né-trả-mệt vs lúc né khác | **38% vs 57%** | **12% vs 32%** |
| Gap trung vị tới đòn kế sau khi chạm trần | 13 tick | 14 tick |
| Bỏ nhịp ≥29 tick sau khi chạm trần | 33% | 39% |
| Hit ăn / punishShare / readableShare | 64 · 62% · 60/64 | 55 · 45% · 53/55 |
| fps min / median | 55 / 60 | 58 / 60 |

## Kết luận

**Không phát hiện tác dụng hành vi của lớp vẽ.** Nói đúng hơn:

1. **Kênh phân biệt tồn tại ở cả hai arm.** "Né sau đòn trả mệt ít gặp telegraph đang mở hơn né thường" lặp lại gần như nguyên độ lớn (19 điểm và 20 điểm). Vậy chỉ tiêu đó đo **cấu trúc của log** — đòn vừa trả mệt thì đang trong recovery, cửa sổ boss thường đã khép — chứ không đo tell. Nó không được dùng làm bằng chứng cho AC5.
2. **Hướng lệch còn ngược chiều** (B bỏ nhịp sau khi chạm trần nhiều hơn A: 39% vs 33%), nhưng với 1 người chơi và 5 run/arm thì chênh này nằm trong dao động giữa các run; không kết luận "tell làm người chơi mash nhiều hơn".
3. **Hai arm không cùng áp lực**: punishShare 62% vs 45%, hit ăn 64 vs 55, readable 60/64 vs 53/55. Đây là so sánh open-label, không phải thí nghiệm một biến.

**AC5 = Partial.** Phần đạt: tell đọc được và đọc đúng (báo cáo user + L3 + `P32.7/P32.8`), không che readout khác, không đổi combat. Phần chưa đạt: chưa có bằng chứng *nhờ có tell mà người chơi đổi nhịp*. Tell **giữ nguyên trong build** vì chi phí gần bằng 0 (4 texture dựng một lần lúc load, signal bắn theo edge) và nó không gây hại cho kênh nào khác.

## Giới hạn cần ghi lại nếu người sau đọc

- n = 1 người, 5 run/arm, thứ tự A rồi B, **không counterbalance**. Học-nhớ chạy một chiều nên mọi hiệu ứng "B tốt hơn A" đều có thể là luyện tập chứ không phải tell.
- Phép đo "gap tới đòn kế" **bị nhiễu bởi combo chain**: mỗi hit trong chain tự ghi một `action_start`, nên gap 13–14 tick sau đòn chạm trần là khoảng cách *trong* chain, không phải thời điểm người chơi bấm lại từ đầu. Muốn đo "ngừng bấm" thật thì phải tính từ `active_end`/hết recovery của chuỗi, hoặc chỉ đếm `action_start` không có input buffer kế tiếp.
- Log bị cắt mỗi lần launch, nên ảnh + CSV của từng arm chỉ còn nguyên vẹn vì `tools/l4_ab.mjs` copy ra ngay khi cửa sổ đóng.

## Nếu muốn đo lại cho chặt

Theo thứ tự đáng làm: (1) sửa metric "ngừng bấm" khỏi combo chain như trên; (2) chạy `--arm B` trước rồi `--arm A`, mỗi arm 10 run; (3) chỉ khi số vẫn 0/0 mới cân nhắc làm tell đậm hơn (arc 2 texel + nhịp nhấn tại trần) — nâng hình ảnh theo một thước chưa đáng tin là đúng cái mà D-029 rủi ro (1) đã cảnh báo.
