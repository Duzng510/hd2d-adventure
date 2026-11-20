# GAME DESIGN DOCUMENT 0.7.1
## Fantasy Semi-Open World Real-Time Action RPG — HD-2D

> **Trạng thái:** GDD 0.7.1 (baseline cho prototyping) · **Dựa trên:** GDD 0.7 · **Cập nhật:** 20/11/2026
> **Mục đích:** Định nghĩa trải nghiệm sản phẩm, nguyên tắc thiết kế và tiêu chí kiểm chứng. Quy tắc kỹ thuật nằm ở `AGENTS.md`, quy tắc làm việc nằm ở Master Prompt.

## Cách đọc tài liệu

| Nhãn | Ý nghĩa |
|---|---|
| **CONFIRMED** | Người dùng đã xác nhận; không tự ý thay đổi |
| **BASELINE** | Hướng hiện tại để làm prototype; có thể đánh giá lại khi có bằng chứng |
| **OPEN** | Chưa quyết; không suy diễn thành yêu cầu cố định |
| **DEFERRED** | Có định hướng, ngoài phạm vi hiện tại |
| **PROPOSED** | Đề xuất của AI, chờ người dùng duyệt hoặc sửa |
| **HYPOTHESIS** | Con số/giả thuyết khởi điểm để đo và có thể bị bác bỏ, không phải giá trị cuối |

Mục đánh dấu **[CẦN BẠN ĐIỀN]** là thông tin chỉ người dùng mới có. Khi còn trống, coi như OPEN. Những mục người dùng đã trả lời được thay bằng giá trị đã xác nhận; các ý AI đề xuất vẫn mang nhãn PROPOSED.

---

# 0. RÀNG BUỘC SẢN XUẤT

| Hạng mục | Giá trị |
|---|---|
| Quy mô đội | **CONFIRMED:** Solo developer (chỉ người dùng) |
| Thời gian khả dụng | **CONFIRMED:** Không cố định; không quy đổi thành lịch làm cứng |
| Mốc đánh giá tiến độ | **CONFIRMED (TARGET):** Một tuần, dùng để review tiến độ **MVS** (xem Scope Anchor bên dưới); không phải deadline cứng |
| Nguồn art | **CONFIRMED:** AI-generated art, sau đó chỉnh sửa và tích hợp |
| Thời lượng Target Slice (Stretch) | **CONFIRMED (TARGET):** 15–30 phút gameplay |
| Thời lượng MVS | **BASELINE (HYPOTHESIS):** 5–10 phút, để kiểm tra quy mô |

Mọi phạm vi ở các phần sau phải được co lại cho khớp với bảng này, không phải ngược lại.

### Vertical Slice Scope Anchor (BASELINE)

Tách mục tiêu thời lượng khỏi scope bắt buộc để mốc một tuần có điểm neo thực tế. Scope này dùng cho planning, không tự động thay thế Phase Gate.

- **Minimum Vertical Slice (MVS, làm trước):** 1 nhân vật; movement/camera đủ dùng; một field nhỏ thuộc **Verdant Frontier**; ít nhất một dấu hiệu khám phá bằng quan sát dẫn tới điểm quan tâm; một đoạn dungeon ngắn (2–3 phòng hoặc tương đương); một encounter cơ bản với combat real-time; một phần thưởng có ý nghĩa; một vòng chơi ngắn từ field đến dungeon và reward. Chưa yêu cầu boss, save system, roster, questline hoàn chỉnh, crafting, UI/inventory production.
- **Stretch / Target Slice:** mở rộng MVS tới 15–30 phút: settlement/preparation, dungeon hoàn chỉnh hơn, boss, reward/progression, checkpoint/save tối thiểu nếu scope cho phép.
- **Mốc một tuần:** review tiến độ **MVS** (không bắt buộc đạt Stretch). Sau mốc, xem evidence, phần còn thiếu và estimate mới. Không quy đổi thành số giờ vì lịch làm không cố định; nếu không đạt, ghi phần hoàn thành, phần thiếu, nguyên nhân và đề xuất điều chỉnh.
- **Effort anchor:** không đặt ngân sách giờ cứng. AI ước lượng task theo khoảng (nhỏ/vừa/lớn, hoặc giờ dự kiến kèm độ tin cậy) sau khi inspect project, và cập nhật khi có evidence.

**Acceptance Criteria của MVS (PROPOSED — chờ bạn duyệt/sửa):**

| # | Tiêu chí quan sát được | Bằng chứng |
|---|---|---|
| MVS-AC1 | Người chơi đi từ điểm xuất phát qua field, vào dungeon và nhận reward mà không gặp lỗi chặn trong 3 lần chơi liên tiếp | Runtime + playtest |
| MVS-AC2 | Có ít nhất 1 dấu hiệu khám phá trong môi trường (không dùng marker UI) dẫn tới một điểm quan tâm (lối ẩn, vật phẩm hoặc shortcut); đánh giá khả năng người chơi tự nhận ra và tìm tới điểm đó theo quy trình playtest đã được duyệt | Runtime + playtest |
| MVS-AC3 | Encounter cơ bản chơi lại được (thắng/thua đều kết thúc hoặc khởi động lại đúng); mỗi swing chỉ trúng mỗi mục tiêu một lần | Runtime + automated |
| MVS-AC4 | Rubric combat: Readability và Responsiveness trung bình ≥ 3/5; ≥ 80% lần bị trúng người chơi hiểu lý do; báo cáo kèm số lần thực tế (x/y) và số người tham gia (n) | Playtest (mục 14) |
| MVS-AC5 | Dungeon 2–3 phòng có lối ra/shortcut hợp lệ, không soft-lock | Runtime |
| MVS-AC6 | Reward có tác dụng quan sát được (mở lối, đổi cách chơi hoặc hiệu ứng rõ), không chỉ tăng con số | Runtime + playtest |
| MVS-AC7 | Build chạy từ scene khởi đầu bằng các bước ghi trong `STATE.md`; không có lỗi nghiêm trọng ở output trong một lần chơi hoàn chỉnh; FPS ghi nhận để chẩn đoán | Runtime |
| MVS-AC8 | Known Issues và phần chưa đạt được liệt kê rõ | Tài liệu |

