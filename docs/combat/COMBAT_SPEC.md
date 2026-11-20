# COMBAT_SPEC — Phase B Combat Prototype

> Tài liệu implementation, **subordinate GDD**: khi xung đột, GDD và xác nhận mới nhất của user thắng. Không nhân bản giá trị runtime — nguồn authoritative duy nhất của thông số là `res://scripts/combat/combat_tuning.tres`; GDD 6.4 chỉ là HYPOTHESIS.
> Status: **APPROVED** — user duyệt 2026-11-20 cùng T-008 (v2 tích hợp review).

## 1. Phạm vi Phase B

Một nhân vật, một vũ khí (Sword), một enemy (Grunt), Light Attack + combo ngắn, Dodge, health/damage, một đòn enemy có telegraph, một encounter chơi lại được (GDD 6.8). Heavy attack, skill, enemy/weapon khác, audio, save: out of scope.

## 2. Bindings (InputMap, BASELINE)

| Action | Phím | Ghi chú |
|---|---|---|
| `move_up/down/left/right` | WASD | có từ Phase A |
| `light_attack` | Chuột trái | khai báo `project.godot` (T-008) |
| `dodge` | Space | khai báo `project.godot` (T-008) |
| `debug_toggle_hitboxes` | F1 | debug bắt buộc (MP 6.4) |
| `encounter_reset` | R | spawn nhanh/reset encounter (MP 6.4) |
| aim | vị trí chuột | reticle Phase A (`unproject_position`, aim ground y=0) |

Action khai báo một lần trong `project.godot`; gameplay chỉ đọc action, không đọc phím cứng.

## 3. Thông số authoritative

- **Runtime value:** `CombatTuning` (`scripts/combat/combat_tuning.gd`) + `scripts/combat/combat_tuning.tres` — giá trị đang chạy; sửa tuning = sửa `.tres`, không sửa logic.
- **Validation envelope:** `tests/test_combat_tuning.gd` kiểm tra resource nằm trong khoảng HYPOTHESIS GDD 6.4 (startup 3–6, active 2–4, recovery 8–14, combo window 8–14, buffer 5–8, dodge i-frame 8–14 / tổng 18–28, hitstop 2–5, telegraph ≥18). Đây là **envelope tạm của prototype, không phải design-approved constraint** — muốn ra ngoài envelope phải cập nhật GDD/DECISIONS trước, không sửa test cho vừa.
- Coverage: startup/active/recovery, combo window + combo hits, buffer, damage, reach; dodge i-frame/total/speed; hitstop; HP player/grunt; detect/attack range, approach speed, telegraph/active/recovery, damage của Grunt.
- Swarm (Phase C): swarm_max_hp/telegraph/active/recovery/damage/approach/detect/attack_range — HYPOTHESIS gate doc §9; telegraph floor ≥18.
- Ranged (Phase C): ranged_max_hp/min_range/max_range/approach/telegraph/active/recovery/damage/projectile speed/lifetime — HYPOTHESIS gate doc §9; telegraph 24 (floor ≥18); projectile lifetime ≤120 tick (2 s).
- Boss (Phase C): boss_max_hp/detect/chase/phase threshold + switch, và theo từng đòn (smash/lunge/sweep) bộ telegraph/active/recovery (phase 1 + phase 2)/damage/radius-range — HYPOTHESIS gate doc §9; **mọi** telegraph ≥18; phase 2 nhanh hơn chỉ qua recovery, không hạ telegraph.

## 4. Frame model (khóa off-by-one)

- Simulation tick 60/s. `sim_frame` monotonic, **không reset khi R**; log dùng `sim_frame`.
- `action_frame` bắt đầu từ 1 tại tick action start; chỉ thuộc action instance hiện tại.
- Startup gồm đúng `startup_frames` frame inclusive: `action_frame` 1..S.
- Active bắt đầu ở `action_frame = S + 1`, gồm đúng `active_frames` frame.
- Recovery bắt đầu ở `S + A + 1`, gồm đúng `recovery_frames` frame.
- Hitbox ON trong active frames; OFF trước khi xử lý frame đầu tiên ngoài active window.
- Ví dụ S=3, A=2:

