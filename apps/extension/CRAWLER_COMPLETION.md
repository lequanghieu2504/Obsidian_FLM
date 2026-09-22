# Biên bản hoàn thành FLM Crawler

**Trạng thái: Hoàn thành — đã triển khai MVP và nghiệm thu bằng dữ liệu thật của curriculum `3335`.**

## 1. Mục đích

Tài liệu này dùng để nghiệm thu các hạng mục còn lại của FLM crawler trong `apps/extension/`. Phạm vi chỉ bao gồm browser extension thu thập dữ liệu FLM và xuất package; không bao gồm Flutter import, Markdown, knowledge graph, RAG, embeddings hoặc hệ thống resume lâu dài.

## 2. Các ràng buộc đã thống nhất

- Một curriculum dự kiến có khoảng 100–150 môn; crawler tuần tự và xử lý package trong bộ nhớ đáp ứng phạm vi MVP.
- Nếu phiên đăng nhập FLM hết hạn, người dùng đăng nhập lại rồi crawl/retry. Không yêu cầu tự đăng nhập hoặc khôi phục crawl sau khi trình duyệt khởi động lại.
- Cho phép export package chưa đầy đủ để kiểm tra, nhưng manifest phải ghi rõ `partial`, `error` hoặc `cancelled`. Package thiếu dữ liệu không được giả là hoàn chỉnh.
- Các môn không có active syllabus trên FLM phải được ghi rõ trong danh sách lỗi, không được bỏ qua âm thầm.

## 3. Luồng crawler đã hoàn thành

1. Popup nhận diện trang Curriculum Details hoặc Combo Management hợp lệ.
2. Crawler chỉ bắt đầu khi người dùng bấm **Start crawl**.
3. Background worker tải Curriculum Details bằng phiên đăng nhập FLM hiện tại.
4. Extractor lấy metadata, PLO, danh sách môn và các combo placeholder.
5. Crawler tải combo list, chỉ giữ `SE_COM`, rồi tải từng combo detail.
6. Các mã môn thật từ curriculum và combo được gộp và loại trùng, không làm thay đổi kiểu chữ gốc.
7. Crawler tìm syllabus theo mã môn và chỉ tải các phiên bản active.
8. Mỗi nguồn được giữ dưới hai dạng: raw HTML và extracted JSON.
9. Toàn bộ dữ liệu được đóng gói thành một file ZIP-compatible `.flmpkg`.

### Hỗ trợ role

- [x] Nhận diện cả `/gui/role/student/CurriculumDetails` và `/gui/role/guest/CurriculumDetails`.
- [x] Role được truyền từ content script qua popup đến background worker.
- [x] CurriculumDetails và SyllabusManagement sử dụng đúng role đã nhận diện.
- [x] Khi mở Combo Management, role được suy ra từ các link role trên trang; mặc định an toàn là `student` nếu không tìm thấy.
- [x] Role được ghi vào `manifest.json` để package thể hiện nguồn crawl.

## 4. Hạng mục 1 — số tín chỉ

### Yêu cầu

FLM thật sử dụng header `NoCredit`, trong khi một số trang/fixture có thể sử dụng `Credit`, `Credits` hoặc `No Credit`.

### Kết quả

- [x] Hỗ trợ `NoCredit`, `No Credit`, `Credit` và `Credits`.
- [x] Giữ nguyên giá trị FLM, không tự chuyển đổi hoặc tự suy diễn.
- [x] Có unit test sử dụng đúng header trên trang FLM thật.

## 5. Hạng mục 2 — phát hiện combo bị parse thiếu

### Yêu cầu

Không được báo crawl hoàn tất nếu curriculum có `SE_COM` nhưng combo list hoặc combo detail không parse được.

### Kết quả

- [x] Nếu curriculum có `SE_COM` placeholder nhưng không parse được SE combo, crawler báo lỗi cấu trúc rõ ràng.
- [x] Nếu combo detail không có bảng môn hợp lệ, crawler báo mã combo và combo ID.
- [x] Raw combo detail vẫn được giữ để phục vụ kiểm tra lỗi.
- [x] Curriculum thực sự không có SE combo vẫn được chấp nhận.
- [x] Có unit test cho cả combo list rỗng bất thường và combo detail rỗng.

## 6. Hạng mục 3 — tính toàn vẹn của package

### Trạng thái package

Manifest hỗ trợ bốn trạng thái:

- `complete`: crawl hoàn tất và không có môn lỗi.
- `partial`: crawl hoàn tất nhưng một số môn không có hoặc không tải được active syllabus.
- `cancelled`: người dùng hủy crawl.
- `error`: lỗi cấp curriculum, combo hoặc orchestration.

### Kết quả

- [x] `manifest.json` chứa trạng thái cuối cùng.
- [x] Lỗi cấp toàn crawl được lưu trong field `error`.
- [x] Lỗi từng môn được lưu dạng `{ code, reason }`.
- [x] Package có môn lỗi không được đánh dấu `complete`.
- [x] Popup hiển thị **Export partial** khi package chưa hoàn chỉnh.
- [x] Có unit test cho cả bốn trạng thái package.