**Ghi chú vận hành MVS-AC2 — ngưỡng đánh giá cần duyệt:**
- Điều kiện tồn tại của nội dung: có ít nhất một dấu hiệu môi trường thực sự dẫn tới một điểm quan tâm; có thể kiểm tra bằng scene/runtime.
- Đối với playtest, trước khi thử cần ghi rõ khu vực/bối cảnh bắt đầu, thời điểm bắt đầu tính thời gian, điều gì được tính là “tìm ra”, và người chơi có nhận gợi ý hoặc can thiệp hay không. Trong mỗi lần thử, ghi số người tham gia, số người tự tìm ra (`x/n`), thời gian của từng lần và vị trí người chơi dừng lại nếu không tìm ra.
- Lần playtest đầu dùng để tạo baseline và phát hiện vấn đề, **không tự đặt ngưỡng thời gian hoặc tỷ lệ đạt**. Cho tới khi quy trình và ngưỡng pass/fail được người dùng duyệt, chỉ báo cáo dữ liệu quan sát được; không tự kết luận MVS-AC2 là Passed/Failed dựa trên một lần thử hoặc một người chơi.

**Ghi chú báo cáo MVS-AC4:** luôn ghi điểm thực tế theo từng người hoặc cách tổng hợp rõ ràng, `x/y` lần bị trúng mà người chơi hiểu lý do, và `n` người tham gia. Không chỉ nêu phần trăm. Nếu mẫu nhỏ, ghi rõ đây là tín hiệu ban đầu, chưa phải kết luận thống kê; không che giấu mẫu số hoặc gộp các lần thử không tương đương.

**Solo-dev reality:** thời gian làm không cố định; mốc một tuần chỉ là điểm quan sát tiến độ. Quy tắc waiver Phase Gate chỉ theo Master Prompt, mục 8.6.

---

# 1. PRODUCT VISION

## 1.1. Ý tưởng cốt lõi

Một fantasy action RPG có cấu trúc semi-open world và nhìn HD-2D (sprite pixel-art trong diorama 3D). Người chơi chọn một nhân vật có sẵn hoặc nhân vật vô danh do mình định hình, rồi đi qua các vùng đất có bản sắc riêng, khám phá di tích, tìm bí mật và chinh phục hầm ngục có quái vật, cạm bẫy, câu đố và kho báu.

Combat là **real-time action RPG — CONFIRMED**. Trải nghiệm nhấn mạnh khả năng điều khiển nhân vật, đọc tình huống, chọn thời điểm tấn công, né tránh và phản công. Dungeon là nội dung trọng tâm: mỗi nơi cần bản sắc kiến trúc, chủ đề và thử thách riêng, không chỉ là chuỗi phòng đánh nhau với texture khác.

## 1.2. Điểm khác biệt (PROPOSED)

Cần một câu trả lời cho "game này khác gì?". Đề xuất để bạn duyệt hoặc thay:

> **Tấm bản đồ do chính người chơi vẽ.** Bản đồ chỉ hiện những gì người chơi đã tự quan sát và tìm thấy; không có marker nhiệm vụ dẫn đường. Dấu hiệu nằm trong môi trường (ánh sáng, kiến trúc, NPC, vật thể lạ). Kết hợp với combat dễ đọc, thế giới thưởng cho người quan sát kỹ.

**PROPOSED — chưa được người dùng xác nhận.**

## 1.3. Bản sắc thế giới

| Hạng mục | Nội dung |
|---|---|
| Tên thế giới / tên game | **[CẦN BẠN ĐIỀN]** |
| Tên game / thế giới | **OPEN:** Chưa có tên |
| Player characters | **CONFIRMED (CONCEPT):** Chọn nhân vật có sẵn hoặc nhân vật vô danh do người chơi định hình. **DEFERRED:** roster, số lượng, selection, lore/relationship. **OPEN:** các nhân vật có moveset/combat riêng hay khác nhau chủ yếu về identity/story? Vertical Slice dùng đúng một nhân vật |
| Tone | **PROPOSED:** tò mò, ấm áp, pha chút u hoài cổ tích; nguy hiểm đủ để có căng thẳng nhưng không bi thảm |
| Xung đột trung tâm | **OPEN:** sẽ được xây dựng dần qua lore; chưa cần chốt overarching conflict |
| Ba Region đầu | **PROPOSED:** 1) **Verdant Frontier** — Region của Vertical Slice; rừng biên giới, settlement nhỏ và tàn tích. Cơ chế khám phá đề xuất: đối chiếu dấu vết (dấu giẫm, cành gãy, ánh sáng lọt qua tán cây) để nhận ra đường vòng/lối vào bị che. 2) **Ember Highlands** — vùng núi/mỏ; cơ chế khám phá đề xuất: đọc luồng gió, tiếng vọng hoặc dấu vận hành máy móc để tìm đường an toàn/shortcut. 3) **Mire of Echoes** — đầm lầy/di tích chìm; cơ chế khám phá đề xuất: quan sát phản chiếu, mực nước hoặc dấu môi trường để xác định lối đi. Tên, biome, cơ chế và bản sắc vẫn PROPOSED; chưa duyệt canon. |

