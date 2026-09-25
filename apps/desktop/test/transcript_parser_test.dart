import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_flm_desktop/utils/transcript_parser.dart';

const _html = '''
<html><body><table><tbody>
<tr><td>No</td><td>Term</td><td>Semester</td><td>Subject Code</td><td>prerequisite</td><td>Replaced Subject</td><td>Subject Name</td><td>Credit</td><td>Grade</td><td>Status</td><td></td></tr>
<tr><td>1</td><td>0</td><td>Fall2023</td><td>VOV114</td><td colspan="2"></td><td>Vovinam 1</td><td>2</td><td>6.8</td><td>Passed</td><td>*</td></tr>
<tr><td>2</td><td>8</td><td></td><td>PRM393</td><td>PRO192</td><td></td><td>Mobile Programming</td><td colspan="2"></td><td>Studying</td><td></td></tr>
<tr><td>No</td><td>Semester</td><td>SubjectCode</td><td>SubjectName</td><td>Credit</td><td>Grade</td><td>Status</td><td colspan="4"></td></tr>
<tr><td>1</td><td>Fall2025</td><td>DXD391c</td><td>Key Activities</td><td>3</td><td>9.4</td><td>Passed</td><td colspan="4"></td></tr>
</tbody></table></body></html>
''';

void main() {
  Future<File> writeFixture(List<int> bytes) async {
    final directory = await Directory.systemTemp.createTemp('transcript_test_');
    final file = File('${directory.path}/transcript.xls');
    await file.writeAsBytes(bytes);
    addTearDown(() => directory.delete(recursive: true));
    return file;
  }

  test('parses UTF-8 WPS HTML and expands colspan cells', () async {
    final file = await writeFixture(utf8.encode(_html));
    final records = await TranscriptParser.parseTranscript(file.path);

    expect(records, hasLength(3));
    expect(records[0].subjectCode, 'VOV114');
    expect(records[0].isScored, isFalse);
    expect(records[1].subjectCode, 'PRM393');
    expect(records[1].grade, isEmpty);
    expect(records[1].status, 'Studying');
    expect(records[2].subjectCode, 'DXD391c');
    expect(records[2].grade, '9.4');
  });

  test('continues to parse UTF-16LE FAP HTML', () async {
    final codeUnits = _html.codeUnits;
    final bytes = <int>[0xFF, 0xFE];
    for (final codeUnit in codeUnits) {
      bytes
        ..add(codeUnit & 0xFF)
        ..add(codeUnit >> 8);
    }
    final file = await writeFixture(bytes);

    final records = await TranscriptParser.parseTranscript(file.path);
    expect(records, hasLength(3));
    expect(records.last.subjectCode, 'DXD391c');
  });

  test('parses raw FAP export with header row in thead/th', () async {
    const fapHtml = """<Table class='table'><thead class='thead-inverse'><tr><th>No</th><th>Term</th><th>Semester</th><th>Subject Code</th><th>prerequisite</th><th>Replaced Subject</th><th>Subject Name</th><th>Credit</th><th>Grade</th><th>Status</th><th></th></tr></thead>
<tbody><tr><td>1</td><td>0</td><td>Fall2023</td><td>VOV114</td><td></td><td></td><td>Vovinam 1</td><td>2</td><td><span class='label'>8.3</span></td><td><span class='label'>Passed</span></td><td><span style='color:red'>*</span></td></tr></tbody></Table>
<Table class='table'><thead><tr><th>No</th><th>Semester</th><th>SubjectCode</th><th>SubjectName</th><th>Credit</th><th>Grade</th><th>Status</th></tr></thead>
<tbody><tr><td>1</td><td>Fall2023</td><td>TRS403</td><td>English 4</td><td>0</td><td><span>6.4</span></td><td><span>Passed</span></td></tr></tbody><Table>""";
    final bytes = <int>[0xFF, 0xFE];
    for (final codeUnit in fapHtml.codeUnits) {
      bytes
        ..add(codeUnit & 0xFF)
        ..add(codeUnit >> 8);
    }
    final file = await writeFixture(bytes);

    final records = await TranscriptParser.parseTranscript(file.path);
    expect(records, hasLength(2));
    expect(records[0].subjectCode, 'VOV114');
    expect(records[0].grade, '8.3');
    expect(records[0].isScored, isFalse);
    expect(records[1].subjectCode, 'TRS403');
    expect(records[1].status, 'Passed');
  });
}
