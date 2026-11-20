# COMBAT_SPEC — Phase B Combat Prototype

> Tài liệu implementation, **subordinate GDD**: khi xung đột, GDD và xác nhận mới nhất của user thắng. Không nhân bản giá trị runtime — nguồn authoritative duy nhất của thông số là `res://scripts/combat/combat_tuning.tres`; GDD 6.4 chỉ là HYPOTHESIS.
> Status: **PROPOSED** (T-008, 2026-11-20) — chờ user duyệt cùng OPERATIONAL_DEFINITIONS Phase B.

## 1. Phạm vi Phase B

Một nhân vật, một vũ khí (Sword), một enemy (Grunt), Light Attack + combo ngắn (3 hit), Dodge, health/damage, một đòn enemy có telegraph, một encounter chơi lại được (GDD 6.8). Heavy attack, skill, enemy/weapon khác, audio, save: out of scope.

## 2. Bindings (InputMap, BASELINE)

| Action | Phím | Ghi chú |
|---|---|---|
| `move_up/down/left/right` | WASD | có từ Phase A |
| `light_attack` | Chuột trái | thêm ở T-008 |
| `dodge` | Space | thêm ở T-008 |
| `debug_toggle_hitboxes` | F1 | debug bắt buộc (MP 6.4) |
| `encounter_reset` | R | spawn nhanh/reset encounter (MP 6.4) |
| aim | vị trí chuột | reticle Phase A (`unproject_position`, aim ground y=0) |

Không đọc phím cứng trong gameplay code; mọi input qua InputMap action.

## 3. Thông số authoritative

`CombatTuning` (`scripts/combat/combat_tuning.gd`) + `scripts/combat/combat_tuning.tres`. Sửa tuning = sửa `.tres`, không sửa logic. Giá trị hiện tại (HYPOTHESIS, nằm trong khoảng GDD 6.4): startup 3–6 · active 2–4 · recovery 8–14 · combo window 8–14 · buffer 5–8 · dodge i-frame 8–14 / tổng 18–28 · hitstop 2–5 · telegraph ≥18 frame. Test `tests/test_combat_tuning.gd` giữ resource trong khoảng này.

## 4. Frame model

- 60 tick/s; mọi cửa sổ tính bằng **số frame đếm** trong `_physics_process`, không dùng delta float.
- Mỗi action giữ `frame` (int) bắt đầu từ 1; phase suy ra từ frame + tuning.
- Hitbox chỉ bật trong active frames, tắt ngay frame đầu tiên sau active.

## 5. Player state machine

| State | Vào | Ra |
|---|---|---|
| Locomotion | mặc định | attack hợp lệ → Attack; dodge hợp lệ → Dodge; nhận damage → Hit; hp ≤ 0 → Dead |
| Attack startup | action start | hết startup → Active |
| Attack active | startup xong | hết active → Recovery |
| Attack recovery | active xong | hết recovery → Locomotion; combo input đã đệm → đòn kế; dodge → Dodge |
| Dodge | dodge hợp lệ | hết `dodge_total_frames` → Locomotion |
| Hit | nhận damage | hết hitstop/flinch → Locomotion |
| Dead | hp ≤ 0 | `encounter_reset` → Locomotion (full HP) |

Quy tắc:

- Combo 3 hit; mỗi hit là một `swing_id` mới. Combo window mở trong recovery; input sớm hơn được đệm tối đa `input_buffer_frames`, tự kích hoạt ở frame hợp lệ đầu tiên.
- Dodge huỷ được attack **recovery**; không huỷ startup/active. i-frame = `dodge_iframe_frames` frame đầu của dodge.
- Movement bị khóa trong attack (rooted) — HYPOTHESIS, tinh chỉnh bằng playtest.
- Hitstop: đóng băng frame counter + di chuyển của attacker và target `hitstop_frames` frame; input buffer vẫn nhận. Không dùng `Engine.time_scale`.

## 6. One-hit-per-swing (quy tắc cứng)

- `HitRegistry` thuần logic: mỗi cặp (`swing_id`, `target_id`) chỉ ghi nhận 1 lần; active window nhiều frame không tạo damage lặp.
- `swing_id` tăng đơn điệu mỗi lần action bắt đầu.
- Test headless: 100 swing liên tiếp lên cùng target → 0 lần damage lặp (GDD 6.8.2), kèm negative control (tắt registry → có lặp, harness phải bắt được).

## 7. Enemy Grunt

States: Idle → Alert (player vào `grunt_detect_range`) → Chase (đến `grunt_attack_range`) → Telegraph (`grunt_telegraph_frames`, tín hiệu hình ảnh rõ) → Active (`grunt_active_frames`) → Recovery (`grunt_recovery_frames`) → Chase/Idle.

- Chỉ bắt đầu Telegraph khi player trong `grunt_attack_range`; telegraph **không** bị huỷ nếu player rời tầm (đòn vẫn ra — người chơi phải né).
- Attack hitbox chỉ active trong active frames; damage player theo `grunt_damage`.
- HP `grunt_max_hp`; chết → encounter win.
- AI là logic thuần (input: vị trí/frame; output: ý định di chuyển/attack) để test headless.

## 8. Hitbox/Hurtbox & physics layers

- Bảng layer/mask authoritative: `AGENTS.md` (1 world, 2 player, 3 player_attack, 4 enemy_attack, 5 player_hurtbox, 6 enemy_hurtbox).
- Hitbox: `Area3D`, `monitoring = true`, mask = layer hurtbox đối phương (player_attack → enemy_hurtbox; enemy_attack → player_hurtbox).
- Hurtbox: `Area3D` passive, mask = 0.
- F1 toggle vẽ hitbox (đỏ) / hurtbox (xanh) — có ảnh before/after (gate D1).

## 9. Combat log (MP 6.4)

- CSV `user://combat_log.csv` + in từng dòng ra stdout. Header: `frame,entity,event,attack_id,target_id,value`.
- Event bắt buộc: `input_light`, `input_dodge`, `action_start`, `active_start`, `active_end`, `hit`, `damage`, `telegraph_start`, `telegraph_end`, `death`, `encounter_reset`.
- Diagnostic input→action_start = số frame engine-side (chỉ diagnostic; không đại diện input-to-display latency — GDD 6.4).

## 10. Readability & feedback

- Telegraph: tín hiệu dưới enemy (màu/scale/vòng cảnh báo) thấy rõ trước active; screenshot L3.
- Active swing: arc placeholder; hit: flash target + hitstop.
- Hiệu ứng không che thông tin combat (GDD 6.3); ưu tiên đọc chuyển động hơn hiệu ứng.
- Encounter phải cho 2 cách tiếp cận hợp lệ: dodge-rồi-phản-công và áp sát-chen-recovery (GDD 6.8.7, gate B7).

## 11. Debug bắt buộc (MP 6.4) — map

| Yêu cầu | Cơ chế |
|---|---|
| Toggle hitbox/hurtbox | F1 + `DebugHitboxes` node |
| Combat log có cấu trúc | §9 CSV |
| Spawn/reset encounter nhanh | R (`encounter_reset`) |

## 12. Tham chiếu

GDD 6.3/6.4/6.8 · MP 6.3/6.4 · `docs/phase-b/OPERATIONAL_DEFINITIONS.md` (gate B1–B7, D1–D3).
