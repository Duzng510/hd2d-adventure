# DECISIONS

Lịch sử quyết định. Quyết định bị thay thế đánh **Superseded**, không xóa.

## Chỉ mục

| ID | Date | Category | Decision | Status |
|---|---|---|---|---|
| D-001 | 2026-11-20 | Product | Combat real-time action RPG | Accepted |
| D-002 | 2026-11-20 | Technical | Godot 4.4+ (khóa 4.7.2.stable) + GDScript | Accepted |
| D-003 | 2026-11-20 | Technical | Input bàn phím + chuột, gamepad DEFERRED | Accepted |
| D-004 | 2026-11-20 | Technical | Renderer Forward+ làm baseline | Proposed |
| D-005 | 2026-11-20 | Technical | Physics layers: 1=world, 2=player, 3–6 combat (Phase B) | Proposed |
| D-006 | 2026-11-20 | Technical | Gameplay XZ-plane + aim ground y=0 + occlusion fade 0.25 | Accepted |
| D-007 | 2026-11-20 | Technical | Projection: ortho texel_scale 4 + camera snap (persp giữ qua P để so sánh) | Accepted |
| D-008 | 2026-11-20 | Technical | Khóa pixel-grid: ortho integer scale + camera snap + sprite visual snap; giữ FIXED_Y, mật độ texel cố định | Accepted |
| D-009 | 2026-11-20 | Workflow | Waiver thoát Phase A khi L4 Not Run (user duyệt) | Accepted |
| D-010 | 2026-11-20 | Product | Light Attack hướng theo mouse snapshot tại action_start | Accepted |
| D-011 | 2026-11-20 | Workflow | Conventional Commits (scope = task ID) + push branch khi DONE | Accepted |
| D-012 | 2026-11-20 | Workflow | Waiver thoát Phase B khi B7 Failed (B7.3 spam 10/10 W); B7 giữ Failed | Accepted |
| D-013 | 2026-11-20 | Product | Scope Phase C: 3 vai trò (Grunt+Swarm+Ranged), mini-boss 2 phase, reward shortcut + hồi máu | Accepted |

---

## D-001 · 2026-11-20 · Product · Accepted

- **Decision:** Combat là real-time action RPG.
- **Reason:** Người dùng xác nhận 20/11/2026 (GDD mục 3): muốn trực tiếp điều khiển nhân vật, cảm nhận phản hồi khi tấn công/né, chủ động xử lý enemy.
- **Alternatives considered:** Turn-based — bị loại.
- **Consequences:** Prototype dùng để cải thiện implementation trong real-time, không chọn lại thể loại. Thiếu playtest/dữ liệu không phải bằng chứng bất khả thi. Ngoại lệ đề nghị xem xét lại chỉ theo Master Prompt 1.1; người dùng quyết định.

## D-002 · 2026-11-20 · Technical · Accepted

- **Decision:** Godot 4.4+ với GDScript (ưu tiên typed). Phiên bản khóa: **4.7.2.stable.official.ed1daf0bf** (xác minh `--version` ngày 2026-11-20).
- **Reason:** Engine + ngôn ngữ là CONFIRMED trong GDD mục 3.
- **Alternatives considered:** Không có phương án khác được ghi nhận trong GDD.
- **Consequences:** Exe không trên PATH, dùng inner exe (AGENTS.md); `.uid` commit cùng file gốc; test headless bằng script SceneTree built-in.

## D-003 · 2026-11-20 · Technical · Accepted

- **Decision:** Input chính bàn phím + chuột; gamepad DEFERRED.
- **Reason:** CONFIRMED trong GDD mục 3; phù hợp real-time action với ngắm chuột.
- **Alternatives considered:** Gamepad-first — để sau, không loại vĩnh viễn.
- **Consequences:** Mọi input đi qua InputMap action để thêm gamepad không phải viết lại. Binding mặc định tạm theo GDD 5.5 (WASD / LMB / RMB / Space / E), chưa phải Combat Spec chính thức.

## D-004 · 2026-11-20 · Technical · Proposed

- **Decision:** Renderer Forward+ làm implementation baseline (GDD mục 3).
- **Reason:** HD-2D cần ánh sáng/bóng/DoF có kiểm soát; Forward+ đủ tính năng nhất trên desktop.
- **Alternatives considered:** Compatibility — nhẹ hơn trên Intel UHD nhưng thiếu một số effect định hình HD-2D (volumetric fog, SSAO, TAA); chỉ đánh giá lại khi có evidence hoặc ràng buộc platform.
- **Consequences:** Máy dev iGPU (i5-13420H, Intel UHD): FPS phải đo thật ở Phase A, không giả định 60. Baseline ≠ user xác nhận; giữ Proposed tới khi user duyệt.

## D-005 · 2026-11-20 · Technical · Proposed

- **Decision:** Physics layers: 1 = world (sàn/tường/vật cản tĩnh), 2 = player body; Phase B (T-008) bổ sung 3 = player_attack, 4 = enemy_attack (hitbox `Area3D`), 5 = player_hurtbox, 6 = enemy_hurtbox. Player mask = world; world mask = 0; hitbox mask = layer hurtbox đối phương; hurtbox mask = 0.
- **Reason:** Collision đầu tiên xuất hiện ở T-002; Master Prompt 6.3 yêu cầu bảng layer/mask trong AGENTS.md; hitbox/hurtbox cần ở Phase B.
- **Alternatives considered:** Layer riêng cho hitbox/hurtbox — đã bổ sung ở Phase B (3–6); ShapeCast thủ công — loại vì Area3D chuẩn Godot, debug vẽ được (F1).
- **Consequences:** Thêm layer phải cập nhật bảng AGENTS.md và mọi consumer (bảng layer authoritative nằm ở AGENTS.md).

## D-006 · 2026-11-20 · Technical · Accepted

- **Decision:** Gameplay trên mặt phẳng XZ (player `velocity.y = 0`, trọng lực không áp dụng ở Phase A); aim = ray camera cắt **ground plane y = 0**; vật cản che khuất bị **fade albedo alpha 0.25** khi chặn ray camera→player-center hoặc camera→aim.
- **Reason:** User duyệt bằng văn bản (y) ngày 2026-11-20 sau evidence G1/G2/G3. G1 chứng minh drift z=0, dừng tường chính xác; G2 offset aim=0 ở cả 5 điểm nhưng G2.2 trái Fail do Block che reticle; G3 fade giải quyết cả 3 tình huống che và đồng thời gỡ G2.2 (`g3/g2_left_after_fade.png`).
- **Alternatives considered:** Aim theo hit collider (bám mặt vật thể) — phức tạp hơn, chưa cần; không fade (giữ vật che opaque) — làm mất reticle/player, bị loại qua G2.2 Fail.
- **Consequences:** Player/telegraph/reticle không bao giờ fade; group `fadeable` = Wall/Block/Roof. Single center-ray có thể sót che khuất một phần; alpha 0.25 cho cảm giác "ghost" (tradeoff đã ghi ở OPERATIONAL_DEFINITIONS §10). Cảm nhận fade cần L4 playtest.

