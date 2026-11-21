# UI_PROGRESSION_SPEC — damage numbers · bảng trạng thái · buff sau wave

Trạng thái: **PROPOSED** (chờ user duyệt file này) · Ngày: 2026-11-21 · Phase: **D** (T-029…T-031)
Nguồn ràng buộc: GDD 0.7.1 (pillar 1, pillar 3, mục 11), AGENTS.md (physics frame 60, một nguồn authoritative, texel D-008), MASTER_PROMPT 3.4.1 (mức tự chủ §3, task/branch).
Các quyết định đã chốt qua chat với user (2026-11-21): ESC **tạm dừng** game; buff **số học + đánh đổi**; buff **reset khi R/thua**; UI **code-gen + Godot Theme**; kiến trúc stat layer **A — PlayerStats thuần**; buff-pick **chặn wave + dừng world**; font **VT323 (Peter Hull, SIL OFL 1.1 — thay m5x7 sau khi gate coverage báo thiếu 17 glyph tiếng Việt)**; mở **Phase D, T-029…T-031**.

---

## 1. Phạm vi

Ba feature, ba task, ba branch:

| Task | Branch | Nội dung | Phụ thuộc |
|---|---|---|---|
| **T-029** | `phase-d/t029-player-stats-sheet` | `PlayerStats` + Theme/khung UI dùng chung + bảng trạng thái ESC (tạm dừng) | — |
| **T-031** | `phase-d/t031-damage-numbers` | Damage numbers nổi trên quái | T-029 (Theme, pool Label) |
| **T-030** | `phase-d/t030-wave-buff-choice` | Buff pool 6 món + `BUFF_PENDING` trong `WaveKernel` + modal 3 card | T-029 (stats), T-031 (không bắt buộc) |

Thứ tự triển khai: **T-029 → T-031 → T-030** (T-030 là mặt phẳng lớn nhất và cần stats đã ổn định).

**Không làm trong spec này:** crit/RNG trong damage path; buff hành vi mới (AoE, counter, on-dodge effect); meta progression/save; Option screen thật (vẫn là nợ D-020); damage number cho sát thương player nhận (chỉ móc chỗ đã có: `player_combat.gd:311`); gamepad; audio.

---

## 2. Quyết định đề nghị ghi DECISIONS (khi spec được duyệt)

- **D-021 · Phase D mở** với ba task UI/progression trước nội dung field/dungeon; lý do: throughput player là nút thắt đã đo (D-018 4,8 dmg/s vs 300 HP), buff damage là đòn bẩy trực tiếp; MVS-AC1…8 vẫn PROPOSED.
- **D-022 · `PlayerStats` là nguồn runtime duy nhất** cho chỉ số nhân vật (base từ `combat_tuning.tres` ⊕ modifiers). Luật ưu tiên ở §3.2 + check máy `tools/check_stat_source.mjs`.
- **D-023 · Buff model:** pool data + `BuffKernel` seed được, mỗi món 1 lần/run, 2 lần chọn/run, reset khi R/thua; buff chỉ áp dụng khi world không có đòn đang chạy.
- **D-024 · UI layer:** Theme dựng bằng code (`hd2d_theme.gd` + StyleBox 9-slice code-gen), font VT323 (SIL OFL 1.1, ghi ASSET_LOG), cỡ chữ bội số 16, kích thước panel chia hết 4, chữ integer-px, coverage font kiểm bằng máy + negative control.

---

## 3. Kiến trúc

### 3.1. `PlayerStats` — `scripts/combat/player_stats.gd`

`RefCounted` thuần, không node, headless-testable (cùng trường phái `AttackState`/`WaveKernel`).