## 1.4. Trải nghiệm hướng tới

Người chơi nên: tò mò khi thấy dấu hiệu chưa giải thích; cảm nhận thế giới có chiều sâu qua môi trường và NPC; thấy việc thành thạo vũ khí và đọc hành vi enemy tạo khác biệt; có động lực khám phá dungeon vì phần thưởng và bí mật; thấy nhân vật tiến bộ qua kỹ năng, trang bị và khả năng tới vùng mới.

## 1.5. Tham khảo (mỗi cái dùng cho đúng một mục đích)

| Tham khảo | Dùng cho | Không dùng cho |
|---|---|---|
| Octopath Traveler II | Nhìn HD-2D, ánh sáng, DoF | Combat (turn-based), camera |
| CrossCode | Đọc combat, tương tác combat–dungeon | Nhìn (2D thuần) |
| Link's Awakening (remake) | Diorama + real-time action | Scope và thể loại |
| Trials of Mana (remake) | Action RPG 3D nhịp độ vừa | Art direction |

Chưa có tham khảo nào kết hợp đủ HD-2D + real-time action; phần ghép này là rủi ro chính (xem mục 13).

---

# 2. DESIGN PILLARS (CÓ THỨ TỰ ƯU TIÊN)

Khi hai pillar xung đột, pillar đứng trước thắng.

1. **Combat dễ đọc, điều khiển đáng tin cậy.** Phản hồi rõ, người chơi hiểu vì sao trúng đòn hoặc bỏ lỡ cơ hội. *Khi xung đột: chọn dễ đọc thay vì đẹp hay hoành tráng.* Ví dụ: hiệu ứng hạt không được che telegraph.
2. **Khám phá bằng quan sát.** Thế giới thưởng cho người nhìn kỹ, không dẫn đường bằng marker. *Khi xung đột: chọn dấu hiệu trong môi trường thay vì chỉ dẫn UI.*
3. **Phần thưởng tạo lựa chọn.** Phần thưởng mở ra cách chơi hoặc lối đi mới, không chỉ tăng con số. *Khi xung đột: ít món nhưng khác biệt, hơn nhiều món chỉ khác chỉ số.*
4. **Diorama HD-2D có bản sắc.** Nhìn là nét nhận diện của game. *Khi xung đột với pillar 1: pillar 1 thắng.*

## Không làm (trong phạm vi hiện tại)

Multiplayer · thế giới procedural · seamless open world không loading · turn-based · voice acting · thương mại hóa/monetization · mobile · gamepad (cho tới khi KB+M được kiểm chứng) · crafting sâu trước Vertical Slice.

---

# 3. QUYẾT ĐỊNH HIỆN TẠI

| Hạng mục | Trạng thái | Nội dung |
|---|---|---|
| Fantasy setting, nhà thám hiểm, dungeon trọng tâm | BASELINE | |
| World structure | BASELINE | Semi-open, chia Region có kết nối |
| Engine | CONFIRMED | Godot 4.4+ |
| Ngôn ngữ | CONFIRMED | GDScript |
| **Combat** | **CONFIRMED** | Real-time Action RPG (20/11/2026). Phương án turn-based bị loại. Lý do confirmed: người dùng muốn trực tiếp điều khiển nhân vật, cảm nhận phản hồi khi tấn công/né, chủ động xử lý enemy; real-time action phù hợp hơn với hình dung về game phiêu lưu hành động. |
| **Input chính** | **CONFIRMED** | Bàn phím + chuột. Gamepad DEFERRED |
| Platform | BASELINE | PC desktop. Phát hành thực tế: OPEN |
| Art direction | BASELINE | HD-2D |
| Renderer | BASELINE | Forward+ |
| Không gian gameplay | **OPEN (P0)** | Giả thuyết: logic trên mặt phẳng XZ, sprite hiển thị trong 3D (xem 5.1) |
| Camera, movement, targeting, elevation | OPEN | Xem mục 5 |

---

# 4. CORE GAMEPLAY LOOP

**Loop chính:** về settlement → chuẩn bị (vũ khí, trang bị, vật phẩm) → chọn khu vực → khám phá field → dungeon/di tích/bí mật → encounter, puzzle, elite, boss → nhận thưởng và thông tin → nâng cấp/đổi cách chơi → mở khóa nội dung mới.

**Loop phụ:**
- *Khám phá:* quan sát → nhận dấu hiệu → tiếp cận → khám phá → thưởng/thông tin.
- *Combat:* quan sát → vào đòn → phản ứng → tạo cơ hội → kết thúc encounter.
- *Dungeon:* đọc bố cục → học cơ chế → vượt thử thách → mở lối tắt/checkpoint → thử thách chính → reward.

