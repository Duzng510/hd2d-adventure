# T-029 Task 3 — Report: m5x7 font + code-generated HD-2D theme + coverage gate

**Status: BLOCKED** — coverage gate is red on real Vietnamese copy. No commit was made
(the brief and the task instructions both say: stop on missing glyphs, the font decision belongs to the user).

Branch: `phase-d/t029-player-stats-sheet` · Engine: Godot 4.7.2.stable.official.ed1daf0bf (headless)

## 1. Font provenance (obtained, not substituted)

- Source: Daniel Linssen — https://managore.itch.io/m5x7 (upload `m5x7.ttf`, 33 kB, uploaded 2016-03-09)
- Download path used (page is rate-limited to 429 for a plain request, so it was driven through the
  real browser session, then fetched with curl from the signed mirror URL itch returns):
  1. `GET https://managore.itch.io/m5x7/purchase` → `csrf_token`
  2. "No thanks, just take me to the downloads" → `POST /m5x7/file/170386?source=download`
     returned `{"url": "https://itchio-mirror...r2.cloudflarestorage.com/upload2/game/57078/170386?X-Amz-...&X-Amz-Signature=..."}`
  3. `curl` that 60 s signed URL → 34300 bytes (HTTP 200)
- Installed at `assets/ui/fonts/m5x7.ttf`
- Verification: `file` → `TrueType Font data, 14 tables, 1st "FFTM", 14 names, Macintosh`;
  first bytes `00 01 00 00 00 0E 00 80 00 03 00 60 46 46 54 4D` (sfnt 1.0 + `FFTM` tag). Tables:
  `FFTM GDEF OS/2 cmap cvt gasp glyf head hhea hmtx loca maxp name post`.
- **sha256 = `47c3f0b01f0fd417b3a44c2888a71d3072f750e76f3e6e946a6a9b188d988cbf`** (recorded literally in `assets/ASSET_LOG.md`)
- Godot generated `assets/ui/fonts/m5x7.ttf.import` (`importer="font_data_dynamic"`, uid `uid://crel45u41en4a`).

## 2. Files created (all untracked, nothing staged, nothing committed)

| File | State |
|---|---|
| `assets/ui/fonts/m5x7.ttf` | new, 34300 bytes, sha256 above |
| `assets/ui/fonts/m5x7.ttf.import` | new, Godot-generated |
| `assets/ASSET_LOG.md` | new, provenance row with literal sha256 |
| `scripts/ui/ui_copy.gd` | new, byte-identical to brief |
| `scripts/ui/ui_copy.gd.uid` | new, Godot-generated |
| `scripts/ui/hd2d_theme.gd` | new, byte-identical to brief |
| `scripts/ui/hd2d_theme.gd.uid` | new, Godot-generated |
| `tests/test_font_coverage.gd` | new, byte-identical to brief |
| `tests/test_font_coverage.gd.uid` | new, Godot-generated |
| `tests/test_theme.gd` | new, byte-identical to brief |
| `tests/test_theme.gd.uid` | new, Godot-generated |

Byte-for-byte comparison against the four `gdscript` blocks in `task-3-brief.md`: **IDENTICAL** (script-diffed, no drift).
No other file touched; `docs/phase-c/evidence/t027/session5/` and `docs/phase-c/evidence/t023/evidence_report.*`
left alone; `.superpowers/` unstaged.

## 3. Theme test — PASS (exit 0)

```
"$GODOT" --headless --path . --import        # exit 0
"$GODOT" --headless --path . -s res://tests/test_theme.gd
PASS test_theme: 8 checks                    # exit 0
```

Covers: theme builds; `default_font` is the pixel font; font size 14 % 7 == 0; SHEET_SIZE 480x320 and
CARD_SIZE 160x220 on the 4 px grid; panel StyleBoxFlat uses `PANEL`; `ACCENT == #d9b26a`;
`COST != #d94a4a`. Palette as briefed: `#12161c #2c3542 #d9b26a #e8e4da #c0695a`.

## 4. Font coverage test — FAIL (exit 1), the blocker

```
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd
FAIL: every UI glyph renders (missing: [...17 codes...])
FAIL test_font_coverage: 1/3 checks failed
exit 1
```