```gdscript
class_name PlayerStats
extends RefCounted
signal changed

func _init(tuning: CombatTuning) -> void     # base = tuning, chưa có modifier
# getter trả giá trị hiệu lực (base ⊕ modifiers):
light_damage/player_max_hp/light_startup_frames/light_active_frames/light_recovery_frames
light_reach/light_combo_hits/combo_window_frames
fatigue_free_swings/fatigue_step_frames/fatigue_max_frames/fatigue_decay_frames
dodge_speed/dodge_total_frames/dodge_iframe_frames/move_speed
func add_modifier(source: StringName, ops: Dictionary) -> void   # ops: {"damage_mult":1.3, "recovery_add":3, ...}
func remove_modifier(source: StringName) -> void
func clear_modifiers() -> void
func active_modifiers() -> Array[Dictionary]  # cho sheet: [{source, ops}]
```

Thứ tự tính cho số nguyên: `floor((base + Σ add) × Π mult)`; số frame kẹp ≥1. `add_modifier` với cùng `source` thay thế modifier cũ (idempotent).

### 3.2. Luật ưu tiên (chống nguồn sự thật thứ hai)

1. `combat_tuning.tres` = **base duy nhất** cho mọi số feel; không modifier nào ghi ngược vào `.tres`.
2. Runtime **chỉ** đọc qua `PlayerStats`; cấm đọc trực tiếp `tuning.light_damage / player_max_hp / player_move_speed / light_startup_frames / light_active_frames / light_recovery_frames / light_combo_hits / combo_window_frames / fatigue_* / dodge_* / light_reach` ngoài `player_stats.gd`. Máy kiểm: `tools/check_stat_source.mjs` (§8).
3. `CombatTuning` thêm **`player_move_speed := 4.0`** — hiện tốc độ chạy là `@export` trên `player_controller.gd:4`; chuyển về tuning để stats là nguồn duy nhất (giá trị giữ 4.0, hành vi không đổi). `PlayerCombat` nhận giá trị đã tính từ `PlayerStats` rồi đẩy vào `player_controller.speed` (§3.3); controller **không** đọc `stats.move_speed()` — một đường đọc duy nhất qua `PlayerStats`. Nếu scene override `speed` thì đó là vi phạm luật (check máy quét `speed =` trên scene player).

### 3.3. Điểm nối (integration points)

| Nơi | Thay đổi |
|---|---|
| `player_combat.gd:54` | `health = Health.new(stats.player_max_hp())` |
| `player_combat.gd:210` | `apply_hit(stats.light_damage())` thay `tuning.light_damage` |
| `player_combat.gd:_ready` | dựng `stats`; `stats.changed` → đồng bộ `health.max_hp` (+heal phần chênh nếu tăng, guard `is_dead()`), `_player.speed` |
| `player_combat.gd:_start_attack` (150) | trước `_attack.start()`, ghi `startup/active/recovery/combo_window/combo_hits` từ stats vào `AttackState` (biến public sẵn có) — buff "có hiệu lực ở đòn kế tiếp" |
| `player_combat.gd` chỗ dùng `tuning.light_reach` / `tuning.dodge_speed` | đọc `stats.light_reach()` / `stats.dodge_speed()`; `DodgeState` dựng từ stats (pool hiện không có buff dodge nên giá trị không đổi trong run, nhưng luật nguồn phải giữ) |
| `player_combat.gd` reset | `stats.clear_modifiers()` trong `reset_run()`/R |
| `player_combat.gd:_apply_stats` | đẩy `_player.speed = stats.move_speed()` (PlayerCombat đã là nơi ghi trạng thái player: facing, lock, override); controller không đọc stats để tránh đường đọc thứ hai |

**Bất biến:** buff chỉ được áp dụng khi `_attack` ở phase NONE và world không chạy đòn nào (thực tế chỉ xảy ra ở `BUFF_PENDING`/paused) ⇒ không bao giờ đổi cửa sổ active của đòn đang bay.

---

## 4. Damage numbers (T-031)

