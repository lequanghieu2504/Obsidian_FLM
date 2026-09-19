# Tài liệu review source code FLM Browser Extension

Tài liệu này mô tả chức năng của phần crawler trong `apps/extension`, trách nhiệm của từng file và cách các hàm đang xử lý dữ liệu. Mục tiêu là giúp review code mà không cần lần theo toàn bộ luồng bằng tay.

## 1. Phạm vi hiện tại

Extension hiện tại thực hiện các việc sau:

1. Kiểm tra tab hiện tại có phải trang `CurriculumDetails` hợp lệ hay không.
2. Chỉ bắt đầu crawl khi người dùng bấm nút **Crawl** trong popup.
3. Dùng session FLM hiện tại của trình duyệt qua `fetch(..., { credentials: "include" })`.
4. Đọc curriculum, PLO và danh sách môn học.
5. Lấy danh sách combo nhưng chỉ giữ combo thuộc họ `SE_COM`.
6. Đọc chi tiết từng combo `SE_COM` để lấy mã môn thật.
7. Gộp môn thường và môn trong combo, loại placeholder và trùng mã môn.
8. Tìm syllabus theo từng mã môn và chỉ crawl những syllabus có `IsActive` được check.
9. Giữ cả HTML gốc và JSON đã trích xuất.
10. Xuất một file `curriculum-<id>.flmpkg`, thực chất là ZIP không nén.

Extension **không tự crawl** khi đăng nhập, tải trang hoặc khởi động extension.

## 2. Kiến trúc và luồng giao tiếp

```text
Popup
  │
  ├── hỏi Content Script về tab hiện tại
  │      └── kiểm tra URL + cấu trúc CurriculumDetails
  │
  └── gửi lệnh cho Background Service Worker
         ├── START_CRAWL
         ├── GET_PROGRESS
         ├── CANCEL_CRAWL
         ├── RETRY_FAILED
         └── EXPORT_PACKAGE
                    │
                    ▼
             CrawlOrchestrator
                    │
                    ├── fetch trang FLM bằng session hiện tại
                    ├── chuyển HTML thành DOM
                    ├── gọi các extractor
                    └── gọi PackageBuilder để tạo .flmpkg
```

Phân chia trách nhiệm:

- `popup/`: giao diện và thao tác của người dùng.
- `content/`: phát hiện trang curriculum đang mở.
- `background/`: điều phối network crawl, trạng thái, retry, cancel và export.
- `extractors/`: chuyển DOM/HTML FLM thành dữ liệu có cấu trúc.
- `utils/`: logic dùng chung không phụ thuộc giao diện.
- `transport/`: đóng gói dữ liệu thành file.
- `types/`: hợp đồng kiểu dữ liệu giữa các phần.

## 3. Luồng crawl đầy đủ

Khi người dùng bấm **Crawl**, luồng xử lý là:

```text
CurriculumDetails?curid=<id>
  ├── metadata curriculum
  ├── PLO
  └── curriculum subjects
          │
          ▼
ViewComBo?cur_id=<id>
  └── chỉ giữ SE_COM
          │
          ▼
/Compo/Detail/<comboId>
  └── lấy subject code thật của từng combo
          │
          ▼
Gộp subject curriculum + combo subjects
  ├── bỏ SE_COM/PHE_COM placeholder
  └── deduplicate không phân biệt hoa thường
          │
          ▼
SyllabusManagement?searchOn=Code&keyword=<subjectCode>
  └── chỉ giữ row có IsActive checkbox được check
          │
          ▼
SyllabusDetails?sylID=<id>
  ├── lưu raw HTML
  └── trích xuất metadata + các bảng
          │
          ▼
curriculum-<id>.flmpkg
```

## 4. Giải thích từng file trong `src`

### 4.1. `src/background/index.ts`

Đây là entry point của Manifest V3 service worker. File tạo một instance duy nhất của `CrawlOrchestrator` và tiếp nhận message từ popup.

Các message được xử lý:

