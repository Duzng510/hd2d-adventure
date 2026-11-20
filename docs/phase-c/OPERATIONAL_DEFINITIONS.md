# PHASE C — ĐỊNH NGHĨA VẬN HÀNH GATE

> Trạng thái: **CONFIRMED** — user xác nhận 2026-11-20 (chat "y" sau review bản PROPOSED). Gate Phase C chỉ được chấm theo bản này. Nguồn gate: GDD 0.7.1 mục 12 (Phase C) + rubric mục 14; giao thức playtest MP mục 9. Tham số cảm giác đọc từ `res://scripts/combat/combat_tuning.tres` (authoritative, mở rộng cho Phase C); số ở Phụ lục §9 là **HYPOTHESIS**, không phải giá trị cuối.

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
- **E1–E5 là điều kiện tiên quyết của L4**: nếu evidence cơ chế chưa Passed, C1/C2 giữ **Not Run** (không được Incomplete/Passed).

## 1. Phạm vi được chấm

- Arena mới `scenes/phase_c/grove_arena.tscn` (~14×10 m, tường ranh giới layer 1, 2–3 trụ cover), encounter 3 wave tuần tự:
  - Wave 1: 2 Grunt + 3 Swarm.
  - Wave 2: 2 Swarm + 2 Ranged.
  - Wave 3: mini-boss "Grove Warden" (2 phase tại HP ≤ 50%).
- Reward: boss chết → cổng ra mở (shortcut) + heal full tại shrine; R reset đóng cổng.
- Tái dùng: player, camera rig, CombatDirector, combat log, physics layers 1–6 (không thêm layer mới), `combat_tuning.tres` (thêm tham số Phase C).
- **Ngoài scope**: cơ chế chống spam GDD 6.8.7 (backlog — khi được thêm phải retest B7.3 bằng `run_b7_spam.tscn` theo D-012), pathfinding, weapon mới, save/inventory.

## 2. Gate C1 — Hoàn thành encounter từ đầu đến cuối ≥ 8/10 (L4)

Run hợp lệ (4 điều kiện, đủ cả 4):
1. Bắt đầu từ trạng thái reset chuẩn: player ở spawn, HP full, wave 1 vừa spawn, cổng đóng, boss phase 1, không projectile tồn. Run đầu tiên bắt đầu khi player vào trigger arena; các run sau bắt đầu ngay sau reset (R hoặc auto-reset).
2. Chơi liên tục từ wave 1 đến kết thúc.
3. Kết thúc ở **win** (boss chết + `reward_granted`) hoặc **lose** (player HP 0).
4. Reset sau run đưa về trạng thái chuẩn cho run kế.

Run bỏ dở/quit/crash/SCRIPT ERROR: ghi riêng, **không** tính vào 10, không âm thầm thay thế.

- C1.1: **10/10 run hợp lệ** liên tiếp trong **một session** (CSV copy ra ngoài trước khi mở Godot — `user://combat_log.csv` truncate mỗi lần launch).
- C1.2: Ghi từng run: kết quả (W/L), wave kết thúc, thời lượng tick. Pass: **wins ≥ 8/10**.
- C1.3 "Độ khó có chủ đích": (a) tuning khóa trước session — ghi commit + giá trị `.tres`, không đổi giữa session; (b) sau session user xác nhận các lần thua (nếu có) đến từ quyết định trong encounter thiết kế, không do lỗi kỹ thuật/khó hiểu. User báo do lỗi → C1 Incomplete, sửa rồi chạy lại.
- Pass: cả 3.

## 3. Gate C2 — Telegraph & feedback rubric ≥ 3/5 (L4 + L3)

- C2.1: **Readability và Fairness** chấm từng run (MP 9), mean trên run hợp lệ **≥ 3/5** mỗi mục, không làm tròn trước khi so ngưỡng; ghi điểm từng run.
- C2.2: `x/n` = số lần bị trúng mà người chơi hiểu lý do / tổng lần bị trúng trong run hợp lệ; Pass **≥ 0.80**; hit không giải thích được vẫn nằm trong `n`; ghi `x`, `n`.
- C2.3: Ảnh telegraph của **mọi đòn mới** (smash, lunge, sweep, projectile) đã xem thật; khác rõ idle, không bị sprite/hiệu ứng che, thấy trước active.
- Pass: cả 3.

## 4. Gate C3 — Không lỗi chặn (L2 + L4)

- C3.1: **0 SCRIPT ERROR** và **0 soft-lock** (wave không spawn, cổng không mở, boss kẹt chuyển phase, projectile tồn vô hạn) trong 10 run.
- C3.2: R reset **10/10** về trạng thái chuẩn đầy đủ: HP player, wave = 1, enemy wave cũ cleared, projectile cleared, cổng đóng, boss HP + phase reset, action phase, buffer/combo, HitRegistry, hitstop; log `encounter_reset` trước-sau.
- C3.3: FPS ghi nhận trong lúc chơi — **diagnostic, không có ngưỡng gate** (đo ở L4, không suy từ ảnh capture `--fixed-fps`).
- Pass: C3.1 + C3.2 (C3.3 chỉ ghi nhận).

## 5. Evidence cơ chế E1–E5 (AI-observed, fail-first — điều kiện tiên quyết của L4)

Mỗi mục cần test dương tính **và** negative control: harness phải fail vì **đúng lý do** (assert message/trạng thái, không chỉ exit code khác 0).