| action_frame | Phase | Hitbox |
|---|---|---|
| 1–3 | Startup | OFF |
| 4–5 | Active | ON |
| 6+ | Recovery | OFF |

- Mỗi boundary (startup→active, active→recovery, recovery→end) phải có test frame cụ thể.

## 5. Player state machine

Top-level states: **Locomotion · Attack · Dodge · Hit · Dead**. `Attack` chứa các phase internal startup/active/recovery (không phải state rời rạc).

Thứ tự resolution mỗi tick (deterministic):

1. Capture input (buffer gắn `sim_frame`).
2. Hitstop: nếu `hitstop_remaining > 0` → giảm 1 và **bỏ qua bước 3–6** (không advance action_frame, không xử lý hitbox, không movement). Input trong hitstop được ghi pending; buffer age bắt đầu từ tick resume đầu tiên.
3. Damage resolution của các hitbox đang active/overlap (§8); nhận hit huỷ buffered attack + reset combo.
4. Input action theo ưu tiên: **dodge > attack**.
5. Advance `action_frame`, chuyển phase/kết thúc action.
6. Movement (chỉ Locomotion; Attack rooted).

Quy tắc:

- Dodge hợp lệ từ Locomotion và Attack **recovery**; không từ startup/active. i-frame = `dodge_iframe_frames` frame đầu của dodge.
- Attack input trong startup/active được đệm; tự thực thi ở frame hợp lệ đầu tiên. Buffer hết hạn sau `input_buffer_frames` tick kể từ lúc capture — hết hạn thì huỷ.
- Combo `light_combo_hits` hit; combo window = `combo_window_frames` đầu của recovery. Combo reset khi: hết recovery không continuation, dodge, nhận hit, chết, `encounter_reset`.
- **Hướng đánh:** snapshot aim tại `action_start` (user chốt 2026-11-20: mouse snapshot) và cố định suốt swing; mouse di chuyển sau đó không đổi hướng đòn. Facing sprite flip theo dấu X của hướng snapshot.
- Rooted: movement khóa trong toàn bộ Attack; aim/facing của đòn giữ snapshot.
- Hitstop: **một** counter tập trung cho encounter (HitstopController), ownership duy nhất; overlap policy = **max remaining** (không cộng dồn); freeze mọi entity combat cùng tick; không dùng `Engine.time_scale`.

## 6. One-hit-per-swing (quy tắc cứng)

- Damage lặp = một attack instance gây **>1 damage event lên cùng một target**. Một swing trúng nhiều target → mỗi target 1 damage là hợp lệ.
- `attack_id` (== `swing_id`) tăng đơn điệu, không tái sử dụng trong lifetime; mọi event của cùng swing dùng cùng ID.
- Test 100 swing liên tiếp lên cùng target: reset HP/state target giữa các swing để swing nào cũng hợp lệ; assert **0 duplicate**.
- Negative control: tắt registry → assert `duplicate_count > 0` trên đúng counter (không chỉ dựa vào exit code khác 0).

## 7. Enemy Grunt

- States: Idle → Chase → Telegraph → Active → Recovery. **Alert là event**, không phải state tồn tại: log `alert` một lần tại tick player vào `grunt_detect_range`, rồi chuyển Chase ngay rule kế tiếp.
- Telegraph lock-in: một khi Telegraph bắt đầu, attack instance có hướng (snapshot vị trí player tại `telegraph_start`) và duration cố định; player rời range không huỷ, không đổi duration/hướng.
- Damage resolution: active window + overlap + target không i-frame + attack instance chưa damage target (§8).
- HP `grunt_max_hp`; chết → encounter win. AI là logic thuần (input: vị trí/frame; output: ý định di chuyển/attack), test headless.

## 8. Hitbox/Hurtbox & damage resolution