- **Móc duy nhất:** `player_combat.gd`, ngay sau `applied > 0` khi đánh trúng (cạnh `:210–212`). Mọi enemy đi qua `Grunt.apply_hit` nên Boss/Swarm/Ranged tự có. Không đổi `CombatDirector`, không đổi schema CSV → E1/E2/E3 giữ nguyên.
- **Node:** `DamageNumbers` (CanvasLayer, `scripts/ui/damage_numbers.gd`), mount trong `scenes/phase_c/grove_arena.tscn`. PlayerCombat tham chiếu qua **exported NodePath rỗng mặc định** → harness/scene không có layer thì tắt êm, không crash.
- **Pool 24 `Label`** tái dùng, không cấp phát mỗi hit (Intel UHD, tránh GC giữa horde). Vị trí: `receiver.global_position + Vector3(0, 1.1, 0)` → `camera.unproject_position` → **làm tròn về pixel nguyên** trước khi đặt, đúng luật D-008 cho thành phần neo vào world.
- **Đọc được (pillar 1):** bay lên + fade 0,55 s; offset ngẫu nhiên trên **lưới 8 px**, không bao giờ lệch xuống dưới (decal telegraph Boss nằm dưới chân); **gộp số cùng mục tiêu trong 6 tick** (cộng dồn) → 1 chuỗi số/đòn AoE; màu trắng `#ffffff`, outline 2 px đen.
- **Tùy chọn:** toggle "Số sát thương" trong sheet (§5) — đây là toggle *thông tin*, không phải feel effect (feel effects sau này vẫn theo luật graduated).
- **Test L3:** box-diff ≥40 px khi một hit rơi vs control cùng pose không hit (chuẩn T-026/T-028); thêm check **bbox số vs vùng decal telegraph = 0 px chồng lấn**; check "ảnh có pixel sáng" để control không xanh rỗng (bài học P26.3).

## 5. Bảng trạng thái — ESC (T-029)

- InputMap action mới **`toggle_character_sheet`** (Escape). Không đọc phím cứng.
- Mở: `get_tree().paused = true`; node sheet `process_mode = PROCESS_MODE_ALWAYS` (`WHEN_PAUSED` không nghe được ESC lúc game còn chạy nên sheet sẽ không bao giờ mở được); đóng: unpause. Trong `BUFF_PENDING` (modal buff mở) ESC **bị bỏ qua** — modal đang giữ ưu tiên.
- Nội dung **chỉ đọc từ `PlayerStats` + `BuffKernel` + `WaveKernel`** (không hằng số viết tay): HP hiện/max; damage hiệu lực; chu kỳ đòn (startup/active/recovery) và dmg/tick lý thuyết; reach; combo hits/window; dodge speed/frames/i-frame; mệt (free/step/cap/decay hiệu lực); danh sách buff đang mang (tên + lợi/hại); wave hiện tại/trạng thái; `buff_seed` của run.
- Toggle "Số sát thương BẬT/TẮT" (lưu trong biến session, không save — chưa có save system).
- Focus: đúng một `grab_focus()` khi mở (bài học D-020); đóng bằng ESC hoặc nút Đóng; phím mũi tên/Enter theo pattern `title_screen.gd`.
- Headless-safe: driver harness không bao giờ mở panel ⇒ không treo `await physics_frame`.

## 6. Buff sau wave (T-030)

### 6.1. Pool (data, `scripts/phase_d/buff_pool.gd` — mảng const)

Base: chu kỳ 17 tick (4+3+10), damage 10, HP 100, reach 1.4 m, combo 3/10, mệt free 3 / decay 6, move 4.0 m/s.

| id | Tên | Lợi | Đổi lại |
|---|---|---|---|
| `heavy_edge` | Rìu Sét | `damage_mult 1.3` (10→13) | `recovery_add +3` (17→20 tick) |
| `quick_rhythm` | Nhịp Gọn | `recovery_add −3`, `combo_window_add +4` | `damage_mult 0.9` (→9), `fatigue_free_add −1` |
| `root_armor` | Giáp Rễ | `max_hp_add +40` | `move_speed_mult 0.88` |
| `slow_breath` | Nhịp Thở | `fatigue_free_add +2`, `fatigue_decay_add −2` (6→4) | `recovery_add +2` (→19 tick) |
| `long_reach` | Tầm Với | `reach_add +0.4` (→1.8 m) | `startup_add +2` (4→6) |
| `fourth_hook` | Lưỡi Hái | `combo_hits_add +1` (3→4) | `combo_window_add −4` (10→6) |

