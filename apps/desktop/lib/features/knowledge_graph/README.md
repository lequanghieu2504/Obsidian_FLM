# Knowledge Graph feature — giải thích chi tiết

Tài liệu này giải thích từng file trong `apps/desktop/lib/features/knowledge_graph/`
(và 2 file bị chỉnh sửa ở ngoài: `pubspec.yaml`, `lib/app/app.dart`), theo đúng
thứ tự dữ liệu chảy qua: **đọc JSON → dựng model → dựng đồ thị → vẽ lên màn hình**.

```
data/subject/*.json          data/concepts/concepts.json
        │  (đọc qua asset)           │  (đọc qua asset)
        ▼                            ▼
SubjectRepository.loadAll()   ConceptRepository.loadAll()
        │  (parse JSON thô)          │  (parse JSON đã biên soạn sẵn)
        ▼                            ▼
List<SubjectRecord>           Map<mãMôn, SubjectConcepts>
  domain/subject_record.dart    domain/concept_data.dart
        └───────────┬────────────────┘
                     ▼
            KnowledgeGraphPage        ← presentation/knowledge_graph_page.dart
                     │
                     ├── Chưa chọn môn nào?
                     │     ├── GraphToolbar (chế độ "chọn môn": chỉ có ô tìm kiếm + số môn)
                     │     └── SubjectPickerGrid   (lưới toàn bộ môn, bấm để chọn)
                     │
                     └── Đã chọn 1 môn?
                           ├── KnowledgeGraphBuilder.buildConceptGraph(subject, concepts)
                           │     (gói thành đồ thị 3 tầng: môn → chủ đề → khái niệm con)
                           ├── GraphToolbar (chế độ "xem đồ thị": có nút Back)
                           ├── ConceptGraphCanvas(...)    (tự vẽ đồ thị — xem mục 5, không dùng package ngoài)
                           │     └── SubjectNodeCard cho từng node, đặt bằng Positioned + FractionalTranslation
                           └── SubjectDetailPanel         (panel chi tiết khi bấm vào 1 node)
```

---

## 0. Lịch sử thay đổi

Tính năng này đã qua 3 lần đổi hướng lớn. Đọc phần này trước để hiểu **vì
sao** code hiện tại trông như vậy, thay vì chỉ đọc mục 2-5 (mô tả trạng thái
hiện tại).

### Lần 1 — sửa lỗi hiển thị của bản đồ thị tiên quyết (đã lỗi thời)