- Bảng layer/mask authoritative: `AGENTS.md` (1 world, 2 player, 3 player_attack, 4 enemy_attack, 5 player_hurtbox, 6 enemy_hurtbox).
- Hitbox: `Area3D` monitoring, mask = hurtbox đối phương. Hurtbox: `Area3D` passive, mask = 0.
- Player hitbox: origin tại player, hướng = snapshot aim, reach `light_reach`; shape cụ thể đặt trong scene. F1 overlay vẽ từ **chính shape/transform của Area3D** (không vẽ xấp xỉ).
- Damage hợp lệ khi **đồng thời**: attack đang trong active tick, hitbox overlap hurtbox đối phương, target không trong i-frame, attack instance chưa ghi nhận target trong HitRegistry. Không dựa vào animation hay signal collision đơn thuần.
- Hitbox bật/tắt đúng boundary §4. Damage query dùng direct space-state với **chính shape/transform** của hitbox và layer mask; `Area3D` giữ layer semantics + overlay F1; query chỉ chạy trong active tick.

## 9. Combat log (MP 6.4)

- CSV `user://combat_log.csv` + in từng dòng ra stdout. Header: `frame,entity,event,attack_id,target_id,value`.
- `frame` = `sim_frame` monotonic (không reset khi R) · `attack_id` = ID của attack instance (không phải combo ID) · `target_id` khi event liên quan target · `value` theo convention từng event (damage amount, phase…), không chứa dữ liệu tùy ý.
- Event bắt buộc: `input_light`, `input_dodge`, `action_start`, `active_start`, `active_end`, `hit`, `damage`, `telegraph_start`, `telegraph_end`, `alert`, `death`, `encounter_reset`.
- Event encounter (T-012): `encounter_win`, `encounter_lose`; `encounter_reset` có `value` = số run đã hoàn tất.
- Event encounter Phase C (T-018): `wave_start` với `value` = chỉ số wave 1-based; log tại tick spawn wave, sau `encounter_reset`/run start. Win/lose/reset giữ semantics T-012, **ngoại lệ T-022: win không auto-reset** (player giữ quyền điều khiển để đi qua cổng mở); lose vẫn auto-reset sau `reset_delay_frames`. Event của vai trò enemy mới (`boss_phase`, `reward_granted`) thêm ở T-021/T-022.
- Reward (T-022): `reward_granted` entity `reward`, `value` = 1, log tại tick boss chết + cổng mở, **đúng một lần mỗi run**; `heal` entity `reward`, `target_id` = 2 (player), `value` = số HP thực hồi — shrine chỉ hồi khi cổng đã mở và chỉ một lần mỗi run. `encounter_reset` (R) đóng cổng và khóa shrine.
- Entity Phase C: enemy theo vai trò log entity = &"grunt" hoặc &"swarm" (cùng schema event); wave_start giữ semantics T-018.
- Projectile (T-020): `projectile_fire` entity `ranged` tại tick `active_start` (cùng `attack_id` của attack instance Ranged); `projectile_hit` entity `projectile`, `target_id` = 2 (player); `damage` cùng `attack_id`/`target_id`, `value` = damage áp dụng; `projectile_despawn` entity `projectile`, `value`: 1 = trúng player, 2 = chạm world/tường, 3 = hết lifetime (≤120 tick). Mỗi projectile damage tối đa 1 lần và despawn ngay sau hit.
- Boss (T-021): mỗi đòn (smash/lunge/sweep) và phase switch là **một attack instance riêng** — `attack_id` tăng tại `telegraph_start`, schema `telegraph_start/telegraph_end/active_start/active_end` như Grunt, entity `boss`. `boss_phase` có `value` = số phase (2), log **đúng một lần** tại tick hoàn tất switch (kết thúc recovery của đòn SWITCH); SWITCH không gây damage nên không có `hit`/`damage`. Damage của boss dùng `target_id` = 2 (player).
- `telegraph_start` tại frame telegraph đầu tiên; `telegraph_end` tại boundary tick kết thúc telegraph (cùng tick với `active_start`, log trước `active_start`). B4.1 đo `active_start.frame − telegraph_start.frame`.
- Swing miss vẫn log `active_end`; không bắt buộc `hit`/`damage`. Enemy attack có `attack_id` riêng cho **mỗi** telegraph/attack instance.
- Diagnostic input→action_start = số tick engine-side (chỉ diagnostic; không đại diện input-to-display — GDD 6.4).