| Message | Xử lý |
|---|---|
| `GET_PROGRESS` | Gọi `crawler.getProgress()` và trả trạng thái hiện tại. |
| `CANCEL_CRAWL` | Gọi `crawler.cancel()` để abort request/delay đang chạy. |
| `START_CRAWL` | Gọi `crawler.start(curriculumId)`. Đây là điểm duy nhất bắt đầu crawl. |
| `RETRY_FAILED` | Gọi `crawler.retryFailed()` cho các subject bị lỗi. |
| `EXPORT_PACKAGE` | Gọi `crawler.buildPackage()`, đổi Blob thành data URL và tải file qua `chrome.downloads.download`. |

Với các nhánh bất đồng bộ, listener trả `true` để giữ `sendResponse` hoạt động sau khi Promise hoàn tất.

Phần export chia byte thành block `0x8000` trước khi gọi `String.fromCharCode`. Việc chia block tránh truyền một mảng quá lớn vào một lần gọi hàm.

### 4.2. `src/background/crawl-orchestrator.ts`

Đây là bộ điều phối chính. File này không tự parse chi tiết cấu trúc FLM mà chuyển việc đó cho các extractor.

#### Hằng số và helper

- `FLM`: origin cố định `https://flm.fpt.edu.vn`.
- `delay(ms, signal)`: chờ giữa các request. Nếu có cancel, timer được xóa và Promise bị reject ngay.
- `Source`: giữ `html` gốc và URL cuối cùng sau redirect.
- `FailedSubject`: giữ `code` môn lỗi và lý do lỗi.

#### State trong `CrawlOrchestrator`

- `controller`: `AbortController` của crawl hiện tại.
- `sources`: map từ đường dẫn trong package sang HTML gốc.
- `curriculum`: curriculum JSON đã extract.
- `combos`: danh sách tóm tắt combo `SE_COM`.
- `comboDetails`: chi tiết từng combo.
- `syllabi`: chi tiết các syllabus active.
- `failedSubjects`: các subject thất bại để retry.
- `progress`: trạng thái dùng để popup hiển thị.

State này chỉ nằm trong bộ nhớ của service worker, chưa phải persistent resume system.

#### `constructor(requestDelayMs = 400, retries = 2)`

Cho phép cấu hình:

- khoảng nghỉ mặc định giữa request là 400 ms;
- retry tối đa 2 lần sau lần request đầu tiên.

Crawler chạy tuần tự, không crawl nhiều syllabus cùng lúc.

#### `getProgress()`

Trả một bản sao nông của `progress`. Popup không nhận trực tiếp object state nội bộ.

#### `cancel()`

Gọi `AbortController.abort()` với lỗi `AbortError`. Signal này được dùng cho cả `fetch` và `delay`, nên có thể dừng ở cả hai trạng thái.

#### `start(curriculumId)`

Đây là hàm chạy toàn bộ crawl:

1. Abort crawl cũ nếu đang có.
2. Tạo controller mới và xóa dữ liệu của session crawl trước.
3. Đặt progress thành `crawling`.
4. Fetch trang curriculum.
5. Parse HTML bằng `linkedom` và gọi `extractCurriculum()`.
6. Kiểm tra tối thiểu curriculum phải có `curriculumCode` hoặc subject.
7. Lưu HTML curriculum vào `raw/curriculum.html`.
8. Fetch trang `ViewComBo`.
9. Gọi `extractComboList()`; extractor tự bỏ PHE và combo không thuộc `SE_COM`.
10. Crawl tuần tự từng link combo thật do FLM trả về.
11. Gọi `extractComboDetail()` và lưu raw HTML từng combo.
12. Gộp curriculum subjects với combo subjects.
13. Gọi `uniqueRealSubjectCodes()` để bỏ placeholder và trùng mã.
14. Gọi `crawlSubjects()` để xử lý syllabus.
15. Cập nhật trạng thái `complete`, `cancelled` hoặc `error`.
16. Trong `finally`, cập nhật quyền export/retry và xóa current subject.

Nếu lỗi ở cấp curriculum hoặc combo làm văng ra khỏi `try`, toàn crawl chuyển sang `error`. Lỗi riêng từng subject được `crawlSubjects()` giữ lại để retry thay vì làm dừng toàn bộ crawl.

#### `retryFailed()`

Chỉ chạy khi đã có curriculum và có subject lỗi:

1. Lấy danh sách code từ `failedSubjects`.
2. Xóa danh sách lỗi cũ.
3. Tạo `AbortController` mới.
4. Gọi lại `crawlSubjects()` chỉ với các code từng lỗi.
5. Cập nhật lại `failed`, `canRetry` và trạng thái cuối.

#### `buildPackage()`

Tạo một `PackageBuilder` và thêm:

- toàn bộ HTML trong `sources`;
- `extracted/curriculum.json`;
- `extracted/combos.json`;
- một JSON cho mỗi combo detail;
- một JSON cho mỗi syllabus;
- `manifest.json` mô tả version, curriculum, số lượng và failure.

Nếu chưa có curriculum, hàm throw để ngăn export package rỗng.

#### `crawlSubjects(subjects)`

Xử lý từng subject theo thứ tự:

1. Kiểm tra cancel trước mỗi subject.
2. Cập nhật `currentSubject`.
3. Fetch `SyllabusManagement` với code đã `encodeURIComponent`.
4. Gọi `extractSyllabusResults()`.
5. Lọc `item.isActive`; không bắt buộc `isApproved`.
6. Với mỗi active syllabus, kiểm tra raw path để tránh request trùng syllabus ID.
7. Fetch detail, lưu raw HTML và gọi `extractSyllabusDetail()`.
8. Tăng `completed` khi xử lý subject thành công.
9. Nếu lỗi, lưu code/reason vào `failedSubjects` và tiếp tục subject kế tiếp.

Nếu một subject có nhiều syllabus active, tất cả version active đều được giữ.

#### `document(source)`

Dùng `parseHTML` của `linkedom` để tạo DOM trong service worker. Chrome service worker không có sẵn `DOMParser` như trang web, vì vậy parser được bundle vào background.

#### `fetchPage(url)`

Là cổng network chung của crawler:

1. Kiểm tra abort.
2. Chờ delay bảo thủ trước request tiếp theo/retry.
3. Fetch với `credentials: "include"`, `redirect: "follow"` và abort signal.
4. Dừng ngay với HTTP `401`, `403`, `429`.
5. Retry các lỗi HTTP/network khác trong giới hạn cấu hình.
6. Đọc HTML và giữ URL cuối sau redirect.
7. Gọi `isAuthenticationPage()` để không lưu nhầm trang login.
8. Trả `{ html, url }` nếu hợp lệ.

Các lỗi authentication, 401, 403 và 429 không được retry vì chúng cần người dùng xử lý hoặc cần dừng để tránh request mạnh hơn.

### 4.3. `src/content/flm-content-script.ts`

Content script chỉ phát hiện trang hiện tại; nó không chạy network crawl.

#### `detectPage()`

Kiểm tra lần lượt:

1. Origin phải đúng `https://flm.fpt.edu.vn`.
2. Path phải đúng `/gui/role/student/CurriculumDetails`.
3. Query `curid` phải tồn tại và chỉ gồm chữ số.
4. Gọi `extractCurriculum(document, curriculumId)` trên DOM đang hiển thị.
5. Trang chỉ được xem là hợp lệ khi tìm được curriculum code hoặc ít nhất một subject.

Kết quả trả về gồm `valid`, `curriculumId`, `curriculumCode`, `curriculumName`.

Message listener chỉ trả kết quả khi nhận `DETECT_CURRICULUM_PAGE` từ popup.

### 4.4. `src/extractors/dom.ts`

Đây là bộ helper dùng chung cho mọi extractor. Mục đích là tránh phụ thuộc vào số thứ tự cố định của table/cột.

#### `DocumentFactory`

Type alias cho một hàm nhận HTML và trả `Document`. Hiện chưa được dùng trực tiếp.

#### `clean(value)`

- biến `null`/`undefined` thành chuỗi rỗng;
- gộp mọi khoảng trắng liên tiếp thành một dấu cách;
- trim đầu/cuối.

Hàm giúp text lấy từ HTML ổn định hơn khi FLM có xuống dòng hoặc spacing khác nhau.

#### `normalizeHeader(value)`