- **E1 Swarm**: E1.1 ≥3 swarm hoạt động đồng thời ở wave 1 (log + ảnh đã xem); E1.2 mỗi đòn swarm có `active_start − telegraph_start ≥ swarm_telegraph_frames` (sàn GDD ≥ 18); E1.3 one-hit-per-swing giữ nguyên cho mọi loại enemy (10 swing/loại, mỗi `attack_id` đúng 1 hit + 1 damage/target); E1.4 negative control (tắt registry → `duplicate_count > 0`, fail đúng counter).
- **E2 Ranged**: E2.1 ngoài `ranged_max_range` không bắn (0 `projectile_fire` trong ≥120 tick); E2.2 telegraph ≥ sàn 18 trước mỗi phát; E2.3 projectile damage player **đúng 1 lần**, despawn khi trúng/tường (log); E2.4 negative control (bỏ gate active-window hoặc range → harness fail đúng assert tương ứng).
- **E3 Boss**: E3.1 hai đòn smash/lunge có telegraph **khác nhau nhận diện được** (ảnh đã xem + frame log); E3.2 phase 2 chuyển **đúng 1 lần** tại HP ≤ 50%, log `boss_phase` value 2, không dao động; E3.3 telegraph mọi đòn (gồm sweep) **≥ 18 frame ở cả 2 phase**; E3.4 one-hit-per-swing với boss; E3.5 negative control (đặt threshold phase sai → test bắt).
- **E4 Reward**: E4.1 trước win cổng đóng và chặn di chuyển; E4.2 sau boss chết: `reward_granted` + cổng mở + HP về full (log + ảnh before/after); E4.3 R đóng cổng + reset HP đúng; E4.4 negative control (tắt reward hook → cổng không mở → assert fail).
- **E5 Wave flow**: E5.1 wave kế chỉ spawn khi wave trước chết hết (10 chu kỳ headless, log `wave_start` đúng thứ tự); E5.2 win **chỉ** khi boss chết (clear wave 1/2 không win); E5.3 10 chu kỳ headless exit 0; E5.4 negative control (cho spawn sớm hoặc win sớm → assert fail).

## 6. Debug bắt buộc D1–D3 (kế thừa Phase B, áp dụng cho enemy mới)

- D1: F1 toggle hitbox/hurtbox hoạt động với **mọi** enemy mới (Swarm, Ranged, Boss) và projectile — overlay đúng shape/transform `Area3D` thật, ảnh before/after.
- D2: Combat log CSV đủ event cũ + event mới: `wave_start`, `projectile_fire/hit/despawn`, `boss_phase`, `reward_granted` — trích CSV; COMBAT_SPEC cập nhật schema trong task tương ứng.
- D3: R spawn/reset nhanh encounter hoạt động trong build.
- Pass: cả 3; thiếu 1 → **không** được tuyên bố encounter "chạy" (MP 6.4).

## 7. Rubric anchors (L4, 1–5) — kế thừa Phase B §9, bổ sung cho encounter nhiều enemy

**Readability** (bổ sung neo): nhận ra đòn của từng vai trò (Grunt/Swarm/Ranged/boss) và phân biệt chúng; đọc được projectile đang bay; nhận ra boss đã vào phase 2; hiệu ứng không che telegraph (pillar 1).
**Fairness** (bổ sung neo): mọi damage truy được về telegraph đã thấy; không có đòn từ ngoài vùng quan sát của camera tĩnh; số enemy đồng thời không vượt khả năng đọc.
**Responsiveness / Fun**: giữ nguyên neo Phase B §9 (MP 9), không đổi.

## 8. Trình tự, exit & nghĩa vụ retest

- Thứ tự: T-017 (bản này) → T-018 arena + wave kernel → T-019/T-020/T-021 (Swarm/Ranged/Boss) → T-022 reward → T-023 evidence E1–E5 + negative controls → T-024 L4 session.
- **Exit Phase C**: C1 + C2 + C3 Passed **và** E1–E5 Passed **và** D1–D3 Passed. Không đạt thì theo waiver MP 8.6 (ghi rõ mục waiver, giữ trạng thái thật).
- **Nghĩa vụ còn treo (không thuộc Phase C)**: khi cơ chế chống spam GDD 6.8.7 được thêm, B7.3 phải retest bằng đúng `run_b7_spam.tscn` (D-012) — Phase C không thêm cơ chế này.

## 9. Phụ lục — HYPOTHESIS tuning Phase C (đọc từ `combat_tuning.tres`; không phải giá trị cuối)

Đơn vị thời gian = physics frame @ 60 tick/s. Mọi thay đổi tuning sau L4: một tham số mỗi lần, ghi trước/sau (MP 9).

| Thực thể | Thông số HYPOTHESIS |
|---|---|
| Swarm | HP 20 · speed ×1.25 so với Grunt · telegraph 18 (sàn 18) · active 4 · recovery 20 · damage 5 · 3 con ở wave 1, 2 con ở wave 2 |
| Ranged | HP 30 · kite min 3.5 m / max 7.0 m · telegraph 24 · projectile speed 6 m/s, lifetime ≤ 2 s · damage 8 · 2 con/wave 2 |
| Boss — smash | HP boss 300 · telegraph 30 · active 6 · recovery 30 · damage 20 · bán kính vùng 2.2 m |
| Boss — lunge | telegraph 24 · active 8 · recovery 24 · damage 12 · tầm 5 m |
| Boss — sweep (phase 2) | telegraph 20 · active 6 · recovery 24 · damage 10 · 360° bán kính 2.6 m |
| Boss — phase | chuyển tại HP ≤ 50% · telegraph chuyển phase 45 frame, không damage · tempo phase 2 nhanh hơn qua recovery, **không hạ telegraph dưới 18** |
| Encounter | wave pause 60 tick · 4 spawn point · cổng đóng mặc định |