### 9.1 L4 capture rig (T-025) — schema `user://l4_probe.csv`

- `CombatDirector` emit thêm `event_logged(entity, event_name, attack_id, target_id, value)` **sau khi** ghi dòng CSV. Đây là tap read-only: không consumer nào trong gameplay nối vào nó, nên không đổi hành vi.
- `L4Probe` ghi file **thứ hai** (không đổi schema §9): header `frame,kind,hp,x,z,nearobs,dodge,swing,boss_hp,boss_state,atk,src,dist,dreact,moved,dmg,near_role,near_dist,fps,note`; join với combat log bằng `sim_frame` (clock chung, không reset khi R).
- Kinds: `v` banner (schema/sample rate) · `s` sample 10 Hz (hp, toạ độ, `nearobs` 1 chạm cover/1,5 m/2_open, `dodge` có bấm được không, `swing`, HP + state boss, enemy gần nhất) · `h` player ăn đòn · `d` player chết (kèm sát thủ + HP boss còn lại) · `p` một PNG `user://l4_death_N.png` đã ghi.
- `dreact` = `(sim_frame − frozen_ticks) − (telegraph_start_frame − frozen_at_start)` = số frame telegraph **thực sự còn** sau khi trừ hitstop; `note` giữ `raw=`/`frozen=`. Projectile tra telegraph của entity `ranged` (cùng `attack_id`).
- Giới hạn phải đọc kèm: `attack_id` đánh số theo **từng instance**, nên khi >1 enemy cùng vai trò đang active thì `dist` là ước lượng nearest-candidate và `note` mang `ambig=N`; `fps` = 0 ở 60 frame đầu và vô nghĩa khi chạy `--fixed-fps` (artifact capture, như known issue cũ).
- Nghiệm thu của rig ở `scenes/phase_c/play_arena.tscn` (`-- auto`, `-- auto passive`, `-- auto negative`), lệnh chấm: `node tools/score_l4.mjs <combat_log.csv> --probe <l4_probe.csv>`.

## 10. Readability & feedback

- Telegraph: tín hiệu dưới enemy (màu/scale/vòng cảnh báo) thấy rõ trước active; screenshot L3.
- Active swing: arc placeholder; hit: flash target + hitstop.
- Hiệu ứng không che thông tin combat (GDD 6.3); ưu tiên đọc chuyển động hơn hiệu ứng.
- Encounter phải cho 2 cách tiếp cận hợp lệ: dodge-rồi-phản-công và áp sát-chen-recovery (GDD 6.8.7, gate B7).

## 11. Debug bắt buộc (MP 6.4) — map

| Yêu cầu | Cơ chế |
|---|---|
| Toggle hitbox/hurtbox | F1 + `DebugHitboxes` node (overlay đúng shape thật) |
| Combat log có cấu trúc | §9 CSV |
| Spawn/reset encounter nhanh | R (`encounter_reset`) |
| Capture tất định (L3) | `aim_override_enabled`/`aim_override_point` + `debug_request_attack()` trên `PlayerCombat` — chỉ harness dùng, mặc định off |

`encounter_reset` phải xoá: HP, vị trí, AI state, action phase, buffer/combo, HitRegistry, hitstop counter; log `encounter_reset`.

Lý do có hook capture: coroutine `await physics_frame` resume ở đầu physics step, press/release quanh nó không bao giờ tới `_physics_process`; `debug_request_attack()` đẩy input vào buffer đúng `_combat_frame` nên kết quả tất định.

## 12. Tham chiếu

GDD 6.3/6.4/6.8 · MP 6.3/6.4 · `docs/phase-b/OPERATIONAL_DEFINITIONS.md` (gate B1–B7, D1–D3).
