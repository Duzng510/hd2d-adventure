# T-022 — Reward: Gate Shortcut + Shrine Heal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Status: DONE** (2026-11-20) — kernel+node `a02545f`, harness `70bfcee`, capture `ac08287`; validation ghi trong STATE.md.

**Goal:** Boss chết → `reward_granted` + cổng ra mở (shortcut đi được thật) + shrine sau cổng hồi full HP khi player chạm vào; R đóng cổng và reset HP đúng. Không còn soft-lock "cổng không mở".

**Architecture:** `RewardKernel extends RefCounted` (logic thuần, 3 trạng thái LOCKED → GATE_OPEN → HEALED, heal **một lần mỗi run**) quyết định grant/heal; node `Reward extends Node3D` nối `WaveEncounter.run_ended` + `run_reset`, tắt collision mesh cổng, dựng shrine bằng code, đo khoảng cách player→shrine và log. `WaveEncounter`: thắng **không** auto-reset (chỉ thua mới auto-reset) để player kịp đi bộ qua shortcut — user chốt 2026-11-20.

**Tech Stack:** Godot 4.7.2 (GDScript typed), headless SceneTree tests, harness `--fixed-fps 60`, capture PNG bằng renderer thật.

**Spec:** `docs/phase-c/OPERATIONAL_DEFINITIONS.md` §1 (reward: cổng mở + heal full tại shrine; R đóng cổng), §5 E4 (E4.1–E4.4), §2 C1 (run kết thúc = boss chết + `reward_granted`; reset về trạng thái chuẩn), §6 D2 (event `reward_granted`), MVS-AC6 (reward có tác dụng quan sát được).

## Global Constraints

- `<GODOT>` = `C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` (inner exe; quote trong Git Bash).
- Typed GDScript; 60 tick/s; physics layers 1–6 không đổi; input qua InputMap (`move_up` cho harness chặn cổng).
- Không sửa hành vi Phase B; `combat_tuning` không đổi (shrine radius là exported var trên node, không phải feel param combat).
- Heal chỉ diễn ra **sau khi cổng mở** và **một lần mỗi run**; HP full ngay khi boss chết là sai thiết kế đã chốt.
- Harness cũ dựa vào auto-reset khi thắng → phải đổi sang reset tường minh (`run_t018_cycles`, `run_t019_swarm`).
- Branch `phase-c/t022-reward` từ `main` (đã chứa T-021). Commit `feat/fix/art/docs(T-022)`, kèm `.uid`, không commit `.godot/`, push + PR sau validation xanh.
- Sau khi thêm `class_name`: `--import` trước L2/L3. Một `quit()` mỗi nhánh trong test SceneTree.

---

### Task 1: `Health.heal` + `RewardKernel` + `tests/test_reward_kernel.gd` (fail-first)

**Files:** Modify `scripts/combat/health.gd`; Create `scripts/phase_c/reward_kernel.gd`; Test `tests/test_reward_kernel.gd`.

**Interfaces:**
- `Health.heal(amount: int) -> int` — trả số HP thực hồi, không vượt max, không hồi khi đã chết.
- `RewardKernel`: `enum State { LOCKED, GATE_OPEN, HEALED }`; `state`; `grant() -> bool` (true lần đầu, các lần sau false); `gate_open() -> bool`; `try_heal(current_hp: int, max_hp: int) -> int` (0 nếu LOCKED/HEALED/full); `reset() -> void` (về LOCKED).

- [ ] Step 1: test — grant 1 lần duy nhất; heal trả đúng `max-hp` và chuyển HEALED; heal lần 2 trả 0; heal khi LOCKED trả 0; reset mở lại LOCKED (heal bị chặn, grant lại được); `Health.heal` cap theo max và trả 0 khi dead.
- [ ] Step 2: chạy → fail (class/ham chưa tồn tại).
- [ ] Step 3: implement.
- [ ] Step 4: positive exit 0; `-- negative` (`BrokenRewardKernel` cho heal khi LOCKED) exit 1 đúng assert "heal blocked before gate".

### Task 2: `Reward` node + wiring arena + win không auto-reset