## D-007 · 2026-11-20 · Technical · Accepted

- **Decision:** Projection chính thức **orthographic**, `texel_scale = 4` → `size = viewport_height × pixel_size / 4` (9 tại 720p, tự theo resolution); camera follow snap (smoothing 0) + `snap_to_pixel = true`, offset (0,10,8). Perspective FOV 35 giữ làm chế độ so sánh qua phím **P**.
- **Reason:** User chọn bằng văn bản ngày 2026-11-20: **"Ortho + giữ FIXED_Y"** sau evidence T-006. Đo thật: persp không thể integer px/texel toàn cục (4.458 tại player, 4.062 tại điểm xa hơn) và camera snap không giảm shimmer persp (residual 18013→18681 px); ortho khóa được world crawl (T-006 −95%, T-007 = 0).
- **Alternatives considered:** Perspective + chỉnh pixel_size — loại vì px/texel đổi theo độ sâu; SubViewport low-res + integer upscale — loại vì mất chi tiết diorama 3D của HD-2D; ortho + full billboard cho texel vuông — user chọn giữ FIXED_Y thay thế.
- **Consequences:** Mật độ texel cố định **4.000 × 2.499 px** (aspect 0.6247) là chủ đích, không phải lỗi (D-008). Mất chiều sâu phối cảnh của diorama; cảm nhận cuối cùng đánh giá ở L4. Follow smoothing >0 vẫn để dành tinh chỉnh feel sau playtest.
- **Evidence:** T-006/T-007, OPERATIONAL_DEFINITIONS §12–13, `docs/archive/phase-a/evidence/pixel/` (T-006), `evidence/pixel_t007/` (T-007).

## D-008 · 2026-11-20 · Technical · Accepted

- **Decision:** Gói khóa pixel-grid gồm 4 phần, nay đủ: (1) ortho integer scale (`texel_scale`); (2) camera snap theo pixel màn hình (`snap_to_pixel`); (3) visual snap của sprite tách khỏi logic position (`visual_snap`, lượng tử hóa vị trí hiển thị về integer px); (4) **giữ billboard FIXED_Y** và sửa luật pixel-grid từ "texel vuông" thành **"mật độ texel cố định, nhất quán mọi frame"** (4.000 × 2.499 px tại scale 4).
- **Reason:** User chốt "Ortho + giữ FIXED_Y" ngày 2026-11-20. Đo T-006 cho thấy thiếu phần nào luật vỡ phần đó; T-007 chứng minh đủ 3 phần kỹ thuật thì `anchor_dev` = `sprite_dev` = 0.0000 suốt 24 frame và residual 0 px. Texel vuông bị loại vì phải đổi cách đặt sprite (full billboard nghiêng theo camera, ảnh hưởng bóng/đổ bóng) — user ưu tiên sprite đứng thẳng của diorama.
- **Alternatives considered:** Full billboard / mặt phẳng nghiêng khớp pitch cho texel vuông — user không chọn; chấp nhận crawl — loại vì phá luật pixel-grid; SubViewport low-res — xem D-007.
- **Consequences:** (1)(2)(3) implement ở T-007 và là mặc định của scene; visual snap dịch sprite ≤0.5 px màn hình (~0.004 u), foot pivot vẫn chạm đất (ảnh T-007 đã xem). Hàng dọc texel vẫn lẻ px (2.499) nhưng **hằng số** nên không crawl. Asset hàng loạt hết chặn về mặt pixel; vẫn chờ chốt bộ hướng sprite + palette (ART_SPEC §6).

## D-009 · 2026-11-20 · Workflow · Accepted

- **Decision:** Cho phép chuyển Phase A → Phase B khi L4 human playtest của build Phase A chưa chạy (Not Run).
- **Reason:** User duyệt bằng văn bản ngày 2026-11-20: "ok push branch hiện tại và tạo branch mới và duyệt thoát Phase A, lên plan Phase B đi". Phase A gates 1–5 đạt: G1–G3 trên renderer thật (ảnh đã xem), Gate 4 Art Spec user xác nhận, Gate 5 DECISIONS đủ (D-006/D-007/D-008 Accepted). L4 không nằm trong gate bắt buộc của GDD Phase A; cảm nhận camera/movement/pixel sẽ thu trong L4 Phase B trên cùng build.
- **Alternatives considered:** Chạy L4 Phase A trước khi sang B — user bỏ qua để không chặn combat prototype; ở lại Phase A chờ playtest — bị loại.
- **Consequences:** L4 Phase A giữ nguyên **Not Run** (không thành Passed). Rủi ro chấp nhận: feel camera/movement chưa được người chơi xác nhận; giảm thiểu bằng L4 Phase B (build tích lũy) và tinh chỉnh theo playtest.
- **Scope:** Chỉ áp dụng cho bước chuyển Phase A→B; không miễn gate nào của Phase B; MVS-AC1…8 vẫn chờ user duyệt riêng.

## D-010 · 2026-11-20 · Product · Accepted

- **Decision:** Light Attack lấy hướng đánh = **snapshot vị trí aim của chuột tại `action_start`** (ground y=0), cố định suốt swing; facing sprite flip theo dấu X của hướng; hitbox định hướng theo snapshot. Mouse di chuyển sau đó không đổi hướng đòn.
- **Reason:** User chốt 2026-11-20 qua lựa chọn "Mouse snapshot" — khớp reticle/aim Phase A (D-006) và GDD 5.3 (free aim bằng chuột).
- **Alternatives considered:** Đánh theo facing L/R — loại vì bỏ free-aim; cập nhật hướng live trong startup/active — loại vì hitbox đổi hướng giữa swing, khó đọc và khó test.
- **Consequences:** Đòn có thể đánh mọi hướng trên XZ (kể cả ngược sprite vì placeholder chỉ flip L/R) — readability hướng dọc/ngược đánh giá ở L4; hitbox reach trong `combat_tuning.tres`.

## D-011 · 2026-11-20 · Workflow · Accepted

