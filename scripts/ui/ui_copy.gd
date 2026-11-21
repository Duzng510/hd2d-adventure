class_name UiCopy
extends RefCounted

## Every user-facing UI string lives here so the font coverage test can check
## each glyph the game may draw. T-030/T-031 append; nothing else hardcodes copy.

const SHEET_TITLE := "TRẠNG THÁI NHÂN VẬT"
const SHEET_HP := "MÁU"
const SHEET_DAMAGE := "SÁT THƯƠNG"
const SHEET_CYCLE := "CHU KỲ ĐÒN"
const SHEET_REACH := "TẦM VỚI"
const SHEET_COMBO := "COMBO"
const SHEET_DODGE := "NÉ"
const SHEET_FATIGUE := "MỆT NHỊP"
const SHEET_BUFFS := "BUFF ĐANG MANG"
const SHEET_NONE := "CHƯA CÓ BUFF"
const SHEET_WAVE := "WAVE"
const SHEET_SEED := "SEED"
const SHEET_CLOSE := "ĐÓNG"
const SHEET_PLACEHOLDER := "-"
const SHEET_HP_ROW := "%d/%d"
const SHEET_DAMAGE_ROW := "%d  (%.2f dmg/tick)"
const SHEET_CYCLE_ROW := "%d + %d + %d = %d tick"
const SHEET_REACH_ROW := "%.1f m"
const SHEET_COMBO_ROW := "%d đòn / cửa sổ %d tick"
const SHEET_DODGE_ROW := "%.1f m/s · %d tick · i-frame %d"
const SHEET_FATIGUE_ROW := "free %d · +%d tick · trần %d · decay %d"
## T-030: the ESC sheet must explain each carried buff (spec §5 name + gain/cost),
## not only its title.
const SHEET_BUFF_LINE := "%s — LỢI: %s\nĐỔI LẠI: %s"
const HUD_PLAYER := "PLAYER"
const HUD_WAVE := "WAVE"
const HUD_ENEMIES := "ENEMIES"
const HUD_FIGHT := "ĐANG ĐÁNH"
const HUD_NEXT := "WAVE TIẾP THEO"
const HUD_WIN := "THẮNG — R chơi lại"
const HUD_LOSE := "THUA — R chơi lại"
const HUD_GATE_OPEN := "CỔNG MỞ — SHRINE PHÍA BẮC"
const HUD_GATE_HEALED := "CỔNG MỞ — ĐÃ HỘI MÁU"
const HUD_ROW := "PLAYER %d/%d | WAVE %s | ENEMIES %d | %s"
const HUD_BOSS_PHASE := "BOSS %d/%d | PHASE %d"
const HUD_WAVE_NONE := "-"
const HUD_WAVE_PROGRESS := "%d/%d"
## T-031: the damage-number readout is an information toggle (spec §5), so the
## state word is copy, not a symbol, and the coverage gate sees it.
const SHEET_TOGGLE := "SỐ SÁT THƯƠNG: %s"
const STATE_ON := "BẬT"
const STATE_OFF := "TẮT"
## Parked from T-030: "1/3" alone did not say whether the wave was fighting,
## parked for a pick, or over.
const SHEET_WAVE_ROW := "%d/%d (%s)"
const BUFF_PANEL_TITLE := "CHỌN NÂNG CẤP"
const BUFF_PANEL_WAVE := "WAVE %d HOÀN THÀNH"
const BUFF_PANEL_HINT := "DÙNG PHÍM MŨI TÊN · ENTER ĐỂ CHỌN"
const BUFF_GAIN := "LỢI"
const BUFF_COST := "ĐỔI LẠI"
const BUFF_HEAVY_EDGE := "RÌU SÉT"
const BUFF_HEAVY_EDGE_GAIN := "SÁT THƯƠNG +30%"
const BUFF_HEAVY_EDGE_COST := "HỒI ĐÒN +3 TICK"
const BUFF_QUICK_RHYTHM := "NHỊP GỌN"
## The card text area is 144 px (160 card - 2 * 8 inset) = 22.5 glyphs at 16 px
## VT323 (6.4 px/glyph). A cost longer than that gets a deliberate line break
## here instead of a mid-phrase wrap in the card. T-030 final review: both lines
## carry the TICK unit (the old single line mixed units).
const BUFF_QUICK_RHYTHM_GAIN := "HỒI ĐÒN -3 TICK\nCOMBO +4 TICK"
const BUFF_QUICK_RHYTHM_COST := "SÁT THƯƠNG -10%\nMỆT SỚM"
const BUFF_ROOT_ARMOR := "GIÁP RỄ"
const BUFF_ROOT_ARMOR_GAIN := "MÁU TỐI ĐA +40"
const BUFF_ROOT_ARMOR_COST := "CHẠY CHẬM 12%"
const BUFF_SLOW_BREATH := "NHỊP THỞ"
const BUFF_SLOW_BREATH_GAIN := "MIỄN MỆT +2, HỒI NHANH"
const BUFF_SLOW_BREATH_COST := "HỒI ĐÒN +2 TICK"
const BUFF_LONG_REACH := "TẦM VỚI"
const BUFF_LONG_REACH_GAIN := "TẦM ĐÁNH +0.4 M"
const BUFF_LONG_REACH_COST := "RA ĐÒN CHẬM 2 TICK"
const BUFF_FOURTH_HOOK := "LƯỠI HÁI"
const BUFF_FOURTH_HOOK_GAIN := "COMBO +1 ĐÒN"
const BUFF_FOURTH_HOOK_COST := "CỬA SỔ COMBO -4 TICK"
