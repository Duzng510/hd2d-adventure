# T-029 Task 4 — Report: `CharacterSheet` + InputMap action + pause test

**Status: DONE** — commit `9011481 feat(T-029): add the paused ESC character sheet`

Branch: `phase-d/t029-player-stats-sheet` · Engine: Godot 4.7.2.stable.official.ed1daf0bf (headless)

## 1. Deliverables

| File | State |
|---|---|
| `project.godot` | +5 dòng: action `toggle_character_sheet` (physical keycode 4194305 = Escape), chèn ngay sau `[input]`, CRLF giữ nguyên |
| `scripts/ui/character_sheet.gd` | mới, 190 dòng; `class_name CharacterSheet extends CanvasLayer` |
| `scripts/ui/character_sheet.gd.uid` | Godot-generated |
| `scripts/ui/ui_copy.gd` | +8 const (row format + placeholder), không sửa const cũ |
| `tests/test_character_sheet.gd` | mới, 8 checks |
| `tests/test_character_sheet.gd.uid` | Godot-generated |

Interface đúng brief: `set_sources(stats, hp_source, encounter = null)`, `open()`, `close()`, `refresh()`,
`is_open()`, `body_text()`. Không stage `.superpowers/`, `docs/phase-c/evidence/t027/session5/`, hay 2 file
`docs/phase-c/evidence/t023/evidence_report.*` (đã modified sẵn từ trước, để nguyên). `.godot/` không vào commit.

## 2. Controller rulings — đã áp dụng đủ 5

1. `process_mode = Node.PROCESS_MODE_ALWAYS` (comment trong code nêu lý do: `WHEN_PAUSED` không nghe được ESC
   lúc game đang chạy → sheet không bao giờ mở được).
2. Title dùng `Hd2dTheme.TITLE_FONT_SIZE` (32), bỏ phép `UI_FONT_SIZE + 7` thời m5x7.
3. `_resolve_sources()` private, gọi ở cả `_ready()` và `open()` khi `_stats == null` (retry theo thứ tự
   `_ready` của child trong arena).
4. `_close` là member field; `open()` gọi `_close.grab_focus()` sau khi `visible = true` → đúng một focus ban đầu.
5. Test assert nguyên dòng: `"10  (0.59 dmg/tick)"` và `"13  (0.76 dmg/tick)"` (không substring trần).

## 3. TDD evidence

### RED — test viết trước, chưa có implementation

```
"$GODOT" --headless --path . -s res://tests/test_character_sheet.gd
SCRIPT ERROR: Parse Error: Identifier "CharacterSheet" not declared in the current scope.
SCRIPT ERROR: Parse Error: Cannot infer the type of "sheet" variable because the value doesn't have a set type.
ERROR: Failed to load script "res://tests/test_character_sheet.gd" with error "Parse error".
RED_EXIT=1
```

### GREEN

```
"$GODOT" --headless --path . --import                       # IMPORT_EXIT=0
"$GODOT" --headless --path . -s res://tests/test_character_sheet.gd
PASS test_character_sheet: 8 checks                          # TEST_EXIT=0
```

8 checks = 1 closed+không pause, 2 open pause, 3 hp `77/100`, 4 damage `10  (0.59 dmg/tick)`,
5 damage theo buff `13  (0.76 dmg/tick)`, 6 close nhả pause, 7 ESC qua InputMap mở, 8 ESC lần hai đóng.

### Negative control

```
"$GODOT" --headless --path . -s res://tests/test_character_sheet.gd -- negative
FAIL: opening pauses the world
FAIL test_character_sheet: 1/8 checks failed                 # NEG_EXIT=1
```

Chỉ 1/8 đỏ theo đúng thiết kế của brief (`paused == (not _negative)`), đủ chứng minh check pause là load-bearing.

### ESC push path — **KHÔNG cần fallback**

`root.push_input()` với `InputEventKey` thật (keycode + physical_keycode = `KEY_ESCAPE`, press rồi release,
`await process_frame` mỗi event, `await physics_frame` cuối) **đến được `_unhandled_input` cả lúc đang pause**
với `PROCESS_MODE_ALWAYS`. Vì vậy KHÔNG dùng `Input.action_press/action_release`; assertion giữ nguyên.

## 4. Deviations so với brief (3, đều vì brief không chạy được / vi phạm global constraint)

1. **`CanvasLayer` không có property `theme`** → brief's `theme = Hd2dTheme.build()` báo
   `Parse Error: Identifier "theme" not declared` (L1 exit 1). Gán theme lên `_panel` (PanelContainer) —
   gốc của mọi Control trong sheet, kế thừa theme xuống toàn subtree. Không đổi visual.