- **Decision:** Commit theo **Conventional Commits** `<type>(<scope>): <summary>` với scope = task ID (ví dụ `feat(T-012): add encounter manager`). Giữ branch naming `<phase>/<task-id>-<slug>`, thêm `exp/<slug>` cho thử nghiệm và `chore/<slug>` cho việc lẻ. **Push branch ngay khi task DONE** (validation xanh + commit), không chờ yêu cầu.
- **Reason:** User chỉ đạo 2026-11-20: "mỗi khi xong một branch thì push lên git" và cung cấp bộ quy ước Conventional Commits/branch naming/.gitignore để tham khảo.
- **Alternatives considered:** Giữ format cũ `T-xxx <summary>` — bị thay theo yêu cầu; đổi branch naming sang `<type>/<name>` — không chọn vì mất traceability phase/task.
- **Consequences:** Commit từ T-012 dùng format mới; `.godot/` tiếp tục không commit; không push khi validation đỏ; không force-push `main` (dùng `revert`). AGENTS.md cập nhật cùng ngày.

## D-012 · 2026-11-20 · Workflow · Accepted

- **Decision:** Cho phép thoát Phase B theo quy tắc waiver MP 8.6 dù gate **B7 Failed** (B7.3). Waiver chỉ mở đường chuyển phase; B7 giữ nguyên **Failed**, không đổi nhãn hay hạ chuẩn bất kỳ gate nào.
- **Tiêu chí chưa đạt:** Phase B exit = AND(B1–B7, D1–D3) (user xác nhận 2026-11-20, `OPERATIONAL_DEFINITIONS` §7/§11). B7.1/B7.2 Passed nhưng **B7.3 Fail**: chiến thuật spam thuần (chỉ attack khi phase NONE, không dodge, không di chuyển) thắng mọi run → gate B7 = **Failed**.
- **Evidence/status:** T-016 harness `scenes/phase_b/run_b7_spam.tscn` + `scripts/phase_b/b7_spam_driver.gd`: **10/10 W**, 87 tick/run, player nhận 1 hit/run (15 dmg, không chết), 0 player death; passive control 10/10 L (332 tick/run) — `docs/phase-b/evidence/b7/spam_combat_log.csv` + `spam_summary.txt`. B7.1/B7.2 từ T-015 `evidence/b7/`; B1–B6, D1–D3 Passed. Gate status: **B7 Failed** (không đổi).
- **Lý do:** User quyết định chuyển tiếp với B7 Failed thay vì bổ sung cơ chế chống spam (GDD 6.8 mục 7) tại thời điểm này, sau khi đã xem số liệu T-016; trước đó user đã ghi nhận "chưa thêm cơ chế vội" (T-015). Không bỏ qua mù — measurement đầy đủ trước khi quyết định.
- **Rủi ro được chấp nhận:** (1) Ở tuning hiện tại, spam đòn thường là chiến thuật thống trị — độ sâu combat theo GDD 6.8.7 chưa được chứng minh; (2) khi thêm cơ chế sau, số liệu balance/readability L4 (B5/B6) có thể phải đánh giá lại; (3) Phase B khép lại với một gate Failed được ghi nhận công khai.
- **Phạm vi waiver:** Chỉ áp dụng cho bước thoát Phase B (sang Phase C theo roadmap); không miễn gate nào khác, không miễn MVS-AC, không đổi kết quả B7.3/B7. Cơ chế GDD 6.8.7 vẫn ở backlog; khi được thêm, B7.3 **phải test lại** bằng đúng harness spam và ghi kết quả vào evidence — waiver không miễn lần test lại này.

## D-013 · 2026-11-20 · Product · Accepted

- **Decision:** Scope Phase C (STRETCH, GDD 12): arena nhỏ 3 wave — Wave 1: 2 Grunt + 3 Swarm · Wave 2: 2 Swarm + 2 Ranged · Wave 3: mini-boss riêng 2 phase (chuyển tại HP ≤ 50%); reward = cổng shortcut mở + hồi máu full. Gate **C1–C3 + evidence E1–E5** theo `docs/phase-c/OPERATIONAL_DEFINITIONS.md` (CONFIRMED).
- **Reason:** User chốt 2026-11-20 qua 3 lựa chọn mức đầy đủ (3 vai trò / boss riêng 2 phase / shortcut + heal) và xác nhận gate doc bằng "y". Hướng đã chốt từ trước: "design ambition, rollout theo giai đoạn" — chi phí chia nhỏ qua T-018…T-024 thay vì cắt scope.
- **Alternatives considered:** 2 vai trò (Grunt+Ranged hoặc Grunt+Swarm) — loại, thiếu so với "nhiều enemy/vai trò" của GDD 12; boss 1 phase hoặc Elite Grunt — loại, silhouette kém đặc trưng hơn yêu cầu GDD 6.7; reward mở Heavy Attack (thêm cơ chế combat mới) hoặc chọn charm (thêm UI/choice) — loại, "reward đơn giản" của Phase C chỉ cần quan sát được.
- **Consequences:** Không thêm physics layer; không pathfinding (Known Issue giữ nguyên); không đụng scene Phase A/B (arena mới). Nghĩa vụ treo: B7.3 vẫn phải retest bằng `run_b7_spam.tscn` khi cơ chế chống spam GDD 6.8.7 được thêm — Phase C không thêm cơ chế này. Reward shortcut + heal chưa phải bằng chứng cho MVS-AC6 (Phase D).
- **Xác nhận của user:** "ghi waiver Phase B theo MP 8.6." (chat, 2026-11-20).
## D-014 · 2026-11-21 · Product · Accepted

- **Decision:** Một lượt tuning từ dữ liệu L4 Phase C (MP 9): **cửa sổ phạt sau cú lao của boss** — `boss_lunge_recovery_frames` 24 → 36, `boss_lunge_phase2_recovery_frames` 16 → 24. Chu kỳ lunge phase 1: 56 → 68 tick (0,93 → 1,13 s); phase 2: 48 → 56 tick (0,80 → 0,93 s). Telegraph / active / damage / tầm lunge / mọi tham số khác **giữ nguyên**.
- **Reason:** 3 run L4 đầu tiên (T-024, `docs/phase-c/evidence/t024/session1_*`) kết luận **0/3 win**, cả 3 thua ở wave 3 trong 3,6–8,4 s, boss còn 270–290/300 HP. Lunge gây **84/132 damage của boss (64%)**. `bossTelegraphMin = 24` (> sàn 18) nên đây **không** phải lỗi readability — boss báo trước đủ, nhưng 0,8 s cho một cú lao 5 m trong khi tầm đánh của player là 1,4 m nghĩa là không tồn tại cửa sổ phạt.
- **Alternatives considered:** hạ `boss_lunge_range` 5,0 → 3,5 (user chọn recovery trước để giữ cảm giác "lao"); giảm `boss_max_hp` 300 → 220 (rút ngắn trận nhưng không sửa đúng chỗ người chơi kêu); tăng damage player hoặc giảm `boss_lunge_damage` (loại — đổi độ nghiêm trọng thay vì đổi nhịp, sẽ làm lệch cả B-series đã chốt); chơi đủ 10 run trên build cũ để lấy số đẹp (loại — 0/3 đã là chỉ dẫn rõ).
- **Consequences:** Giá trị chạy khác Phụ lục §9 của `OPERATIONAL_DEFINITIONS.md` — §9 là **HYPOTHESIS** nên giữ nguyên bản, nguồn số thật là `combat_tuning.tres`; `test_boss_tuning` cập nhật 2 assert (kèm comment lý do) và law "phase 2 nhanh hơn qua recovery" vẫn giữ (24 < 36). Mọi số liệu L4 thu trước lượt tuning này (3 run) chỉ còn giá trị baseline, không dùng để chấm C1. Validation: `test_boss_tuning` 36 checks exit 0, `test_boss_ai` 30 exit 0, `run_t021_boss` 41 exit 0, `run_t018_cycles` wins=10 exit 0 (bot không né nên **không** phải bằng chứng cho nhịp — chỉ là regression), `--import` exit 0, 0 `SCRIPT ERROR`.
- **Xác nhận của user:** chọn "Đổi 1 tham số: lunge recovery (recommended)" (chat, 2026-11-21).