Loop định hướng, không bắt buộc mỗi phiên đi đủ các bước.

---

# 5. CAMERA, MOVEMENT & KHÔNG GIAN

> **OPEN/BASELINE.** Nhóm quyết định ảnh hưởng mạnh tới movement, combat, level design, rendering và collision. Chốt bằng prototype Phase A, không bằng tranh luận.

## 5.1. Quyết định kiến trúc không gian (P0)

Câu hỏi nền: gameplay chạy trên **mặt phẳng 2D (XZ) với sprite hiển thị trong 3D**, hay là **3D thật** (có độ cao, nhảy, vật lý 3D đầy đủ)? Câu trả lời quyết định kiểu physics, hitbox, level design, độ cao và độ đọc combat.

**Giả thuyết khởi điểm (BASELINE):** mặt phẳng XZ, Y cố định ở prototype, `CharacterBody3D`, hitbox dạng đơn giản. Độ cao/địa hình chỉ đưa vào khi người chơi đọc được tác động của nó.

## 5.2. Các thuộc tính cần kiểm chứng

| Thuộc tính | Trạng thái | Cần làm |
|---|---|---|
| Projection | OPEN | So sánh orthographic và perspective (FOV thấp) |
| Camera behavior | OPEN | Cố định theo khu vực / follow / kết hợp |
| Camera rotation | OPEN | Có xoay hay không |
| Movement | OPEN | 4 hay 8 hướng; hướng input theo camera hay world axes |
| Elevation | OPEN | Ảnh hưởng movement và combat thế nào |
| Occlusion | OPEN | Một quy tắc nhất quán khi vật che sprite |
| World scale | OPEN | Tỷ lệ player/cửa/tường/enemy/vật thể |
| Combat readability | **CONFIRMED** | Player, enemy, hit area, telegraph phải dễ đọc |

## 5.3. Chuột & ngắm

Với bàn phím + chuột, ngắm tự do là khả thi và tự nhiên. **Targeting vẫn OPEN**: free aim, directional (theo hướng di chuyển), target lock hay hybrid. Prototype nên thử tối thiểu free-direction bằng chuột và so với hướng theo di chuyển. Điểm ngắm trong thế giới lấy bằng tia từ camera cắt mặt phẳng ngắm; chất lượng phép chiếu này phải được kiểm tra trên camera nghiêng thật.

## 5.4. Nguyên tắc không gian

- Collision shape và visual sprite tách riêng nhưng căn chỉnh nhất quán.
- Foot pivot ổn định khi di chuyển và đổi animation.
- Vật che nhân vật phải theo một quy tắc nhất quán.
- Kích thước phòng, cửa, hành lang kiểm tra với nhân vật thật trong game.

## 5.5. Movement & traversal

Mục tiêu: dễ kiểm soát, phản hồi ổn định, khớp với animation, không cảm giác trượt. Chưa chốt: tốc độ, tăng/giảm tốc, sprint, leo/nhảy/rơi, bậc thềm. Chỉ thêm traversal khi level design cần.

**Default binding đề xuất (BASELINE, qua InputMap):** WASD di chuyển · chuột trái Light Attack · chuột phải Heavy Attack (khi có) · Space Dodge · E Interact · Q/1–4 Skill/Item (khi có). Đây là binding tạm để prototype, chưa phải Combat Spec chính thức. Chỉ tạo `docs/combat/COMBAT_SPEC.md` khi có nhu cầu thực tế cần gom binding, timing, state, hitbox hoặc quy tắc combat; tài liệu này phải subordinate GDD và không được tự nâng BASELINE/OPEN thành CONFIRMED.

---

# 6. COMBAT

> Real-time Action RPG — CONFIRMED. Prototype kiểm chứng và cải thiện implementation (input, movement, hit detection, animation timing, enemy behavior, readability, feedback). Không dùng để so với turn-based.

## 6.1. Triết lý

Nhanh, phản hồi tốt, dễ đọc, có chiều sâu khi thành thạo. Không biến thành spam một nút. Người chơi phải có lựa chọn thật sự giữa tấn công, né, giữ khoảng cách, dùng kỹ năng và chờ phản công. Vòng lặp: Observe → Engage → Attack/Combo → Evade/Defend → Punish → Finish.

## 6.2. Hành động dự kiến

Light Attack · Heavy Attack · Dodge · Skill · Special Attack · Interact. Prototype chỉ cần Light Attack (+ combo ngắn) và Dodge.

## 6.3. Readability (phải nhận biết được)

Vị trí/hướng của player và enemy; trạng thái cơ bản của enemy; đòn sắp tới và vùng nguy hiểm; khi nào có thể bị trúng; khi nào có cơ hội phản công; kết quả của đòn đánh. Hiệu ứng hình ảnh không được che các thông tin này.

## 6.4. Giả thuyết khởi điểm (HYPOTHESIS, để đo và điều chỉnh)

Đơn vị là physics frame ở 60 tick/s. Không phải giá trị cuối; mục đích là để prototype có thứ để đo. Mỗi con số là HYPOTHESIS và phải ghi điều kiện test, phương pháp, số mẫu, kết quả và giới hạn đo. Combat log chỉ đo được khoảng cách giữa sự kiện input được game nhận và sự kiện logic bắt đầu; không đại diện độ trễ vật lý từ thiết bị đến màn hình. Nếu muốn kết luận input-to-display latency, cần công cụ đo ngoài (ví dụ quay video tốc độ cao) và nêu rõ sai số.