- check 1 "font file loads": PASS
- check 2 "every UI glyph renders": **FAIL**
- check 3 "control: coverage detector alive (has CJK = false, expected false)": PASS — the detector is alive
- Required by `UiCopy` now: **50 unique non-space glyphs**; 33 present, **17 missing**
- m5x7 maps **356 codepoints** across its cmap subtables (format 4 pid 0 = 319, format 6 pid 1 = 185 Latin-1, format 4 pid 3 = 356 union).
  Independently re-derived with a raw cmap parser (Python, no fontTools): identical 17 missing, and none of
  them appear in *any* subtable. The gate's verdict is real, not a loader artefact.

### Missing list (17) — full

```
Ơ(U+01A0)  ơ(U+01A1)  Ư(U+01AF)  Ạ(U+1EA0)  ạ(U+1EA1)  Ầ(U+1EA6)  Ậ(U+1EAC)
Ắ(U+1EAE)  Ế(U+1EBE)  Ệ(U+1EC6)  Ị(U+1ECA)  Ổ(U+1ED4)  Ộ(U+1ED8)  Ớ(U+1EDA)
Ở(U+1EDE)  Ỳ(U+1EF2)  —(U+2014)
```

Affected copy constants (`scripts/ui/ui_copy.gd`):

| const | value | missing glyphs |
|---|---|---|
| `SHEET_TITLE` | TRẠNG THÁI NHÂN VẬT | Ạ(U+1EA0) Ậ(U+1EAC) |
| `SHEET_DAMAGE` | SÁT THƯƠNG | Ơ(U+01A0) Ư(U+01AF) |
| `SHEET_CYCLE` | CHU KỲ ĐÒN | Ỳ(U+1EF2) |
| `SHEET_REACH` | TẦM VỚI | Ầ(U+1EA6) Ớ(U+1EDA) |
| `SHEET_FATIGUE` | MỆT NHỊP | Ệ(U+1EC6) Ị(U+1ECA) |
| `SHEET_NONE` | CHƯA CÓ BUFF | Ư(U+01AF) |
| `HUD_NEXT` | WAVE TIẾP THEO | Ế(U+1EBE) |
| `HUD_WIN` | THẮNG — R chơi lại | Ắ(U+1EAE) ơ(U+01A1) ạ(U+1EA1) —(U+2014) |
| `HUD_LOSE` | THUA — R chơi lại | ơ(U+01A1) ạ(U+1EA1) —(U+2014) |
| `HUD_GATE_OPEN` | CỔNG MỞ — SHRINE PHÍA BẮC | Ắ(U+1EAE) Ổ(U+1ED4) Ở(U+1EDE) —(U+2014) |
| `HUD_GATE_HEALED` | CỔNG MỞ — ĐÃ HỘI MÁU | Ổ(U+1ED4) Ộ(U+1ED8) Ở(U+1EDE) —(U+2014) |

Unaffected: `SHEET_HP`, `SHEET_COMBO`, `SHEET_DODGE`, `SHEET_BUFFS`, `SHEET_WAVE`, `SHEET_CLOSE`,
`HUD_PLAYER`, `HUD_WAVE`, `HUD_ENEMIES`, `HUD_FIGHT`.

## 5. Concerns / findings for the user's decision

1. **m5x7 is only *partially* Vietnamese.** It does cover `ă â đ ê ô Ă Â Đ Ê Ô` (Latin-1 + Latin Extended-A),
   so the gap is not "all diacritics" — it is precisely the Latin Extended-B `Ơ ơ Ư ư` letters plus the
   U+1EA0–U+1EF9 Vietnamese block. `Ơ`/`Ư` are core letters, not optional tone marks: any real Vietnamese
   copy ("THƯƠNG", "ĐƯỢC", "MỞ") hits them. "Fix the copy" cannot make this font sufficient.
2. **U+2014 (em dash) is missing too** and appears in 4 constants. That one *is* a copy decision
   (`-` / `--` / `·`), separate from the diacritic question.
3. Negative control: `-s res://tests/test_font_coverage.gd -- negative` exits **1** as specified
   (2/3 checks: the coverage failure plus the deliberately inverted control). It is currently
   indistinguishable from the normal red run, so the negative control only regains diagnostic value once
   coverage is green.
4. Nothing was substituted, stripped, or faked: font is the author's file, copy is the brief's copy verbatim.
5. Options seen (NOT implemented, for the user to choose, per spec §7):
   (a) different pixel font with full Vietnamese coverage (would redo the coverage gate + theme const);
   (b) keep m5x7 for the Latin/ASCII face and add a Godot font *fallback* resource for the missing 17 glyphs
       (visual mismatch in a 5x7 pixel face is likely — needs an L3 screenshot before it can be accepted);
   (c) ship m5x7 and restrict UI copy to its 356-codepoint charset (means writing Vietnamese without Ơ/Ư,
       i.e. spelling changes, an authorial decision);
   (d) strip accents — rejected by the spec, listed only for completeness.
   Related data point: the same author publishes `m6x11` (6x11) and `m3x6`; their Vietnamese coverage was
   **not** checked (out of scope, no download made).

