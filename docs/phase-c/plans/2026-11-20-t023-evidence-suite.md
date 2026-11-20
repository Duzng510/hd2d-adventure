# T-023 — Evidence E1–E5 Automated Suite + Negative Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Một lệnh duy nhất chấm xong **E1–E5** (Điều kiện tiên quyết của L4, `OPERATIONAL_DEFINITIONS.md` §5): dương tính **và** negative control cho từng evidence, mỗi check có id (`E1.2`…), host fail phải fail **vì đúng lý do** (assert message chứa id), và kết quả rơi vào một report machine-readable để không thể "tự chấm green".

**Architecture:** Ba lớp, không trùng logic đã verify:
1. **Harness cũ (t018–t022)** giữ nguyên assertion; `_check()` in thêm dòng `CHECK <PASS|FAIL> <label>` để từng id nổi lên stdout.
2. **Hai driver mới lấp khoảng trống:** `run_t023_onehit.tscn` (E1.2/E1.3/E1.4 — sân khấu kiểm soát, spawn từng role qua `WaveEncounter.debug_spawn`, ghim player, thu ≥10 attack window/loại) và `run_t023_flow.tscn` (E5.1/E5.2/E5.4 — log/state trên arena thật, fault injection bằng `kernel.tick(0)` gian dối).
3. **Aggregator `tools/run_evidence.mjs`** (Node, zero dependency): chạy 7 positive + 5 negative + 1 selftest, parse `CHECK` lines, bắt mỗi negative phải exit 1 **và** in đúng id mong đợi, sinh `docs/phase-c/evidence/t023/evidence_report.md` + `.json`, exit code tổng.

**Tech Stack:** Godot 4.7.2 headless (`--fixed-fps 60`), typed GDScript, Node 24 `node:child_process` (không npm package).

**Status:** DONE 2026-11-21 — code `0fdfecb`, validation `node tools/run_evidence.mjs` exit 0 (`EVIDENCE e1-e5 passed runs=7 negatives=7 ids=17 failures=0 seconds=58`), report `docs/phase-c/evidence/t023/`. Tên API/arg trong plan đã được chỉnh khớp code thật khi ship (`duplicate_hit_count`, một token `-- negative`, `--selftest`).

**Spec:** `docs/phase-c/OPERATIONAL_DEFINITIONS.md` §5 (E1.1–E5.4), §0 (fail-first: harness phải fail vì đúng lý do), §8 (E1–E5 là điều kiện tiên quyết của L4), §6 D2 (tên event), `COMBAT_SPEC.md` §9 (semantics projectile/boss/reward).

## Global Constraints

- `<GODOT>` = `C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` (inner exe; quote trong Git Bash; không dùng `_console.exe`).
- Không đổi gameplay behaviour: chỉ additive debug hook (`Grunt.debug_set_registry_enforce`, `Grunt.duplicate_count`, `WaveEncounter.debug_spawn`) + 1 dòng print trong `_check`.
- Không đổi ngưỡng tuning, không đổi cách đo giữa chừng (§0). Ngưỡng floor 18 tick lấy từ GDD, not from convenience.
- Snapshot counter **trước** khi chờ state (bias đã ghi nhận: driver resume trên `physics_frame` = một tick sau transition).
- `set_physics_process(false)` phải gọi **sau** `add_child`.
- Headless exit 0 không nghĩa là sạch: grep stderr `SCRIPT ERROR`.
- Regression baseline phải giữ nguyên số: t018 `runs=10 wins=10 ticks=11531`, t019 `runs=3 wins=3 swarms=3 grunts=2`, t020 14 checks, t021 41 checks, t022 14 checks, combat kernel 98 checks.
- Commit Conventional Commits `feat|test|chore|docs(T-023): …`, stage theo path, `.uid` đi kèm file mới, không commit `.godot/`, không đụng `docs/phase-b/evidence` (26 file dirty của user).

---

### Task T1: CHECK lines trong harness cũ (machine-readable per-id)

**Files:** modify `scripts/phase_c/t018_cycle_driver.gd`, `t019_swarm_driver.gd`, `t020_ranged_driver.gd`, `t021_boss_driver.gd`, `t022_reward_driver.gd` (hàm `_check` của mỗi file).