| Thông số | Giả thuyết |
|---|---|
| Phản hồi input → frame đầu của hành động | ≤ 2 frame (~33 ms), đo bằng combat log |
| Input buffer | 5–8 frame (~80–130 ms) |
| Light Attack: startup / active / recovery | 3–6 / 2–4 / 8–14 frame |
| Cửa sổ nối combo | 8–14 frame |
| Dodge: i-frame / tổng thời gian | 8–14 / 18–28 frame |
| Telegraph enemy cơ bản | ≥ 18 frame (~300 ms) với tín hiệu hình ảnh rõ |
| Hit-stop | 2–5 frame |
| Hiệu năng | 60 FPS ổn định trên máy dev |
| **Quy tắc cứng (không phải giả thuyết)** | Mỗi swing trúng mỗi mục tiêu tối đa một lần |

**Task đo ngoài tùy chọn:** dùng điện thoại quay 240 fps nếu hỗ trợ, đặt sao cho thấy thao tác nhấn phím/chuột và màn hình cùng khung hình; xem clip để xác định thời điểm nhấn và frame phản hồi đầu tiên. Thử khoảng 20 lần, ghi median/max và sai số (mỗi frame video ≈ 4,17 ms); đây chỉ là ước lượng input-to-display, không phải gate và không thay playtest rubric.

## 6.5. Weapon system

| Weapon | Vai trò dự kiến |
|---|---|
| Sword | Linh hoạt, cân bằng tốc độ/sát thương |
| Greatsword | Chậm, sát thương cao, phá thế thủ |
| Dual Blades | Nhanh, combo liên tục |
| Spear | Tầm xa, kiểm soát khoảng cách |
| Bow | Tầm xa, áp lực từ khoảng cách an toàn |

Prototype: **một** vũ khí (Sword). Phần còn lại là production backlog. Mỗi vũ khí khi triển khai phải có bản sắc qua moveset, tầm đánh, nhịp độ, rủi ro và kỹ năng, không chỉ chỉ số.

## 6.6. Enemy roles

Grunt (học combat) · Swarm (áp lực số lượng) · Bruiser (ép quản lý khoảng cách) · Agile (tiếp cận nhanh) · Ranged (áp lực từ xa) · Support (hỗ trợ/đổi hành vi enemy khác) · Elite · Boss. Mỗi enemy tạo một vấn đề chiến đấu rõ ràng. Prototype: **một Grunt** với ít nhất một đòn có telegraph.

## 6.7. Boss

Silhouette dễ nhận; bộ đòn đặc trưng; telegraph đủ rõ để học; cơ hội phản công có chủ đích; cơ chế riêng hợp chủ đề; thay đổi hành vi ở giai đoạn sau nếu cần. Không tăng độ khó chỉ bằng máu/sát thương.

## 6.8. Tiêu chí đạt của Combat Prototype (đo được)

Prototype giới hạn ở: một nhân vật, một vũ khí, một enemy cơ bản, Light Attack + combo ngắn, Dodge, health/damage, một đòn enemy có telegraph, một encounter chơi lại được. Đạt khi **tất cả**:

1. **Responsiveness:** điểm trung bình ≥ 3/5 trong human playtest theo rubric mục 14. Engine-side latency chỉ là diagnostic metric; phép đo ngoài input-to-display là task tùy chọn tại mục 6.4, không phải gate.
2. Test tự động: 0 lần gây sát thương lặp trong 100 swing liên tiếp lên cùng mục tiêu.
3. Enemy phát hiện → tiếp cận → tấn công theo phạm vi đã thiết kế.
4. Telegraph ≥ ngưỡng ở 6.4 và người chơi phản ứng kịp: trong playtest, **≥ 80% lần bị trúng người chơi tự nhận hiểu vì sao**.
5. Chơi encounter 10 lần liên tiếp không có lỗi chặn hoàn thành.
6. Playtest rubric (mục 14): điểm Readability trung bình **≥ 3/5**.
7. Người chơi có ít nhất hai cách tiếp cận hợp lệ khác nhau (ví dụ né-rồi-phản-công và áp sát), không chỉ giữ nút tấn công. Nếu không đạt, bổ sung đúng một cơ chế (ví dụ combo ngắt được, hoặc đòn mạnh), không mở rộng cả hệ thống.

Con số cụ thể được đo và tinh chỉnh qua playtest; không khóa vào GDD khi chưa có bằng chứng. Khi báo kết quả, không chỉ ghi “đạt/không đạt”: nêu scene/build, cấu hình máy, cách đo, số lần thử, dữ liệu thô hoặc tóm tắt, và giới hạn của phép đo. Nếu sample nhỏ hoặc đánh giá chủ quan, ghi rõ là tín hiệu ban đầu, không phải kết luận thống kê.

---

# 7. WORLD & DUNGEON

## 7.1. Semi-open world