## 6. Reproduction commands

```bash
GODOT="C:/Users/My Lenovo/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
"$GODOT" --headless --path . --import                                    # exit 0
"$GODOT" --headless --path . -s res://tests/test_theme.gd                # PASS 8 checks, exit 0
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd        # FAIL 1/3, exit 1
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd -- negative   # exit 1
sha256sum assets/ui/fonts/m5x7.ttf   # 47c3f0b0...988cbf
```

---

# 7. Fix pass — font swap to VT323 (controller ruling, 2026-11-21)

**Status: COMPLETE** — coverage gate xanh, theme xanh, đã commit `8a8664e`. Blocker ở §4 đã được giải
bằng ruling của controller: đổi font sang VT323 (OFL 1.1), không sửa copy, không strip dấu.

## 7.1 Font provenance

| Mục | Giá trị |
|---|---|
| Font | VT323 (Peter Hull), Google Fonts |
| Nguồn | https://fonts.google.com/specimen/VT323 · repo https://github.com/google/fonts/tree/main/ofl/vt323 |
| File | `assets/ui/fonts/vt323.ttf`, 153116 bytes, TrueType (tables `DSIG GDEF GPOS GSUB OS/2 cmap cvt fpgm gasp glyf head hhea hmtx loca maxp name post prep`) |
| sha256 font | `cf4de751ada78ceac033dbe16a687742939995b77bc2a052ae17a4957958594d` |
| License | SIL OFL 1.1 — toàn văn `assets/ui/fonts/OFL-VT323.txt` (4367 bytes, 93 dòng, tải `https://github.com/google/fonts/raw/main/ofl/vt323/OFL.txt` → HTTP 200; sha256 `27d9af34210253e7ca1251fbace86c6f65b40031d6ce1a75493a1b2093631298`) |
| m5x7 | đã xóa `assets/ui/fonts/m5x7.ttf` + `m5x7.ttf.import`; không còn dùng ở đâu |

Cmap (raw parser, không fontTools): fmt4 pid0 = 568, fmt4 pid3 = 568, fmt6 pid1 = 247 (Latin-1);
union = 623 codepoint; Godot `Font.get_supported_chars()` = **567**. ASCII 32–126 đầy đủ. **Toàn bộ 17
glyph từng thiếu đều có**: `Ơ ơ Ư Ạ ạ Ầ Ậ Ắ Ế Ệ Ị Ổ Ộ Ớ Ở Ỳ` và `—`(U+2014).

## 7.2 Thay đổi so với brief

- `scripts/ui/hd2d_theme.gd`: `FONT_PATH = "res://assets/ui/fonts/vt323.ttf"`, `UI_FONT_SIZE = 16`
  (native 8x16 terminal grid của VT323), thêm `const TITLE_FONT_SIZE := 32`. Palette, StyleBoxFlat,
  panel geometry giữ nguyên.
- `tests/test_theme.gd`: luật cỡ chữ `% 7` → `% 16` kèm comment 16 px = 8x16 grid; thêm 1 check
  `TITLE_FONT_SIZE % 16 == 0` để const mới không bị untested (9 checks thay vì 8).
- `tests/test_font_coverage.gd`: `FONT_PATH` → vt323; comment control cập nhật; dòng PASS in thêm
  số codepoint của font và trạng thái control (bằng chứng cho ruling 5).
- `assets/ASSET_LOG.md`: đúng 1 dòng VT323 (ngày 2026-11-21, source URL, OFL 1.1 reference tới
  `OFL-VT323.txt`, sha256, 153116 bytes) + 1 ghi chú ngắn: m5x7 bị loại vì thiếu 17 glyph tiếng Việt.

## 7.3 Validation (output nguyên văn)

```
"$GODOT" --headless --path . --import                                     # exit 0
    reimport: vt323.ttf → vt323.ttf.import (uid://b7d7cecgqu4i0)
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd
PASS test_font_coverage: 3 checks, 50 glyphs, font cmap=567 codepoints, control U+4E00 present=false   # exit 0
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd -- negative
FAIL: control: coverage detector alive (has CJK = false, expected true)
FAIL test_font_coverage: 1/3 checks failed (missing: [])                  # exit 1
"$GODOT" --headless --path . -s res://tests/test_theme.gd
PASS test_theme: 9 checks                                                 # exit 0
```