## D-015 · 2026-11-21 · Workflow · Accepted

- **Decision:** Dựng L4 capture rig (T-025): `L4Probe` ghi `user://l4_probe.csv` (10 Hz sample + một row ngữ cảnh cho mỗi đòn player ăn + row lúc chết) và PNG đúng frame chết; `play_arena.tscn` mount probe lên arena thật mà không sửa scene game; `tools/score_l4.mjs --probe` join theo `sim_frame`. Mục tiêu: bỏ phần "user nhớ rồi báo lại" khỏi phiên L4.
- **Reason:** Yêu cầu của user 2026-11-21 ("tôi chỉ cần chơi thôi"). Dữ liệu họ đang phải nhớ thật ra máy đo được: cửa sổ telegraph thực tế (trừ hitstop), có di chuyển sau telegraph không, dodge có sẵn không, ăn đòn khi áp sát trụ/tường, ai kết liễu, boss còn bao nhiêu HP, fps thật. Session 3 run trước đó cho thấy trí nhớ người chơi lệch khỏi số đo (báo "khá khó đánh" trong khi 0/3 win và boss còn 270–290/300 HP).
- **Rủi ro được chấp nhận:** (1) tap `event_logged` nằm trên đường ghi log của mọi event — thêm chi phí mỗi tick, đo được là không ảnh hưởng (windowed vẫn 59–61 fps, `checks=8 failures=0`); (2) `dist` khi nhiều enemy cùng vai trò đang active là ước lượng nearest-candidate, đánh dấu `note=ambig=N` chứ không giả chính xác; (3) PNG mỗi lần chết ghi vào user://, cần copy thủ công khi nghiệm thu.
- **Phạm vi thay thế:** Rig **thay được** C3.3 (fps), một phần C2.2 (readable-share = proxy, không phải tử số user chấm), C2.3 (ảnh thật tại thời điểm chết), và mọi ô "số đòn đã ăn". Rig **không thay được** C1.3 (thua có chủ đích không), C2.1 (Readability/Fairness là phán quyết), Fun. Bảng probe không bao giờ tự ghi Passed cho sub-check L4 (MP 5.3).
- **Xác nhận của user:** "liệu bạn có thể tối ưu, nâng cấp tool để lấy được nhiều thông tin nhất không? ... tôi sẽ không phải nhớ rồi cung cấp lại thông tin" + chọn "Tier 1+2: tự động hoàn toàn" (chat, 2026-11-21).

## D-016 · 2026-11-21 · Workflow · Accepted

- **Decision:** Thoát Phase C theo MP 8.6 với **C1 Not Run**, **C2 Incomplete**, **C3 Partial**; E1–E5 và D1–D3 giữ nguyên **Passed**. Không nâng nhãn, không đổi ngưỡng, không đổi cách đo.
- **Bằng chứng / status từng sub-check:**
  - C1.1 Not Run: 2 run hợp lệ trên 10 yêu cầu (run 3 user quit giữa chừng, ghi riêng, không tính). C1.2: 0/2 win — cả hai thua ở wave 3, boss còn 200/300 và 260/300 HP. C1.3 **đạt điều kiện**: user xác nhận thua do kỹ năng cá nhân, không do lỗi kỹ thuật/khó hiểu → không có blocker cần sửa trước khi chơi lại.
  - C2.1: Readability 5/5 và Fairness 5/5 cho cả 2 run (mean 5.0 ≥ ngưỡng 3, nhưng mẫu = 2 nên không đủ để gọi Passed). C2.2: tử số user không đưa; proxy từ rig **18/18 đòn ăn đều có cửa sổ telegraph dùng được** (min lead 18 và 20 frame, đã trừ hitstop). C2.3: 2 ảnh frame chết thật đã xem (`evidence/t024/session2/`), không thấy telegraph nào bị che trong 2 khung đó.
  - C3.1: 0 `SCRIPT ERROR` (engine log của launch này), không soft-lock, không wave kẹt. C3.2: 2/2 run khép bằng `encounter_reset`; trạng thái reset đầy đủ do harness `run_t022_reward` (E4.3) chứng minh, không phải do session này. C3.3: play fps min 58 / median 60; con số 19 chỉ ở frame 60–90 = warm-up launch, **không phải** vấn đề hiệu năng trong combat.
  - E1–E5 + D1–D3: `node tools/run_evidence.mjs` → `EVIDENCE e1-e5 passed runs=7 negatives=7 ids=17 failures=0` trên build có capture rig.
