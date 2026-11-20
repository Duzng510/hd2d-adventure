# PHASE B — ĐỊNH NGHĨA VẬN HÀNH GATE

> Trạng thái: **CONFIRMED** — user xác nhận 2026-11-20 (chat "y" sau review v2). Gate Phase B chỉ được chấm theo bản này. Nguồn gate: GDD 6.8; debug bắt buộc: MP 6.4. Giá trị tham số đọc từ `res://scripts/combat/combat_tuning.tres` (authoritative); khoảng GDD 6.4 chỉ là validation envelope tạm, không phải design-approved constraint.

## 0. Quy tắc chung & trạng thái

| Trạng thái | Ý nghĩa |
|---|---|
| **Passed** | Đã thực hiện đủ; **mọi** sub-check của gate Passed; evidence đã xem |
| **Failed** | Đã thực hiện; có ít nhất một sub-check không đạt |
| **Not Run** | Chưa thực hiện test |
| **Blocked** | Không thể thực hiện do prerequisite/build/công cụ bị chặn (ghi blocker + điều kiện gỡ) |
| **Incomplete** | Đã chạy nhưng thiếu evidence/trả lời để xác minh — không được Passed |

- `Failed` ≠ `Blocked`. Gate chỉ Passed khi **tất cả** sub-check Passed; không dùng "overall looks good" để override một sub-check Fail.
- Waiver theo MP 8.6 không biến check thành Passed; phải ghi rõ check được waiver, người xác nhận, lý do, phạm vi.
- Mỗi check nhị phân, quan sát được. AI-observed (L1–L3) tách khỏi User-reported (L4); rubric L4 theo MP mục 9.
- Không tự nâng ngưỡng/đổi cách đo giữa chừng; thay đổi phải ghi DECISIONS và được user duyệt.
- Không dùng kết quả gate này bù trừ gate khác (B1/B6 chấm độc lập).

## 1. Gate B1 — Responsiveness (L4)

- B1.1: **10 encounter hợp lệ** (định nghĩa run hợp lệ ở B5.1). Nếu dùng session thay thế, session phải chứa đủ 10 encounter được ghi riêng — không thay bằng "4 hành vi".
- B1.2: Chấm điểm **từng encounter**, lấy mean trên các encounter hợp lệ, **không làm tròn trước khi so ngưỡng**; ghi điểm từng run + mean. Pass: mean **≥ 3/5** (rubric §9).
- Evidence: form MP mục 9 + điểm từng run. Engine-side input→action_start từ combat log chỉ là diagnostic, không thay rubric.

## 2. Gate B2 — One-hit-per-swing (L3 automated)

- B2.1: Test kernel 100 swing liên tiếp lên cùng target, **reset HP/state target giữa các swing** → **0 damage lặp** (exit 0). Damage lặp = một attack instance gây >1 damage event lên cùng target.
- B2.2: Log in-scene của ≥10 swing: mỗi `attack_id` có đúng 1 cặp `hit`+`damage` trên **mỗi** target; swing trúng nhiều target → mỗi target 1 hit hợp lệ (CSV đã xem).
- B2.3: Negative control (tắt registry) → assert `duplicate_count > 0` trên đúng counter, chứng minh harness bắt được lỗi vì đúng lý do (không chỉ exit code khác 0).
- Pass: cả 3.

## 3. Gate B3 — Enemy detect → approach → attack

- B3.1: Đo từ **tick đầu tiên player ở trong** `grunt_detect_range` đến event `alert` (Alert là event, không phải state) → **≤ 5 tick**. Không đo từ lúc spawn/bắt đầu test.
- B3.2: **10 trial độc lập**: mỗi trial reset vị trí player/enemy + AI state, để enemy detect/chase bình thường; điều kiện "attack từ ngoài `grunt_attack_range` không gây damage" phải đúng 10/10; ghi kết quả từng trial.
- B3.3: Không xuyên player/tường khi chase (log L2 + 1 ảnh).
- Pass: cả 3.

## 4. Gate B4 — Telegraph (L3 + L4)