**Luật bắt buộc giữ (test):** sau MỌI tổ hợp buff khả dĩ, `fatigue_decay < fatigue_max` (luật D-019) và mọi frame/cap ≥1. Nhịp Thở là món duy nhất chạm decay; nó kéo decay xuống 4 nên luật càng chặt hơn.

### 6.2. `BuffKernel` — `scripts/phase_d/buff_kernel.gd` (RefCounted thuần)

- `BuffKernel.new(pool, seed)`; `offer() -> Array` (đúng 3, loại món đã chọn, shuffle bằng RNG seed); `take(id)`; `picked_ids()`; `reset()`.
- Cùng seed ⇒ cùng thứ tự 3 món (test bắt buộc; không nới assertion để lấy xanh).
- Game lấy seed ngẫu nhiên lúc run bắt đầu và **ghi `buff_seed` vào combat log** ⇒ mọi run thật tái lập được.

### 6.3. Wave flow

`WaveKernel` thêm `State.BUFF_PENDING` + `buff_pick_enabled: bool` (mặc định **false** — mọi harness/test cũ chạy y nguyên):

```
FIGHTING & alive=0 & wave_index < last:
    buff_pick_enabled ? -> BUFF_PENDING (đứng yên, chờ resolve_pick())
                      : -> PAUSED (pause_remaining = pause_frames)   # hành vi cũ
BUFF_PENDING: tick() không làm gì; resolve_pick() -> PAUSED(pause_frames)
reset(): về INACTIVE, xoá pending
player_died(): FIGHTING/PAUSED -> LOST (BUFF_PENDING không thể, world paused)
```

`WaveEncounter` (arena) đặt `buff_pick_enabled = true`, hook `kernel` vào `BUFF_PENDING` → mở modal (paused) → người chơi chọn → `buff.take(id)` + `stats.add_modifier(id, ops)` + `kernel.resolve_pick()` + unpause. `reset_run()` → `buff.reset()` + `stats.clear_modifiers()`.

## 7. UI system (T-029 dựng, T-031/T-030 dùng chung)

- **Theme dựng bằng code:** `scripts/ui/hd2d_theme.gd` — `static func build() -> Theme`; StyleBox 9-slice sinh bằng code theo texel (cùng trường phái `PlaceholderTextures`), áp làm `theme` của UI root để mọi panel kế thừa. Không asset khung tải về.
- **Palette:** panel `#12161c`, viền `#2c3542`, focus/tiêu đề `#d9b26a`, chữ `#e8e4da`, số sát thương `#ffffff`, phần "đổi lại" của buff `#c0695a` (không dùng đỏ telegraph địch).
- **Font:** VT323 (Peter Hull, SIL OFL 1.1) tại `assets/ui/fonts/vt323.ttf` (toàn văn license `OFL-VT323.txt` cùng thư mục), ghi `assets/ASSET_LOG.md` (nguồn, ngày, license, sha256). Antialiasing/hinting/subpixel đặt tắt trong `Hd2dTheme.build()`. Cỡ chữ = **bội số nguyên của 16 px** (16 body / 32 title) — 16 px là lưới terminal 8×16 gốc của font, nên không resample; đơn vị đúng là chiều cao cell của font, không phải texel world.
- **Coverage tiếng Việt:** m5x7 đã bị loại (cmap thiếu 17 glyph copy cần — `Ơ ơ Ư Ạ ạ Ầ Ậ Ắ Ế Ệ Ị Ổ Ộ Ớ Ở Ỳ` và em dash), VT323 phủ 567 codepoint và qua gate. Gate bắt buộc: `tests/test_font_coverage.gd` assert `font.has_char()` với **toàn bộ** ký tự UI copy (hiện 79 glyph, 0 missing); negative control với ký tự ngoài bảng mã phải đỏ. Nếu fail: hoặc copy UI rút về Latin (chấp nhận mất dấu), hoặc thêm fallback font (ghi DECISIONS) — **không** tự đổi font im lặng.
- **Hình học:** panel 480×320, card 160×220, spacing 8/16 (chia hết 4); vị trí/tọa độ integer px; outline 2–4 px như HUD hiện tại.
- **Motion:** card stagger 0.05 s, fade+scale 0.12 s EASE_OUT; số sát thương 0.55 s. Không shake/flash toàn màn hình.