- **Lý do:** 10 run trong một session là thời gian thật của user; sau D-014 (cửa sổ phạt lunge) tín hiệu chất lượng đã đủ để đóng phase mà không tự nâng chuẩn. Rig T-025 lấy được phần khách quan nên phần còn thiếu chỉ còn mẫu 10 run, không phải dữ liệu.
- **Rủi ro được chấp nhận:** (1) C1 "≥8/10 win" chưa từng được đo trong một session 10 run, nên độ khó encounter nhiều enemy chỉ có bằng chứng định tính; (2) Fun 4/5 là một mẫu đơn; (3) punish window mở 97 và 155 tick nhưng chỉ đổi được 6 và 3 đòn trúng — nguyên nhân chưa kết luận (đang tra: body boss che player khi áp sát); (4) mọi tuning Phase D mất baseline C1.
- **Phạm vi waiver:** chỉ C1/C2/C3 của Phase C. Không miễn sub-check nào khác, không miễn MVS-AC, không biến Not Run thành Passed. Phase D vẫn phải có L4 riêng; nghĩa vụ retest B7.3 khi thêm cơ chế chống spam GDD 6.8.7 (D-012) giữ nguyên.
- **Xác nhận của user:** "Run 1: Read 5/5 Fair 5/5 / Run 2: Read 5/5 Fair 5/5 / Fun 4/5 — và: hai lần thua đó ... (do tôi chơi gà bị boss hành)" + "điều tra chỗ fps tụt xuống 19 với body boss che mất player đi, rồi tính tiếp lever nào" (chat, 2026-11-21).
- **Đính chính (cùng ngày, sau T-026):** dòng "punish window mở 97 và 155 tick nhưng chỉ đổi được 6 và 3 đòn trúng" dùng **sai đơn vị** — 97/155 là **số mẫu** (mỗi mẫu 6 tick ≈ 582/930 tick thật), và vế "chỉ đổi được N đòn" so số đòn với số mẫu nên cho ra cảm giác "cửa sổ bỏ trống ~90%". Khi đo lại bằng damage (trace `boss_hp`) trên cả 8 run hợp lệ: cửa sổ RECOVERY chiếm **43–62% thời gian đánh boss** và **50–100% sát thương lên boss nằm trong đó** (pooled 64% pre-ring, 70% session3, 56% session4). Kết luận "cửa sổ chưa được dùng" là **sai**; các suy luận dựa trên nó (kể cả lựa chọn lever đã cân nhắc) phải đọc lại theo số mới. Không đổi nhãn gate nào ở trên — chỉ sửa cách đọc metric.

## D-018 · 2026-11-21 · Workflow · Accepted

- **Decision:** **Đóng Phase C** trên build `phase-c/t026-self-marker`, giữ nguyên waiver D-016 và mọi nhãn gate (C1 Not Run / C2 Incomplete / C3 Partial; E1–E5 + D1–D3 Passed). **Không đổi tham số combat nào** từ mẫu L4 này. Nút thắt đo được — throughput sát thương so với 300 HP boss — ghi thành **input bắt buộc** cho tuning Phase D, không xử lý tiện tay.
- **Bằng chứng (8 run hợp lệ sau D-014: 2 trước ring, 6 sau ring):** 0 win; sát thương lên boss mỗi run 40–190/300; pooled DPS ≈ **4,8 dmg/s** ⇒ TTK ≈ **63 s**, trong khi run dài nhất chỉ sống tới 55 s; readable **36/36** đòn có ≥18 frame usable; 0 `SCRIPT ERROR`; dodge-ready lúc ăn đòn 43–80%; 78–90% đòn ăn xảy ra sát trụ/tường.
- **Luật đã ghi trước khi đo (state §Next):** punish ≥25% mà vẫn thua → **metric cũ sai đơn vị, đã thay bằng damage-share và không còn áp dụng**; dodge-ready <50% → **không đạt**; boss HP left trung bình ≤120 → **không đạt (mean 237)**. Không có ngưỡng nào bị vượt nên theo MP 9 không tồn tại tuning hợp lệ trên mẫu này; mọi thay đổi số lúc này là **quyết định thiết kế**, phải ghi D riêng và đo trước/sau.
- **Rủi ro được chấp nhận:** (1) Phase D không có win-baseline cho C1, nên mọi chỉnh độ khó đầu Phase D so sánh với con số 0/8; (2) độ khó encounter nhiều enemy mới có bằng chứng định tính; (3) D-017 chứng minh **readability**, không chứng minh đổi kết quả — nếu Phase D vẫn mất vị trí player thì quay lại fade enemy (ba gap cấu trúc đã ghi ở Known Issues).
- **Nghĩa vụ treo mang sang Phase D:** retest B7.3 khi thêm cơ chế chống spam GDD 6.8.7 (D-012); MVS-AC1…8 vẫn PROPOSED; ngưỡng pass/fail cho MVS-AC2 chưa đặt.
- **Xác nhận của user:** chọn "Đóng Phase C theo D-016" (chat, 2026-11-21) sau khi xem bảng 4 run và phép tính TTK.

## D-019 · 2026-11-21 · Product · Accepted

- **Decision:** Thêm **đúng một cơ chế** theo GDD 6.8.7 (nợ D-012): **mệt nhịp độ (attack tempo)** cho player. Mỗi đòn liên tiếp vượt định mức cộng thêm tick vào **recovery**; không bấm (hoặc né) trả lại tốc độ. **Không** stagger, **không** ngắt đòn khi trúng, **không** đổi damage/HP/telegraph của enemy, **không** áp dụng cho enemy.
- **Reason:** User từ chối khung "bị khựng khi ăn đòn" và yêu cầu cái giá phải **mềm** (mất nhịp, không mất điều khiển). Số đo Phase C cho thấy cửa sổ phạt không bỏ trống (đính chính D-016), nên hướng xử lý đúng là đổi kinh tế nhịp của phía người chơi.
- **Số chốt (combat_tuning.tres):** `fatigue_free_swings = 3` · `fatigue_step_frames = 4` · `fatigue_max_frames = 12` · `fatigue_decay_frames = 6`. Chu kỳ đòn: gốc 17 tick → có mệt 21/25/29 tick (trần ở cấp 3). Né xoá toàn bộ mệt; đứng/đi 6 tick trừ một cấp.
- **Luật rút ra từ đo (phải giữ):** chu kỳ của người chơi nhịp = `17 + decay`, chu kỳ của người mash ở trần = `17 + cap`. ⇒ **chỉ khi `decay < cap` thì chơi nhịp mới thắng**; với decay = cap = 12, đo được mash 3,48 đòn/100 tick **cao hơn** paced 3,27 — cơ chế thành vô nghĩa. Đây là lý do decay là 6 chứ không phải 12.
- **Bằng chứng (`docs/phase-c/evidence/t027/tempo_report.md`, deterministic, không RNG):** P27.1 cả hai policy đều gây damage (360 vs 420); P27.2 mash trả mệt 12 frame, paced trả 0; P27.3 paced đánh dày hơn ≥5% (3,85 vs 3,48 đòn/100 tick); P27.4 paced gây nhiều damage hơn trước khi chết (420 vs 360); P27.5 **exposure không đổi** (cả hai ăn đúng 21 đòn) vì boss đánh theo đồng hồ riêng. Negative control (định mức thành 100000): P27.2/P27.3/P27.4 đỏ, exit 1.
- **Regression:** `test_combat_kernel` 107 checks (thêm 9 check timeline mệt), `test_tempo_fatigue` 15 checks, 14/14 unit test exit 0; `node tools/run_evidence.mjs` → `runs=7 negatives=7 ids=17 failures=0`; L1 các script đổi sửa exit 0, `--import` exit 0.
- **Rủi ro được chấp nhận:** (1) **B7.3 vẫn Fail** — mỗi run spam cần ~5 đòn hạ Grunt, chỉ đòn thứ 5 trả mệt (`action_start,5,0,4` = 4 tick), thắng/thua không đổi (`runs=10 wins=10 ticks=87`); B7 giữ **Failed**, nợ D-012 còn nguyên và đã báo trước khi làm; (2) cơ chế chỉ đổi DPS, **không** đổi an toàn (P27.5: hai policy ăn đúng 21 đòn như nhau vì boss đánh theo đồng hồ riêng); (3) người chơi chưa có tín hiệu nhìn thấy rằng đòn đang chậm lại → cần một tell riêng (việc sau, không làm tiện tay ở đây); (4) mọi số DPS đã đo ở Phase C (D-018) là của build **chưa có mệt**, Phase D muốn dùng baseline phải đo lại.
- **Xác nhận của user:** "mở T-27 đi" · "theo đòn liên tiếp đi" · "chỉ player" · "chọn A — chỉ recovery + cửa sổ combo, né xóa mệt" · "2" (hồi theo thời gian ở trạng thái NONE) · "C" (cap +12, trade-off thật) · "ok triển khai" (chat, 2026-11-21).