Control checks:

1. **Positive**: 50 unique non-space glyph từ `UiCopy` → 0 missing (lần trước 33/50, thiếu 17).
2. **Control char**: `has_char(0x4E00) == false` trên máy dev Windows (máy có font CJK hệ thống) —
   `has_char` chỉ xét font file + fallbacks khai báo, không xét system fallback, nên gate đo đúng file
   shipped. Giữ U+4E00, không cần đổi codepoint.
3. **Negative**: exit 1 với đúng **một** check đỏ (`missing: []`, chỉ inverted control) — negative giờ
   có giá trị chẩn đoán thật, khác lần trước khi red run trùng màu với negative run.

## 7.4 Commit

`8a8664e feat(T-029): add VT323 theme with a glyph coverage gate` — 12 file: `ASSET_LOG.md`,
`vt323.ttf`, `vt323.ttf.import`, `OFL-VT323.txt`, `ui_copy.gd(.uid)`, `hd2d_theme.gd(.uid)`,
`test_font_coverage.gd(.uid)`, `test_theme.gd(.uid)`. Stage theo path; không `.godot/`, không
`.superpowers/`, không đụng `docs/phase-c/evidence/t023/evidence_report.*` (đã modified từ trước) hay
`docs/phase-c/evidence/t027/session5/`.

## 7.5 Concerns

1. `docs/phase-d/UI_PROGRESSION_SPEC.md` và `docs/phase-d/PLAN_T029_stats_sheet.md` vẫn ghi m5x7 /
   "bội số 7" (tài liệu kế hoạch lịch sử, ngoài scope Task 3) — **Task 5 phải cập nhật** sang VT323 / 16.
2. `.import` sinh với `allow_system_fallback=true`; không sửa tay file generated. Gate không phụ thuộc
   nó (control ở §7.3 chứng minh), nhưng L3 nên để ý glyph lạ có bị fallback hệ thống không.
3. **L3 visual chưa chạy**: VT323 là font terminal 8x16 — cần 1 screenshot thật để chốt look trước khi
   Task 4 dựng CharacterSheet.

---

# 8. Fix pass — HUD copy đi qua `UiCopy` (review finding, 2026-11-21)

**Status: COMPLETE** — commit `1a30d03`.

Finding: gate tự nhận "mọi UI string sống trong `UiCopy`", nhưng `scripts/phase_c/wave_hud.gd`
hardcode toàn bộ string hiển thị; `BOSS`, `PHASE`, `|`, `-`, `/` chưa từng nằm trong const nào nên
gate không bao giờ thấy, và `UiCopy.HUD_*` chỉ là bản sao của sự thật. Sửa đúng phạm vi: **chỉ đổi nguồn
string, không đổi rendered text** (không restyle, không apply `Hd2dTheme`, không đụng outline/màu).

## 8.1 Thay đổi

`scripts/ui/ui_copy.gd`: +4 const, không xóa const nào (25 const tổng):

| const | giá trị |
|---|---|
| `HUD_ROW` | `PLAYER %d/%d \| WAVE %s \| ENEMIES %d \| %s` |
| `HUD_BOSS_PHASE` | `BOSS %d/%d \| PHASE %d` |
| `HUD_WAVE_NONE` | `-` |
| `HUD_WAVE_PROGRESS` | `%d/%d` |

`scripts/phase_c/wave_hud.gd` — 10 literal → const (mỗi dòng còn lại giữ nguyên):

| trước | sau |
|---|---|
| `"ĐANG ĐÁNH"` | `UiCopy.HUD_FIGHT` |
| `"-"` | `UiCopy.HUD_WAVE_NONE` |
| `"%d/%d"` | `UiCopy.HUD_WAVE_PROGRESS` |
| `"WAVE TIẾP THEO"` | `UiCopy.HUD_NEXT` |
| `"THẮNG — R chơi lại"` | `UiCopy.HUD_WIN` |
| `"THUA — R chơi lại"` | `UiCopy.HUD_LOSE` |
| `"PLAYER %d/%d \| WAVE %s \| ENEMIES %d \| %s"` | `UiCopy.HUD_ROW` |
| `"CỔNG MỞ — SHRINE PHÍA BẮC"` | `UiCopy.HUD_GATE_OPEN` |
| `"CỔNG MỞ — ĐÃ HỘI MÁU"` | `UiCopy.HUD_GATE_HEALED` |
| `"BOSS %d/%d \| PHASE %d"` | `UiCopy.HUD_BOSS_PHASE` |

