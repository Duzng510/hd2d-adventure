# T-020 — Ranged Role + Projectile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Status: DONE** (2026-11-20) — code `9e11a7d` + harness `331eff7`; validation ghi trong STATE.md.

**Goal:** Thêm vai trò Ranged thật (kite band 3.5–7.0 m, telegraph 24, bắn projectile) vào wave 2 (2 Swarm + 2 Ranged) và đưa projectile vào combat log — không đổi hành vi Phase B.

**Architecture:** `RangedAI extends GruntAI` — giữ nguyên enum `GruntAI.State`, override `tick()` cho logic kite + bắn; `GruntAI._init(detect, attack, …)` được tái diễn giải thành `(max_range, min_range, …)`. `Ranged extends Grunt` — override hook tuning/màu/log/move và factory `_create_ai()`; Grunt thêm hook rỗng `_on_active_start()` + null-guard cho melee hitbox. `Projectile extends Area3D` — tự di chuyển, ray world + shape query player_hurtbox, damage đúng 1 lần, despawn 3 lý do có log. `WaveEncounter` đổi composition wave 2 và clear projectile khi reset.

**Tech Stack:** Godot 4.7.2 (GDScript typed), headless SceneTree tests, harness scene `--fixed-fps 60`.

**Spec:** `docs/phase-c/OPERATIONAL_DEFINITIONS.md` §1 (wave 2: 2 Swarm + 2 Ranged), §5 E2 (E2.1–E2.4), §9 (Ranged HYPOTHESIS: HP 30 · kite min 3.5/max 7.0 · telegraph 24 · projectile 6 m/s, lifetime ≤ 2 s · damage 8 · 2 con/wave 2). `COMBAT_SPEC` §9 (thêm event `projectile_*`).

## Global Constraints

- `<GODOT>` = `C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` (inner exe; quote trong Git Bash).
- Typed GDScript; physics frame 60 tick/s; input qua InputMap; physics layers 1–6 không đổi.
- **Hành vi Phase B giữ nguyên**: playground + script Phase A/B không sửa ngoài `grunt.gd` (thêm factory hook/null-guard/hook rỗng — default y hệt) và `combat_tuning` (thêm field, không đổi giá trị cũ).
- Giá trị không có trong gate doc §9 (active 4, recovery 30, approach 2.0) là **HYPOTHESIS implementation**, ghi trong tuning test.
- D1 (F1 overlay cho enemy spawn runtime + projectile) vẫn là known issue T-018 → xử lý ở T-023; projectile vẫn vào group `enemy_attack` + `enemy_projectile` để T-023 nhặt.
- Branch `phase-c/t020-ranged-projectile` từ `main`. Commit `feat(T-020): …`/`fix(T-020): …`/`docs(T-020): …`, kèm `.uid`, không commit `.godot/`, push sau validation xanh.
- Sau khi thêm `class_name` mới: `<GODOT> --headless --path . --import` trước L2/L3.
- Một `quit()` mỗi nhánh trong SceneTree test.

---

### Task 1: CombatTuning ranged fields + tuning/composition test (fail-first)

**Files:**
- Modify: `scripts/combat/combat_tuning.gd`
- Modify: `scripts/combat/combat_tuning.tres`
- Test: `tests/test_ranged_tuning.gd`

**Interfaces:**
- Produces (dùng bởi Task 2, 3, 4): `ranged_max_hp: int = 30`, `ranged_min_range: float = 3.5`, `ranged_max_range: float = 7.0`, `ranged_approach_speed: float = 2.0`, `ranged_telegraph_frames: int = 24`, `ranged_active_frames: int = 4`, `ranged_recovery_frames: int = 30`, `ranged_damage: int = 8`, `ranged_projectile_speed: float = 6.0`, `ranged_projectile_lifetime_frames: int = 120`.

- [ ] **Step 1: Write the failing test** — `tests/test_ranged_tuning.gd`:
  - Assert tuning HYPOTHESIS §9: hp 30, telegraph 24 & `>= 18` (GDD floor), min 3.5, max 7.0, damage 8, speed 6.0, lifetime `<= 120`.
  - Assert derived HYPOTHESIS implementation: active 4, recovery 30, approach 2.0.
  - Regression: grunt/swarm values không đổi (hp 30/20, telegraph 20/18, damage 15/5).
  - Node hooks: `Ranged.new()` + tuning → `_max_hp() == 30`, `_detect_range() == 7.0`, `_attack_range() == 3.5`, `_log_entity() == &"ranged"`, `_create_ai() is RangedAI` (thêm ở Task 3 khi class tồn tại).
  - Composition (thêm ở Task 4 khi default `wave_roles` đổi): `WaveEncounter.new().wave_roles[1]` = 2 swarm + 2 ranged; wave 1 vẫn 2 grunt + 3 swarm. (Wave 3 chưa assert — T-021 thay.)
  - Negative `-- negative`: `ranged_telegraph_frames = 10` → floor check fail → exit 1.

- [ ] **Step 2: Run test to verify it fails**

```bash
"<GODOT>" --headless --path . -s res://tests/test_ranged_tuning.gd
```