## D-017 · 2026-11-21 · Product · Accepted

- **Decision:** Sửa bằng chứng "body boss che mất player" (T-026) bằng **vòng định vị player** (`SelfMarker`), không bằng cách fade thân enemy. Ring 0,9 m đặt dưới chân, vẽ xuyên vật thể (`no_depth_test` + `render_priority` trên material), màu `tunic` green nên không nhầm với telegraph đỏ hay reticle vàng.
- **Reason:** Số đo trước khi chọn: punish window mở 97 và 155 tick nhưng chỉ đổi được 6 và 3 đòn trúng, và `session2/l4_death_1.png` mất hút player khi boss đứng sát. Fade enemy bị loại vì thân enemy **là** thông tin phải đọc (telegraph, tư thế đòn) và `OcclusionFader` gom `fadeable` một lần lúc load nên enemy spawn runtime vốn không nằm trong danh sách; thu nhỏ boss thì phá scale art đã chốt. Ring trả lời đúng câu hỏi còn lại ("tôi đứng đâu") mà không xoá thứ player phải nhìn.
- **Bằng chứng (L3, `docs/phase-c/evidence/t026/capture.log`):** boss đặt phía camera che kín sprite; tắt/mở ring cho **1280 px** khác nhau trong box 80 px quanh chân (ngưỡng 40); negative control cùng pose với ring depth-tested = **0 px** → thước đo phân biệt được đúng thứ nó đo. Bài học harness: `await physics_frame` không đảm bảo frame đã được vẽ — capture từng đọc ảnh đen hoàn toàn (0 px ở cả hai mode); phải `await RenderingServer.frame_post_draw` và kiểm "ảnh có pixel sáng" (P26.3) để control không thể xanh rỗng.
- **Rủi ro được chấp nhận:** (1) ring là công cụ định vị, **không** phải occlusion culling — khi boss đè lên, sprite vẫn bị khuất, chỉ có vị trí chân là còn đọc được; (2) ring vẽ xuyên nên có thể hiện cả khi player đứng sau pillar (đã cân nhắc: pillar tự fade qua `fadeable` nên trường hợp đó hiếm và không mất thông tin); (3) `show_self_marker` exported, tắt được nếu L4 Phase D thấy nhiễu.
- **Không đổi:** physics layers, ngưỡng C/E/D, engine, renderer, asset pipeline (texel 0,05 m — ring 18 texel).
- **Xác nhận của user:** chọn "Vòng định vị player (recommended)" (chat, 2026-11-21).

## D-020 · 2026-11-21 · Product · Accepted

- **Decision:** Màn hình title `scenes/ui/title_screen.tscn` là **entry point** của game — `run/main_scene` đổi từ `phase_a_playground.tscn` sang title. Menu gồm tiêu đề + 3 nút **Start / Option / Credit**; Start fade 0,25 s rồi `change_scene_to_file("res://scenes/phase_c/play_arena.tscn")`; **Option và Credit enabled nhưng không nối action** (placeholder có chủ đích, vẫn focusable để ↑↓ có nghĩa). Tên game là `@export var game_title` với placeholder **"HD-2D ADVENTURE"** — một chỗ duy nhất, đổi khi user chốt tên.
- **Reason:** Nền menu **không** thể instance `grove_arena.tscn`: `WaveEncounter` mồi wave ngay frame vật lý đầu tiên vì player spawn trùng `player_spawn` (distance 0 ≤ `trigger_radius` 2.0), nên quái sẽ đánh player ngay sau chữ. `title_backdrop.tscn` dựng lại geometry arena và tái dùng `PlaceholderTextures` + `CameraRig`; camera trôi qua `DriftPath` nên vẫn đi qua `PixelGrid.snap_position` — luật texel 4 px/texel (D-008) giữ nguyên, không crawl. Điều hướng dùng focus navigation có sẵn của Godot (`ui_accept` mặc định đã gồm Enter + Space, `ui_up/down` đã gồm mũi tên) ⇒ **không sửa InputMap**, không tự viết logic chọn dòng.
- **Bằng chứng:** L1 4 script `--check-only` exit 0, `--import` exit 0. L2 `tests/test_title_entry.gd` **14 checks exit 0** — test nạp menu đúng đường engine (`change_scene_to_file`) rồi push `InputEventKey` thật vào window, nên nó chứng minh luồng thật: ↑↓ đổi highlight, Option/Credit ở lại menu, Start đổi scene và menu được free; negative (`-- negative`) đỏ đúng P28.12 exit 1. **Mutation proof** (thước phải biết đỏ): đổi text Start + đặt `focus_mode = 0` trên Option + bỏ dòng gán title → P28.4/P28.6/P28.8 đỏ exit 1; bỏ riêng `_start.grab_focus()` → P28.7 đỏ (engine không tự focus giúp). L3 `scenes/ui/capture_title.tscn` (renderer thật, 1280×720, `--fixed-fps 60`): `checks=3 failures=0`, highlight dời xuống Credit đổi **2546 px** trong band menu, control cùng pose **0 px**, lit 230400/230400 (không ảnh đen rỗng); 3 ảnh đã xem thật ở `docs/phase-d/evidence/t028/`.
- **Vòng lặp bố cục đã sửa bằng ảnh, không đoán:** bản 1 để hero bị nút Start che và camera 51° chỉ thấy sàn ⇒ tách title (band 0–40%) khỏi menu (band 56–96%), hạ camera xuống offset (0, 7, 10); bản 2 lộ rìa thế giới đen dưới khung ⇒ sàn 26×24 và `uv1_scale (5.2, 6.0)` để mật độ ô trở lại đúng 0,625×0,5 m như arena (mật độ lưới lệch là lỗi đọc ảnh, không phải lỗi measure).
- **Rủi ro / chưa làm:** Option/Credit chưa có screen thật; `run.bat` không còn vào playground (phải truyền scene path tường minh); UI dùng font theme mặc định + outline, chưa phải pixel font (chờ Art Spec); chưa có audio menu, gamepad, ESC-to-quit; placeholder art (trụ xám) chưa phải art cuối.
- **Không đổi:** InputMap, physics layers, tuning combat, engine/renderer, **display/stretch settings** — ortho size vẫn suy từ viewport height nên mọi bằng chứng pixel Phase A/B/C còn hiệu lực.
- **Xác nhận của user:** "xây dựng màn hình lúc vào game đi gồm tiêu đề ... start option credit (option và credit để đấy chưa có tương tác gì)" + chọn "cảnh 3D arena + camera trôi chậm", "phím ↑↓ + Enter/Space + chuột", "enabled nhưng vô tác dụng", tên tạm "HD-2D ADVENTURE" (chat, 2026-11-21).

