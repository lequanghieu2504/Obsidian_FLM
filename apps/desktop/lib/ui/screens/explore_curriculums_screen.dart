import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../app/theme/app_colors.dart';
import 'explore_curriculum_detail_screen.dart';
import '../../utils/folder_reader.dart';
import '../../models/curriculum_data.dart';

class ExploreCurriculumsScreen extends StatefulWidget {
  const ExploreCurriculumsScreen({super.key});

  @override
  State<ExploreCurriculumsScreen> createState() => _ExploreCurriculumsScreenState();
}

class _ExploreCurriculumsScreenState extends State<ExploreCurriculumsScreen> {
  String _searchQuery = '';
  String _selectedMajor = 'Tất cả Ngành';
  String _selectedCohort = 'Tất cả Khóa';
  String _selectedCombo = 'Tất cả Combo';

  bool _isLoading = true;
  List<Map<String, dynamic>> _curriculums = [];
  List<String> _majors = ['Tất cả Ngành'];
  List<String> _cohorts = ['Tất cả Khóa'];
  List<String> _combos = ['Tất cả Combo'];

  @override
  void initState() {
    super.initState();
    _loadCurriculums();
  }

  Future<void> _loadCurriculums() async {
    try {
      final basedDataPath = p.join(Directory.current.path, 'data', 'based_data');
      final basedDataDir = Directory(basedDataPath);
      
      if (await basedDataDir.exists()) {
        List<Map<String, dynamic>> loadedData = [];
        Set<String> majorsSet = {};
        Set<String> combosSet = {};
        Set<String> cohortsSet = {};

        await for (var entity in basedDataDir.list()) {
          if (entity is Directory && !entity.path.endsWith('combo-details')) {
             final extractedPath = p.join(entity.path, 'extracted');
             if (await Directory(extractedPath).exists()) {
                try {
                  final curriculumData = await FolderReader.parseFolder(extractedPath);
                  final code = curriculumData.metadata['curriculumCode']?.toString() ?? 'Unknown';
                  
                  String major = 'Khác';
                  if (code.contains('_SE_')) major = 'SE - Kỹ thuật phần mềm';
                  else if (code.contains('_AI_')) major = 'AI - Trí tuệ nhân tạo';
                  else if (code.contains('_IA_')) major = 'IA - An toàn thông tin';
                  else if (code.contains('_GD_')) major = 'GD - Thiết kế đồ họa';
                  else if (code.contains('_SS_')) major = 'SS - Kỹ thuật hệ thống';

                  String cohort = p.basename(entity.path).toUpperCase();

                  List<String> comboNames = [];
                  if (curriculumData.allCombos.isEmpty) {
                    comboNames.add('None');
                    combosSet.add('None');
                  } else {
                    for (var combo in curriculumData.allCombos) {
                      // Extract short descriptive name
                      final shortName = combo.name.split('_').last.split('(').first.trim();
                      comboNames.add(shortName);
                      combosSet.add(shortName);
                    }
                  }

                  majorsSet.add(major);
                  cohortsSet.add(cohort);
                  
                  loadedData.add({
                    'code': code,
                    'major': major,
                    'cohort': cohort,
                    'subjectsCount': curriculumData.subjects.length,
                    'combos': comboNames,
                    'data': curriculumData,
                  });
                } catch(e) {
                  // Ignore parse errors for specific folder
                }
             }
          }
        }
        
        if (mounted) {
          setState(() {
            _curriculums = loadedData;
            _majors = ['Tất cả Ngành', ...majorsSet.toList()..sort()];
            _cohorts = ['Tất cả Khóa', ...cohortsSet.toList()..sort((a,b) => b.compareTo(a))];
            _combos = ['Tất cả Combo', ...combosSet.toList()..sort()];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch(e) {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var filteredList = _curriculums.where((c) {
      if (_searchQuery.isNotEmpty && !c['code'].toString().toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_selectedMajor != 'Tất cả Ngành' && c['major'] != _selectedMajor) return false;
      if (_selectedCohort != 'Tất cả Khóa' && c['cohort'] != _selectedCohort) return false;
      if (_selectedCombo != 'Tất cả Combo' && !(c['combos'] as List).contains(_selectedCombo)) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Filters
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          decoration: const InputDecoration(
                            hintText: 'Tìm kiếm mã chương trình...',
                            hintStyle: TextStyle(color: AppColors.textSub, fontSize: 14),
                            border: InputBorder.none,
                            icon: Icon(Icons.search, color: AppColors.textSub, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Dropdowns
                    _buildDropdown(_majors, _selectedMajor, (v) => setState(() => _selectedMajor = v!)),
                    const SizedBox(width: 16),
                    _buildDropdown(_cohorts, _selectedCohort, (v) => setState(() => _selectedCohort = v!)),
                    const SizedBox(width: 16),
                    _buildDropdown(_combos, _selectedCombo, (v) => setState(() => _selectedCombo = v!)),
                  ],
                ),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : filteredList.isEmpty
                    ? const Center(
                        child: Text('Không tìm thấy chương trình nào phù hợp.', style: TextStyle(color: AppColors.textSub)),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(32),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          childAspectRatio: 1.8,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          return _buildCurriculumCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String value, Function(String?) onChanged) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSub),
          style: const TextStyle(color: AppColors.textMain, fontSize: 14),
          onChanged: onChanged,
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCurriculumCard(Map<String, dynamic> item) {
    final List<String> combos = (item['combos'] as List).cast<String>();

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ExploreCurriculumDetailScreen(item: item),
        ));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['code'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDark)),
                      const SizedBox(height: 4),
                      Text(item['major'], style: const TextStyle(fontSize: 13, color: AppColors.textSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoBadge(Icons.calendar_month_rounded, item['cohort']),
                const SizedBox(width: 12),
                _buildInfoBadge(Icons.menu_book_rounded, '${item['subjectsCount']} Môn học'),
              ],
            ),
            if (combos.isNotEmpty && combos.first != 'None') ...[
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: combos.map((c) => _buildComboChip(c)).toList(),
                  ),
                ),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSub),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textMain, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildComboChip(String comboName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        comboName,
        style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
      ),
    );
  }
}