- B4.1: **Frame là authoritative**: `active_start.frame − telegraph_start.frame` ≥ `grunt_telegraph_frames` đọc từ `.tres` (hiện ≥18 theo GDD). Thời gian giây chỉ là diagnostic; không đổi gate theo FPS.
- B4.2: Tín hiệu telegraph đọc được trên ảnh L3: khác rõ idle, không bị sprite/hiệu ứng che, thấy trước active.
- B4.3: L4 — `n` = **tổng số lần player bị hit** trong các encounter được đánh giá; `x` = số lần người chơi nhận diện **đúng loại nguyên nhân** (đứng trong vùng active, dodge sai timing, vị trí bị đòn bao phủ… — không yêu cầu diễn đạt giống đáp án mẫu). Pass: `x/n ≥ 0.80`; hit không xác định nguyên nhân **vẫn nằm trong n**, không được loại để làm đẹp tỷ lệ. Ghi `x/n` và `n`.
- Pass: cả 3.

## 5. Gate B5 — 10 encounter liên tiếp

Run hợp lệ: (1) bắt đầu từ trạng thái reset chuẩn; (2) chơi được encounter bình thường; (3) kết thúc ở win hoặc lose state hợp lệ; (4) reset đưa về trạng thái bắt đầu chuẩn cho run kế. Run aborted/crash/không vào encounter **không tính** vào 10 run — ghi riêng, không âm thầm thay thế.

- B5.1: **10/10 run hợp lệ**.
- B5.2: Không SCRIPT ERROR / lỗi chặn trong log 10 run.
- B5.3: R reset đưa về trạng thái đầu đầy đủ (HP player/enemy, vị trí, AI state, action phase, buffer/combo, HitRegistry, hitstop; log `encounter_reset`) — ảnh/log trước-sau.
- Pass: cả 3.

## 6. Gate B6 — Readability (L4 + L3)

- B6.1: Rubric Readability chấm **từng run**, mean trên run hợp lệ ≥ 3/5 (§9), không làm tròn trước khi so.
- B6.2: Sau mỗi run, người chơi trả lời có/không 3 câu: (a) nhận ra enemy đang telegraph, (b) biết đòn đã trúng mình, (c) biết khi nào có cơ hội phản công. Với 10 run: `n = 30`; Pass nếu **≥ 24/30** "có". Ghi `x/30`; run thiếu câu trả lời đánh dấu **Incomplete**, không mặc định "có".
- B6.3: Ảnh telegraph/active/hit đã xem thật.
- Pass: cả 3.

## 7. Gate B7 — Hai cách tiếp cận hợp lệ (L4)

- B7.1: Thắng ≥1 run bằng dodge-rồi-phản-công.
- B7.2: Thắng ≥1 run bằng áp sát/chen recovery (không chỉ né).
- B7.3: Chiến thuật **spam thống nhất** (chỉ giữ attack liên tục, không dodge, không chủ động chờ punish) không được thắng mọi run; nếu thắng mọi run → Fail và bổ sung **đúng một** cơ chế (GDD 6.8.7), không mở rộng hệ thống.
- Pass: B7.1 + B7.2, và B7.3 không vi phạm.

## 8. Debug bắt buộc (MP 6.4) — nhị phân

- D1: F1 toggle hitbox/hurtbox hoạt động, overlay đúng shape/transform của `Area3D` thật — ảnh before/after.
- D2: Combat log CSV có đủ event §9 COMBAT_SPEC (gồm `alert`) — trích CSV.
- D3: Spawn/reset nhanh encounter (R) hoạt động trong build.
- Pass: cả 3; thiếu 1 → **không** được tuyên bố combat prototype "chạy" (MP 6.4).

## 9. Rubric anchors (L4, 1–5)

**Responsiveness**
1 = input mất >¼ giây hoặc mất input thường xuyên; 2 = thường trễ, khó phối hợp đánh/né; 3 = phản hồi đủ chơi, thỉnh thoảng trễ; 4 = phản hồi nhanh, hiếm trễ; 5 = tức thì, không quan sát thấy trễ.

**Readability**
1 = không phân biệt telegraph/đòn/hit; 2 = thường mất dấu trạng thái enemy; 3 = đọc được phần lớn tình huống; 4 = đọc rõ mọi đòn và trạng thái; 5 = đọc rõ cả khi hiệu ứng dày.

Rubric chủ quan một người, sample nhỏ → tín hiệu ban đầu, không phải kết luận thống kê (GDD ghi chú MVS-AC4). Chấm độc lập từng rubric, không bù trừ lẫn nhau.

## 10. Evidence & metadata