## D-021 · 2026-11-21 · Product · Accepted

- **Decision:** Mở **Phase D** bằng ba task UI/progression trước nội dung field/dungeon của MVS: **T-029** (`PlayerStats` + theme/khung UI + bảng trạng thái ESC), **T-031** (damage numbers), **T-030** (buff sau wave). MVS-AC1…8 vẫn **PROPOSED** — không kết quả nào của ba task này được tính là bằng chứng MVS.
- **Reason:** Throughput là nút thắt đã **đo** (D-018: pooled ≈4,8 dmg/s ⇒ TTK ≈63 s cho 300 HP, 0/8 run thắng), và buff damage là đòn bẩy trực tiếp lên đúng nút đó; làm lớp UI/stats trước để T-030 đo lại dmg/s trên cùng một chỗ đọc số (sheet + `PlayerStats`) thay vì dựng UI sau khi đã chỉnh balance.
- **Bằng chứng (đo thật trong T-029, branch `phase-d/t029-player-stats-sheet`):** `test_player_stats` 16 checks exit 0 (negative 6/16 exit 1); `test_combat_kernel` giữ **107 checks**; `node tools/check_stat_source.mjs` → `stat-source clean: 68 scripts` lúc chốt luật (`72` sau khi T-029 thêm 4 script UI), `--selftest` → `violations=1 allowed_hit=0`; `test_font_coverage` 3 checks / **79 glyphs** / cmap 567; `test_theme` 9 checks; `test_character_sheet` **8/8** exit 0 (negative 1/8 exit 1); L3 `capture_sheet` `checks=3 failures=0 band_diff=153600` + control **0 px**; `node tools/run_evidence.mjs` → `runs=7 negatives=7 ids=17 failures=0 seconds=109`; 19/19 suite `tests/test_*.gd` exit 0; L2 arena 120 frame exit 0, 0 `SCRIPT ERROR`.
- **Rủi ro được chấp nhận:** (1) mọi baseline DPS Phase C (D-018) mất hiệu lực khi buff đổi DPS — T-030 phải đo lại trước khi chỉnh độ khó; (2) UI không thay được L4 feel, chỉ làm số đọc được; (3) thứ tự T-031 trước T-030 vì modal buff dùng lại pool `Label` của damage numbers.
- **Không đổi:** nội dung MVS, physics layers, tuning combat, engine/renderer.
- **Xác nhận của user:** chọn "Mở Phase D, T-029..T-031" (chat, 2026-11-21).

## D-022 · 2026-11-21 · Technical · Accepted

- **Decision:** `PlayerStats` (`scripts/combat/player_stats.gd`, `RefCounted` thuần, headless-testable) là **nguồn runtime duy nhất** cho chỉ số nhân vật: base = `combat_tuning.tres` (chỉ đọc — không modifier nào ghi ngược vào `.tres`), composition `floor((base + Σ add) × Π mult)`, frame kẹp ≥1, float kẹp ≥0,1; `PlayerCombat` là **nơi ghi duy nhất** (`health.max_hp`, `player.speed`, cửa sổ `AttackState` khi swing bắt đầu) và push giá trị đã tính xuống node con; luật giữ bằng **máy** `tools/check_stat_source.mjs` (+ `--selftest`), không bằng review mắt.
- **Reason:** Nguồn sự thật thứ hai là lỗi lặp lại của repo này (HUD tự đọc tuning, `speed` nằm trên controller). Bảng trạng thái chỉ đọc `PlayerStats` nên nó không thể trưng một con số khác con số combat đang dùng — đó là điều kiện để người chơi tin bảng số.
- **Alternatives considered:** (B) tính chỉ số tại chỗ trong `player_combat.gd` — loại, sheet sẽ phải đọc lại tuning lần hai; (C) modifier ghi đè thẳng vào `.tres` — loại, phá tính immutable của tuning và làm mọi evidence cũ không tái lập; (D) sheet hiển thị số của riêng nó — loại, đúng cái bẫy "hai nguồn" mà D-022 sinh ra để chặn.
- **Bằng chứng:** `test_player_stats` 16 checks exit 0 (negative `-- negative` 6/16 đỏ, exit 1 — sai thứ tự add/mult, clamp, clear đều bị bắt); `check_stat_source.mjs` clean 68 script lúc chốt (72 hiện tại), `--selftest` chứng minh thước còn báo đỏ được; `test_combat_kernel` 107 + `test_tempo_fatigue` 15 + movement/model + `run_evidence` `failures=0` giữ nguyên sau khi đổi nguồn đọc; T-027 positive vẫn `mash fatigue_max 12 / paced 0`.
- **Rủi ro được chấp nhận:** (1) `_apply_stats` chưa kẹp HP khi `max_hp` **giảm** (chưa có buff giảm max — mang sang T-030); (2) cửa sổ `AttackState` chỉ refresh ở `_start_attack` nên buff giữa swing chỉ có hiệu lực từ đòn kế tiếp (đúng ý đồ, nhưng là hành vi phải nhớ); (3) `input_buffer_frames`/`hitstop_frames` nằm ngoài `STAT_KEYS` nên vẫn đọc tuning trực tiếp; (4) nhánh `stats.changed → _apply_stats` chưa có test riêng (mới chứng minh bằng đường chạy thật).
- **Không đổi:** số tuning (giá trị 4,0 m/s của `player_move_speed` chỉ chuyển nhà từ controller sang tuning), physics layers, engine.
- **Xác nhận của user:** chọn "A — PlayerStats thuần" (chat, 2026-11-21).

## D-023 · 2026-11-21 · Product · Accepted

