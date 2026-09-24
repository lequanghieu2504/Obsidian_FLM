String buildStudyRoadmapRequest({
  required String subjectCode,
  required List<String> fileNames,
}) {
  final attachments = fileNames.isEmpty
      ? 'bảng điểm tôi sẽ cung cấp'
      : fileNames.join(', ');
  return '''Hãy phân tích bảng điểm đính kèm ($attachments) và xây dựng lộ trình học cá nhân hóa cho môn $subjectCode.

Yêu cầu:
1. Trích xuất các môn, điểm và kết quả liên quan từ bảng điểm. Đánh dấu rõ thông tin nào không đọc được hoặc chưa chắc chắn; không tự suy đoán điểm bị thiếu.
2. Đối chiếu nền tảng hiện tại với môn $subjectCode, prerequisite, CLO, session plan, hình thức đánh giá và tài liệu trong syllabus.
3. Xác định kiến thức đã vững, lỗ hổng cần bổ sung và mức độ ưu tiên.
4. Tạo lộ trình theo tuần gồm mục tiêu, chủ đề, tài liệu, bài tập thực hành, thời lượng dự kiến và tiêu chí hoàn thành.
5. Thêm các mốc tự đánh giá và cách điều chỉnh kế hoạch nếu kết quả chưa đạt.

Trình bày ngắn gọn bằng tiếng Việt, dùng bảng khi phù hợp. Nếu bảng điểm chưa đủ để cá nhân hóa, hãy hỏi tôi các thông tin còn thiếu trước khi kết luận.''';
}
