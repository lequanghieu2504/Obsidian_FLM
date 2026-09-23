import 'dart:io';
import 'dart:convert';
import 'package:html/parser.dart' as parser;
import '../models/transcript.dart';

class TranscriptParser {
  /// Giải mã file UTF-16LE sang chuỗi String
  static String _decodeUtf16Le(List<int> bytes) {
    int start = 0;
    // Bỏ qua BOM nếu có (0xFF 0xFE)
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      start = 2;
    }

    StringBuffer sb = StringBuffer();
    for (int i = start; i < bytes.length; i += 2) {
      if (i + 1 < bytes.length) {
        int charCode = bytes[i] | (bytes[i + 1] << 8);
        sb.writeCharCode(charCode);
      }
    }
    return sb.toString();
  }

  /// Phân tích file điểm từ FAP
  static Future<List<TranscriptRecord>> parseTranscript(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // File của FAP thực chất là HTML dạng UTF-16LE
    String htmlString = _decodeUtf16Le(bytes);

    final document = parser.parse(htmlString);
    final rows = document.querySelectorAll('tbody tr');

    List<TranscriptRecord> records = [];

    for (var row in rows) {
      final tds = row.querySelectorAll('td');
      if (tds.length == 7) {
        // Table Prep/OJT
        final no = int.tryParse(tds[0].text.trim()) ?? 0;
        final semester = tds[1].text.trim();
        final subjectCode = tds[2].text.trim();
        final subjectName = tds[3].text.trim();
        final credit = int.tryParse(tds[4].text.trim()) ?? 0;
        final grade = tds[5].text.trim();
        final status = tds[6].text.trim();

        records.add(TranscriptRecord(
          no: no,
          semester: semester,
          subjectCode: subjectCode,
          subjectName: subjectName,
          credit: credit,
          grade: grade,
          status: status,
        ));
      } else if (tds.length >= 10) {
        // Main Curriculum table (usually 11 columns)
        final no = int.tryParse(tds[0].text.trim()) ?? 0;
        final semester = tds[2].text.trim();
        final subjectCode = tds[3].text.trim();
        final subjectName = tds[6].text.trim();
        final credit = int.tryParse(tds[7].text.trim()) ?? 0;
        final grade = tds[8].text.trim();
        final status = tds[9].text.trim();

        // Check for '*' in note column which means "not counted in GPA"
        bool isScored = true;
        if (tds.length >= 11) {
          final note = tds[10].text.trim();
          if (note.contains('*')) {
            isScored = false;
          }
        }

        // Skip rows without a valid semester or subject code
        if (semester.isEmpty && subjectCode.isEmpty) continue;

        records.add(TranscriptRecord(
          no: no,
          semester: semester.isEmpty ? 'Unknown' : semester,
          subjectCode: subjectCode,
          subjectName: subjectName,
          credit: credit,
          grade: grade,
          status: status,
          isScored: isScored,
        ));
      }
    }

    return records;
  }
}