Bản đầu tiên dựng 1 đồ thị **tiên quyết giữa các môn** (môn A là tiên quyết
của môn B, đọc từ trường `Pre-Requisite`), có 2 chế độ xem ("Cây tiên
quyết" / "Mạng lưới") và 1 toggle "Hiện CLO". Cách tiếp cận này đã bị bỏ hẳn
ở lần đổi hướng 2 — không còn trong code nữa — nhưng 2 lỗi kỹ thuật đã sửa ở
giai đoạn này vẫn còn áp dụng cho đồ thị hiện tại, nên ghi lại ở đây:

1. **Màn hình trắng, không thấy đồ thị đâu cả.** Nguyên nhân: gọi
   `GraphView.builder(..., centerGraph: true, ...)` nhưng thiếu
   `autoZoomToFit: true`. `centerGraph: true` chỉ đặt đồ thị vào **giữa** 1
   canvas ảo cố định 2.000.000 × 2.000.000 pixel mà thuật toán bố cục dùng
   để tính toạ độ — không liên quan gì tới việc camera (`InteractiveViewer`
   bên trong `GraphView.builder`) đang nhìn vào đâu. Camera mặc định đứng
   yên ở góc trên-trái canvas ảo đó, rất xa nơi đồ thị thật sự được vẽ.
   Phải bật thêm `autoZoomToFit: true` thì camera mới tự phóng to/thu nhỏ
   và di chuyển tới đúng chỗ có node. **Vẫn áp dụng ở code hiện tại** — xem
   `GraphView.builder` trong `presentation/knowledge_graph_page.dart`.
2. **Crash `RangeError` khi đồ thị chỉ có 1 node, 0 cạnh.**
   `FruchtermanReingoldAlgorithm.positionCluster` (dùng cho "Mạng lưới") gom
   node thành cluster theo thành phần liên thông, loại bỏ mọi cluster chỉ
   có 1 node, rồi đọc thẳng `clusters[0]` không kiểm tra rỗng — đồ thị 0
   cạnh thì mọi node đều bị loại, `clusters` rỗng, đọc `[0]` ném
   `RangeError`. Đây là **bug có sẵn trong package `graphview` 1.5.1**,
   không phải lỗi tự viết. Cách né (không đụng code package): nếu đồ thị
   đang xem có `edges.isEmpty` thì không gọi `GraphView` (bỏ qua thuật toán
   bố cục) luôn, vẽ trực tiếp 1 `SubjectNodeCard` đứng giữa màn hình kèm
   dòng giải thích. **Vẫn áp dụng ở code hiện tại** — xem
   `_buildNoConceptsView` trong `presentation/knowledge_graph_page.dart`.

### Lần 2 — đổi từ đồ thị tiên quyết sang đồ thị khái niệm bằng từ khoá (đã lỗi thời)

Người dùng phản hồi: đồ thị tiên quyết giữa các môn **không phải thứ họ
cần**. Thứ họ muốn: chọn 1 môn (vd `CSD201`) thì thấy 1 đồ thị chỉ ra môn đó
**nói về cái gì** — các công nghệ/khái niệm nó dạy (Java, OOP, Data
Structures, Sorting, ...), lấy từ phần **Mô tả** và **CLO** của chính môn
đó — không phải quan hệ môn nào học trước môn nào.

Cách tiếp cận ở lần này (`ConceptExtractor` so khớp ~70 từ khoá cố định
trong văn bản, bằng regex, chạy lúc app đang chạy) **đã bị bỏ hẳn ở lần đổi
hướng 3 bên dưới**, vì quá thưa và thiên lệch tiếng Anh/CS — xem lý do chi
tiết ngay dưới đây. Những thay đổi UI ở lần này (bỏ đồ thị tiên quyết, bỏ
toggle layout, bỏ toggle "Hiện CLO") thì **vẫn giữ nguyên**.

### Lần 3 — đổi từ so khớp từ khoá lúc chạy sang dữ liệu chủ đề biên soạn sẵn (trạng thái hiện tại)

Người dùng thử đồ thị của `JPD133` (môn tiếng Nhật sơ cấp, mô tả hoàn toàn
bằng tiếng Việt) và thấy **"Khái niệm được nhận diện (0)"** — từ điển của
`ConceptExtractor` chỉ có thuật ngữ CS bằng tiếng Anh, nên với 1 môn không
phải CS hoặc không viết bằng tiếng Anh thì gần như luôn khớp 0 khái niệm.
Yêu cầu cụ thể của người dùng: đồ thị cần **nhiều thông tin hơn** — gần hết
những gì Mô tả/CLO nhắc tới — và phải có **cấu trúc phân cấp**: 1 chủ đề
rộng (vd "Mobile App Development") có các khái niệm con nằm dưới nó (vd
"Flutter", "UI/UX"), thay vì 1 danh sách phẳng; và phải hoạt động được với
**mọi loại môn**, kể cả các môn ngôn ngữ/nhân văn viết hoàn toàn bằng tiếng
Việt như `JPD133`.

Đây không phải việc regex/từ điển từ khoá có thể làm được — nó đòi hỏi đọc
hiểu thật sự văn bản tự do, đa ngôn ngữ. Vì vậy, thay vì so khớp lúc chạy,
dữ liệu chủ đề/khái niệm con của **cả 84 môn** được đọc và biên soạn thủ
công (từng môn một, đọc Mô tả + toàn bộ CLO), đóng gói sẵn thành 1 file JSON
tĩnh, và app chỉ **tải** dữ liệu đó lên — không còn "trích xuất" gì lúc
chạy nữa.

Thay đổi cụ thể:

- **Thêm mới** `data/concepts/concepts.json`: 1 object JSON, khoá là mã môn
  (vd `"PRM393"`), giá trị là `{"topics": [{"label": ..., "subtopics": [...]},
  ...]}` — biên soạn thủ công cho toàn bộ 84 môn (302 chủ đề, 687 khái niệm
  con). Ví dụ `PRM393` (Lập trình di động — Flutter/Dart) có chủ đề "Mobile
  App Development" với các khái niệm con "Flutter", "Dart", "UI/UX",
  "Widgets & Plugins", đúng ví dụ người dùng đưa ra. Các môn ngôn ngữ/nhân
  văn (vd `JPD133`, `MLN111`) dùng nhãn **tiếng Việt** vì văn bản nguồn của
  chúng là tiếng Việt — không ép mọi nhãn phải là tiếng Anh.
- **Xoá khỏi luồng chạy** `domain/concept_extractor.dart` (không file nào
  còn import nữa — an toàn để xoá thủ công nếu muốn dọn dẹp, giống
  `domain/prerequisite_parser.dart` và `presentation/knowledge_graph_layout.dart`
  trước đó).
- **Thêm mới** `domain/concept_data.dart`: model thuần cho dữ liệu đã biên
  soạn — `ConceptTopic {label, subtopics}` và `SubjectConcepts {topics}` —
  xem mục 2.
- **Thêm mới** `data/concept_repository.dart`: `ConceptRepository.loadAll()`
  đọc `data/concepts/concepts.json` qua Flutter asset bundle (giống hệt cách
  `SubjectRepository` đọc `data/subject/*.json`), trả về
  `Map<mãMôn, SubjectConcepts>`. Không throw nếu asset thiếu/hỏng — trả về
  map rỗng để tính năng suy giảm nhẹ nhàng (chỉ còn node môn, không crash cả
  trang).
- `domain/graph_model.dart`: `NodeType` đổi từ `concept` (phẳng) thành
  **2 tầng**: `topic` (chủ đề rộng) và `subtopic` (khái niệm con nằm dưới 1
  chủ đề). `RelationType` đổi từ `MENTIONS_CONCEPT` thành **2 loại**:
  `HAS_TOPIC` (môn → chủ đề) và `HAS_SUBTOPIC` (chủ đề → khái niệm con).
  `RelationCategory` giữ nguyên `official`/`inferred` — cả 2 loại cạnh mới
  vẫn luôn là `inferred`, vì dữ liệu chủ đề tuy được đọc hiểu bởi con
  người/mô hình chứ không phải regex, nhưng vẫn là **suy luận** từ Mô
  tả/CLO chứ không phải 1 trường FLM đánh dấu sẵn "đây là chủ đề của môn
  này" — không có trường như vậy.
- `domain/knowledge_graph_builder.dart`: `buildConceptGraph` đổi chữ ký
  thành `buildConceptGraph(subject, concepts)` (nhận thêm 1
  `SubjectConcepts`, lấy từ `ConceptRepository` thay vì tự gọi
  `ConceptExtractor.extract` bên trong). Dựng đồ thị 3 tầng: môn → từng
  chủ đề (`HAS_TOPIC`) → từng khái niệm con của chủ đề đó
  (`HAS_SUBTOPIC`).
- `presentation/widgets/subject_node_card.dart`: kiểu vẽ `concept` (1 pill)
  đổi thành `topic` (pill lớn hơn, màu `secondary`) và `subtopic` (pill nhỏ
  hơn, màu `tertiary`) — để 2 tầng phân biệt được bằng mắt ngay trên đồ thị,
  không cần bấm vào panel chi tiết mới biết cái nào là chủ đề, cái nào là
  khái niệm con.
- `presentation/widgets/subject_detail_panel.dart`: panel của 1 **môn** giờ
  hiện toàn bộ cây chủ đề → khái niệm con (không còn danh sách phẳng); panel
  của 1 **chủ đề** hiện các khái niệm con của nó; panel của 1 **khái niệm
  con** hiện chủ đề cha + mã môn. Panel giờ nhận thêm tham số
  `knowledgeGraph` (thay vì tự lưu "nguồn khớp" trong `node.attributes` như
  bản `ConceptExtractor` cũ) để dò cây chủ đề bằng cách đi theo cạnh
  `HAS_TOPIC`/`HAS_SUBTOPIC` trong đồ thị đang vẽ.
- `presentation/knowledge_graph_page.dart`: thêm field `conceptRepository`,
  `_conceptsByCode`; `initState` giờ tải **song song** `SubjectRepository` +
  `ConceptRepository` bằng `Future.wait`. `_rebuildFocusedGraphObjects`
  truyền thêm `concepts` vào `buildConceptGraph`. `SubjectDetailPanel` được
  gọi với `knowledgeGraph:` thay vì chỉ `subject:`.
- `apps/desktop/pubspec.yaml`: thêm `data/concepts/` vào danh sách
  `assets:` (bên cạnh `data/subject/` sẵn có).

### Lần 4 — căn giữa node môn khi mở đồ thị, cho kéo node tự do, hover hiện thông tin (đã lỗi thời — xem Lần 5)

**Toàn bộ cách làm ở mục này (dùng `graphview` + sửa hành vi của nó) đã bị
bỏ hẳn ở Lần 5** — dù đã sửa lỗi crash và tưởng đã sửa xong lỗi kéo bị loạn,
người dùng chạy thử vẫn thấy đồ thị "chạy lung tung" chỉ với 1 cái chạm, và
cạnh không theo node lúc kéo. Đọc kỹ thêm mã nguồn `graphview` mới phát hiện
nguyên nhân sâu hơn hẳn những gì đã sửa: **bất kỳ tương tác nào trên trang
này (không chỉ kéo — chạm để chọn node, gõ ô tìm kiếm...)** đều gọi
`setState`, mà `setState` nào cũng khiến `graphview` chạy lại toàn bộ thuật
toán bố cục — không có cách nào né triệt để nếu còn dùng `GraphView.builder`.
Giữ lại mục này để hiểu **quá trình** debug (mỗi bước đọc mã nguồn, mỗi giả
thuyết bị chạy thử bác bỏ) — thứ tự đó là lý do Lần 5 đi tới quyết định bỏ
hẳn thư viện ngoài, không phải chỉ để đọc cho vui. Người dùng phản hồi đồ
thị đã ổn về nội dung (sau Lần 3), nhưng còn thiếu 3 điều về cách
**tương tác**:

1. Mở đồ thị của 1 môn lên thì node của **môn đó phải nằm đúng giữa màn
   hình**, không phải lệch qua trái/phải/trên/dưới tuỳ vào cây chủ đề nặng
   về phía nào.
2. Người dùng phải **kéo được** bất kỳ node nào (môn, chủ đề, khái niệm con)
   đi chỗ khác để tự sắp xếp lại đồ thị theo ý mình.
3. **Di chuột vào 1 node** (không cần bấm) phải hiện ngay thông tin kèm
   theo, không bắt phải bấm để mở panel chi tiết mới biết.

Cả 3 đều chỉ sửa trong `presentation/knowledge_graph_page.dart`, không đụng
tới `domain/`/`data/` hay dữ liệu `concepts.json`:

1. **Căn giữa node môn** — dùng tham số `initialNode:` của
   `GraphView.builder` (có từ `graphview` 1.5.0, vẫn còn ở 1.5.1 đang dùng),
   **thay cho** `autoZoomToFit: true` chứ không phải dùng chung với nó.

   > **Sửa lỗi (phát hiện lúc chạy thử):** bản đầu của Lần 4 vẫn giữ
   > `autoZoomToFit: true` (đã bật từ Lần 1) và thêm `initialNode:` bên
   > cạnh, với suy đoán `initialNode` sẽ chạy *sau* bước zoom-to-fit để dịch
   > khung nhìn tới đúng node môn. Suy đoán đó sai: `graphview` 1.5.1 chặn
   > thẳng bằng 1 `assert` ngay trong constructor —
   > `!(autoZoomToFit && initialNode != null)` (`GraphView.dart` dòng 348)
   > — 2 tham số này **không được dùng chung**, app crash ngay khi mở đồ
   > thị (`Cannot use both autoZoomToFit and initialNode together. Choose
   > one.`). Vì yêu cầu là căn giữa **đúng node môn**, không phải phóng vừa
   > khung nhìn theo hộp bao toàn bộ node (tâm hộp đó không chắc trùng với
   > node môn, do cây chủ đề hiếm khi cân đối đều 2 bên) — nên đã bỏ hẳn
   > `autoZoomToFit: true`, chỉ giữ `initialNode:`. `centerGraph: true` vẫn
   > giữ nguyên (không liên quan tới lỗi này — chỉ ảnh hưởng toạ độ node
   > trong canvas ảo, không phải khung nhìn camera).

   Cần truyền vào đúng `Node.key` (kiểu `ValueKey`) của node môn — không tự
   dựng `ValueKey(mãMôn)` mới, vì `Node.Id(dynamic id) { key = ValueKey(id);
   }` nhận tham số kiểu `dynamic` nên trình biên dịch suy ra
   `ValueKey<dynamic>`, còn `ValueKey` tự dựng từ 1 `String` sẽ được suy ra
   là `ValueKey<String>` — 2 kiểu generic khác nhau thì `==` của `ValueKey`
   (so `runtimeType` trước) sẽ luôn trả `false`, `initialNode:` sẽ âm thầm
   không khớp node nào. Cách né: lưu lại đúng instance `Node` đã tạo cho mỗi
   node (field mới `_graphNodesById`, set trong `_rebuildFocusedGraphObjects`)
   rồi lấy `.key` từ đó — đảm bảo khớp bằng cách **dùng lại instance**, không
   dựa vào suy đoán kiểu.
2. **Kéo node tự do**.

   > **Sửa lỗi (phát hiện lúc chạy thử):** bản đầu bọc mỗi node bằng
   > `GestureDetector` với `onPanUpdate: (details) => _onNodeDrag(node,
   > details)`, và `_onNodeDrag` gọi `setState(() => node.position +=
   > details.delta)` **trên mỗi khung hình khi kéo** — dựa trên suy đoán
   > (từ `GraphChildDelegate.shouldRebuild`, chỉ so sánh **instance**
   > `graph`/`algorithm`) rằng `setState` này an toàn, không làm chạy lại
   > thuật toán bố cục. Người dùng báo lại: "đụng nhẹ [vào node] nó nhảy
   > lung tung" — tức không phải 1 mình node bị kéo di chuyển sai, mà **cả
   > đồ thị** loạn lên chỉ với 1 cái chạm nhẹ.
   >
   > Đọc thẳng mã nguồn `graphview` 1.5.1 (`RenderCustomLayoutBox`) mới
   > thấy suy đoán trên sai: setter `delegate` của nó —
   > ```dart
   > set delegate(GraphChildDelegate value) {
   >   // if (value != _delegate) {
   >   _needsFullRecalculation = true;
   >   _isInitialized = false;
   >   _delegate = value;
   >   markNeedsLayout();
   >   // }
   > }
   > ```
   > — chạy **vô điều kiện** mỗi khi widget `GraphView.builder` được
   > rebuild (dòng `if (value != _delegate)` để so sánh có tồn tại trong mã
   > nguồn nhưng **bị comment lại**, tức không hề được dùng). Vì
   > `GraphView.builder(...)` được gọi lại (tạo `GraphChildDelegate` mới)
   > mỗi lần `_KnowledgeGraphPageState.build()` chạy — tức là mỗi lần
   > `setState` bất kỳ ở trang này, không riêng gì lúc kéo node — nên
   > **mọi** `setState` đều buộc `FruchtermanReingoldAlgorithm` chạy lại
   > toàn bộ 400 vòng lặp từ đầu. `onPanUpdate` bắn ra hàng chục `setState`
   > mỗi giây khi kéo ⇒ hàng chục lần chạy lại thuật toán mỗi giây ⇒ thuật
   > toán lực-đẩy-lực-hút xáo lại **toàn bộ** vị trí node mỗi lần, không
   > chỉ node đang kéo — đúng như người dùng mô tả.
   >
   > **Cách sửa**: không cho việc kéo chạm tới `setState` của
   > `_KnowledgeGraphPageState` (và do đó tới `GraphView.builder`) nữa
   > trong lúc đang kéo. Node giờ bọc trong 1 widget con riêng,
   > `_DraggableNodeCard`, có `State` **của riêng nó**: theo đúng cơ chế
   > Flutter, `setState` bên trong 1 `State` chỉ rebuild nhánh cây của
   > chính `State` đó, không lan lên tổ tiên — nên việc kéo (mỗi khung hình
   > gọi `setState` của `_DraggableNodeCardState`, cập nhật 1 `Offset
   > _liveOffset` cục bộ, hiện bằng `Transform.translate`) **không bao giờ
   > đụng tới** `RenderCustomLayoutBox` của `GraphView.builder` — đồ thị
   > hoàn toàn đứng yên trong lúc kéo, chỉ node đang kéo di chuyển theo
   > chuột. Chỉ khi **buông chuột** (`onPanEnd`), tổng độ dịch chuyển mới
   > được báo 1 lần lên `_onNodeDrag`, lúc đó mới thật sự `setState(() =>
   > node.position += totalDelta)` — trả giá 1 lần chạy lại thuật toán duy
   > nhất, thay vì hàng chục lần liên tục.
   >
   > **Đánh đổi phải chấp nhận** (do giới hạn thật của `graphview`, không
   > có cách nào né hoàn toàn nếu vẫn dùng `GraphView.builder`): (a) đường
   > nối (cạnh) tới node đang kéo **không** di chuyển theo trong lúc kéo —
   > nó được vẽ từ `Node.position` thật, chỉ "bắt kịp" khi buông chuột và
   > `setState` thật sự chạy; (b) lần `setState` khi buông chuột đó **vẫn**
   > làm thuật toán chạy lại toàn bộ, nên về lý thuyết cả đồ thị (không chỉ
   > node vừa kéo) có thể xê dịch nhẹ khi buông tay — chỉ còn xảy ra
   > **1 lần** lúc buông, không còn liên tục nữa.
3. **Hover hiện thông tin** — bọc mỗi node bằng widget `Tooltip` sẵn có của
   Flutter (tự bật khi rê chuột qua trên desktop, không cần thư viện nào
   thêm), nội dung lấy từ hàm mới `_tooltipMessage`: node môn hiện tên đầy
   đủ, tín chỉ, bậc đào tạo và đoạn đầu Mô tả (cắt ở 160 ký tự); node chủ đề
   hiện thuộc môn nào, có bao nhiêu khái niệm con; node khái niệm con hiện
   thuộc chủ đề nào, môn nào.

Cả 3 cùng bắt nguồn từ `builder: (Node node) { ... }` của `GraphView.builder`
(node được bọc `Tooltip` cho mục 3, rồi `_DraggableNodeCard` cho mục 1+2 —
xem class đó ở cuối file để hiểu rõ vì sao việc kéo phải tách thành `State`
riêng), và áp dụng luôn `Tooltip` cho `_buildNoConceptsView` (trường hợp môn
chưa có dữ liệu chủ đề, chỉ vẽ 1 node đứng giữa — vẫn hover được, tuy không
kéo được vì không có `GraphView` bao quanh để kéo trong đó, nhưng cũng không
cần: nó luôn đứng yên ở giữa vì là node duy nhất).

**Chưa kiểm chứng bằng compiler** (không có Flutter SDK trong môi trường
biên soạn) — cần `flutter run` (hot-restart) và thử lại cả 3 việc trên môn
`PRM393` hoặc môn bất kỳ: đồ thị mở lên đã căn giữa đúng node môn chưa; kéo
node có mượt, có bám theo chuột không, cả đồ thị có còn đứng yên trong lúc
kéo không (bug đã sửa ở mục 2 phía trên — chỉ mới sửa theo lý thuyết đọc mã
nguồn, chưa chạy thử được), đường nối có "bắt kịp" đúng chỗ khi buông chuột
không; hover có hiện tooltip đúng nội dung không.

**Kết quả chạy thử thực tế (người dùng báo lại): vẫn lỗi.** "Đụng phát nó
vẫn chạy lung tung, kéo mà cái cạnh không đi theo thì kéo làm gì" — xem
Lần 5 để biết nguyên nhân gốc và hướng giải quyết cuối cùng.

### Lần 5 — bỏ hẳn `graphview`, tự vẽ đồ thị bằng canvas riêng (trạng thái hiện tại)

**Nguyên nhân gốc** (đọc thẳng mã nguồn `graphview` 1.5.1,
`RenderCustomLayoutBox` trong `GraphView.dart`): setter `delegate` của nó —

```dart
set delegate(GraphChildDelegate value) {
  // if (value != _delegate) {
  _needsFullRecalculation = true;
  _isInitialized = false;
  _delegate = value;
  markNeedsLayout();
  // }
}
```

chạy **vô điều kiện** mỗi khi widget `GraphView.builder` được rebuild — dòng
kiểm tra "đồ thị có thực sự đổi không" (`if (value != _delegate)`) có trong
mã nguồn gốc của package nhưng **bị comment lại**, tức bị vô hiệu hoá hoàn
toàn. Vì `GraphView.builder(...)` được gọi lại (tạo `GraphChildDelegate`
mới) mỗi khi `_KnowledgeGraphPageState.build()` chạy, tức là **mỗi khi có
`setState` bất kỳ trên trang này** — chạm để chọn node, gõ ô tìm kiếm, hay
kéo node — nên **mọi** tương tác đều buộc `FruchtermanReingoldAlgorithm`
chạy lại toàn bộ 400 vòng lặp từ đầu, xáo lại vị trí của **toàn bộ** node,
không riêng gì node vừa được tương tác. Lần 4 chỉ vá được đường kéo (gộp
nhiều `setState` liên tục thành 1 lần lúc buông tay), nhưng lỗi tương tự vẫn
còn nguyên ở đường chạm-để-chọn-node (`_onNodeTap`) — chưa kịp vá thì đã rõ
ra đây không phải chuyện vá từng chỗ, mà là **giới hạn kiến trúc** của
`GraphView.builder`: hễ còn dùng nó, còn phải hứng chịu việc này ở bất kỳ
đường tương tác nào tương lai có thể thêm vào.

**Quyết định**: bỏ hẳn dependency `graphview`, tự vẽ đồ thị bằng các widget
Flutter chuẩn (`Stack` + `Positioned` + `CustomPaint` + `InteractiveViewer`
— đều là 1 phần của Flutter SDK, không phải package ngoài, nên hành vi được
tài liệu hoá đầy đủ, không còn phải suy đoán/đọc mã nguồn package của người
khác nữa). Toàn bộ logic nằm trong 1 file mới,
`presentation/widgets/concept_graph_canvas.dart` (`ConceptGraphCanvas`):

1. **Vị trí node**: không còn thuật toán lực-đẩy-lực-hút chạy lúc runtime
   nữa. Thay bằng **bố cục hình tia (radial layout) tính 1 lần, không lặp**
   — node môn ở tâm (0,0); các node chủ đề rải đều quanh 1 vòng tròn bán
   kính cố định quanh tâm; khái niệm con của mỗi chủ đề rải trên 1 cung
   (không phải cả vòng tròn) quay ra hướng ngược với tâm, để không đè lên
   chủ đề khác. Vì là công thức lượng giác đơn giản (`cos`/`sin` theo góc
   chia đều), tính ra là xong — không có khái niệm "hội tụ", nên **không
   có gì để xáo lại** dù gọi `setState` bao nhiêu lần cũng vậy. Không nhận
   diện va chạm giữa các nhánh (nếu 1 môn có rất nhiều chủ đề, mỗi chủ đề
   lại có rất nhiều khái niệm con, các nhánh có thể đè lên nhau) — chấp
   nhận được vì dữ liệu biên soạn tay hiện tại chỉ vài chủ đề, vài khái
   niệm con mỗi chủ đề (302 chủ đề / 687 khái niệm con cho 84 môn); người
   dùng vẫn luôn kéo tay ra xa nhau được nếu cần.
2. **Kéo node tự do + cạnh theo real-time**: vị trí node giờ là 1
   `Map<String, Offset>` (`_positions`) do chính `ConceptGraphCanvas` giữ
   và cập nhật bằng `setState` bình thường mỗi khung hình kéo — an toàn
   tuyệt đối lần này, vì `setState` ở đây **chỉ** làm 2 việc: xếp lại vị
   trí các widget `Positioned` và vẽ lại các đường nối bằng `CustomPainter`
   (đọc thẳng từ `_positions` mỗi lần vẽ) — không có bước "chạy lại thuật
   toán" nào ẩn giấu để lo nữa. Vì cạnh cũng đọc từ đúng `_positions` đó
   mỗi khung hình, **cạnh bám theo node đang kéo ngay lập tức**, không cần
   "bắt kịp" sau khi buông tay như Lần 4.
3. **Căn giữa node môn khi mở đồ thị**: tự tính bằng
   `TransformationController` của chính `InteractiveViewer` (Flutter SDK,
   không phải của `graphview`) — sau khung hình đầu tiên (biết được kích
   thước khung nhìn thật), dịch ma trận biến đổi sao cho toạ độ node môn
   rơi đúng giữa khung nhìn. Không còn phụ thuộc `initialNode`/
   `autoZoomToFit` hay bất kỳ tham số đặc thù nào của `graphview` — nên
   cũng không còn nguy cơ dính phải 1 giới hạn/lỗi lạ khác của package đó.
4. **Hover hiện thông tin**: giữ nguyên `Tooltip` như Lần 4 — không liên
   quan gì tới `graphview`, không cần đổi.

**Thay đổi thêm**:

- **Xoá** dependency `graphview: ^1.5.1` khỏi `apps/desktop/pubspec.yaml`
  — sau khi kéo file này về máy, cần chạy `flutter pub get` (hoặc IDE tự
  chạy khi mở lại project) để cập nhật `pubspec.lock`, môi trường biên
  soạn ở đây không có Flutter SDK để tự chạy giúp.
- **Xoá** toàn bộ import/sử dụng `package:graphview/GraphView.dart`,
  class `Node`/`Graph`/`Algorithm`/`FruchtermanReingoldAlgorithm`, và
  class `_DraggableNodeCard` (không còn cần thiết — logic kéo giờ nằm
  thẳng trong `ConceptGraphCanvas`) khỏi
  `presentation/knowledge_graph_page.dart`. Trang này giờ chỉ còn giữ
  `KnowledgeGraph` (model của chính app, không phải của `graphview`) và
  giao hết việc vẽ/tương tác cho `ConceptGraphCanvas` qua các tham số
  (callback `onNodeTap`, hàm `isHighlighted`/`tooltipMessage`, id môn/node
  đang chọn) — trang không còn biết gì về toạ độ hay cách vẽ nữa.
- Gộp luôn trường hợp môn chưa có dữ liệu chủ đề (trước đây là
  `_buildNoConceptsView` riêng, để né 1 bug crash *khác* của `graphview`
  khi đồ thị 0 cạnh — xem Lần 1 mục 2) vào cùng 1 đường vẽ với mọi môn
  khác: bố cục hình tia của Lần 5 không có bug đó (không đọc mảng
  `clusters[0]` như `FruchtermanReingoldAlgorithm`, nên 0 chủ đề chỉ đơn
  giản là vòng lặp rải chủ đề chạy 0 lần), nên không cần code né riêng
  nữa — chỉ còn 1 dòng chữ nhỏ phía trên đồ thị báo "chưa có dữ liệu chủ
  đề" khi `edges.isEmpty`.

**Chưa kiểm chứng bằng compiler** (không có Flutter SDK trong môi trường
biên soạn) — đây là 1 bản viết lại tương đối lớn (bỏ hẳn 1 dependency, thêm
1 file mới ~300 dòng), nên rủi ro có lỗi cú pháp/kiểu dữ liệu cao hơn những
lần vá nhỏ trước, dù mọi API dùng ở đây (`Stack`, `Positioned`,
`FractionalTranslation`, `CustomPaint`, `InteractiveViewer`,
`TransformationController`) đều là Flutter SDK chuẩn, có tài liệu đầy đủ —
không còn phải đoán hành vi 1 package ngoài như các lần trước. Cần chạy
`flutter pub get` rồi `flutter run` (hoặc hot-restart nếu app đang chạy —
nhưng đổi `pubspec.yaml` thường cần full restart, không chỉ hot-restart) và
thử lại đúng những gì Lần 4 chưa làm được: chạm để chọn node có còn làm cả
đồ thị "loạn" không (phải hết hẳn); kéo node có mượt, cạnh có bám theo
real-time không (không còn độ trễ "bắt kịp" nữa); mở đồ thị lên node môn có
đúng giữa màn hình không; hover có hiện tooltip không; và thêm 1 việc mới
chưa từng thử: bố cục hình tia trông có ổn không (chủ đề/khái niệm con có
đè lên nhau nhiều không, nhất là với môn có nhiều chủ đề như `PRM393`).

### Lần 6 — panel chi tiết của chủ đề/khái niệm con hiện thêm Mô tả + CLO của môn (trạng thái hiện tại)

Người dùng phản hồi sau khi thử Lần 5: đồ thị vẽ/kéo/hover đã ổn, nhưng bấm
vào 1 node thì **"nó ra thông tin hơi sơ xài"**, và để ý thấy CLO của môn
**chưa được dùng ở đâu cả** trong panel chi tiết — dù CLO (cùng với Mô tả)
chính là nguồn văn bản gốc mà `data/concepts/concepts.json` được biên soạn
từ đó (xem mục 0, Lần 3 và mục 7).

**Nguyên nhân**: `SubjectDetailPanel` nhận tham số `subject: SubjectRecord?`
từ `knowledge_graph_page.dart`, nhưng chỗ gọi cũ tra cứu bằng
`_subjectsByCode[selectedNode.id]` — chỉ đúng cho **node môn** (id của nó
chính là mã môn). Với node **chủ đề**/**khái niệm con**, `id` là 1 chuỗi
ghép (vd `"PRM393::topic:mobile-app-development"`), không khớp mã môn nào
trong `_subjectsByCode` ⇒ tra cứu luôn ra `null` ⇒ `_TopicDetails`/
`_SubtopicDetails` chưa bao giờ có `SubjectRecord` trong tay để hiện Mô
tả/CLO, dù dữ liệu đó vẫn nằm sẵn trong bộ nhớ (`_subjectsByCode`), chỉ là
tra sai khoá.

**Cách sửa** — 2 file:

1. `presentation/knowledge_graph_page.dart`: đổi chỗ gọi
   `SubjectDetailPanel(subject: ...)` thành

   ```dart
   subject: _subjectsByCode[
       selectedNode.attributes['subjectCode']?.toString() ??
           selectedNode.id],
   ```

   Node chủ đề/khái niệm con đều đã có sẵn `attributes['subjectCode']` (gắn
   lúc `KnowledgeGraphBuilder.buildConceptGraph` dựng node — xem mục 2), nên
   ưu tiên đọc từ đó; `?? selectedNode.id` là fallback đúng cho node môn
   (không có `subjectCode` trong `attributes` vì bản thân `id` của nó đã là
   mã môn rồi). Kết quả: `subject` giờ **luôn** có giá trị đúng cho cả 3
   loại node, chỉ trừ khi dữ liệu môn thật sự thiếu.

2. `presentation/widgets/subject_detail_panel.dart`: viết lại đáng kể —

   - Nhánh hiển thị trong `SubjectDetailPanel.build()` đổi từ kiểm tra
     `subject != null` sang `switch (node.type)` — rẽ theo **loại node
     trước**, để `_TopicDetails`/`_SubtopicDetails` luôn được gọi đúng
     lúc dù `subject` có null hay không (trường hợp `subject == null` giờ
     chỉ còn xảy ra thật sự bất thường — dữ liệu môn thiếu — không còn là
     đường mặc định cho mọi node chủ đề/khái niệm con như trước).
   - `_TopicDetails` và `_SubtopicDetails` nhận thêm tham số `subject:
     SubjectRecord?`; nếu khác null, cả 2 đều nối thêm (qua hàm dùng chung
     `_subjectSourceSections`) 2 mục mới ở cuối panel: **"Mô tả môn (nguồn
     biên soạn chủ đề/khái niệm này)"** và **"Chuẩn đầu ra (CLO) của môn
     (N)"** — hiện **toàn bộ** CLO của môn, không lọc/khớp riêng theo từng
     node, vì không có dữ liệu ánh xạ "CLO nào ứng với chủ đề nào" được lưu
     lại đâu cả (chủ đề/khái niệm con được biên soạn *từ* toàn bộ Mô tả +
     CLO cùng lúc, không tách riêng theo từng CLO) — tên mục cố tình ghi rõ
     "(nguồn biên soạn ... này)" thay vì ngụ ý 1 phép ánh xạ chính xác không
     hề tồn tại.
   - Cả 2 widget đổi từ `Padding(child: Column(...))` sang `ListView` (nội
     dung giờ dài hơn hẳn khi có thêm Mô tả/CLO — cần cuộn được, nhất là môn
     nhiều CLO).
   - `_SubtopicDetails` nhận thêm `graph: KnowledgeGraph` (trước đây không
     cần) để dò ra **khái niệm con anh em** (cùng chủ đề cha): quét
     `graph.edges` tìm cạnh `HAS_SUBTOPIC` mà `targetId == node.id` để biết
     `parentTopicId`, rồi quét tiếp mọi cạnh `HAS_SUBTOPIC` khác có cùng
     `sourceId` đó — thêm 1 mục **"Khái niệm khác cùng chủ đề"** hiện các
     khái niệm con anh em dưới dạng chip, giúp thấy được bối cảnh rộng hơn
     mà không phải đóng panel rồi bấm lại vào node chủ đề cha.
   - Đoạn vẽ CLO (từng có sẵn trong `_SubjectDetails`) được tách ra thành 1
     widget dùng chung mới, `_CloList`, để cả `_SubjectDetails` lẫn 2 mục
     mới ở `_TopicDetails`/`_SubtopicDetails` hiện CLO **giống hệt nhau**
     (định dạng `CLO1: <nội dung>`, mã in đậm) — không lặp code vẽ CLO ở 3
     chỗ khác nhau.

**Không đổi**: `domain/concept_data.dart`, `domain/knowledge_graph_builder.dart`,
`data/concepts/concepts.json` — đây thuần là thay đổi ở tầng hiển thị (panel
đọc thêm dữ liệu `SubjectRecord` đã có sẵn trong bộ nhớ, không cần biên soạn
lại hay tính toán gì mới).

**Chưa kiểm chứng bằng compiler** (không có Flutter SDK trong môi trường
biên soạn) — cần `flutter run` (hot-restart đủ, không đụng `pubspec.yaml`
lần này) rồi thử: bấm vào 1 node **chủ đề** và 1 node **khái niệm con** của
vài môn khác nhau (nhất là môn nhiều CLO như `PRM393`), kiểm tra panel có
cuộn được, có hiện đúng Mô tả + toàn bộ CLO của đúng môn chứa node đó không
(so với bấm thẳng vào node **môn** của cùng môn đó — 2 nơi phải hiện cùng 1
nội dung Mô tả/CLO); với node khái niệm con, kiểm tra thêm mục "Khái niệm
khác cùng chủ đề" có liệt kê đúng các khái niệm con anh em, không lẫn khái
niệm con của chủ đề khác.

---

## 1. Các file đã sửa ở ngoài feature

### `apps/desktop/pubspec.yaml`
Khai báo `assets: - data/subject/ - data/concepts/` để Flutter đóng gói
toàn bộ 84 file JSON môn học + file JSON chủ đề đã biên soạn vào app lúc
build, thay vì đọc trực tiếp từ ổ đĩa bằng `dart:io`. Cách này chạy giống
hệt nhau dù là `flutter run` hay app đã build/đóng gói sẵn (`.exe`), vì
asset được nhúng vào app chứ không phụ thuộc "app đang chạy từ thư mục
nào". Không còn dependency ngoài nào cho việc vẽ đồ thị (từng có
`graphview: ^1.5.1` qua Lần 1–4, đã bỏ hẳn ở Lần 5 — xem mục §0 đó để biết
lý do; đồ thị giờ tự vẽ bằng widget Flutter SDK chuẩn).

### `apps/desktop/lib/app/app.dart`
Trước đây `home:` chỉ là 1 màn hình rỗng in chữ "Obsidian FLM". Giờ trỏ
`home: const KnowledgeGraphPage()` để mở thẳng vào màn hình đồ thị khi chạy
app, và bật `useMaterial3: true` + màu chủ đạo indigo cho đẹp hơn.

---

## 2. `domain/` — logic thuần, không phụ thuộc Flutter UI

### `domain/subject_record.dart`
Định nghĩa 2 class:

- **`LearningOutcome`** — 1 chuẩn đầu ra (CLO), có `code` (vd `CLO1`) và
  `detail` (mô tả đầy đủ).
- **`SubjectRecord`** — bản sạch của 1 môn học, có `factory
  SubjectRecord.fromJson(...)` để parse file JSON thô của FLM. File JSON gốc
  có 2 phần: `metadata` (map phẳng các trường như `Subject Code`,
  `Pre-Requisite`...) và `sections` (danh sách bảng, mỗi bảng có `heading` +
  `rows`). Hàm này:
  - Đọc các trường cần thiết từ `metadata` (mã môn, tên môn, tín chỉ, mô
    tả, chuỗi tiên quyết thô...).
  - Tìm section nào có `heading` khớp regex `LO\(s\)\s*$` (vd `"5 LO(s)"`,
    `"12 LO(s)"`) — đó chính là bảng chuẩn đầu ra — rồi đọc từng dòng
    `[no, cloname, clodetails]` thành `LearningOutcome`.
  - Có fallback: nếu thiếu `Subject Code` thì dùng `Syllabus ID`; nếu cả
    `metadata` cũng rỗng thì dùng tên file làm id, để không bao giờ crash
    vì thiếu dữ liệu.

Trường `description` và `learningOutcomes[].detail` là nguồn văn bản gốc mà
dữ liệu trong `data/concepts/concepts.json` được biên soạn từ đó — không có
trường "chủ đề"/"khái niệm" nào có sẵn trong dữ liệu FLM gốc. `prerequisiteRaw`
vẫn được giữ **nguyên văn** để panel chi tiết hiện đúng 100% những gì FLM
ghi, dù không còn dùng để vẽ cạnh đồ thị nữa.

### `domain/concept_data.dart` (mới ở Lần 3)
Model thuần cho dữ liệu chủ đề đã biên soạn sẵn, đọc từ
`data/concepts/concepts.json`:

- **`ConceptTopic`** — 1 chủ đề: `label` (vd `"Mobile App Development"`) +
  `subtopics` (`List<String>`, có thể rỗng nếu chủ đề không có gì hẹp hơn để
  tách ra).
- **`SubjectConcepts`** — toàn bộ `topics` của 1 môn (khoá theo mã môn ở
  tầng `ConceptRepository`, nên bản thân class này không lặp lại mã môn).
  Có `SubjectConcepts.empty` cho môn chưa được biên soạn, và
  `subtopicCount` (tổng số khái niệm con, gộp mọi chủ đề) tiện cho UI.

### `domain/knowledge_graph_builder.dart`
Đúng 1 hàm tĩnh: `KnowledgeGraphBuilder.buildConceptGraph(subject, concepts)`:

1. Tạo 1 node `subject` cho chính môn đang xem.
2. Với mỗi `ConceptTopic` trong `concepts.topics`: tạo 1 node `topic` (id
   dạng `"<mãMôn>::topic:<slug>"`) + 1 cạnh `HAS_TOPIC` từ môn tới chủ đề
   đó.
3. Với mỗi `subtopic` (chuỗi) trong `topic.subtopics`: tạo 1 node `subtopic`
   (id dạng `"<idChủĐề>::subtopic:<slug>"`) + 1 cạnh `HAS_SUBTOPIC` từ chủ
   đề tới khái niệm con đó.

Kết quả là 1 `KnowledgeGraph` 3 tầng — nhỏ (thường vài tới vài chục node),
chỉ phụ thuộc đúng 1 `SubjectRecord` + 1 `SubjectConcepts`, không cần biết
gì về 83 môn còn lại. Hàm `_slug` dùng chung cho cả `topic` lẫn `subtopic`,
tự bỏ dấu tiếng Việt (vd `"Chủ đề giao tiếp"` → `"chu-de-giao-tiep"`) để id
luôn là ASCII gọn, dễ đọc khi debug.

### `domain/concept_extractor.dart` (không còn dùng, từ Lần 3)
Còn tồn tại trên đĩa (so khớp ~70 từ khoá tiếng Anh cố định trong Mô tả/CLO
bằng regex, chạy lúc app đang chạy) nhưng **không còn file nào trong tính
năng này import nó nữa** kể từ lần đổi hướng 3 ở mục 0 — lý do bị thay là
quá thưa và thiên lệch tiếng Anh/CS (vd môn tiếng Nhật `JPD133` khớp 0 khái
niệm). An toàn để xoá thủ công nếu muốn dọn dẹp; để lại cũng không gây lỗi
build.

### `domain/prerequisite_parser.dart` (không còn dùng, từ Lần 2)
Còn tồn tại trên đĩa (regex trích mã môn tiên quyết từ chuỗi `Pre-Requisite`
thô) nhưng **không còn file nào trong tính năng này import nó nữa** kể từ
lần đổi hướng 2 ở mục 0. An toàn để xoá thủ công nếu muốn dọn dẹp; để lại
cũng không gây lỗi build.

### `domain/graph_model.dart`
Định nghĩa hình dạng đồ thị **độc lập với package vẽ** (không import
`graphview` ở đây), cố tình khớp với `schemas/graph-node.schema.json` và
`schemas/graph-edge.schema.json` đã có sẵn trong repo:

- `NodeType` — 3 loại node: `subject` (môn đang xem, ở giữa đồ thị),
  `topic` (1 chủ đề rộng biên soạn cho môn đó), `subtopic` (1 khái niệm con
  nằm dưới 1 `topic`).
- `RelationType` — 2 loại cạnh: `HAS_TOPIC` (môn → chủ đề) và
  `HAS_SUBTOPIC` (chủ đề → khái niệm con).
- `RelationCategory` — `official` / `inferred`, đúng tinh thần ADR-0003 của
  repo (phân biệt sự kiện lấy thẳng từ FLM với quan hệ suy luận). Cả
  `HAS_TOPIC` lẫn `HAS_SUBTOPIC` luôn là `inferred` — xem lý do ở mục 0,
  Lần 3.
- `GraphNodeData`, `GraphEdgeData` — node/cạnh thật, có `attributes` tự do
  (tên môn, tín chỉ, mô tả, mã môn/chủ đề cha của 1 node con...) để UI hiển
  thị.
- `KnowledgeGraph` — gói `nodes` + `edges` + `nodesById` (map tra cứu nhanh
  theo id).

---

## 3. `data/` — lấy dữ liệu thô

### `data/subject_repository.dart`
`SubjectRepository.loadAll()`:

1. Gọi `AssetManifest.loadFromAssetBundle(rootBundle)` — API chuẩn của
   Flutter (`package:flutter/services.dart`) để lấy danh sách **mọi** asset
   đã đóng gói vào app.
2. Lọc ra những path bắt đầu bằng `data/subject/` và kết thúc bằng `.json`.
3. Với từng file, `rootBundle.loadString(path)` rồi `jsonDecode` ra
   `Map<String, dynamic>`, đưa qua `SubjectRecord.fromJson`.

Đây là bước duy nhất "chạm" vào hệ thống file/asset cho dữ liệu môn học —
nếu sau này bạn muốn đổi nguồn dữ liệu (đọc từ ổ đĩa bằng `dart:io`, hoặc từ
API), chỉ cần sửa đúng 1 file này.

### `data/concept_repository.dart` (mới ở Lần 3)
`ConceptRepository.loadAll()`:

1. `rootBundle.loadString('data/concepts/concepts.json')` — nếu asset
   thiếu/lỗi, bắt lỗi và trả về map rỗng ngay (không throw), để trang đồ thị
   suy thoái nhẹ nhàng thành "chỉ còn node môn" thay vì crash cả trang.
2. `jsonDecode` ra 1 object phẳng khoá theo mã môn.
3. Với mỗi khoá, đưa giá trị qua `SubjectConcepts.fromJson`, gom vào
   `Map<String, SubjectConcepts>` trả về.

Không dùng `AssetManifest` như `SubjectRepository` vì đây chỉ có đúng 1 file
cố định (`data/concepts/concepts.json`), không phải một thư mục nhiều file
JSON cần liệt kê.

---

## 4. `presentation/` — giao diện

### `presentation/knowledge_graph_page.dart`
`StatefulWidget` chính, là "nhạc trưởng". Luồng:

- `initState()`: gọi `Future.wait([repository.loadAll(), conceptRepository.loadAll()])`
  — tải song song danh sách môn **và** dữ liệu chủ đề, khi cả 2 xong mới lưu
  `_subjects`, `_subjectsByCode`, `_conceptsByCode`. Không còn "đồ thị đầy
  đủ" nào để dựng trước — mỗi đồ thị chỉ phụ thuộc đúng môn đang chọn.
- `_focusedSubjectCode == null` → `build()` trả về màn hình chọn môn
  (`SubjectPickerGrid`). Bấm vào 1 môn gọi `_onSubjectSelected`, set
  `_focusedSubjectCode` rồi gọi `_rebuildFocusedGraphObjects()`.
- `_rebuildFocusedGraphObjects()`: lấy `concepts = _conceptsByCode[subjectCode]
  ?? SubjectConcepts.empty`, gọi
  `KnowledgeGraphBuilder.buildConceptGraph(subject, concepts)` và lưu thẳng
  kết quả (`KnowledgeGraph` — model của chính app) vào `_knowledgeGraph`.
  **Không** còn bước convert sang model của package ngoài nữa (Lần 5 bỏ
  `graphview` — xem mục 0 và mục 5) — trang này giờ hoàn toàn không biết gì
  về toạ độ/thuật toán bố cục, chỉ giao thẳng `KnowledgeGraph` cho
  `ConceptGraphCanvas` vẽ. Chạy lại khi vừa chọn/đổi môn — **không** chạy
  lại khi gõ tìm kiếm hay bấm chọn node.
- `_onBackToPicker()`: xoá `_focusedSubjectCode` và toàn bộ state đồ thị,
  quay lại lưới chọn môn.
- Ô tìm kiếm có debounce 250ms (`Timer`). Ở màn hình chọn môn, `_query` lọc
  trực tiếp danh sách môn; ở màn hình đồ thị, `_query` chỉ tô viền vàng
  (`isHighlighted`) node khớp, không ẩn node nào.
- `ConceptGraphCanvas` được gán `key: ValueKey('graph-$mã môn')` để Flutter
  dựng lại đúng 1 `State` mới (bố cục + vị trí pan/zoom/kéo tay đều reset)
  mỗi khi đổi môn, nhưng **giữ nguyên** `State` đó (và mọi vị trí đã kéo
  tay) khi trang chỉ rebuild vì lý do khác (gõ tìm kiếm, bấm chọn node) —
  xem chú thích tại chỗ gọi `ConceptGraphCanvas` trong `build()`.
- Không còn `_buildNoConceptsView` riêng — môn chưa có dữ liệu chủ đề biên
  soạn (0 cạnh) giờ đi chung 1 đường vẽ với mọi môn khác (bố cục hình tia
  của `ConceptGraphCanvas` không có bug crash-trên-đồ-thị-0-cạnh mà
  `graphview` từng có — xem mục 0, Lần 1, lỗi 2 và Lần 5), chỉ thêm 1 dòng
  chữ nhỏ phía trên đồ thị khi `knowledgeGraph.edges.isEmpty`.
- `build()`: dùng `FutureBuilder<void>` (trên `_loadFuture` gộp cả 2 nguồn
  dữ liệu) để hiện loading/lỗi, sau đó rẽ nhánh theo `_focusedSubjectCode`.

### `presentation/widgets/graph_toolbar.dart`
Thanh công cụ trên cùng (dựng từ 1 `AppBar` thường, không nằm trong
`Scaffold.appBar` để còn chỗ đặt panel chi tiết bên cạnh):

- Màn hình chọn môn: chỉ có ô tìm kiếm + số môn.
- Màn hình đồ thị: thêm nút Back (mũi tên trái, gọi `onBack`), tiêu đề nối
  thêm mã môn đang xem, và số nút/cạnh của đồ thị 3 tầng đang vẽ (bao gồm cả
  chủ đề lẫn khái niệm con).

### `presentation/widgets/subject_picker_grid.dart`
Màn hình đầu tiên người dùng thấy: `GridView.builder` liệt kê toàn bộ môn
học (đã sắp theo mã môn), mỗi ô là 1 thẻ nhỏ hiện mã môn + số tín chỉ + tên
môn, bấm vào gọi `onSelect(mãMôn)`. Lọc theo `query` (mã môn / tên tiếng Việt
/ tên tiếng Anh, không phân biệt hoa thường).

### `presentation/widgets/concept_graph_canvas.dart`
`ConceptGraphCanvas` — tự vẽ toàn bộ đồ thị (không dùng package ngoài, xem
mục 5 để biết lý do/cách hoạt động chi tiết). Nhận `knowledgeGraph` +
`subjectId` + `selectedNodeId` từ `knowledge_graph_page.dart`, cùng 3
callback (`isHighlighted`, `onNodeTap`, `tooltipMessage`) để không phải tự
biết gì về logic tìm kiếm/chọn node/nội dung tooltip — chỉ gọi lại đúng lúc
cần. Tự giữ `Map<String, Offset> _positions` (vị trí từng node, tính 1 lần
bằng bố cục hình tia lúc `initState`, sau đó chỉ đổi khi kéo tay) và tự vẽ
cạnh bằng `CustomPainter` đọc thẳng từ đó mỗi khung hình.

### `presentation/widgets/subject_node_card.dart`
Widget vẽ **1 node** — `ConceptGraphCanvas` gọi lại đúng widget này cho mỗi
node, đặt vị trí bằng `Positioned` + `FractionalTranslation` theo toạ độ
trong `_positions`. Tuỳ `node.type` mà vẽ khác nhau:

- `subject`: khung bo góc, tên mã môn in đậm + badge số tín chỉ + tên môn
  (tối đa 2 dòng). Đổi màu khi được chọn (`isSelected`) hoặc khớp từ khoá
  tìm kiếm (`isHighlighted`, viền vàng).
- `topic`: 1 "chip" bo tròn cỡ lớn, màu `secondary`, hiện tên chủ đề.
- `subtopic`: 1 "chip" bo tròn cỡ nhỏ hơn, màu `tertiary`, hiện tên khái
  niệm con — nhỏ và nhạt hơn `topic` một chút để 2 tầng phân biệt được ngay
  trên đồ thị mà không cần bấm vào panel chi tiết.

Cả 2 loại pill đều tô viền vàng khi khớp tìm kiếm (`isHighlighted`).

### `presentation/widgets/subject_detail_panel.dart`
Panel bên phải khi bấm vào 1 node. Nhận `subject` (bản ghi đầy đủ của môn
chứa node đang xem — xem cách `knowledge_graph_page.dart` tra đúng môn cho
cả 3 loại node ở mục "Lần 6" trên) và `knowledgeGraph` (đồ thị đang vẽ, để
dò cây chủ đề/khái niệm con bằng cách đi theo cạnh `HAS_TOPIC`/
`HAS_SUBTOPIC`, thay vì đọc lại dữ liệu biên soạn từ đầu). Rẽ nhánh theo
`node.type`:

- Bấm vào node **môn** (`subject` — chính là môn đang xem): tên môn, các
  chip (tín chỉ / bậc học / hình thức học), mục **"Chủ đề được nhận diện"**
  — hiện toàn bộ cây: mỗi chủ đề là 1 chip lớn, các khái niệm con của nó
  xếp thành hàng chip nhỏ ngay bên dưới (thụt vào) — rồi **nguyên văn**
  chuỗi tiên quyết FLM ghi, mô tả môn, và danh sách đầy đủ các CLO kèm nội
  dung.
- Bấm vào node **chủ đề** (`topic`): tên chủ đề, mã môn chứa nó, danh sách
  các khái niệm con của riêng chủ đề đó, rồi (từ Lần 6) **Mô tả môn** và
  **toàn bộ CLO của môn** — nguồn văn bản đã biên soạn ra chủ đề này, không
  phải 1 phép ánh xạ CLO-riêng-cho-chủ-đề-này (không có dữ liệu đó).
- Bấm vào node **khái niệm con** (`subtopic`): tên khái niệm, tên chủ đề
  cha, mã môn chứa nó (lấy từ `node.attributes['topicLabel']` +
  `node.attributes['subjectCode']`, được `KnowledgeGraphBuilder` gắn sẵn lúc
  dựng node), mục mới **"Khái niệm khác cùng chủ đề"** (các khái niệm con
  anh em, dò từ `knowledgeGraph`), rồi (từ Lần 6) cùng Mô tả + CLO của môn
  như trên.

`_CloList` là widget dùng chung vẽ danh sách CLO (`CLO1: <nội dung>`, mã in
đậm) — dùng cả ở panel môn lẫn 2 mục Mô tả/CLO mới ở panel chủ đề/khái niệm
con, tránh lặp code vẽ CLO 3 chỗ khác nhau. Xem mục 0, "Lần 6" để biết đầy
đủ lý do/chi tiết thay đổi này.

---

## 5. Vẽ đồ thị bằng gì?

**Không dùng package ngoài nào** — trước đây (Lần 1–4) dùng
[`graphview`](https://pub.dev/packages/graphview), bỏ hẳn ở Lần 5 vì giới
hạn kiến trúc thật của package đó (mọi tương tác đều buộc chạy lại toàn bộ
thuật toán bố cục — chi tiết đầy đủ ở mục 0, Lần 5). Giờ tự vẽ bằng đúng
các widget có sẵn trong Flutter SDK, tất cả nằm trong
`ConceptGraphCanvas` (`presentation/widgets/concept_graph_canvas.dart`):

1. **Tính toạ độ node — bố cục hình tia (radial layout), 1 lần, không lặp**:
   không dùng thuật toán lực hút/đẩy nữa (không cần: cây 3 tầng môn → chủ đề
   → khái niệm con đã có sẵn cấu trúc phân cấp rõ ràng, không cần mô phỏng
   vật lý để "tự tìm ra" cách sắp xếp hợp lý). Môn đặt ở gốc toạ độ `(0,0)`;
   mỗi chủ đề đặt trên 1 vòng tròn bán kính cố định quanh môn, chia đều góc
   theo số chủ đề (`cos`/`sin`); khái niệm con của 1 chủ đề đặt trên 1 cung
   (không phải cả vòng tròn) quay ra hướng ngược với môn, quanh **chính chủ
   đề đó** (không phải quanh môn). Kết quả lưu trong `Map<String, Offset>
   _positions`, tính 1 lần lúc `initState` (mỗi khi đổi môn — key đổi nên
   `State` mới, xem mục 4), sau đó **chỉ** đổi khi người dùng kéo tay 1 node.
2. **Vẽ cạnh**: `CustomPainter` (`_EdgePainter`) vẽ 1 đường thẳng cho mỗi
   `GraphEdgeData`, đọc toạ độ 2 đầu **trực tiếp từ `_positions` mỗi lần
   vẽ** — nên khi 1 node bị kéo, cạnh nối tới nó bám theo ngay trong cùng
   khung hình, không có độ trễ.
3. **Vẽ node**: mỗi `GraphNodeData` là 1 `Positioned` (toạ độ từ
   `_positions`) bọc `FractionalTranslation(translation: Offset(-0.5,
   -0.5))` để tâm đúng vào điểm toạ độ bất kể kích thước thật của thẻ (thẻ
   môn/pill chủ đề/pill khái niệm con dài ngắn khác nhau tuỳ nội dung), rồi
   `Tooltip` (hover) bọc `GestureDetector` (`onTap` để chọn, `onPanUpdate`
   để kéo — mỗi khung hình kéo chỉ `setState(() => _positions[id] += delta)`,
   an toàn vì không đụng gì tới việc tính lại bố cục), rồi mới tới
   `SubjectNodeCard` (widget "1 node trông như thế nào", không đổi so với
   trước).
4. **Pan/zoom + căn giữa**: `InteractiveViewer` (Flutter SDK) bọc quanh 1
   `SizedBox` cố định kích thước lớn (`constrained: false`) chứa `Stack` gồm
   lớp cạnh + lớp node ở trên. Căn giữa node môn lúc mở đồ thị bằng cách tự
   tính ma trận dịch chuyển cho `TransformationController` của chính
   `InteractiveViewer` này (không phải tham số đặc thù của package ngoài
   nữa) ngay sau khung hình vẽ đầu tiên (`addPostFrameCallback`, lúc đã biết
   kích thước khung nhìn thật).

---

## 6. Vì sao không (còn) dùng `graphview` hay thư viện đồ thị khác?

| Cách | Nhận xét |
|---|---|
| Tự vẽ bằng `CustomPaint`/widget Flutter chuẩn (**đã chọn**, Lần 5) | Không có "hộp đen" nào để đoán hành vi — mọi API dùng đều là Flutter SDK, có tài liệu đầy đủ. Với cấu trúc cây 3 tầng sẵn có, bố cục hình tia tính 1 lần còn đơn giản hơn hẳn so với việc cấu hình đúng 1 thuật toán lực hút/đẩy của package ngoài, và tránh hoàn toàn lớp lỗi mà `graphview` gặp phải (xem mục 0, Lần 5). |
| `graphview` (Lần 1–4, đã bỏ) | Có sẵn thuật toán bố cục lực hút/đẩy chuẩn (Fruchterman-Reingold), lúc đầu tưởng đỡ việc — nhưng có giới hạn kiến trúc nghiêm trọng (mọi `setState` trên trang đều làm nó chạy lại toàn bộ bố cục) chỉ lộ ra sau nhiều vòng vá không xong; đọc mã nguồn mới hiểu được. |
| Nhúng thư viện JS (D3.js, vis.js...) qua WebView | **Không** thuần Dart nữa — phải viết thêm JS và cầu nối WebView↔Dart, không hợp yêu cầu "chỉ dùng Dart". |

---

## 7. Vì sao dữ liệu chủ đề (`data/concepts/concepts.json`) là biên soạn thủ công, không phải trích xuất tự động?

Đây là điểm khác biệt lớn nhất so với 2 lần trước (`PrerequisiteParser`,
`ConceptExtractor`), cả 2 đều là **code chạy lúc app đang chạy**, đọc trực
tiếp `SubjectRecord` và tự tính ra kết quả. Bộ dữ liệu chủ đề hiện tại thì
**không**: nó là 1 file JSON tĩnh, được biên soạn 1 lần (ngoài app, lúc phát
triển tính năng), rồi chỉ đọc lại lúc chạy.

Lý do: yêu cầu ở Lần 3 (đồ thị phải nhiều thông tin, có cấu trúc phân cấp,
và hoạt động đúng với văn bản tiếng Việt lẫn tiếng Anh, chủ đề CS lẫn phi-CS)
vượt quá khả năng của regex/từ điển từ khoá — nó cần đọc hiểu ngữ nghĩa thật
sự của từng câu trong Mô tả/CLO. Nếu muốn làm việc này lúc app đang chạy,
sẽ cần gọi 1 mô hình ngôn ngữ (LLM) qua mạng cho mỗi môn — thêm phụ thuộc
mạng, độ trễ, và chi phí API vào 1 tính năng vốn chỉ cần đọc file JSON tĩnh.
Biên soạn sẵn 1 lần, đóng gói thành asset, giữ được đặc tính "chạy hoàn toàn
offline, không phụ thuộc mạng" của toàn bộ tính năng này — giống tinh thần
`data/subject/*.json` đã có sẵn.

**Đánh đổi**: khi FLM cập nhật Mô tả/CLO của 1 môn, `concepts.json` sẽ không
tự động cập nhật theo — phải biên soạn lại thủ công cho đúng môn đó. Đây là
đánh đổi chấp nhận được vì nội dung syllabus không đổi thường xuyên, và
`subject.description`/`learningOutcomes` (nguồn gốc) vẫn luôn hiện nguyên
văn trong `SubjectDetailPanel` để người dùng tự đối chiếu nếu nghi ngờ dữ
liệu chủ đề đã cũ.