2. **Row format strings chuyển vào `UiCopy`** (`SHEET_HP_ROW`, `SHEET_DAMAGE_ROW`, `SHEET_CYCLE_ROW`,
   `SHEET_REACH_ROW`, `SHEET_COMBO_ROW`, `SHEET_DODGE_ROW`, `SHEET_FATIGUE_ROW`, `SHEET_PLACEHOLDER`).
   Lý do: global constraint "UI text comes from UiCopy" + tiền lệ fix `1a30d03` (review đã bắt đúng lỗi
   hardcode display string ngoài `UiCopy`); gate glyph chỉ quét `UiCopy` nên literal trong `refresh()`
   sẽ vô hình với gate. Bằng chứng rendered text không đổi: test assert nguyên dòng damage/hp GREEN.
   Gate glyph: **56 → 79 glyphs, 0 missing** (23 glyph mới, gồm `đ ò ử ổ ầ`, VT323 phủ đủ).
3. **Bỏ `set_anchors_and_offsets_preset(PRESET_CENTER)`**, thay bằng anchors 0.5 + offset ±`SHEET_SIZE/2`.
   Đo thật bằng probe tạm (đã xoá, không commit): preset chạy khi panel còn size 0 **trước** khi vào tree →
   panel mọc từ giữa màn hình chứ không nằm giữa:
   - trước: `VIEW (64.0, 64.0) PANEL [P: (32.0, 32.0), S: (480.0, 320.0)] CENTER (272.0, 192.0) EXPECT (32.0, 32.0)`
   - sau:  `VIEW (64.0, 64.0) PANEL [P: (-208.0, -128.0), S: (480.0, 320.0)] CENTER (32.0, 32.0) EXPECT (32.0, 32.0)`
   Probe cũng xác nhận `MODE_ALWAYS true` và `FOCUS @Button@22` (Close button) sau `open()`.

## 5. Validation

| Lệnh | Kết quả |
|---|---|
| `--import` sau khi thêm action và mọi lần sau | exit 0 |
| `grep -A3 "^toggle_character_sheet" project.godot` | thấy block, `"physical_keycode":4194305`, 1 event |
| `--check-only --script res://scripts/ui/character_sheet.gd` | exit 0 |
| `--check-only --script res://scripts/ui/ui_copy.gd` | exit 0 |
| `-s res://tests/test_character_sheet.gd` | `PASS ... 8 checks`, exit 0 |
| `-s res://tests/test_character_sheet.gd -- negative` | exit 1, 1/8 |
| `-s res://tests/test_font_coverage.gd` | `PASS ... 3 checks, 79 glyphs, font cmap=567`, exit 0 |
| `-s res://tests/test_font_coverage.gd -- negative` | exit 1 (chỉ inverted control) |
| `-s res://tests/test_theme.gd` | `PASS test_theme: 9 checks`, exit 0 |
| toàn bộ 19 suite `tests/test_*.gd` (chạy lại sau commit) | `SUITES=19 ANY_FAIL=0` |

Commit: `9011481 feat(T-029): add the paused ESC character sheet`, 6 file, 276 insertions; blob `.gd` là LF
giống các file khác trong repo (git cảnh báo autocrlf chỉ là worktree).

## 6. Concerns

1. **Pause ownership**: `open()` set `get_tree().paused = true`, `close()` set `false` vô điều kiện. Khi có menu
   thứ hai (T-030/031) cùng pause, đóng sheet sẽ cưỡng bức resume. Chưa cần pause-stack cho T-029 nhưng phải
   xử lý trước khi có overlay thứ hai.
2. **Retry path chưa có test riêng**: `_resolve_sources()` trong `open()` cần một `PlayerCombat` thật trong cây;
   test headless hiện gọi `set_sources` trực tiếp nên nhánh retry (ruling 3) chỉ được review bằng mắt. Arena
   mount ở Task 5 sẽ là nơi kiểm chứng thật.
3. **`_encounter` / `encounter_path` đang là field chết**: interface brief mang `WaveEncounter` nhưng sheet
   chưa có row wave. Task 5 quyết: thêm row hay bỏ field.
4. **Centering đo trên window headless 64x64** (project chưa set window size). Rect đúng tuyệt đối theo anchor
   0.5 + offset nửa size, nhưng look cuối phải xác nhận bằng L3 screenshot ở Task 5.
5. **Negative control yếu theo thiết kế brief**: chỉ đảo 1/8 check (pause). Nếu muốn negative mạnh hơn (đảo cả
   8) phải sửa test — ngoài chỉ dẫn, để controller quyết.
6. **Chưa push**: branch chưa có upstream (`git rev-parse --abbrev-ref '@{u}'` → fatal), và task này chỉ yêu cầu
   commit + report. AGENTS.md muốn push ngay sau task xanh — quyết định thuộc controller.
7. Báo cáo này và mọi thứ trong `.superpowers/` giữ untracked theo chỉ dẫn.

## 7. Reproduction

```bash
GODOT="C:/Users/My Lenovo/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
"$GODOT" --headless --path . --import                                                # 0
"$GODOT" --headless --path . -s res://tests/test_character_sheet.gd                 # 8 checks, 0
"$GODOT" --headless --path . -s res://tests/test_character_sheet.gd -- negative     # 1
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd                   # 79 glyphs, 0
"$GODOT" --headless --path . -s res://tests/test_theme.gd                           # 9 checks, 0
```