Không phải bản đồ khổng lồ liền mạch. Region phải khác nhau không chỉ bởi biome mà bởi dấu hiệu quan sát, cơ chế khám phá và cách dungeon/shortcut thưởng cho người chơi để ý môi trường (Pillar 2). Ba Region mục 1.3 là đề xuất định hướng; **Verdant Frontier** là vùng dùng cho Vertical Slice. Không cần thiết kế đầy đủ Region 2–3 trong prototype. Nhiều Region nối qua đường bộ, cầu, cổng, hang động, lối đặc biệt. Cấu trúc: Main Settlement; mỗi Region gồm Field Exploration, Minor Dungeon, Major Dungeon, Hidden Locations; mở khóa dần qua khám phá, nhiệm vụ, điều kiện đặc biệt. Số Region thực tế: theo mục 0.

## 7.2. Settlement

Nơi an toàn để nghỉ và chuẩn bị. Dịch vụ có thể có: Blacksmith, Merchant, Inn, Quest Board, Training Area, NPC. Không cần đủ mọi dịch vụ ở mọi nơi; quy mô theo vai trò của địa điểm.

## 7.3. Field Exploration

Enemy xuất hiện tự nhiên, điểm thu thập, hang động nhỏ và di tích, chest và hidden path, NPC/sự kiện, elite, địa điểm không đánh dấu. Mỗi vùng cần vài phát hiện đặc trưng, ưu tiên mật độ hơn diện tích.

## 7.4. Dungeon

- **Linear:** tiến trình rõ, encounter sắp đặt, cơ chế môi trường riêng, ít quay lại.
- **Exploration:** nhiều nhánh, lối bí mật, shortcut mở từ phía bên kia, khu vực cần năng lực mới, khuyến khích quay lại.
- **Khung Major Dungeon (tham khảo):** Entrance → First Encounter → Exploration → Challenge → Shortcut/Checkpoint → Final Area → Boss → Reward.

**Tiêu chí chất lượng:** chủ đề và bản sắc là gì; cơ chế chỉ nơi này có; người chơi học được gì; có bí mật đáng tìm không; nhịp độ khám phá–chiến đấu–nghỉ hợp lý không; phần thưởng tương xứng công sức không.

---

# 8. PROGRESSION

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| EXP/Level (nguồn: enemy, quest, dungeon, boss) | OPEN | Công thức chờ prototype progression |
| Skill: Offense / Mobility / Utility | DEFERRED | Skill tree chi tiết sau khi combat cơ bản ổn định |
| Equipment: Weapon, Armor, Helmet, Accessory | DEFERRED | Tránh món chỉ khác con số; trang bị quan trọng có nguồn rõ (boss, quest, kho báu ẩn) |
| Crafting & Upgrade | DEFERRED | Sau Vertical Slice |

---

# 9. QUEST & NARRATIVE

Ba nhóm: **Main Quest** (dẫn qua các khu vực, mở nội dung), **Side Quest** (câu chuyện nhỏ về cư dân/thương nhân/nhà thám hiểm), **Exploration Quest** (tìm di tích, săn sinh vật hiếm, dungeon bí mật). Một số quest có kết quả khác nhau theo lựa chọn/phát hiện. Không bắt buộc mọi quest gắn main story. Nội dung cụ thể chờ mục 1.3.

---

# 10. ART DIRECTION — HD-2D

Pixel-art character kết hợp môi trường 3D dạng diorama: ánh sáng, bóng, hạt, magic, fog có kiểm soát. Không sao chép sprite/asset/nhân vật có bản quyền. Trong combat, ưu tiên đọc chuyển động và nguy hiểm hơn hiệu ứng phức tạp.

## 10.1. Art Spec chuẩn chỉ có sau khi kiểm chứng trong engine

Phải đo và ghi lại: sprite canvas/visible bounds; chiều cao nhân vật theo world unit; pixel density và filtering; frame size/số frame/FPS; foot pivot; hướng nhìn và quy tắc đổi hướng; collision footprint; shadow; tương tác với lighting; render resolution/viewport scale/độ ổn định pixel.

## 10.2. Quy trình xác nhận

Scene thử nhỏ → một character prototype → kiểm tra scale/pivot/pixel/animation/shadow → thử nhiều vị trí và ánh sáng → xác nhận camera và độ đọc → ghi thông số → chỉ sau đó sản xuất character/enemy/NPC/tileset.

---

# 11. UI, AUDIO, SAVE, ACCESSIBILITY

Đưa vào roadmap khi gameplay loop hình thành. Cần nghiên cứu: HUD và combat feedback; con trỏ/reticle (cho ngắm bằng chuột); inventory/equipment; map theo pillar 2; audio cho attack/hit/dodge/telegraph; save/checkpoint; **remap phím**; độ đọc chữ, subtitle, tùy chọn accessibility. Không dựng UI hoàn chỉnh trước khi biết dữ liệu gameplay cần hiển thị.

---

# 12. CÁC PHASE & TIÊU CHÍ THOÁT

Mỗi phase tạo ra kết quả quan sát được; chỉ sang phase sau khi đạt tiêu chí tối thiểu đủ để giảm rủi ro của phase kế tiếp. Nếu cần tiến tiếp khi tiêu chí chưa đạt, áp dụng duy nhất waiver rule trong Master Prompt, mục 8.6. Lỗi nhỏ không ảnh hưởng pillar hoặc khả năng đánh giá ghi vào Known Issues/backlog; không cần polish hoàn hảo. Chỉ giữ gate khi lỗi ảnh hưởng pillar, làm mất khả năng đánh giá, gây blocker hoặc tạo rủi ro lớn cho chi phí về sau.

