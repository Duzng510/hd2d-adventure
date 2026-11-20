# PHASE B — ĐỊNH NGHĨA VẬN HÀNH GATE (DRAFT)

> Trạng thái: **PROPOSED** (T-008, 2026-11-20) — cần user xác nhận **trước khi** đánh giá bất kỳ gate nào (luật như Phase A T-001). Nguồn gate: GDD 6.8; debug bắt buộc: MP 6.4.

## 0. Quy tắc chung

- Mỗi check là nhị phân, quan sát được; Passed chỉ khi evidence đã được xem thật.
- AI-observed (L1–L3) tách khỏi User-reported (L4); rubric L4 theo MP mục 9.
- Không tự nâng ngưỡng/đổi cách đo giữa chừng; thay đổi phải ghi DECISIONS và được user duyệt.
- Thiếu evidence → Not Run/Blocked, không Passed. Fail phải kèm bước tái hiện + log/ảnh.
- Giá trị tham số gate đọc từ `res://scripts/combat/combat_tuning.tres` (authoritative), không chép số vào file này.

## 1. Gate B1 — Responsiveness (L4)

- B1.1: Người chơi chơi tối thiểu 10 encounter (hoặc 1 phiên phủ đủ: di chuyển, đánh, né, bị đánh) và chấm điểm theo rubric §9.
- B1.2: Trung bình Responsiveness **≥ 3/5**.
- Evidence: form MP mục 9 + điểm theo rubric §9. Engine-side input→action_start từ combat log chỉ là diagnostic, không thay rubric.

## 2. Gate B2 — One-hit-per-swing (L3 automated)

- B2.1: Test kernel 100 swing liên tiếp lên cùng target → **0 lần damage lặp** (exit 0).
- B2.2: Log in-scene của ≥10 swing: mỗi `attack_id` có đúng 1 cặp `hit`+`damage` trên mỗi target (CSV đã xem).
- B2.3: Negative control (tắt registry) cho ra >0 lặp — harness chứng minh biết FAIL.
- Pass: cả 3.

## 3. Gate B3 — Enemy detect → approach → attack

- B3.1: Player vào `grunt_detect_range` → enemy chuyển Alert trong ≤5 frame (log transition + test headless).
- B3.2: Chase tới `grunt_attack_range` rồi mới Telegraph; **0** lần đánh từ ngoài tầm qua 10 lần thử (CSV).
- B3.3: Không xuyên player/tường khi chase (log L2 + 1 ảnh).
- Pass: cả 3.

## 4. Gate B4 — Telegraph (L3 + L4)

- B4.1: Số frame `telegraph_start`→`active_start` trong log **≥ `grunt_telegraph_frames`** của tuning (hiện ≥18 theo GDD).
- B4.2: Tín hiệu telegraph đọc được trên ảnh L3: khác rõ idle, không bị sprite/hiệu ứng che, thấy trước active.
- B4.3: L4 — **≥80%** số lần bị trúng người chơi tự hiểu vì sao; ghi `x/y` và `n`.
- Pass: cả 3.

## 5. Gate B5 — 10 encounter liên tiếp

- B5.1: 10 run liên tiếp (thắng hoặc thua), mỗi run kết thúc đúng (win/lose) và reset được → **10/10**.
- B5.2: Không SCRIPT ERROR / lỗi chặn trong log 10 run.
- B5.3: R reset đưa về trạng thái đầu (HP player/enemy, vị trí, log reset event) — ảnh/log trước-sau.
- Pass: cả 3.

## 6. Gate B6 — Readability (L4 + L3)

- B6.1: Rubric Readability trung bình **≥ 3/5** (§9).
- B6.2: Sau mỗi run, người chơi trả lời có/không: (a) nhận ra enemy đang telegraph, (b) biết đòn đã trúng mình, (c) biết khi nào có cơ hội phản công. Pass nếu **≥80%** câu trả lời "có" trên toàn bộ run; ghi `x/y`.
- B6.3: Ảnh telegraph/active/hit đã xem thật.
- Pass: cả 3.

## 7. Gate B7 — Hai cách tiếp cận hợp lệ (L4)

- B7.1: Thắng ≥1 run bằng dodge-rồi-phản-công.
- B7.2: Thắng ≥1 run bằng áp sát/chen recovery (không chỉ né).
- B7.3: Không tồn tại cách thắng bằng spam thuần tấn công ở mọi run; nếu có, ghi Fail và bổ sung **đúng một** cơ chế (GDD 6.8.7), không mở rộng hệ thống.
- Pass: B7.1 + B7.2, và B7.3 không vi phạm.

## 8. Debug bắt buộc (MP 6.4) — nhị phân

- D1: F1 toggle hitbox/hurtbox hoạt động — ảnh before/after.
- D2: Combat log CSV có đủ event §9 (MP 6.4) — trích CSV.
- D3: Spawn/reset nhanh encounter (R) hoạt động trong build.
- Pass: cả 3; thiếu 1 → **không** được tuyên bố combat prototype "chạy" (MP 6.4).

## 9. Rubric anchors (L4, 1–5)

**Responsiveness**
1 = input mất >¼ giây hoặc mất input thường xuyên; 2 = thường trễ, khó phối hợp đánh/né; 3 = phản hồi đủ chơi, thỉnh thoảng trễ; 4 = phản hồi nhanh, hiếm trễ; 5 = tức thì, không quan sát thấy trễ.

**Readability**
1 = không phân biệt telegraph/đòn/hit; 2 = thường mất dấu trạng thái enemy; 3 = đọc được phần lớn tình huống; 4 = đọc rõ mọi đòn và trạng thái; 5 = đọc rõ cả khi hiệu ứng dày.

Rubric chủ quan một người, sample nhỏ → tín hiệu ban đầu, không phải kết luận thống kê (GDD ghi chú MVS-AC4).

## 10. Evidence & cách chạy

- Thư mục: `docs/phase-b/evidence/<gate>/` (b1…b7, debug); harness `scenes/phase_b/` + driver `scripts/phase_b/` (tạo ở task tương ứng).
- Build: `run.bat` / VSCode Ctrl+Shift+B; commit hash ghi trong STATE.md tại thời điểm chơi.
- Combat CSV chép từ `user://combat_log.csv` vào evidence; ảnh phải xem thật trước khi ghi Passed.
- FPS trong combat: ghi nhận kèm cấu hình máy (i5-13420H / Intel UHD, Forward+); là diagnostic cho D-004, không phải gate.

## 11. Bảng tổng hợp (điền khi đánh giá)

| Gate | Kết quả | Evidence | Ngày |
|---|---|---|---|
| B1 Responsiveness | | | |
| B2 One-hit-per-swing | | | |
| B3 Enemy AI ranges | | | |
| B4 Telegraph | | | |
| B5 10 runs | | | |
| B6 Readability | | | |
| B7 Two approaches | | | |
| D1–D3 Debug | | | |

## 12. Thứ tự thực hiện

B2/B3 chạy được sớm bằng test headless sau T-009/T-011; B1/B4.3/B6/B7 cần L4 sau T-012; D1–D3 kiểm trong T-010–T-012. Chỉ chấm gate tổng sau khi user xác nhận file này; Phase B exit cần đủ B1–B7 + D1–D3 (hoặc waiver MP 8.6).