Gọi `clean()`, chuyển chữ thường và bỏ ký tự không phải chữ/số. Ví dụ `Subject Code` và `Subject-Code` đều thành `subjectcode`.

#### `cells(row)`

Lấy trực tiếp các `th`/`td` con của một row bằng `:scope`, tránh lấy nhầm cell từ table lồng bên trong.

#### `tableHeaders(table)`

Ưu tiên row đầu trong `thead`; nếu không có thì dùng `tr` đầu tiên. Kết quả header được normalize.

#### `findTable(document, requiredHeaders)`

Duyệt các table và trả table đầu tiên chứa đầy đủ các header bắt buộc. Đây là cơ chế signature-based table detection.

#### `headerIndex(headers, ...names)`

Tìm index của một cột theo nhiều tên thay thế, ví dụ `Credits` hoặc `Credit`. Trả `-1` nếu không tìm thấy.

#### `dataRows(table)`

Bỏ row đầu được coi là header, sau đó chỉ giữ row có ít nhất một cell có text.

#### `extractLabelValues(document)`

Trích xuất metadata dạng key-value từ hai kiểu HTML:

- table row có đúng hai cell;
- cặp `<dt>` và element kế tiếp, thường là `<dd>`.

Dấu `:` cuối label được loại bỏ. Kết quả là `Record<string, string>`.

#### `lookup(values, ...labels)`

Tìm value trong record metadata bằng label đã normalize. Hỗ trợ nhiều tên tương đương.

### 4.5. `src/extractors/auth.ts`

File phát hiện response có phải trang authentication hay không.

#### `isAuthenticationPage(document, responseUrl?)`

Hàm không dùng broad text matching như tìm chữ `login` trong toàn trang. Nó kiểm tra cấu trúc:

1. URL có path login/signin trực tiếp hoặc dạng `/account/login`, `/auth/signin`.
2. DOM có password input.
3. Password input nằm trong form.
4. Form có input nhận dạng user/email.
5. Form có submit button.

Nếu URL là login và có password input, kết luận ngay là auth page. Nếu URL không rõ, hàm chỉ kết luận login khi có một login form đủ cấu trúc.

### 4.6. `src/extractors/curriculum.ts`

File parse trang `CurriculumDetails`.

#### `isComboPlaceholder(code)`

Nhận diện placeholder tổng quát theo mẫu `<FAMILY>_COM`, ví dụ:

- `SE_COM*1`;
- `SE_COM*4_ELE`;
- `PHE_COM*1`.

#### `isSeComboPlaceholder(code)`

Chỉ nhận diện placeholder thuộc họ `SE_COM`. Hàm này chủ yếu phục vụ kiểm tra/phân loại; logic loại toàn bộ placeholder khi thu subject dùng `isComboPlaceholder()`.

#### `extractCurriculum(document, curriculumId)`

Xử lý ba nhóm dữ liệu:

**Metadata**

- Dùng `extractLabelValues()` để lấy các cặp label/value.
- Map sang `curriculumCode`, `name`, `englishName`, `description`, `decision`.
- `curriculumId` lấy từ URL do caller truyền vào.

**PLO**

- Tìm table có header `PLO`.
- Tìm cột code và description theo nhiều tên header.
- Nếu thiếu cột description, fallback sang cell ngay sau code.
- Chỉ thêm PLO khi code không rỗng.

**Subjects**

- Tìm table có `Subject Code` và `Subject Name`.
- Trích xuất code, name, semester, credits, prerequisite/note.
- Đánh dấu `isPlaceholder` bằng `isComboPlaceholder()`.
- Giữ nguyên casing của subject code do FLM cung cấp.

Nếu table không tồn tại, hàm trả mảng rỗng thay vì throw; caller quyết định cấu trúc đó có hợp lệ cho ngữ cảnh hiện tại hay không.

### 4.7. `src/extractors/combo.ts`

File xử lý trang combo list và combo detail.

#### `isSeCombo(code)`

Kiểm tra combo code thuộc họ `SE_COM`, ví dụ `SE_COM5.2`, `SE_COM7.1`, `SE_COM9`. Không nhận PHE hoặc family khác.

#### `extractComboList(document, baseUrl)`