- [x] Thêm vào `_check` một dòng in trạng thái theo label (`CHECK PASS <label>` / `CHECK FAIL <label>`), **giữ nguyên** push_error/failed-count hiện có.
- [x] L1: `<GODOT> --headless --path . --check-only --script res://scripts/phase_c/t020_ranged_driver.gd` cho cả 5 file → exit 0.
- [x] Verify hành vi không đổi: `<GODOT> --headless --path . res://scenes/phase_c/run_t020_ranged.tscn --fixed-fps 60` → `checks=14 failures=0` + 14 dòng `CHECK PASS E2.` ; negative → vẫn fail đúng `E2.1` exit 1.

### Task T2: Debug hook additive

**Files:** modify `scripts/combat/grunt.gd`, `scripts/phase_c/wave_encounter.gd`.

- [x] `Grunt`: `func debug_set_registry_enforce(value: bool) -> void` và `func duplicate_hit_count() -> int` (đọc `_registry.duplicate_applied`), comment nêu rõ dùng cho evidence harness.
- [x] `WaveEncounter`: tách vòng spawn trong `_begin_wave()` thành `func debug_spawn(role: String, at: Vector3) -> Grunt` (cùng wiring: tuning/player_path/director_path/target_id/spawn_position/position/name), `_begin_wave()` gọi nó. Hành vi wave 1/2/3 phải giống hệt.
- [x] L1 cả 2 file → exit 0. Regression: `run_t018_cycles.tscn --fixed-fps 60` → `runs=10 wins=10 reset_checks=true` (ticks ~11531); `run_t019_swarm.tscn` → `swarms=3 grunts=2`.

### Task T3: `run_t023_onehit` — E1.2 / E1.3 / E1.4

**Files:** create `scripts/phase_c/t023_onehit_driver.gd`, `scenes/phase_c/run_t023_onehit.tscn` (+ `.uid`).

- [x] Scene: instance `GroveArena` + driver `Node`. Driver `_ready()`: `add_child` arena/`WaveEncounter` rồi **đóng băng** encounter (freeze sau add_child), ghim player tại `player_spawn`, `aim_override_enabled = false` (player không đánh lại — ta đếm swing của enemy).
- [x] Với mỗi `role` trong `[grunt, swarm, ranged, boss]`: `debug_spawn(role, vị_trí_trong_tầm)` (ranged: trong band 3.5–7.0), loop tới khi thu đủ `WINDOWS_PER_ROLE := 10` attack window hoàn chỉnh; mỗi window: snapshot `hit`/`damage` counter và `hp()` **trước** khi chờ `ACTIVE`; assert
  - `E1.3` đúng 1 `hit` cho `attack_id` window, damage == `_damage_of(role)`, `duplicate_hit_count()` không đổi;
  - `E1.2` `active_frame − telegraph_frame == telegraph_frames_of(role)` (grunt 20, swarm 20, ranged 24, boss theo kind) và `>= 18`.
- [x] `E1.4` positive: sau 40 window, `duplicate_hit_count() == 0` với `enforce = true` (registry thật sự đang chặn).
- [x] Negative `-- negative`: `debug_set_registry_enforce(false)` cho mọi enemy → kỳ vọng `E1.3` đỏ (2 hit/attack_id) **và** `E1.4` đỏ (`duplicate_hit_count() > 0`); exit 1.
- [x] In `checks=N failures=M` + `CHECK` lines; `PASS t023_onehit` / `FAIL t023_onehit`.

### Task T4: `run_t023_flow` — E5.1 / E5.2 / E5.4

**Files:** create `scripts/phase_c/t023_flow_driver.gd`, `scenes/phase_c/run_t023_flow.tscn` (+ `.uid`).

- [x] Play 3 run thật (staging teleport như t018) và với mỗi run assert:
  - `E5.1` chuỗi value của event `wave_start` == `[1, 2, 3]`, và tại mỗi `wave_start` > 1 thì `alive_count()` của wave trước == 0 (không spawn chồng wave);
  - `E5.2` `WON` chỉ đạt khi `wave_index == 2` **và** boss đã chết; ngay sau khi wave 1 và wave 2 clear phải thấy `PAUSED`, không thấy `WON`;
  - `E5.3` 3 run kết thúc trong MAX_TICKS, exit 0.