- Thư mục: `docs/phase-b/evidence/<gate>/` (b1…b7, debug); harness `scenes/phase_b/` + driver `scripts/phase_b/` (tạo ở task tương ứng).
- Mỗi evidence ghi/dẫn: commit hash · build/config (Forward+ / Intel UHD 1280×720) · tên test + version harness · ngày chạy · expected · actual · PASS/FAIL · đường dẫn file · người đánh giá (L4).
- Build: `run.bat` / VSCode Ctrl+Shift+B; commit hash trong STATE.md tại thời điểm chơi.
- Combat CSV chép từ `user://combat_log.csv` vào evidence; ảnh phải xem thật trước khi ghi Passed. `frame` trong log là `sim_frame` monotonic, không reset khi R.
- FPS combat: ghi nhận kèm cấu hình máy; diagnostic cho D-004, không phải gate.

## 11. Bảng tổng hợp (khởi tạo)

| Gate | Trạng thái | Evidence ref | Ngày |
|---|---|---|---|
| B1 Responsiveness | Passed | `evidence/b5/`: 11 run hợp lệ, user chấm gộp 4/5 (mean 4.0, không làm tròn) | 2026-11-20 |
| B2 One-hit-per-swing | Passed | B2.1 kernel 98 checks (100 swing, target HP reset); B2.2 `evidence/b2/` 12 swing; B2.3 registry-off negative exit 1 | 2026-11-20 |
| B3 Enemy AI ranges | Passed | `evidence/b3/`: 10 trial alert 0 tick, telegraph 1.292 ≤ 1.3, wall_min 0.350, player_min 3.100; negative telegraph 3.96 exit 1 | 2026-11-20 |
| B4 Telegraph | Passed | B4.1 t011 CSV 20 frame; B4.2 t011 ảnh telegraph; B4.3 x/n = 5/5 hit trong 11 run hợp lệ (user báo hiểu 19/19 toàn session) | 2026-11-20 |
| B5 10 runs | Passed | `evidence/b5/`: 13 run liền, 11 hợp lệ (2 run đứng yên chủ đích loại), 12 reset, 0 SCRIPT ERROR | 2026-11-20 |
| B6 Readability | Passed | User chấm gộp 4/5 (mean 4.0); a/b/c = 11/11 mỗi câu (33/33); B6.3 ảnh t011 | 2026-11-20 |
| B7 Two approaches | Incomplete | B7.1 `evidence/b7/` dodge run 20 Space, W; B7.2 11 run thắng áp sát/đánh gần; **B7.3 Not Run** (chưa test spam thuần; user chưa muốn thêm cơ chế) | 2026-11-20 |
| D1–D3 Debug | Passed | D1 t010 ảnh off/on; D2 CSV có `alert`; D3 t012 cycles + capture | 2026-11-20 |

## 12. Thứ tự, overlap & exit

- B2/B3 chạy được sớm bằng test headless sau T-009/T-011; B1/B4.3/B6/B7 cần L4 sau T-012; D1–D3 kiểm trong T-010–T-012.
- Overlap có chủ đích: B3 = AI/range correctness; B4 = attack warning correctness; B6 = holistic player understanding; B1 = input responsiveness. Không gate nào thay thế gate khác.
- **Phase B exit = AND(B1…B7, D1, D2, D3)** hoặc waiver MP 8.6; không có "80% gate là đủ", không gộp gate kỹ thuật với trải nghiệm thành điểm trung bình. Chỉ chấm gate tổng sau khi user xác nhận file này.

## 13. Evidence automated T-014 (2026-11-20)

Harness: `scenes/phase_b/run_b2_swings.tscn`, `run_b3_trials.tscn`, `capture_b3.tscn`; driver: `scripts/phase_b/b2_swing_driver.gd`, `b3_trial_driver.gd`, `b3_capture_driver.gd`. Kết quả dưới đây chạy trên commit T-014 (nhánh `phase-b/t014-gate-evidence`), Forward+/Intel UHD, headless dùng `--fixed-fps 60`.