1. Tìm table bằng header `Combo ID` + `Combo Name`, fallback table chỉ có `Combo Name`.
2. Với từng row, tìm actual link chứa `/Compo/Detail/`.
3. Lấy combo ID từ path thay vì tự dựng ID.
4. Lấy combo name và tìm code `SE_COM...` trong name; nếu không có thì fallback sang cột ID.
5. Bỏ row không có link hợp lệ hoặc không thuộc `SE_COM`.
6. Dùng `new URL(relativeHref, baseUrl)` để tạo URL tuyệt đối nhưng vẫn giữ href FLM cung cấp.

Kết quả mỗi item gồm `id`, `code`, `name`, `href`.

#### `extractComboDetail(document, id)`

1. Lấy metadata `Combo Name` và `Note` từ key-value structure.
2. Tìm subject table bằng `Subject Code` + `Subject Name`.
3. Trích xuất code, name, semester và note cho từng row.
4. Giữ nguyên casing mã môn, ví dụ `PRP201c`.
5. Đặt `isPlaceholder: false` vì subject trong combo detail là môn thật theo dữ liệu đã xác nhận.

Hàm không tự suy diễn mapping giữa `SE_COM*1` và một môn cụ thể.

### 4.8. `src/extractors/syllabus.ts`

File xử lý kết quả tìm syllabus và trang syllabus detail.

#### `checked(row, cellIndex)`

Helper private đọc checkbox trong một cell. Kết quả là true nếu:

- property `input.checked` là true; hoặc
- HTML có attribute `checked`.

Hàm không đọc `innerText`, vì checkbox không biểu diễn trạng thái checked bằng text.

#### `extractSyllabusResults(document, baseUrl)`

1. Tìm result table qua header `IsActive` hoặc `Is Active`.
2. Xác định index các cột active, approved, code và name.
3. Với từng row, tìm link `SyllabusDetails`.
4. Lấy `sylID` từ query string trong href.
5. Tạo absolute URL từ href thật.
6. Parse riêng `isActive` và `isApproved` bằng checkbox state.

Hàm trả cả active và inactive rows. Việc chỉ crawl active nằm trong orchestrator, tại `.filter(item => item.isActive)`. `IsApproved` được lưu nhưng không dùng làm điều kiện crawl.

#### `extractSyllabusDetail(document, id)`

Hiện đây là extractor tổng quát:

- `metadata`: mọi cặp key-value tìm được bởi `extractLabelValues()`;
- `sections`: mỗi table trở thành một section;
- `heading`: text của element ngay trước table, hoặc fallback `Table N`;
- `headers`: danh sách header đã normalize;
- `rows`: toàn bộ cell text đã clean.

Raw HTML vẫn được giữ riêng nên extractor này có thể được cải tiến sau mà không cần crawl lại.

### 4.9. `src/utils/subjects.ts`

#### `uniqueRealSubjectCodes(subjects)`

Tạo danh sách mã môn thật để crawl syllabus:

1. Trim subject code.
2. Chuyển code sang lowercase chỉ để tạo comparison key.
3. Bỏ code rỗng.
4. Bỏ mọi combo placeholder qua `isComboPlaceholder()`; vì vậy cả `SE_COM` và `PHE_COM` đều không được tìm syllabus.
5. Bỏ code trùng không phân biệt hoa thường.
6. Giữ casing của lần xuất hiện đầu tiên trong kết quả.

Ví dụ `PRP201c` và `prp201C` chỉ tạo một request, kết quả giữ `PRP201c` nếu nó xuất hiện trước.

### 4.10. `src/transport/package-builder.ts`

File tự tạo ZIP store-mode để không phụ thuộc thư viện ZIP runtime. Dữ liệu không được nén nhưng tuân theo cấu trúc ZIP và dùng extension `.flmpkg`.

#### `crc32(bytes)`

Tính CRC-32 của nội dung file. ZIP reader dùng giá trị này để kiểm tra integrity.

#### `write16(view, offset, value)` và `write32(...)`

Ghi số 16-bit/32-bit theo little-endian vào ZIP binary headers.

#### State `files`

`Map<string, Uint8Array>` giữ path và nội dung. Map giúp một path chỉ có một phiên bản; thêm lại cùng path sẽ ghi đè nội dung cũ.