Expected: parse error — property `ranged_max_hp` không tồn tại (exit ≠ 0).

- [ ] **Step 3: Add fields** — `combat_tuning.gd` sau group "Swarm":

```gdscript
@export_group("Ranged")
@export var ranged_max_hp: int = 30
@export var ranged_min_range: float = 3.5
@export var ranged_max_range: float = 7.0
@export var ranged_approach_speed: float = 2.0
@export var ranged_telegraph_frames: int = 24
@export var ranged_active_frames: int = 4
@export var ranged_recovery_frames: int = 30
@export var ranged_damage: int = 8
@export var ranged_projectile_speed: float = 6.0
@export var ranged_projectile_lifetime_frames: int = 120
```

`combat_tuning.tres` sau `swarm_damage = 5`: cùng 10 dòng giá trị.

- [ ] **Step 4: Run positive + negative**

```bash
"<GODOT>" --headless --path . -s res://tests/test_ranged_tuning.gd                  # exit 0
"<GODOT>" --headless --path . -s res://tests/test_ranged_tuning.gd -- negative      # exit 1
```

Ghi chú: bước này `Ranged`/`RangedAI` chưa tồn tại — tách assertion node hooks sang Task 2/3; test tạm chỉ chấm tuning + composition, bổ sung node hooks ở Task 3.

---

### Task 2: RangedAI kite state machine + test (fail-first)

**Files:**
- Create: `scripts/combat/ranged_ai.gd`
- Test: `tests/test_ranged_ai.gd`

**Interfaces:**
- Produces (dùng bởi Task 3): `class_name RangedAI extends GruntAI`; constructor kế thừa `(p_detect = max_range, p_attack = min_range, telegraph, active, recovery)`; override `tick(player_pos, self_pos)`; overridable `_within_range() -> bool` (= `distance <= detect_range`) và `_can_fire() -> bool` (= `attack_range <= distance <= detect_range`); giữ `state/frame/distance/move_dir/attack_dir/alert_pending` của GruntAI.

- [ ] **Step 1: Write the failing test** — `tests/test_ranged_ai.gd`:
  - Ngoài max range 8.0: 120 tick → không TELEGRAPH/ACTIVE, không alert.
  - Trong band 5.0: IDLE → CHASE (alert 1 lần) → TELEGRAPH tick kế; `active_start − telegraph_start == 24` (đo bằng frame AI, 3 chu kỳ liên tiếp).
  - Quá gần 2.0: CHASE, `move_dir` ngược hướng player (dot < 0), không telegraph.
  - Xa 8.0 sau alert: CHASE, `move_dir` hướng player, không telegraph.
  - Telegraph snapshot: đổi vị trí player trong TELEGRAPH → `attack_dir` không đổi.
  - Recovery 30 → về CHASE, bắn lại được khi còn trong band.
  - Negative `-- negative`: `BrokenRangedAI` override `_within_range()/_can_fire()` = true → player ở 20 m vẫn telegraph → assert "no engagement outside max range" fail → exit 1.

- [ ] **Step 2: Run test → parse error `RangedAI` chưa tồn tại (exit ≠ 0).**

- [ ] **Step 3: Implement `ranged_ai.gd`** — enum dùng `GruntAI.State`; CHASE: `distance < attack_range` → retreat (`move_dir = -dir`), `_can_fire()` → snapshot `attack_dir` + TELEGRAPH, còn lại advance (`move_dir = dir`); TELEGRAPH/ACTIVE/RECOVERY giữ `move_dir = ZERO`, đếm frame y convention GruntAI (`_enter` set frame 1, chuyển phase khi `frame > frames`). Không đổi `GruntAI`.

- [ ] **Step 4: Run positive + negative → exit 0 / exit 1.**

---

### Task 3: Grunt factory hooks + Projectile + Ranged node/scenes

**Files:**
- Modify: `scripts/combat/grunt.gd`
- Modify: `scripts/combat/combat_director.gd`
- Create: `scripts/combat/projectile.gd`, `scenes/combat/projectile.tscn`
- Create: `scripts/combat/ranged.gd`, `scenes/combat/ranged.tscn`
- Test: mở rộng `tests/test_ranged_tuning.gd` (node hooks đã chừa ở Task 1)

**Interfaces:**
- `Grunt` thêm: `_create_ai() -> GruntAI` (factory, default y hệt hiện tại), `_on_active_start()` (hook rỗng, gọi trong nhánh ACTIVE của `_handle_events` sau log `active_start`), null-guard `get_node_or_null` cho `AttackHitbox` (ranged không có melee hitbox).
- `CombatDirector` thêm `event_counts: Dictionary` — đếm mỗi event name trong `log_event` (harness E2 đọc delta; CSV không đổi).
- `Projectile`: `@export tuning/director/player_combat`, `attack_id`, `direction`; mỗi tick: lifetime check → ray world (mask 1) → shape query player_hurtbox (mask 16) → damage đúng 1 lần (`_dead` guard) → `queue_free`. Log `projectile_hit`/`damage` (target_id 2) + `projectile_despawn` value 1=hit / 2=wall / 3=lifetime. Frozen tick → đứng yên. Group `enemy_attack` + `enemy_projectile`.
- `Ranged extends Grunt`: override `_max_hp/_detect_range (max)/_attack_range (min)/_approach_speed/_telegraph_frames/_active_frames/_recovery_frames/_damage/_base_color/_log_entity (&"ranged")/_create_ai (RangedAI)/_move (CHASE dùng move_dir)/_resolve_damage (no-op)/_on_active_start (spawn 1 projectile + log projectile_fire, attack_id = attack instance)`.