### Phase A — Visual & Camera Prototype
**Phạm vi:** scene 3D nhỏ, sprite placeholder, camera, movement, mouse aim; thử ánh sáng/occlusion ở mức đủ đọc.
**Gate tối thiểu.** Định nghĩa vận hành của từng mục (checklist quan sát nhị phân và cách chụp bằng chứng) được ghi **trước** khi đánh giá và được bạn xác nhận; đó là deliverable đầu tiên của Phase A. Không đặt tolerance số tùy ý trước khi scene và camera thực tế tồn tại; sau prototype có thể đề xuất tolerance và chỉ dùng làm gate khi bạn duyệt.

1. **Movement & camera:** 4 tình huống thử (đi thẳng, rẽ, chạy sát vật cản, đổi hướng nhanh), mỗi tình huống ghi pass/fail; không có hành vi sai điều khiển (trượt, lệch hướng, camera giật làm mất kiểm soát).
2. **Mouse aim:** marker khớp con trỏ tại 5 vị trí (trung tâm và bốn vùng gần rìa), có ảnh chụp.
3. **Occlusion:** 3 tình huống (vật che gần, tường, mái hoặc tán cây); player và thông tin combat vẫn nhìn thấy, có ảnh chụp.
4. **Art Spec tạm:** scale, frame size, foot pivot, hướng nhìn của sprite prototype được ghi và bạn xác nhận **trước khi sinh asset AI hàng loạt**.
5. **Ghi vào `DECISIONS.md`:** kiến trúc không gian (XZ hoặc 3D), projection, camera, cách ngắm bằng chuột, lỗi visual còn lại.

Pixel shimmer, pivot polish và FPS được đo và ghi Known Issues nếu không ảnh hưởng khả năng đánh giá; không biến Phase A thành polish gate.

**Thứ tự xử lý rủi ro Phase A (sequence triển khai, không phải ép chốt trước prototype):** (1) chọn/kiểm tra kiến trúc không gian XZ hay 3D; (2) camera projection và behavior; (3) sprite scale, visible bounds và pivot trong camera thật; (4) movement/input orientation; (5) mouse aim, marker và collision; (6) readability, occlusion và khả năng combat. Các lựa chọn P0 phụ thuộc nhau; có thể thử nhanh và điều chỉnh theo evidence, không xem lựa chọn thử đầu tiên là quyết định vĩnh viễn.

### Phase B — Combat Prototype
Phạm vi và tiêu chí: mục 6.8. Kết quả dùng để tinh chỉnh real-time combat.

### Phase C — Extended Combat Encounter (STRETCH; không chặn MVS)
**Phạm vi:** một khu vực nhỏ, encounter nhiều enemy/vai trò, mini-boss, reward đơn giản. Đây là phần mở rộng sau MVS, không bắt buộc để hoàn thành MVS.
**Thoát khi:** người chơi hoàn thành encounter từ đầu đến cuối ≥ 8/10 lần cố gắng với độ khó có chủ đích; telegraph và feedback đạt rubric ≥ 3/5; không lỗi chặn.

### Phase D — Vertical Slice
**Phạm vi:** hoàn thành MVS theo mục 0. MVS chỉ phụ thuộc Phase A và B; không bắt buộc hoàn thành Phase C. Stretch hướng tới 15–30 phút có thể gồm settlement/preparation, field Verdant Frontier, dungeon có bản sắc, boss, reward/progression và checkpoint/save tối thiểu. Roster nhân vật không thuộc Vertical Slice.
**Thoát khi:** MVS đạt các tiêu chí MVS-AC1…8 ở mục 0 (sau khi bạn duyệt) với bằng chứng phù hợp; đủ bằng chứng để đánh giá pillar exploration-by-observation và combat real-time, đồng thời ghi rõ Known Issues. Stretch 15–30 phút là target phát triển sau MVS, không bắt buộc để tuyên bố MVS hoàn thành. Không đạt gate thì follow waiver rule tại Master Prompt, mục 8.6.

### Phase E — Production
Mở rộng Region, dungeon, weapon, enemy, quest, progression, UI/audio dựa trên kết quả Vertical Slice.

---

# 13. SỔ RỦI RO

| # | Rủi ro | Giảm thiểu |
|---|---|---|
| R1 | Hitbox 3D lệch so với sprite 2D, khó đọc đòn | Logic trên mặt phẳng XZ, footprint riêng, debug hitbox, đo ở Phase A |
| R2 | Mơ hồ chiều sâu (không biết đòn có trúng hay không) | Bóng/dấu hiệu mặt đất, vùng nguy hiểm vẽ rõ, kiểm chứng bằng playtest |
| R3 | Shimmer/crawl pixel khi camera chuyển động | Thử snap camera hoặc render qua SubViewport ở Phase A |
| R4 | Ngắm bằng chuột sai lệch trên camera nghiêng | Marker debug, nhiều vị trí thử |
| R5 | Transparency sorting và bóng sprite sai | Kiểm tra alpha cut, shadow, thứ tự vẽ sớm |
| R6 | Tinh chỉnh combat feel khi AI không tự "chơi" được | Combat log, giao thức playtest, thông số chỉnh được không sửa code |
| R7 | Scope vượt khả năng sản xuất | Mục 0, "không làm", quality gate mỗi phase |
| R8 | Asset AI-sinh thiếu nhất quán/giấy phép không rõ | Placeholder trước, `ASSET_LOG`, một asset đại diện trước khi mở rộng |