## 8. Gates (DG1–DG5) & bằng chứng

| Gate | Nội dung | Công cụ |
|---|---|---|
| **DG1** | L1 `--check-only` mọi script mới + `--import` exit 0 | Godot |
| **DG2** | Unit headless: `test_player_stats` (precedence, thứ tự add-then-mult, floor, clear, HP delta), `test_buff_kernel` (seed tái lập, không trùng, đúng 3, mỗi món 1 lần), `test_wave_kernel` mở rộng (flag false == hành vi cũ; flag true không tự advance; reset xoá pending), `test_font_coverage`, `test_buff_laws` (decay<cap sau mọi tổ hợp) | `-s res://tests/...` exit 0 |
| **DG3** | Negative controls đỏ **đúng id**, exit 1: không apply buff ⇒ dmg/s < ngưỡng; thiếu `resolve_pick` ⇒ `wins=0`; bỏ `clear_modifiers` ⇒ buff còn sau R. Fail-first fixtures có tên: `buffs-not-reset-on-r`, `stat-source-violation` | harness |
| **DG4** | L3 renderer thật: sheet/3 card/damage number — box-diff ≥40 px vs control cùng pose, ảnh có pixel sáng, **overlap số↔telegraph = 0 px**; ảnh phải được xem thật | `capture_t030_ui.tscn` |
| **DG5** | Harness flow `run_t030_buffs.tscn`: 10 run seed cố định, `picks=2/run`, `wins=10`, in **dmg/s sau buff** để so với 4,8 (D-018) | exit 0 |

**Regression bắt buộc xanh sau mỗi task:** `node tools/run_evidence.mjs` (`failures=0`), 14 unit test cũ, harness t018/t019/t020/t021/t022, `test_title_entry` + capture title. **L4 thuộc user** (MP 5.3): brief mới chấm Readability/Fairness/Fun + câu "có hiểu vì sao nên chọn món này thay món kia không"; AI chỉ đo phần khách quan (`score_l4.mjs --probe`), không tự chấm.

## 9. Rủi ro & giới hạn

1. **Font thiếu dấu tiếng Việt** — đã xảy ra với m5x7 (17 glyph) và được chốt bằng VT323 (OFL 1.1); gate §7 giữ nguyên để một font khác sau này không lọt qua im lặng.
2. **Đổi nguồn `speed` của player** (controller → tuning/stats) — nguy cơ lệch hành vi movement Phase A; giữ giá trị 4.0 và chạy lại test movement + G1 capture.
3. **`BUFF_PENDING` chèn vào flow** — flag mặc định false để 22 test/harness cũ không đổi; harness t030 bật true mới phủ trạng thái mới.
4. **Tắt font/hiển thị giữa chừng** — damage number là toggle thông tin; không được biến thành feel toggle.
5. **Bộ số buff là HYPOTHESIS** như mọi con số trước đây — L4 quyết định giữ/đổi; không chỉnh số để "làm gate xanh".
6. Buff damage sẽ **làm cũ baseline D-018** — đây là mục đích của T-030 (đo lại dmg/s có buff); số mới phải ghi kèm seed + danh sách buff đã chọn.

## 10. Xác nhận của user (điền khi duyệt)

- [ ] Spec này được duyệt nguyên trạng, hay sửa phần nào?
- [ ] Thứ tự task T-029 → T-031 → T-030 OK?
- [x] Cho phép tải `vt323.ttf` (SIL OFL 1.1) từ Google Fonts và ghi ASSET_LOG? — user chọn "đổi sang font pixel khác có đủ dấu" (chat, 2026-11-21)
