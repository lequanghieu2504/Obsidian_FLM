import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../app/theme/app_colors.dart';
import '../../models/transcript.dart';
import '../../utils/transcript_parser.dart';

class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({super.key});

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  List<TranscriptRecord> _records = [];
  String _searchQuery = '';
  String _selectedSemester = 'Tất cả';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalTranscript();
  }

  Future<String> get _transcriptFilePath async {
    return p.join(Directory.current.path, 'data', 'transcript.json');
  }

  Future<void> _loadLocalTranscript() async {
    try {
      final path = await _transcriptFilePath;
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        setState(() {
          _records = jsonList.map((e) => TranscriptRecord.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLocalTranscript() async {
    try {
      final path = await _transcriptFilePath;
      final file = File(path);

      // Ensure directory exists
      final dir = file.parent;
      if (!(await dir.exists())) {
        await dir.create(recursive: true);
      }

      final jsonList = _records.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      // Error silently or handle via log
    }
  }

  Future<void> _pickAndParseFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xls'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final path = result.files.single.path!;
        final records = await TranscriptParser.parseTranscript(path);
        setState(() {
          _records = records;
        });
        await _saveLocalTranscript();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi đọc file bảng điểm: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  double _calculateGPA(List<TranscriptRecord> records,
      {bool useEstimated = false}) {
    double totalPoints = 0;
    int totalCredits = 0;

    for (var r in records) {
      if (r.credit <= 0 || !r.isScored) continue;

      double? point;
      if (useEstimated && r.estimatedGrade != null) {
        point = r.estimatedGrade;
      } else {
        point = double.tryParse(r.grade);
      }

      // If status is Passed or Failed, or we are estimating
      if (point != null &&
          (r.status == 'Passed' || r.status == 'Failed' || useEstimated)) {
        totalPoints += point * r.credit;
        totalCredits += r.credit;
      }
    }

    if (totalCredits == 0) return 0.0;
    return totalPoints / totalCredits;
  }

  int _calculatePassedCredits(List<TranscriptRecord> records) {
    int total = 0;
    for (var r in records) {
      if (r.status == 'Passed' && r.credit > 0) {
        total += r.credit;
      }
    }
    return total;
  }

  Map<String, List<TranscriptRecord>> _groupRecordsBySemester(
      List<TranscriptRecord> records) {
    Map<String, List<TranscriptRecord>> map = {};
    for (var r in records) {
      if (!map.containsKey(r.semester)) {
        map[r.semester] = [];
      }
      map[r.semester]!.add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    var filteredList = _records.where((r) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return r.subjectCode.toLowerCase().contains(query) ||
          r.subjectName.toLowerCase().contains(query);
    }).toList();

    final currentGPA = _calculateGPA(_records, useEstimated: false);
    final estimatedGPA = _calculateGPA(_records, useEstimated: true);
    final passedCredits = _calculatePassedCredits(_records);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildStatCard('Tín chỉ', '$passedCredits', Icons.military_tech),
                          const SizedBox(width: 16),
                          _buildStatCard('GPA Hiện tại', currentGPA.toStringAsFixed(2), Icons.grade),
                          // if (estimatedGPA != currentGPA) ...[
                          //   const SizedBox(width: 16),
                          //   _buildStatCard(
                          //       'GPA Ước tính',
                          //       estimatedGPA.toStringAsFixed(2),
                          //       Icons.trending_up,
                          //       color: AppColors.warning),
                          // ],
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                onChanged: (val) => setState(() => _searchQuery = val),
                                decoration: const InputDecoration(
                                  hintText: 'Tìm kiếm mã môn hoặc tên môn...',
                                  hintStyle: TextStyle(color: AppColors.textSub, fontSize: 14),
                                  border: InputBorder.none,
                                  icon: Icon(Icons.search, color: AppColors.textSub),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          ElevatedButton.icon(
                            onPressed: _pickAndParseFile,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Nhập điểm từ FAP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),

                // Tabs
                if (_records.isNotEmpty)
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabItem('Tất cả'),
                          ...(() {
                            final keys = _groupRecordsBySemester(_records).keys.toList()..sort();
                            return keys.map((e) => _buildTabItem(e));
                          })(),
                        ],
                      ),
                    ),
                  ),

                // Content
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Text(
                            _records.isEmpty
                                ? 'Chưa có dữ liệu bảng điểm. Vui lòng tải lên file .xls từ FAP.'
                                : 'Không tìm thấy kết quả nào.',
                            style: const TextStyle(
                                color: AppColors.textSub, fontSize: 16),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(32),
                          children: _buildSemesterGroups(filteredList),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      {Color color = AppColors.primary}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textSub, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: AppColors.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String label) {
    bool isSelected = _selectedSemester == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedSemester = label),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textMain,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSemesterGroups(List<TranscriptRecord> filteredList) {
    final groups = _groupRecordsBySemester(filteredList);
    List<Widget> widgets = [];
    
    final sortedSemesters = groups.keys.toList()..sort();

    for (var sem in sortedSemesters) {
      if (_selectedSemester != 'Tất cả' && sem != _selectedSemester) continue;

      final records = groups[sem]!;
      final semGPA = _calculateGPA(records, useEstimated: true);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sem,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark),
              ),
              if (semGPA > 0)
                Text(
                  'GPA Kỳ: ${semGPA.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success),
                ),
            ],
          ),
        ),
      );

      for (var r in records) {
        widgets.add(_buildSubjectCard(r));
      }
    }

    return widgets;
  }

  Widget _buildSubjectCard(TranscriptRecord record) {
    bool isPassed = record.status == 'Passed';
    bool isFailed = record.status == 'Failed';
    bool isStudying = record.status == 'Studying' ||
        record.status == 'Not started' ||
        record.grade.isEmpty;

    Color statusColor = AppColors.textSub;
    if (isPassed) statusColor = AppColors.success;
    if (isFailed) statusColor = AppColors.error;
    if (isStudying) statusColor = AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(record.subjectCode,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16)),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.subjectName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.military_tech,
                        size: 16, color: AppColors.textSub),
                    const SizedBox(width: 4),
                    Text('${record.credit} tín chỉ',
                        style: const TextStyle(
                            color: AppColors.textSub, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          if (isStudying && record.credit > 0 && record.isScored) ...[
            // Input for estimated grade
            SizedBox(
              width: 100,
              child: TextField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Điểm dự kiến',
                  labelStyle: TextStyle(fontSize: 12),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
                onChanged: (val) {
                  final valDouble = double.tryParse(val);
                  setState(() {
                    record.estimatedGrade = valDouble;
                  });
                  _saveLocalTranscript();
                },
              ),
            ),
          ] else ...[
            SizedBox(
              width: 100,
              child: Text(
                record.grade.isNotEmpty ? record.grade : '-',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: double.tryParse(record.grade) != null &&
                            double.parse(record.grade) >= 5
                        ? AppColors.success
                        : AppColors.error),
              ),
            ),
          ],
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              record.status,
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          )
        ],
      ),
    );
  }
}