## 7. Hạng mục 4 — không làm mất nội dung học thuật

### Nguyên tắc

Raw HTML là nguồn dữ liệu gốc không mất mát. Extracted JSON phải giữ được thông tin có ý nghĩa kể cả khi FLM biểu diễn dữ liệu bằng form control thay vì text.

### Dữ liệu được giữ

- [x] Metadata curriculum, mô tả đầy đủ, DecisionNo và các action link.
- [x] PLO code và PLO description.
- [x] Subject code, subject name, semester, credits và prerequisite/note.
- [x] Checkbox/radio gồm cả `true` và `false`.
- [x] Input value, textarea, selected option và link.
- [x] Các field tồn tại nhưng FLM để trống được giữ với giá trị `""`.
- [x] Bảng không có header không bị mất dòng đầu tiên.
- [x] Syllabus vẫn có `rows` dạng text đơn giản và `richRows` chứa text, controls và links đầy đủ.

### Kiểm thử liên quan

Fixture đã kiểm tra:

- `IsScored` được check.
- Checkbox không được check.
- Credit input.
- Textarea.
- Select option.
- Link và URL tuyệt đối.
- Field có nhãn nhưng giá trị rỗng.

## 8. Hạng mục 5 — nghiệm thu end-to-end

### Package được nghiệm thu

- Curriculum ID: `3335`
- Curriculum code: `BIT_SE_K18D_19A`
- File kiểm tra: `curriculum-3335 (2).zip`
- Kết quả kiểm tra ZIP: hợp lệ, không có entry bị hỏng.

### Kết quả dữ liệu curriculum

- [x] 48 curriculum subjects.
- [x] Tất cả subject có key semester, credits và prerequisite.
- [x] 13 PLO với đầy đủ code và description.
- [x] DecisionNo: `1140/QĐ-ĐHFPT dated 09/11/2026`.
- [x] Có đủ `View PO`, `View Combo`, `View Elective`.

### Kết quả dữ liệu combo

- [x] 12 SE combo trong combo list.
- [x] 12 combo detail tương ứng.
- [x] Tổng cộng 46 subject rows trong combo details.
- [x] Không có combo detail rỗng.
- [x] Không crawl PHE combo hoặc combo family không liên quan.

### Kết quả dữ liệu syllabus

- [x] 84 syllabus JSON.
- [x] 84 raw syllabus HTML tương ứng một-một.
- [x] Không có syllabus thiếu sections.
- [x] Không có syllabus thiếu Subject Code metadata.
- [x] Tất cả syllabus có `richRows`.
- [x] Không lưu nhầm trang đăng nhập.
- [x] Giữ lại 112 field có nhãn nhưng FLM để giá trị rỗng.

### Các môn đã spot-check

Môn curriculum thông thường:

- `CEA201`
- `PRF192`
- `CSD201`

Môn đến từ combo:

- `PRP201c`
- `DPL303m`
- `AIL304m`

Các field được đối chiếu gồm `NoCredit`, `Is Scored` và `IsActive`.

### Sáu môn không có active syllabus

Manifest được đánh dấu `partial` vì FLM không trả về active syllabus cho:

1. `PEN`
2. `TMI_ELE`
3. `SE_GRA_ELE`
4. `PRC392m`
5. `ASP301`
6. `DSO391`

Đây là tình trạng dữ liệu nguồn trên FLM, không phải crawler bỏ sót. Cả mã môn và lý do `No active syllabus found` đều được ghi trong manifest và hiển thị trong popup.

## 9. Kết quả kiểm thử kỹ thuật

- [x] 17/17 unit tests pass.
- [x] TypeScript typecheck pass.
- [x] Production build pass.
- [x] `dist/content.js` không chứa ESM `import`, phù hợp với Manifest V3 classic content script.
- [x] Package có ZIP signature hợp lệ và giải nén thành công.
- [x] Không có lỗi whitespace từ `git diff --check`.

## 10. Tiêu chí hoàn thành

Crawler được xem là hoàn thành khi:

- Các hạng mục 1–4 đã được triển khai và có kiểm thử.
- Automated checks đều pass.
- Có ít nhất một lượt crawl bằng phiên FLM thật.
- Package thật được giải nén và đối chiếu raw/extracted.
- Mọi dữ liệu thiếu đều được báo rõ, không bị bỏ qua âm thầm.

Tất cả tiêu chí trên đã đạt.

## 11. Kết luận nghiệm thu

**FLM browser-extension crawler MVP đã hoàn thành và đủ điều kiện nghiệm thu trong phạm vi đã thống nhất.**

Package thật của curriculum `3335` đã chứng minh crawler có thể thu thập curriculum, PLO, SE combo, subject và active syllabus; giữ raw HTML cùng extracted JSON; báo rõ dữ liệu không có trên FLM; và xuất một package duy nhất phục vụ bước import ở giai đoạn sau.
