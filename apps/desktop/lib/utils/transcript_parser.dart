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

  static String _decodeUtf16Be(List<int> bytes) {
    final start = bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF
        ? 2
        : 0;
    final sb = StringBuffer();
    for (int i = start; i + 1 < bytes.length; i += 2) {
      sb.writeCharCode((bytes[i] << 8) | bytes[i + 1]);
    }
    return sb.toString();
  }

  /// FAP exports HTML with an `.xls` extension. Depending on whether the file
  /// was downloaded directly or re-saved by Excel/WPS, it can be UTF-16LE or
  /// UTF-8, so the encoding must not be assumed from the extension.
  static String _decodeHtml(List<int> bytes) {
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        return _decodeUtf16Le(bytes);
      }
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return _decodeUtf16Be(bytes);
      }
    }

    // UTF-16 files without a BOM contain a NUL byte in roughly every other
    // position near the start. UTF-8 HTML does not.
    final sampleLength = bytes.length < 200 ? bytes.length : 200;
    var oddNulls = 0;
    var evenNulls = 0;
    for (var i = 0; i < sampleLength; i++) {
      if (bytes[i] == 0) {
        if (i.isEven) {
          evenNulls++;
        } else {
          oddNulls++;
        }
      }
    }
    if (oddNulls > sampleLength ~/ 8) return _decodeUtf16Le(bytes);
    if (evenNulls > sampleLength ~/ 8) return _decodeUtf16Be(bytes);

    return utf8.decode(bytes, allowMalformed: false);
  }

  static String _headerKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Expands HTML `colspan` cells so indexes match the columns shown in Excel.
  static List<String> _logicalCells(List<dynamic> cells) {
    final values = <String>[];
    for (final cell in cells) {
      final value = cell.text.trim();
      final span = int.tryParse(cell.attributes['colspan'] ?? '') ?? 1;
      values.add(value);
      for (var i = 1; i < span; i++) {
        values.add('');
      }
    }
    return values;
  }

  /// Phân tích file điểm từ FAP
  static Future<List<TranscriptRecord>> parseTranscript(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final htmlString = _decodeHtml(bytes);

    final document = parser.parse(htmlString);
    final rows = document.querySelectorAll('tbody tr');

    final records = <TranscriptRecord>[];
    Map<String, int>? columns;

    for (var row in rows) {
      final tds = row.querySelectorAll('td');
      if (tds.isEmpty) continue;
      final cells = _logicalCells(tds);

      final headerIndexes = <String, int>{};
      for (var i = 0; i < cells.length; i++) {
        final key = _headerKey(cells[i]);
        if (key.isNotEmpty) headerIndexes[key] = i;
      }
      if (headerIndexes.containsKey('subjectcode') &&
          headerIndexes.containsKey('status')) {
        columns = headerIndexes;
        continue;
      }

      if (columns == null) continue;
      String value(String name) {
        final index = columns![name];
        return index == null || index >= cells.length ? '' : cells[index];
      }

      final no = int.tryParse(value('no'));
      final subjectCode = value('subjectcode');
      if (no == null || subjectCode.isEmpty) continue;

      final semester = value('semester');
      final statusIndex = columns['status']!;
      final note = statusIndex + 1 < cells.length ? cells[statusIndex + 1] : '';
      records.add(
        TranscriptRecord(
          no: no,
          semester: semester.isEmpty ? 'Unknown' : semester,
          subjectCode: subjectCode,
          subjectName: value('subjectname'),
          credit: int.tryParse(value('credit')) ?? 0,
          grade: value('grade'),
          status: value('status'),
          isScored: !note.contains('*'),
        ),
      );
    }

    if (records.isEmpty) {
      throw const FormatException(
        'Không tìm thấy dữ liệu bảng điểm trong file đã chọn.',
      );
    }
    return records;
  }
}