#### `addText(path, contents)`

Encode UTF-8 bằng `TextEncoder` và lưu vào map.

#### `addJson(path, value)`

Serialize JSON với indentation 2 spaces, thêm newline cuối file, sau đó gọi `addText()`.

#### `build()`

Với mỗi file, hàm tạo:

1. local file header;
2. UTF-8 filename;
3. raw file content;
4. central directory entry.

Sau tất cả file, hàm thêm End of Central Directory record và trả `Blob` MIME `application/zip`.

ZIP method là `0` tức store/no compression. Điều này giữ code nhỏ và rõ ràng, đổi lại package lớn hơn ZIP có compression.

### 4.11. `src/types/models.ts`

File định nghĩa hợp đồng dữ liệu:

| Type | Ý nghĩa |
|---|---|
| `CurriculumMetadata` | ID, code, tên, tên tiếng Anh, description, decision. |
| `Plo` | Mã PLO và description. |
| `CurriculumSubject` | Code, tên, kỳ, tín chỉ, prerequisite/note và cờ placeholder. |
| `CurriculumData` | Metadata + PLO + subjects của curriculum. |
| `ComboSummary` | Combo ID/code/name và actual detail URL. |
| `ComboDetail` | Metadata combo và các subject thật bên trong. |
| `SyllabusSummary` | Kết quả search, gồm active/approved checkbox states. |
| `SyllabusData` | Metadata và các table section từ syllabus detail. |
| `CrawlProgress` | Trạng thái phục vụ popup và các cờ cho phép retry/export. |

Các field không chắc chắn xuất hiện trên mọi trang được đánh dấu optional. Code không tự tạo dữ liệu khi FLM thiếu field.

### 4.12. `src/popup/popup.ts`

Đây là logic UI của popup, không trực tiếp fetch FLM.

#### `Detection`

Type nội bộ lưu kết quả content script trả về: trang có hợp lệ không, ID/code/name curriculum.

#### `element<T>(id)`

Helper lấy DOM element và cast sang type cụ thể, giúp code thao tác button/text ngắn hơn.

#### Các biến button

`crawl`, `cancel`, `retry`, `exportButton` giữ reference tới bốn action button.

#### `render(progress)`

Cập nhật UI:

- curriculum code/name/ID;
- số SE combo;
- số unique subject;
- completed/failed;
- subject hiện tại hoặc trạng thái crawl;
- error message;
- enabled/disabled state của từng button.

Khi status là `crawling`, hàm tạo interval gọi `refresh()` mỗi 500 ms. Khi crawl kết thúc, interval được dừng.

#### `refresh()`

Gửi `GET_PROGRESS` cho background và render kết quả.

#### `initialize()`

1. Lấy active tab hiện tại.
2. Gửi `DETECT_CURRICULUM_PAGE` cho content script.
3. Nếu tab không có content script hoặc message lỗi, xem là invalid.
4. Hiển thị curriculum detected hoặc hướng dẫn mở trang Curriculum Details.
5. Lấy progress hiện tại từ background.

#### Event listeners

- Crawl gửi `START_CRAWL` kèm detected curriculum ID.
- Cancel gửi `CANCEL_CRAWL`.
- Retry gửi `RETRY_FAILED`.
- Export gửi `EXPORT_PACKAGE`.

Cuối file gọi `initialize()`. Việc khởi tạo popup chỉ detect trang và đọc progress, không tự gửi `START_CRAWL`.

## 5. Các file hỗ trợ ngoài `src`

### `popup.html`

Khai báo UI tối thiểu của popup: thông tin curriculum, combo, subject, progress, current item, error và bốn button.

### `src/popup/popup.css`

Style tối thiểu cho popup; chưa phải polished UI. Có hỗ trợ color scheme sáng/tối theo trình duyệt.

### `manifest.json` và `public/manifest.json`

Khai báo Manifest V3:

- service worker `background.js`;
- popup `popup.html`;
- content script trên domain FLM;
- `host_permissions` chỉ cho `https://flm.fpt.edu.vn/*`;
- permissions `activeTab`, `downloads`, `storage`.