- **Decision:** Buff sau wave dùng **pool data 6 món** (`heavy_edge`, `quick_rhythm`, `root_armor`, `slow_breath`, `long_reach`, `fourth_hook`; mỗi món 1 lợi + 1 đánh đổi) + `BuffKernel` **seed được** (`RefCounted` thuần: cùng seed ⇒ cùng 3 món, loại món đã chọn, mỗi món 1 lần/run); **2 lần chọn/run** và chỉ khi wave kết thúc **không phải wave cuối**; state `BUFF_PENDING` trong `WaveKernel` **chặn wave + dừng world** (`buff_pick_enabled` mặc định **false** để harness cũ không đổi); **reset khi R/thua** (`buff.reset()` + `stats.clear_modifiers()`); buff chỉ áp dụng khi world không có đòn nào đang chạy.
- **Reason:** "Số học + đánh đổi" là cách duy nhất vừa tăng throughput vừa giữ quyết định có nghĩa (món nào cũng mất một thứ); seed ghi vào combat log để mọi run tái lập được; chặn world khi chọn để buff không bao giờ đổi cửa sổ active của đòn đang bay (bất biến của D-019/D-022).
- **Bằng chứng:** bộ số buff là **HYPOTHESIS** như mọi con số trước đây — chưa task nào đo, vì T-030 chưa làm; hiện có (a) spec `UI_PROGRESSION_SPEC` §6.1 khóa 6 món + lợi/hại, (b) luật bắt buộc `fatigue_decay < fatigue_max` sau **mọi** tổ hợp (Nhịp Thở kéo decay 6→4 nên luật chặt hơn), (c) `fatigue_free_swings = 3`, `fatigue_decay_frames = 6`, `fatigue_max_frames = 12` đang chạy thật trong `combat_tuning.tres` (D-019, `test_tempo_fatigue` 15 checks exit 0). Gate DG2/DG3 (`test_buff_kernel`, `test_buff_laws`, negative `buffs-not-reset-on-r`) thuộc T-030 và **phải** chạy trước khi coi D-023 là đã kiểm.
- **Rủi ro được chấp nhận:** (1) chưa có số nào chứng minh 2 lần chọn/run là đủ để cảm nhận tiến bộ — L4 quyết; (2) damage buff sẽ làm cũ baseline 4,8 dmg/s (D-018) nên T-030 phải đo lại **kèm seed + danh sách buff**; (3) `BUFF_PENDING` là state mới chèn vào flow (đã giảm rủi ro bằng flag mặc định false); (4) sheet hiện in id snake_case của modifier cho tới khi T-030 thêm tên hiển thị.
- **Không đổi:** tuning hiện tại (chưa món nào được áp), physics layers, `WaveKernel` hành vi cũ khi flag false.
- **Xác nhận của user:** chọn "Số học + đánh đổi", "Reset khi R/thua", "Chặn + dừng world" (chat, 2026-11-21).

## D-024 · 2026-11-21 · Technical · Accepted

- **Decision:** Lớp UI Phase D: **theme dựng bằng code** (`Hd2dTheme.build()`, StyleBoxFlat thuần, không asset khung tải về), **font VT323** (Peter Hull, **SIL OFL 1.1**) tại `assets/ui/fonts/vt323.ttf` + toàn văn `OFL-VT323.txt`, ghi `assets/ASSET_LOG.md` (nguồn, ngày, license, sha256); antialiasing/hinting/subpixel **tắt**; **cỡ chữ bội số 16 px** (16 body / 32 title = lưới terminal 8×16 gốc, không resample); hình học panel **bội số 4** (sheet 480×320, card 160×220, gap 8/16); coverage glyph kiểm bằng máy + negative control; sheet ESC là `CanvasLayer` mount **cuối** trong `grove_arena.tscn` để vẽ trên `WaveHUD`.
- **Reason:** m5x7 (public domain) **bị gate loại thật**: cmap thiếu **17 glyph** (16 chữ cái + em dash) mà copy cần (`Ơ ơ Ư Ạ ạ Ầ Ậ Ắ Ế Ệ Ị Ổ Ộ Ớ Ở Ỳ` + em dash) — không phải thiếu toàn bộ dấu mà thiếu đúng block U+1EA0–U+1EF9 cộng `Ơ/Ư`; VT323 phủ **567** codepoint, đủ 100% copy hiện tại, và là bitmap-terminal 8×16 nên 16/32 px không bị mờ. Theme code-gen giữ kỷ luật texel (border 2 px, không scale ảnh), và một nguồn style duy nhất cho mọi panel T-030/T-031.
- **Bằng chứng:** `test_font_coverage` `3 checks, 79 glyphs, font cmap=567`, negative exit 1 (đỏ đúng inverted control, `missing: []`); `test_theme` 9 checks exit 0 (gồm `UI_FONT_SIZE % 16 == 0`, `TITLE_FONT_SIZE % 16 == 0`, `SHEET_SIZE`/`CARD_SIZE` chia hết 4, panel dùng `PANEL`, `COST != #d94a4a`); `test_character_sheet` **8/8** exit 0 (ESC qua `InputEventKey` thật, pause mở/đóng, HP `77/100`, damage `10  (0.59 dmg/tick)` → `13  (0.76 dmg/tick)`), negative 1/8 exit 1; **L3** `scenes/ui/capture_sheet.tscn` (renderer thật 1280×720, `--fixed-fps 60`): `checks=3 failures=0 band_diff=153600` (= đúng 480×320 px của panel) / ngưỡng 40, lit **230130 / 230134** px (không ảnh đen), control cùng pose **0 px** exit 0; 3 ảnh đã mở xem thật ở `docs/phase-d/evidence/t029/` (panel canh giữa, không cắt chữ, VT323 sắc cạnh khi zoom 2× nearest, palette đọc được).
- **Rủi ro được chấp nhận:** (1) `WaveHUD` **chưa** vào theme (ngoài scope T-029 — restyle cần L3 + quyết riêng); (2) sheet tự set `get_tree().paused` không có pause-stack ⇒ overlay thứ hai (T-030/T-031) phải xử lý trước khi cùng pause; (3) `.import` của font để `allow_system_fallback=true` (file generated, không sửa tay) nên về lý thuyết glyph lạ có thể fallback hệ thống — gate đọc cmap trực tiếp nên không bị che; (4) `InputEventKey`/ESC đi qua InputMap `toggle_character_sheet` (không đọc phím cứng).
- **Không đổi:** luật texel D-008 (font là UI screen-space, không phải world), physics layers, tuning, engine/renderer.
- **Xác nhận của user:** chọn "Code-gen + Godot Theme" và "m5x7" (chat, 2026-11-21); sau khi gate báo thiếu 17 glyph, user chọn **đổi sang font pixel khác có đủ dấu** ⇒ VT323 (OFL 1.1) thay m5x7, ghi lại ở ASSET_LOG (chat, 2026-11-21).
