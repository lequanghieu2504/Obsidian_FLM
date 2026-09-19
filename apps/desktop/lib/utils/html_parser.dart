import 'package:html/parser.dart' as html_parser;
import '../models/subject.dart';

class HtmlParser {
  static List<Subject> parseCurriculumDetail(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final List<Subject> subjects = [];

    // Lấy bảng Môn học, có id='gvSubs'
    final table = document.getElementById('gvSubs');
    if (table == null) return subjects;

    final rows = table.getElementsByTagName('tr');
    
    // Bỏ qua dòng header (i = 0)
    for (int i = 1; i < rows.length; i++) {
      final tds = rows[i].getElementsByTagName('td');
      if (tds.length >= 5) {
        final code = tds[0].text.trim();
        final name = tds[1].text.trim();
        final semesterStr = tds[2].text.trim();
        final credits = tds[3].text.trim();
        final preRequisite = tds[4].text.trim();

        int semester = 0;
        try {
          semester = int.parse(semesterStr);
        } catch (_) {}

        subjects.add(Subject(
          semester: semester,
          code: code,
          name: name,
          credits: credits,
          preRequisite: preRequisite,
        ));
      }
    }

    return subjects;
  }
}