`public/manifest.json` được Vite copy vào `dist/`. Hai manifest hiện cần được giữ đồng bộ khi sửa cấu hình extension.

### `vite.config.ts`

Build ba entry:

- background service worker;
- content script;
- popup HTML/TypeScript/CSS.

Output chính được đặt tên ổn định là `background.js`, `content.js`, `popup.js` để khớp manifest.

### `package.json`

Scripts:

- `test`: chạy Vitest;
- `typecheck`: chạy TypeScript không emit;
- `build`: build production bằng Vite.

Dependencies chính:

- `linkedom`: parse HTML trong service worker;
- `vitest`: test runner;
- Vite/TypeScript và Chrome types.

### `test/extractors.test.ts`

Test fixture HTML nhỏ cho:

- metadata curriculum;
- PLO;
- curriculum subjects;
- `SE_COM`/`PHE_COM` placeholder;
- combo list và lọc `SE_COM`;
- combo detail và mixed-case subject code;
- deduplication;
- active/approved checkbox state;
- active syllabus filtering;
- authentication page detection;
- missing table;
- ZIP package signature.

## 6. Cấu trúc package xuất ra

```text
curriculum-3335.flmpkg
├── manifest.json
├── raw/
│   ├── curriculum.html
│   ├── combo-list.html
│   ├── combo-details/
│   │   └── <comboId>.html
│   └── syllabi/
│       └── <syllabusId>.html
└── extracted/
    ├── curriculum.json
    ├── combos.json
    ├── combo-details/
    │   └── <comboId>.json
    └── syllabi/
        └── <syllabusId>.json
```

`manifest.json` trong package hiện có:

- `format`;
- package `version`;
- `createdAt`;
- FLM source origin;
- curriculum ID;
- số combo, syllabus, failed subjects;
- danh sách failure và lý do.

## 7. Các điểm nên chú ý khi review

1. **Selector/header thực tế của FLM:** extractor đã hỗ trợ một số biến thể header, nhưng vẫn cần so với HTML thật của nhiều curriculum.
2. **Syllabus detail:** hiện được extract tổng quát thành metadata và table; chưa có model sâu riêng cho learning outcomes, sessions, assessments hoặc materials.
3. **Service worker state:** dữ liệu crawl chỉ ở memory. Nếu service worker bị trình duyệt terminate thì không có persistent resume.
4. **Export data URL:** package được đổi toàn bộ sang Base64 data URL trước khi download; package rất lớn sẽ tốn thêm memory.
5. **ZIP không nén:** package hợp lệ nhưng kích thước lớn hơn ZIP compressed.
6. **Missing syllabus result table:** extractor trả mảng rỗng, nên hiện chưa phân biệt rõ “không có syllabus” với “FLM đổi cấu trúc table”.
7. **Hai manifest:** `manifest.json` và `public/manifest.json` đang trùng nội dung, nên có rủi ro lệch nhau khi chỉnh sửa sau này.
8. **Progress semantics:** `completed` đang tính số subject search đã xử lý thành công, không phải số syllabus detail tải được.
9. **Combo detail malformed:** nếu không tìm thấy subject table, extractor trả combo có `subjects: []`; hiện chưa đánh dấu đây là lỗi cấu trúc.
10. **Actual FLM validation:** cần load `dist/` dưới dạng unpacked extension và thử với session FLM thật để xác nhận redirect, table signatures và download package.

## 8. Checklist chạy lại khi review

Từ thư mục `apps/extension`:

```sh
npm test
npm run typecheck
npm run build
```

Sau đó:

1. Load thư mục `dist/` bằng chức năng **Load unpacked** của Chrome/Edge.
2. Đăng nhập FLM thủ công.
3. Mở trang `CurriculumDetails?curid=<id>`.
4. Mở popup và kiểm tra ID/code/name.
5. Bấm Crawl và theo dõi combo count, subject count, current subject, completed/failed.
6. Thử Cancel rồi Retry Failed.
7. Export `.flmpkg` và mở bằng ZIP tool.
8. Kiểm tra HTML raw không phải login page.
9. Kiểm tra JSON giữ đúng casing và nội dung học thuật từ FLM.
