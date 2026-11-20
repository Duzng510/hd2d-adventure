# PLAYTEST BRIEF — PHASE C (L4, T-024)

> Trạng thái: **sẵn sàng chơi** — chờ user chạy 10 encounter trong MỘT session và gửi báo cáo theo mẫu §5.
> Build: nhánh `phase-c/t024-l4-session`, commit `3ada4db` (scorer + launcher) trên nền `3fba5fe` (sửa boss lặp đòn chuyển phase). Đây là build **khóa cho session** — không đổi tuning, không pull code giữa chừng (C1.3a).
> Môi trường: Windows (i5-13420H / Intel UHD / 24 GB), 1280×720, Forward+ Vulkan. Bàn phím + chuột.

## 1. Cách chạy

**Double-click `run_arena.bat`** ở root repo. File này mở thẳng `scenes/phase_c/grove_arena.tscn`.
`run.bat` và `Ctrl+Shift+B` vẫn mở playground Phase A — **dùng `run_arena.bat`**, vì mỗi lần mở game là `user://combat_log.csv` bị xoá để ghi lại (log truncate theo launch).

Nếu game báo hàng loạt `Parse Error: Identifier "..." not declared` sau khi đổi branch: chạy một lần
`<GODOT> --headless --path . --import` rồi mở lại — không phải lỗi gameplay.

| Phím | Tác dụng |
|---|---|
| WASD | Di chuyển |
| Chuột | Ngắm (hướng đòn snapshot lúc bắt đầu swing, D-010) |
| LMB | Light attack (combo 3, buffer 6 tick) |
| Space | Dodge (i-frame 10/22 tick) |
| **R** | Reset encounter (về wave 1, HP full, cổng đóng) |
| F1 | Overlay hitbox/hurtbox (debug — không cần chấm) |
| P / L | Persp-ortho / frame log (debug — không cần chấm) |

HUD: dòng trên trái `frame | pos | vel | fps | ...` (có **fps** — dùng cho C3.3); dòng dưới `PLAYER hp | WAVE x/3 | ENEMIES n | trạng thái`, thêm `BOSS hp/300 | PHASE n` và `CỔNG MỞ — SHRINE PHÍA BẮC` / `CỔNG MỞ — ĐÃ HỘI MÁU`.

**Encounter:** vào arena (lại gần điểm spawn) để mồi wave 1. Wave 1 = 2 Grunt + 3 Swarm · Wave 2 = 2 Swarm + 2 Ranged · Wave 3 = mini-boss Grove Warden (đổi phase tại HP ≤ 50%). Thắng = boss chết → cổng bắc mở + shrine phía sau hồi đầy HP. **Win không tự reset** (bạn vẫn đi được, thử đi qua cổng) — ấn **R** để về run kế. Thua (HP 0) tự reset sau ~2 s.

**Thông số khóa (`scripts/combat/combat_tuning.tres`, HYPOTHESIS — giá trị đang chạy):** player 100 HP; light 4/3/10 frame, 10 dmg, reach 1.4, combo 3; dodge i-frame 10/22. Grunt 30 HP, telegraph 20, dmg 15. Swarm 20 HP, telegraph 18, active 4, recovery 20, dmg 5, nhanh ×1.25. Ranged 30 HP, telegraph 24, dmg 8, projectile 6 m/s (sống tối đa 2 s), giữ khoảng cách 3.5–7.0 m. Boss 300 HP — smash 30/6/30 dmg 20 (r 2.2 m) · lunge 24/8/24 dmg 12 (tầm 5 m) · sweep (phase 2) 20/6/24 dmg 10 (360°, r 2.6 m) · đòn chuyển phase telegraph 45 frame không damage, phase 2 nhanh hơn qua recovery (20/16). Mọi telegraph ≥ 18 frame.

## 2. Run hợp lệ (C1) — 4 điều kiện

1. Bắt đầu từ trạng thái chuẩn: player ở spawn, HP full, wave 1 vừa spawn, cổng đóng, boss phase 1, không projectile tồn.
2. Chơi liên tục từ wave 1 tới hết.
3. Kết thúc ở **win** (boss chết + `reward_granted`) hoặc **lose** (HP 0).
4. Ấn **R** sau run để đưa về trạng thái chuẩn cho run kế.

Run bỏ dở / quit / crash / kẹt: **ghi riêng ở §6, không tính vào 10** (C1.1). Chơi **một session liên tục, một lần mở game** cho cả 10 run.

Gợi ý phân bổ: cả 10 run chơi tự nhiên như bạn muốn thắng (không cần ép bài). Nếu muốn, 2 run cuối thử chơi "an toàn" (né nhiều) để xem độ khó dịch về đâu.

## 3. Sau MỖI run, trả lời ngay (kéo dài ~2–3 s)

- **Readability 1–5** và **Fairness 1–5** cho run đó (C2.1 — chấm từng run, không chấm gộp).
- **x/y**: `y` = số lần bị trúng trong run (đếm theo cảm nhận; HP cuối run đối chiếu được: `y ≈ HP mất / dmg từng vai trò`), `x` = trong đó bạn **hiểu rõ lý do** đứng trúng (đọc được telegraph, không bị che, không phải đòn từ ngoài tầm nhìn).
- 4 câu có/không: (a) phân biệt được 4 vai trò chỉ bằng hình? (b) đọc được projectile đang bay? (c) nhận ra boss đã vào phase 2? (d) có lúc nào telegraph bị trụ/hiệu ứng/body che không?