---

# 14. QUALITY GATES

- Một hệ thống không được coi là xong chỉ vì script đã viết.
- Mỗi tính năng có Acceptance Criteria theo phạm vi.
- Phân biệt static, runtime, visual/automated, human playtest.
- **Tiêu chí về cảm giác chơi phải qua playtest.**
- Ghi lại lỗi, giới hạn, giả định chưa kiểm chứng.
- Không mở rộng nội dung để che vấn đề của gameplay cốt lõi.
- Phase Gate waiver: tham chiếu Master Prompt, mục 8.6.

**Playtest rubric (dùng chung):** chấm 1–5 cho Responsiveness, Readability, Fairness, Fun; ghi số lần bị trúng mà người chơi hiểu lý do (x/y). Mẫu báo cáo đầy đủ nằm trong Master Prompt, mục 9.

---

# 15. CÂU HỎI MỞ

| Ưu tiên | Câu hỏi | Vì sao |
|---|---|---|
| **P0** | Kiến trúc không gian: mặt phẳng XZ hay 3D thật (độ cao, nhảy)? | Quyết định physics, hitbox, level design, độ đọc combat |
| **P0** | Camera projection và behavior phù hợp real-time combat với chuột? | Ảnh hưởng movement, scale, ngắm, rendering |
| **P0** | Movement 4 hay 8 hướng; theo camera hay world axes? | Input, animation, combat |
| **P0** | Scale, pixel density, pivot thực tế? | Toàn bộ pipeline asset |
| **P1** | Targeting: free aim chuột, directional, lock, hay hybrid? | Cảm giác điều khiển và readability |
| **P1** | Platform phát hành thực tế (ngoài PC)? | Input, UI, hiệu năng |
| **P2** | Độ sâu save/checkpoint, inventory, quest | Chỉ cần khi Vertical Slice yêu cầu |

**Cách quyết định:** P0 còn OPEN thì làm prototype nhỏ và chọn theo tiêu chí cụ thể. Quyết định CONFIRMED không bị đưa lại thành câu hỏi chỉ vì một implementation thử nghiệm đầu tiên chưa tốt: trước hết xác định nguyên nhân (input, camera, movement, animation, hitbox/hurtbox, AI, readability, feedback, code) rồi sửa trong real-time. Mọi quyết định quan trọng được ghi vào `docs/DECISIONS.md`.

---

# 16. CHANGELOG

| Phiên bản | Thay đổi |
|---|---|
| 0.7.1 (baseline cho prototyping) | Làm rõ ngoại lệ của quyết định combat: thiếu playtest/thiếu dữ liệu không phải bằng chứng đổi hướng; bỏ mục đã xác nhận khỏi bảng Câu hỏi mở; bổ sung quy trình ghi nhận và duyệt ngưỡng MVS-AC2, cùng yêu cầu báo cáo mẫu `x/y`, `n` cho MVS-AC4 |
| 0.7 (baseline cho prototyping) | Sửa con trỏ header; đồng bộ bảng mục 0 với MVS/Stretch; thêm MVS-AC1…8 (PROPOSED); Phase A có định nghĩa vận hành trước khi đánh giá và gate Art Spec tạm trước khi sinh asset AI hàng loạt; bỏ lặp mốc một tuần |
| 0.6 (final baseline for prototyping) | Làm rõ Phase A: tolerance/rubric được xác định sau prototype thay vì đặt số tùy ý; thêm sequence triển khai các P0 phụ thuộc nhau; giữ scope, combat real-time và MVS/Stretch nguyên trạng |
| 0.5 (candidate, revised) | Đã sửa tham chiếu nguồn; tách MVS bắt buộc và Stretch; dùng một nhân vật trong Vertical Slice, roster DEFERRED; Region đề xuất có hook khám phá và chọn Verdant Frontier cho slice; waiver chỉ tham chiếu Master Prompt 8.6; rút gọn tiêu chí responsiveness và thêm task đo ngoài tùy chọn |
| 0.4 | Làm rõ cách đo và giới hạn của các giả thuyết định lượng; thêm nguyên tắc quality gate “đủ để giảm rủi ro, không cầu toàn”; làm rõ Combat Spec là tài liệu tùy thời điểm, subordinate GDD và chưa cần tạo sớm |
| 0.3 | Thêm ràng buộc sản xuất (mục 0), điểm khác biệt và bản sắc thế giới (PROPOSED), pillar có thứ tự và quy tắc xung đột, danh sách "không làm", input KB+M CONFIRMED, câu hỏi kiến trúc không gian XZ/3D (P0), giả thuyết số cho combat, tiêu chí phase đo được, sổ rủi ro, tham khảo theo mục đích. Gộp trùng lặp tiêu chí đạt. Bỏ nhãn "CONFIRMED PRINCIPLE" |
| 0.2 | Chốt combat real-time (CONFIRMED) |
| 0.1 | Bản đầu |

---

**Design principle:** Một thế giới rộng lớn không nhất thiết phải có hàng nghìn km². Nó cần đủ nhiều điều thú vị để người chơi luôn tò mò về nơi tiếp theo họ có thể đặt chân đến.