**Files:** Create `scripts/phase_c/reward.gd`; Modify `scripts/phase_c/wave_encounter.gd` (thêm `signal run_reset`, chỉ auto-reset khi LOST), `scenes/phase_c/grove_arena.tscn` (node `Reward` + paths), `scripts/phase_c/wave_hud.gd` (dòng trạng thái reward).

**Interfaces:** `Reward` exports: `tuning`, `encounter_path`, `player_path`, `director_path`, `gate_body_path`, `gate_shape_path`, `shrine_position := Vector3(0, 0, -7.2)`, `shrine_radius := 1.5`. Hành vi: `run_ended(true)` → `kernel.grant()` → tắt collision cổng (`CollisionShape3D.disabled = true`) + ẩn mesh + log `reward_granted` (entity `reward`, value 1); mỗi tick nếu gate open và player trong `shrine_radius` → `Health.heal` + log `heal` (entity `reward`, target_id 2, value = amount) + hiện ring shrine; `run_reset` → kernel reset, bật lại collision + hiện mesh, ẩn ring.

- [ ] Step 1: `wave_encounter.gd` — tách nhánh WON/LOST (WON giữ player trong tay người chơi), emit `run_reset` cuối `reset_run()`.
- [ ] Step 2: `reward.gd` + shrine visual (disc ring code-gen, màu xanh mint) + wiring vào `grove_arena.tscn`.
- [ ] Step 3: `wave_hud.gd` thêm dòng "CỔNG MỞ | SHRINE SẴN" / "ĐÃ HỘI MÁU" khi có node Reward (export path, mặc định null → không hiện).
- [ ] Step 4: import + L1 + L2 arena/playground exit 0 + regression `test_combat_kernel`, `test_wave_kernel`, `test_reward_kernel`.

### Task 3: Harness E4 + driver cũ theo auto-reset

**Files:** Create `scripts/phase_c/t022_reward_driver.gd`, `scenes/phase_c/run_t022_reward.tscn`; Modify `scripts/phase_c/t018_cycle_driver.gd`, `scripts/phase_c/t019_swarm_driver.gd` (reset tường minh sau WIN vì win không còn auto-reset).

Harness dùng arena + WaveEncounter thật (không tắt encounter):
- [ ] E4.1 gate chặn: sau wave 1 spawn, teleport player (0,0,−4.5) + giữ `move_up` 120 tick → z không bao giờ < −5.8; `reward_granted` == 0.
- [ ] E4.2 grant + mở cổng + heal: kill toàn bộ enemy từng wave (`apply_hit(9999)`) tới khi WON → `reward_granted` delta 1; **win không auto-reset**: 200 tick sau `runs_completed` không đổi; giữ `move_up` → player đi qua được z < −6.2; đặt HP = 40 tại shrine → HP về 100, `heal` delta 1 value 60; chạm lại không heal nữa.
- [ ] E4.3 R reset: `reset_run()` → cổng đóng lại (giữ `move_up` 60 tick, z > −5.8), HP full, `reward_granted` không tăng, shrine không heal (HP 50 giữ nguyên 60 tick).
- [ ] Negative (E4.4): `reward.process_mode = DISABLED` trước khi win → cổng không mở → ASSERT FAIL "E4.2 gate opens after reward" exit 1.
- [ ] Regression: t018 10 run, t019 3 run, t020, t021 + toàn bộ unit test; playground/arena L2.

### Task 4: Capture before/after + docs + PR

- [ ] `capture_t022.tscn` + driver: 3 PNG (gate đóng chặn lối / gate mở + shrine ring / sau heal HP full) vào `docs/phase-c/evidence/t022/`, xem thật.
- [ ] COMBAT_SPEC §9: `reward_granted` (entity `reward`, value 1, tại tick boss chết + cổng mở) và `heal` (entity `reward`, target_id 2, value = amount hồi); semantics win = boss chết + `reward_granted`, không auto-reset.
- [ ] STATE: T-022 DONE + số validation; known issues liên quan; Next T-023.
- [ ] Commit theo task, stage path cụ thể + `.uid`, push, PR vào `main`.

## Out of scope

- E4 chấm formal + negative suite đầy đủ (T-023); L4 cảm nhận reward có "đáng" không (T-024).
- Save/inventory, quest, nhiều shrine, door animation phức tạp (Phase D).
- F1 overlay cho node spawn runtime (known issue T-018 → T-023).