## 4. Cuối session (C1.3, C3)

- C1.3: các lần **thua** (nếu có) đến từ quyết định trong encounter (tham đánh, đứng sai chỗ, bị kite) hay do lỗi kỹ thuật/khó hiểu? Nếu do lỗi → C1 Incomplete, sửa rồi chơi lại.
- C3.1: có **SCRIPT ERROR**, wave không spawn, cổng không mở, boss kẹt chuyển phase, projectile tồn tại vô hạn không?
- C3.2: 10/10 lần ấn R có đưa về đúng trạng thái chuẩn (HP full, wave 1, enemy cũ sạch, cổng đóng, boss HP/phase reset)?
- C3.3: **fps** đọc trên HUD ở 2 thời điểm — wave 1 (5 enemy) và boss phase 2 (chỉ ghi nhận, không có ngưỡng).
- Chấm gộp **Fun 1–5** + **Responsiveness 1–5** toàn session (MP 9; Responsiveness không thuộc gate Phase C nhưng cần baseline).

## 5. Mẫu báo cáo (copy và điền)

```
Build/commit: 3ada4db (nhánh phase-c/t024-l4-session)
Ngày chơi:
Số lần mở game trong session: 1 (bắt buộc)
FPS quan sát: wave 1 ~__ / boss phase 2 ~__
Fun: __/5   Responsiveness: __/5

| # | W/L | Wave dừng | Read | Fair | a | b | c | d | Hit (y) | Hiểu lý do (x) | Ghi chú |
|---|-----|-----------|------|------|---|---|---|---|---------|----------------|---------|
| 1 |     |           |      |      |   |   |   |   |         |                |         |
| 2 |     |           |      |      |   |   |   |   |         |                |         |
| 3 |     |           |      |      |   |   |   |   |         |                |         |
| 4 |     |           |      |      |   |   |   |   |         |                |         |
| 5 |     |           |      |      |   |   |   |   |         |                |         |
| 6 |     |           |      |      |   |   |   |   |         |                |         |
| 7 |     |           |      |      |   |   |   |   |         |                |         |
| 8 |     |           |      |      |   |   |   |   |         |                |         |
| 9 |     |           |      |      |   |   |   |   |         |                |         |
| 10|     |           |      |      |   |   |   |   |         |                |         |

C1.3 thua do quyết định trong encounter? (có/không + giải thích)
C3.2 R luôn về trạng thái chuẩn? (mấy/10 + mục nào lệch)
C3.1 lỗi kẹt/không spawn/telegraph biến mất:
Run bỏ dở (không tính):
```

## 6. Gửi kèm số đo máy (chạy 1 lệnh)

**Trước khi mở lại Godot**, copy log ra ngoài:

```
copy "%APPDATA%\Godot\app_userdata\hd2d-adventure\combat_log.csv" docs\phase-c\evidence\t024\session1.csv
node tools/score_l4.mjs docs/phase-c/evidence/t024/session1.csv --engine-log "%APPDATA%\Godot\app_userdata\hd2d-adventure\logs\godot.log" --runs 10
```

Lệnh in bảng per-run (W/L, wave, ticks, hit nhận theo từng vai trò, reward) + mục `Violations`. Dán cả output vào báo cáo (hoặc gửi file). Tool chỉ đo phần khách quan — nó **không** tự chấm Passed cho C1/C2/C3.

Nếu tool báo đỏ mà bạn cho rằng log sạch: đó là lúc cần đối chiếu, không phải lúc bỏ qua (`node tools/score_l4.mjs --selftest` chứng minh tool vẫn biết báo đỏ).

## 7. Lỗi đã biết — không tính là lỗi mới

- Cổng reward trông giống hệt tường bắc (known issue T-022) — dễ không nhận ra "đây là cổng".
- Body boss (1.6×2.4 m) che phần trên decal telegraph — viền vẫn đọc được (T-021).
- Boss chase/lunge không pathfind: lunge có thể đâm vào tường giữa đường (T-014 → T-021).
- Player đi xuyên body Grunt/Swarm/Ranged (`collision_layer = 0`, D-005) — session này đánh giá mức khó chịu.
- HUD giữ dòng `BOSS 0/300 | PHASE 1` sau khi boss chết (T-022).
- Spam Light Attack vẫn chưa có cơ chế chống spam (GDD 6.8.7, waiver D-012) — **đừng** dùng spam làm bài thử Phase C.
- Ảnh capture cũ fps thấp là artifact `--fixed-fps`, không phải FPS game.

**Vừa sửa, cần để ý:** trước `3fba5fe`, boss đứng yên 2 lần liên tiếp khi vào phase 2. Nếu bạn vẫn thấy nó lặp đòn chuyển phase (đứng yên ~1.5 s hai lần liền) → báo ngay, đó là bug chứ không phải thiết kế.

## 8. Sau khi có báo cáo

- Chấm C1.1/C1.2/C1.3/C2.1/C2.2/C3.1/C3.2/C3.3 + đối chiếu E1–E5 (đã Passed ở `docs/phase-c/evidence/t023/`), suy ra C1–C3 và **exit Phase C** (OPERATIONAL_DEFINITIONS §8).
- Tuning: một tham số mỗi lần, ghi trước/sau, chỉ khi có dữ liệu playtest/log (MP 9). Không suy cảm giác từ code.