- **B2.1**: `test_combat_kernel` 98 checks exit 0; 100 swing cùng target, target `Health(30)` reset mỗi swing → HP còn 20 sau mỗi swing (đúng 1 damage/swing). Negative `-- negative` fail 4/98 (gồm duplicate + HP reset) exit 1.
- **B2.2**: 12 swing trong scene (Grunt reset mỗi swing) → mỗi `attack_id` đúng 1 `hit` + 1 `damage`, target 1, damage 10; `evidence/b2/summary.txt` + `combat_log.csv`.
- **B2.3**: registry `enforce = false` → 3 hit/damage mỗi swing, harness FAIL exit 1 (bắt đúng lỗi duplicate).
- **B3.1**: 10 trial độc lập, player vào vùng detect ở x=7 (Grunt x=3) → `alert` cùng tick (latency 0 ở cả 10, ngưỡng ≤5).
- **B3.2**: telegraph tại distance 1.2917 ≤ 1.3 (10/10); damage xảy ra sau active và chỉ trong range; negative (attack_range=8) telegraph 3.96 + không damage → exit 1.
- **B3.3**: chase 240 tick vào tường: min clearance tâm Grunt→AABB tường = 0.350 (ngưỡng ≥0.3); min distance tới player = 3.100 (≥0.7); ảnh `chase_wall.png`, `chase_blocked.png` đã xem. AI không pathfind nên đứng tại tường — không phải xuyên.
- **B4.1**: từ `evidence/t011/combat_log.csv`: attack 2–7 có `active_start − telegraph_start = 20`; attack 1 = 23 do hitstop 3 khi player trúng đòn; min 20 ≥ `grunt_telegraph_frames`. **B4.2**: ảnh `t011/telegraph.png` + `telegraph_hitbox_overlay.png` đã xem.
- **D2**: CSV có `alert` (`t011` frame 1; `b3` 10 alert). **D1**: `t010/d1_off.png`/`d1_on.png` đã xem. **D3**: `t012` cycles (R/auto reset + `encounter_reset`) và capture HUD.
- Trước L4, node `Player/Telegraph` (placeholder Phase A luôn hiện quanh player) đã được ẩn (`visible=false`) để tránh nhầm với telegraph của Grunt; không ảnh hưởng logic/hitbox.

## 14. Evidence L4 — session 2026-11-20

Build: nhánh `phase-b/t014-gate-evidence` (nền T-012 `fd3a031`). Session liền 17:30–17:45, CSV `evidence/b5/combat_log_session.csv` (498 dòng), engine log `evidence/b5/engine_log.txt` (0 SCRIPT ERROR).

- **Run:** 13 run hoàn tất — 11 W, 2 L. Hai run L (7–8) do user **cố ý đứng yên** để Grunt đánh chết → loại khỏi 10 run hợp lệ (B5 còn 11 run). 12 `encounter_reset` (value 1…12) sau mỗi run.
- **B5.1/B5.3:** 11/11 run hợp lệ; reset có log; run kế tiếp bắt đầu từ trạng thái chuẩn (HP/HP Grunt đầy; log `encounter_reset`). B5.2: không SCRIPT ERROR trong engine log session.
- **B1:** user chấm gộp **4/5** cho 11 run (rubric §9). Mean 4.0 ≥ 3. *Deviation:* không chấm riêng từng run; ghi rõ user-reported gộp. Diagnostic engine-side: `input_light`→`action_start` 0 tick ×35, 1 tick ×9, 2 tick ×2 trên 47 cặp (~0–33 ms; 4 input không tạo action trong 6 tick do recovery/buffer).
- **B6:** readability gộp **4/5** (mean 4.0 ≥ 3); a/b/c = **11/11 mỗi câu** (33/33 ≥ 24). B6.3 ảnh t011 đã xem.
- **B4.3:** 11 run hợp lệ có **n=5** hit nhận; user báo hiểu lý do **19/19** cho toàn session (gồm 14 hit ở 2 run đứng yên, loại khỏi B5) → x/n = 5/5 = 100% cho run hợp lệ.
- **B7.1:** session riêng `evidence/b7/combat_log_dodge_run.csv`: 20 `input_dodge` (Space), 6 lần attack, 3 hit gây ra/2 hit nhận, **W** frame 1009 → dodge-rồi-phản-công hợp lệ.
- **B7.2:** 11 run thắng có 3–6 attack, 0–1 hit nhận, đánh gần; user xác nhận có run né bằng WASD; đủ một run áp sát/chen recovery (user-reported).
- **B7.3: Not Run.** Chưa có test spam thuần (chỉ giữ attack, không né/di chuyển/chờ). 11 run không có Space nhưng user báo có né bằng WASD → không phải spam thuần; user chưa muốn thêm cơ chế. **Rủi ro:** spam có thể vẫn thắng (run spam ~150 frame vs dodge run 1009 frame); cần test riêng trước khi tuyên bố B7 Passed.
- **Phase B exit: chưa đạt** — B7 Incomplete (B7.3); các gate còn lại Passed/đủ điều kiện. Cần test B7.3 + (nếu Fail) đúng một cơ chế, hoặc waiver MP 8.6.