`"\n"` nối dòng giữ inline: newline không có glyph (gate bỏ qua code ≤ 32), thêm const cho whitespace
không tăng giá trị gate. `_ready()` (position, `font_color`, `outline_size`) không đổi một ký tự.
Diff: `2 files changed, 14 insertions(+), 10 deletions(-)`.

## 8.2 Rendered text byte-identical (bằng chứng)

So sánh literal cũ (lấy từ `git show HEAD~1:scripts/phase_c/wave_hud.gd`) với giá trị const mới, format
cùng một bộ args:

```
IDENTICAL 'PLAYER 7/10 | WAVE - | ENEMIES 0 | ĐANG ĐÁNH'
IDENTICAL 'PLAYER 7/10 | WAVE 2/3 | ENEMIES 4 | WAVE TIẾP THEO'
IDENTICAL 'BOSS 30/40 | PHASE 2'
IDENTICAL '1/3'
IDENTICAL '12/12'
IDENTICAL HUD_FIGHT 'ĐANG ĐÁNH'
IDENTICAL HUD_NEXT 'WAVE TIẾP THEO'
IDENTICAL HUD_WIN 'THẮNG — R chơi lại'
IDENTICAL HUD_LOSE 'THUA — R chơi lại'
IDENTICAL HUD_GATE_OPEN 'CỔNG MỞ — SHRINE PHÍA BẮC'
IDENTICAL HUD_GATE_HEALED 'CỔNG MỞ — ĐÃ HỘI MÁU'
IDENTICAL HUD_WAVE_NONE '-'
RENDER_EQUIVALENT = True
```

Không còn literal hiển thị nào trong `wave_hud.gd` (4 "unmatched" còn lại khi quét là `NodePath("../Player")`,
`"PlayerCombat"`, `&"font_color"`, `&"font_outline_color"` — node path / StringName, không phải copy).

## 8.3 Glyph delta + validation (output nguyên văn)

```
"$GODOT" --headless --path . --import                                     # exit 0
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd
PASS test_font_coverage: 3 checks, 56 glyphs, font cmap=567 codepoints, control U+4E00 present=false   # exit 0
"$GODOT" --headless --path . -s res://tests/test_font_coverage.gd -- negative
FAIL: control: coverage detector alive (has CJK = false, expected true)
FAIL test_font_coverage: 1/3 checks failed (missing: [])                  # exit 1
"$GODOT" --headless --path . -s res://tests/test_theme.gd
PASS test_theme: 9 checks                                                 # exit 0
"$GODOT" --headless --path . --check-only --script res://scripts/phase_c/wave_hud.gd   # exit 0
"$GODOT" --headless --path . res://scenes/phase_c/grove_arena.tscn --quit-after 120
1,encounter,wave_start,0,0,1                                              # exit 0, grep error|warn = 0 dòng
```

Glyph mà gate thấy: **50 → 56**; 6 glyph mới đều ASCII và VT323 phủ đủ nên vẫn xanh:
`%`(U+0025) `-`(U+002D) `/`(U+002F) `d`(U+0064) `s`(U+0073) `|`(U+007C). Không xóa glyph nào.
Test logic `test_font_coverage.gd` không sửa — const mới tự vào qua `get_script_constant_map()`.

## 8.4 Commit + staging

`1a30d03 fix(T-029): route HUD copy through UiCopy` — stage đúng 2 path `scripts/phase_c/wave_hud.gd`,
`scripts/ui/ui_copy.gd`; không file mới nên không có `.uid` để thêm. Không stage `.superpowers/`,
`docs/phase-c/evidence/t027/session5/`, và 2 file `docs/phase-c/evidence/t023/evidence_report.*`
(vẫn modified sẵn từ trước, để nguyên).

## 8.5 Concerns

1. Branch chưa có upstream (`git rev-parse --abbrev-ref '@{u}'` → `fatal: no upstream configured`) nên
   chưa push; AGENTS.md muốn push ngay sau khi task xanh — quyết định thuộc controller.
2. Gate giờ phủ HUD copy nhưng vẫn chỉ quét `UiCopy`; nếu sau này có module khác hardcode copy thì gate
   vẫn mù — chỉ một review/rule mới bịt được, ngoài scope fix này.