- [ ] **Step 1: Grunt refactor** — factory + hook + null-guard; chạy L1 + regression `test_grunt_ai`, playground L2.
- [ ] **Step 2: Projectile scene/script** — Area3D layer 8, mask 17, monitoring off; sphere shape 0.15; visual unshaded.
- [ ] **Step 3: Ranged scene/script** — capsule 0.35×1.6, mesh 0.7×1.5×0.7, Telegraph quad 1.4, Hurtbox 0.7×1.5×0.7 layer 32; không có AttackHitbox.
- [ ] **Step 4: Import + L1 tất cả script mới/sửa; chạy `test_ranged_tuning` (đủ node hooks) + `test_ranged_ai` + `test_combat_tuning`.**

---

### Task 4: Wave 2 composition + reset clear projectiles + harness E2

**Files:**
- Modify: `scripts/phase_c/wave_encounter.gd` (default `wave_roles` wave 2 = 2 swarm + 2 ranged; `reset_run()` clear group `enemy_projectile`)
- Modify: `scenes/phase_c/grove_arena.tscn` (add `ranged.tscn`, `enemy_scenes` + `wave_roles`)
- Modify: `scripts/phase_c/t018_cycle_driver.gd`, `scripts/phase_c/t019_swarm_driver.gd` — staging đổi từ pinned point sang teleport cạnh enemy sống gần nhất (lệch 0.8 m về phía tâm arena) vì ranged kite khiến pin-point không thể clear wave 2
- Create: `scripts/phase_c/t020_ranged_driver.gd`, `scenes/phase_c/run_t020_ranged.tscn`

**Harness phases (headless, `--fixed-fps 60`, WaveEncounter disable trong driver):**
1. E2.1 range gate: 1 Ranged tại (0,0,−4), player (0,0,6) → 120 tick, `projectile_fire` delta == 0.
2. E2.2 + E2.3: player (0,0,3) → đo `active_start − telegraph_start >= 18`; 1 phát trúng: `projectile_hit` delta == 1, HP giảm đúng 8, `projectile_despawn` delta == 1, 30 tick sau không thêm hit (tắt physics của ranged sau phát đầu để cô lập).
3. E2.3 wall: thêm blocker StaticBody 2×2×1 tại (0,1,−1); ranged (0,0,−4), player (0,0,2) → despawn delta == 1, hit 0, HP không đổi.
4. Lifetime: ranged (−6.5,0,0), player (−1.5,0,0); sau khi fire teleport player sang (−1.5,0,5) → despawn (lifetime) trong 118–126 tick sau fire, hit 0, HP không đổi.
- Negative `-- negative`: duplicate tuning với `ranged_max_range = 100.0` → phase 1 fire > 0 → in `ASSERT FAIL E2.1 …` → exit 1.

- [ ] **Step 1: Composition + reset clear + drivers staging + harness scene/driver.**
- [ ] **Step 2: Import; L2 grove_arena 120 frame exit 0.**
- [ ] **Step 3: Harness positive exit 0; negative exit 1 (đúng dòng ASSERT E2.1).**
- [ ] **Step 4: Regression: `run_t018_cycles` 10 run, `run_t019_swarm` 3 run, `test_wave_kernel`, `test_swarm_tuning`, playground L2.**

---

### Task 5: Docs + full validation + commit/push

**Files:**
- Modify: `docs/combat/COMBAT_SPEC.md` (§3 coverage Ranged; §9 event semantics `projectile_fire/hit/despawn` + `damage` theo attack_id; value despawn 1/2/3)
- Modify: `docs/STATE.md` (Đang làm trống, T-020 DONE, Next T-021, Known issues wave 3 placeholder + DebugHitboxes runtime overlay → T-023)

- [ ] **Step 1: Update docs.**
- [ ] **Step 2: Full targeted validation** — L1 script list, L2 arena + playground, L3 tests/harness trên; ghi output thật vào STATE/report.
- [ ] **Step 3: Commit theo task (4–5 commit), stage path cụ thể + `.uid`; push branch.**

## Out of scope / Known issues giữ nguyên

- D1 F1 overlay cho enemy/projectile spawn runtime (known issue T-018 → T-023).
- E2.1–E2.4 evidence đầy đủ + negative controls (T-023); T-020 chỉ dựng cơ chế + harness nền.
- LOS check cho ranged (gate doc không yêu cầu); C2.3 ảnh telegraph (T-024).
- Wave 3 vẫn 1 Grunt placeholder (T-021).