- [x] Negative `-- negative` (một mode duy nhất, `OS.get_cmdline_user_args().has("negative")` — hai tên `spawn_early`/`win_early` gộp lại): driver gọi `kernel.tick(0)` khi vẫn còn enemy sống (gian dối alive_count) → wave sau spawn khi wave trước chưa wipe → `E5.1` đỏ, đồng thời `WON` đạt khi boss chưa chết → `E5.2` đỏ. Exit 1, in đúng cả hai id.

### Task T5: Aggregator `tools/run_evidence.mjs`

**Files:** create `tools/run_evidence.mjs`.

- [x] Bảng kế hoạch run (name, args, loại positive/negative, id mong đợi khi negative).
- [x] Chạy tuần tự `<GODOT> --headless --path . res://scenes/... --fixed-fps 60 [-- negative ...]` qua `node:child_process` (không shell interpolation), timeout 300 s/run, bắt stdout + stderr, grep `CHECK`/`ASSERT FAIL`/`SCRIPT ERROR`.
- [x] Positive: exit 0 + `failures=0` + `CHECK FAIL` = 0. Negative: exit 1 **và** stdout chứa `CHECK FAIL <expected id prefix>` (không chấp nhận "exit khác 0" trần). Script ERROR được tách thành lỗi hạ tầng, không tính là evidence fail.
- [x] `--selftest`: chạy lại một negative nhưng khai sai expected id → aggregator **phải** đỏ (known-bad fixture cho chính thước đo).
- [x] Viết `docs/phase-c/evidence/t023/evidence_report.md` (bảng E-id → trạng thái, counter, ticks, lệnh) + `evidence_report.json`, in `EVIDENCE checks=N failures=M seconds=S`, exit != 0 khi có failure.
- [x] Đo thời gian thật: gate đầy đủ **58 s** (7 positive + 7 negative, mỗi run exit 0/1 như kỳ vọng) → dưới ngưỡng 6 phút nên `--quick` **không** cần và đã không thêm; nếu suite phình quá 6 phút thì quay lại bước này.

### Task T6: Validation đầy đủ + docs

- [x] `node tools/run_evidence.mjs` một lần đầy đủ → 0 failure; `node tools/run_evidence.mjs --selftest` → đỏ đúng 1 mục.
- [x] Regression: combat kernel 98, `test_wave_kernel`, t018/t019/t020/t021/t022, 2 driver T-023.
- [x] L1 + `--import` + playground L2 exit 0, stderr 0 `SCRIPT ERROR`.
- [x] `docs/STATE.md`: T-023 DONE + số liệu, con trỏ report, "Next: T-024 L4 session"; plan doc → Status DONE + commit hash.
- [x] Commit/push branch (`feat` + `docs` trên `phase-c/t023-evidence-suite`, push lên remote). **Mở PR vào `main` chưa làm** — chờ user duyệt vì PR là action hiển thị với người khác.

## Verification matrix (mục §5 nào được chứng minh bởi đâu)

| Evidence | Nguồn check |
|---|---|
| E1.1 ≥3 swarm đồng thời wave 1 | `run_t019_swarm` (`swarms=3 grunts=2`) |
| E1.2 telegraph swarm ≥ tuning & ≥18 | **T-023 `run_t023_onehit`** |
| E1.3 one-hit-per-swing mọi loại, 10 window/loại | **T-023 `run_t023_onehit`** (+ t021 E3.4, t020 E2.3 giữ nguyên) |
| E1.4 negative registry → duplicate_count > 0 | **T-023 `run_t023_onehit -- negative registry`** |
| E2.1–E2.4 | `run_t020_ranged` + negative (range gate 100 m) |
| E3.1–E3.5 | `run_t021_boss` + negative (threshold 0) |
| E4.1–E4.4 | `run_t022_reward` + negative (ngắt reward hook) |
| E5.1–E5.4 | **T-023 `run_t023_flow`** + `run_t018_cycles` (10 chu kỳ) |
