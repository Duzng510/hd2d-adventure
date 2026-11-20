# AGENTS.md — Quy tắc kỹ thuật

Project: **hd2d-adventure** — fantasy semi-open world real-time action RPG, nhìn HD-2D (Godot + GDScript).
Nguồn sự thật: design = `docs/GDD.md` (0.7.1) · quy trình = `docs/MASTER_PROMPT.md` (3.4.1) · trạng thái = `docs/STATE.md` · quyết định = `docs/DECISIONS.md`.
Tài liệu/báo cáo tiếng Việt (thuật ngữ kỹ thuật giữ English); identifier/comment/commit tiếng Anh.

## Engine & môi trường

- Godot **4.7.2.stable.official.ed1daf0bf** (GDScript build, không .NET). Yêu cầu GDD: 4.4+.
- Exe không trên PATH. Gọi đúng inner exe:
  `C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
  Không dùng `_console.exe` wrapper (hỏng trên máy này, error 193).
- Renderer: **Forward+** (BASELINE, D-004 Proposed). Máy dev: i5-13420H / Intel UHD / 24 GB RAM — FPS phải đo thật, không giả định 60.
- Chưa có main scene: mở editor hoặc chạy scene cụ thể.

## Cấu trúc thư mục

Hiện có: `project.godot`, `AGENTS.md`, `.gitignore`, `docs/` (GDD, MASTER_PROMPT, STATE, DECISIONS).
Dự kiến (chỉ tạo khi task cần): `scenes/`, `scripts/`, `assets/` (+ `ASSET_LOG.md`), `tests/`, `docs/phase-a/`, `docs/log/`, `docs/archive/`.

## Coding conventions

- Typed GDScript; tên file/class/node/signal nhất quán.
- Input chỉ qua InputMap action; không đọc phím cứng trong gameplay code.
- Combat timing tính bằng physics frame (60 tick/s) trong `_physics_process`; không dùng delta float cho cửa sổ đánh/né.
- Thông số feel (startup/active/recovery/i-frame/buffer/hit-stop/telegraph/damage) trong Resource `.tres` hoặc exported var; runtime có một nguồn authoritative duy nhất.
- Logic testable (combat state machine, damage, one-hit-per-swing) tách khỏi node để test headless.
- Signal đi lên, call đi xuống; node path dùng `const`/`preload`/exported resource, không rải string.
- Hạn chế Autoload; không dựng abstraction/framework trước nhu cầu thật.
- Không giả định API bản Godot khác; chưa chắc thì kiểm tra docs 4.7 hoặc thử trực tiếp trong project.

## Physics layers

| Layer | Tên | Dùng cho |
|---|---|---|
| 1 | world | Sàn, tường, vật cản tĩnh (`StaticBody3D`) |
| 2 | player | Player `CharacterBody3D` |

Mask: player mask = 1 (chạm world); world mask = 0. Hitbox/hurtbox layers sẽ thêm ở Phase B. Thêm layer phải cập nhật bảng này và mọi consumer (D-005 Proposed).

## Chạy & test (headless)

`<GODOT>` = đường dẫn exe tuyệt đối ở trên.

- L1 static: `<GODOT> --headless --path . --check-only --script res://<file>.gd`
- Import: `<GODOT> --headless --path . --import`
- L2 runtime: `<GODOT> --headless --path . res://<scene>.tscn --quit-after <N>`
- Test tự động: script `extends SceneTree` chạy bằng `--headless --path . -s res://tests/<file>.gd` (built-in, exit code truyền qua `quit()`). Lưu ý: `quit()` không dừng script ngay — dùng if/else sao cho chỉ **một** `quit()` chạy, nếu không lệnh quit cuối ghi đè exit code. Chưa dùng GUT/gdUnit4 — chỉ thêm khi có nhu cầu thật và được duyệt, ghi DECISIONS.
- L3 visual: cần renderer thật (Movie Maker không chạy với `--headless`); screenshot phải được xem thật mới tính bằng chứng.
- L4 playtest: giao thức Master Prompt mục 9; AI không tự suy luận feel từ code/log.

## Kỷ luật thay đổi

- `git status` trước khi sửa; không ghi đè thay đổi chưa commit của user; xem diff sau sửa; không tự commit/push khi chưa được yêu cầu.
- `.uid` commit cùng file gốc; không commit `.godot/`.
- Không xóa file/scene/resource/dữ liệu khi chưa đánh giá ảnh hưởng; không tự nâng engine/renderer/plugin/dependency.
- Scope hygiene: bug ngoài task → Known Issues, không sửa tiện tay.

## Asset

- Placeholder trước; một asset đại diện tích hợp thành công trước khi mở rộng.
- Art Spec tạm (scale, frame size, foot pivot, hướng nhìn) phải được user xác nhận trước khi sinh asset AI hàng loạt.
- Mọi asset ghi `assets/ASSET_LOG.md` (nguồn/công cụ, ngày, giấy phép); không dùng giấy phép không rõ.