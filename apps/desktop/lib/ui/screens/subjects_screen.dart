import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:graphview/GraphView.dart';
import '../../models/subject.dart';
import '../../models/curriculum_data.dart';
import '../../app/theme/app_colors.dart';

class SubjectsScreen extends StatefulWidget {
  final CurriculumData curriculumData;

  const SubjectsScreen({
    super.key,
    required this.curriculumData,
  });

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _searchQuery = '';
  bool _isGridView = false;

  bool _isFullGraphView = true;
  String? _selectedGraphSubject;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> _parsePrerequisites(String prereq) {
    if (prereq.isEmpty || prereq.toLowerCase() == 'none' || prereq == '-') {
      return [];
    }

    List<String> foundCodes = [];
    final allSubjectCodes =
        widget.curriculumData.subjects.map((s) => s.code).toList();

    for (var code in allSubjectCodes) {
      if (code.contains('*') || code.contains('_')) {
        // Fallback cho các mã có ký tự đặc biệt
        if (prereq.toUpperCase().contains(code.toUpperCase())) {
          foundCodes.add(code);
        }
      } else {
        // Dùng word boundary (\b) để khớp chính xác mã môn học
        String escapedCode = RegExp.escape(code);
        RegExp regExp = RegExp('\\b$escapedCode\\b', caseSensitive: false);
        if (regExp.hasMatch(prereq)) {
          foundCodes.add(code);
        }
      }
    }

    return foundCodes;
  }

  void _showSyllabus(String code) {
    final subIdx =
        widget.curriculumData.subjects.indexWhere((s) => s.code == code);
    if (subIdx == -1) return;
    final subject = widget.curriculumData.subjects[subIdx];

    String description = 'Chưa có mô tả.';
    if (widget.curriculumData.syllabi.containsKey(code)) {
      final syllabus = widget.curriculumData.syllabi[code];
      if (syllabus['metadata'] != null &&
          syllabus['metadata']['Description'] != null) {
        description = syllabus['metadata']['Description'];
      }
    }

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(code,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(subject.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        fontSize: 20)),
              ],
            ),
            content: SizedBox(
              width: 800, // Make dialog wider for the table
              child: SingleChildScrollView(
                child: _buildDescriptionTable(description),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
              )
            ],
          );
        });
  }

  Widget _buildDescriptionTable(String description) {
    final hasBullets = description.contains('•');
    final hasHyphenBullets = description.contains(' - ');

    if (!hasBullets && !hasHyphenBullets) {
      return Text(description,
          style: const TextStyle(color: AppColors.textMain, height: 1.5));
    }

    final splitPattern = hasBullets ? '•' : ' - ';
    final parts = description.split(splitPattern);

    final intro = parts[0].trim();
    final bullets = parts.sublist(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (intro.isNotEmpty) ...[
          Text(intro,
              style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  height: 1.5)),
          const SizedBox(height: 16),
        ],
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Table(
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xFFE2E8F0)),
                verticalInside: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              columnWidths: const {
                0: FixedColumnWidth(60),
                1: FlexColumnWidth(),
              },
              children: [
                TableRow(
                  decoration:
                      BoxDecoration(color: AppColors.primary.withOpacity(0.05)),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('STT',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark),
                          textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Nội dung',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark)),
                    ),
                  ],
                ),
                ...bullets.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String content = entry.value.trim();
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('${idx + 1}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSub,
                                fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(content,
                            style: const TextStyle(
                                color: AppColors.textMain, height: 1.5)),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thanh công cụ (Tìm kiếm & Grid/List)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.toLowerCase();
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm môn học...',
                      hintStyle:
                          TextStyle(color: AppColors.textSub, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppColors.textSub, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.list_rounded,
                          color: !_isGridView
                              ? AppColors.primary
                              : AppColors.textSub),
                      onPressed: () => setState(() => _isGridView = false),
                      tooltip: 'Dạng danh sách',
                    ),
                    Container(
                        width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                    IconButton(
                      icon: Icon(Icons.grid_view_rounded,
                          color: _isGridView
                              ? AppColors.primary
                              : AppColors.textSub),
                      onPressed: () => setState(() => _isGridView = true),
                      tooltip: 'Dạng lưới',
                    ),
                  ],
                ),
              )
            ],
          ),
        ),

        // Custom TabBar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSub,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: const [
              Tab(text: 'Tất cả môn học'),
              Tab(text: 'Môn có tiên quyết'),
              Tab(text: 'Chuyên ngành hẹp (Combos)'),
              Tab(text: 'Đồ thị Lộ trình'),
            ],
          ),
        ),

        // TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildAllSubjectsTab(),
              _buildPrerequisiteTab(),
              _buildCombosTab(),
              _buildCoordinateGraphTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllSubjectsTab() {
    return _buildSubjectView(widget.curriculumData.subjects);
  }

  Widget _buildPrerequisiteTab() {
    final preReqSubjects = widget.curriculumData.subjects.where((s) {
      final reqs = _parsePrerequisites(s.preRequisite);
      return reqs.isNotEmpty;
    }).toList();

    return _buildSubjectView(preReqSubjects, highlightPrereq: true);
  }

  Widget _buildSubjectView(List<Subject> sourceList,
      {bool highlightPrereq = false}) {
    final filteredList = sourceList
        .where((s) =>
            s.code.toLowerCase().contains(_searchQuery) ||
            s.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (filteredList.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy môn học nào.',
            style: TextStyle(color: AppColors.textSub, fontSize: 16)),
      );
    }

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 350,
          mainAxisExtent: 200,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          return _buildGridCard(filteredList[index], highlightPrereq);
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(32),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          return _buildListCard(filteredList[index], highlightPrereq);
        },
      );
    }
  }

  Widget _buildListCard(Subject sub, bool highlightPrereq) {
    return InkWell(
      onTap: () => _showSyllabus(sub.code),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            ]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code Badge
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sub.code,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 24),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildChip(Icons.military_tech_rounded,
                          '${sub.credits} Tín chỉ'),
                      const SizedBox(width: 12),
                      _buildChip(Icons.calendar_month_rounded,
                          'Học kỳ ${sub.semester}'),
                    ],
                  ),
                  if (highlightPrereq &&
                      sub.preRequisite.isNotEmpty &&
                      sub.preRequisite.toLowerCase() != 'none' &&
                      sub.preRequisite != '-') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tiên quyết: ${sub.preRequisite}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  ]
                ],
              ),
            ),
            // Action
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AppColors.primary),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(Subject sub, bool highlightPrereq) {
    return InkWell(
      onTap: () => _showSyllabus(sub.code),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
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
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sub.code,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                const Spacer(),
                _buildChip(Icons.calendar_month_rounded, 'HK ${sub.semester}'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                sub.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            _buildChip(Icons.military_tech_rounded, '${sub.credits} Tín chỉ'),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSub),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
      ],
    );
  }

  Widget _buildCombosTab() {
    final combos = widget.curriculumData.combos;
    if (combos.isEmpty) {
      return const Center(
        child: Text(
            'Bạn chưa chọn chuyên ngành hẹp nào, hoặc dữ liệu không có.',
            style: TextStyle(color: AppColors.textSub, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: combos.length,
      itemBuilder: (context, index) {
        final combo = combos[index];
        final comboSubjects = combo.subjects ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: const Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.hub_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(combo.code,
                              style: TextStyle(
                                  color: AppColors.primary.withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          Text(combo.name,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (comboSubjects.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _isGridView
                      ? Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: comboSubjects.map((sub) {
                            return InkWell(
                              onTap: () => _showSyllabus(sub.code),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 250,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sub.code,
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(sub.name,
                                        style: const TextStyle(
                                            color: AppColors.textMain,
                                            fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      : Column(
                          children: comboSubjects
                              .map((sub) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildListCard(sub, false)))
                              .toList(),
                        ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có chi tiết môn học',
                      style: TextStyle(color: AppColors.textSub)),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomGridGraph() {
    Map<int, List<Subject>> semesterGroups = {};
    for (var sub in widget.curriculumData.subjects) {
      semesterGroups.putIfAbsent(sub.semester, () => []).add(sub);
    }
    final sortedSemesters = semesterGroups.keys.toList()..sort();

    int maxRows = 0;
    for (var list in semesterGroups.values) {
      if (list.length > maxRows) maxRows = list.length;
    }

    const double columnWidth = 320.0;
    const double rowHeight = 150.0;
    const double headerHeight = 60.0;

    final double totalWidth = sortedSemesters.length * columnWidth + 100;
    final double totalHeight = headerHeight + maxRows * rowHeight + 100;

    List<Widget> stackChildren = [];

    // Tự tính vị trí các môn học theo lưới
    for (int i = 0; i < sortedSemesters.length; i++) {
      final sem = sortedSemesters[i];
      final subjects = semesterGroups[sem]!;
      for (int j = 0; j < subjects.length; j++) {
        final sub = subjects[j];
        final double left = i * columnWidth + 40;
        final double top = headerHeight + j * rowHeight + 20;

        stackChildren.add(Positioned(
          left: left,
          top: top,
          child: _buildCoordinateNode(sub),
        ));
      }
    }

    // Header trục X
    for (int i = 0; i < sortedSemesters.length; i++) {
      final sem = sortedSemesters[i];
      final title = sem == 0 ? 'OJT / Prep' : 'Học kỳ $sem';
      stackChildren.add(Positioned(
        left: i * columnWidth + 40,
        top: 0,
        width: 220,
        height: headerHeight,
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2))),
          child: Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textMain),
          ),
        ),
      ));
    }

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(1000),
      minScale: 0.1,
      maxScale: 3.0,
      child: Container(
        width: totalWidth,
        height: totalHeight,
        color: AppColors.background,
        child: Stack(
          children: stackChildren,
        ),
      ),
    );
  }

  Graph _buildFullGraph() {
    final Graph graph = Graph()..isTree = false;
    Map<String, Node> nodeMap = {};
    for (var sub in widget.curriculumData.subjects) {
      if (!nodeMap.containsKey(sub.code)) {
        final node = Node.Id(sub.code);
        nodeMap[sub.code] = node;
        graph.addNode(node);
      }
    }
    for (var sub in widget.curriculumData.subjects) {
      final reqs = _parsePrerequisites(sub.preRequisite);
      for (var req in reqs) {
        if (nodeMap.containsKey(req)) {
          graph.addEdge(nodeMap[req]!, nodeMap[sub.code]!);
        }
      }
    }
    return graph;
  }

  Graph _buildSubGraph(String targetCode) {
    final Graph graph = Graph()..isTree = false;
    final Set<String> relatedNodes = {targetCode};

    // Forward and backward search for dependencies
    bool changed = true;
    while (changed) {
      changed = false;
      for (var sub in widget.curriculumData.subjects) {
        final reqs = _parsePrerequisites(sub.preRequisite);
        for (var req in reqs) {
          if (relatedNodes.contains(req) && !relatedNodes.contains(sub.code)) {
            relatedNodes.add(sub.code);
            changed = true;
          } else if (relatedNodes.contains(sub.code) &&
              !relatedNodes.contains(req)) {
            relatedNodes.add(req);
            changed = true;
          }
        }
      }
    }

    Map<String, Node> nodeMap = {};
    for (var code in relatedNodes) {
      final node = Node.Id(code);
      nodeMap[code] = node;
      graph.addNode(node);
    }

    for (var sub in widget.curriculumData.subjects) {
      if (!relatedNodes.contains(sub.code)) continue;
      final reqs = _parsePrerequisites(sub.preRequisite);
      for (var req in reqs) {
        if (relatedNodes.contains(req)) {
          graph.addEdge(nodeMap[req]!, nodeMap[sub.code]!);
        }
      }
    }
    return graph;
  }

  // Giao diện Đồ thị hệ toạ độ (X = Kỳ học, Y = Danh sách môn)
  Widget _buildCoordinateGraphTab() {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Toàn bộ lộ trình')),
                    ButtonSegment(value: false, label: Text('Môn tiên quyết')),
                  ],
                  selected: {_isFullGraphView},
                  onSelectionChanged: (set) {
                    setState(() => _isFullGraphView = set.first);
                  },
                ),
                if (!_isFullGraphView) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGraphSubject,
                          isExpanded: true,
                          hint: const Text(
                              'Chọn một môn học để xem chuỗi tiên quyết...'),
                          items: widget.curriculumData.subjects
                              .map((s) => DropdownMenuItem(
                                    value: s.code,
                                    child: Text('${s.code} - ${s.name}',
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedGraphSubject = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),

          // Graph View
          Expanded(
            child: Stack(
              children: [
                if (!_isFullGraphView && _selectedGraphSubject == null)
                  const Center(
                      child: Text(
                          'Vui lòng chọn môn học ở thanh chọn phía trên',
                          style: TextStyle(
                              color: AppColors.textSub, fontSize: 16)))
                else if (_isFullGraphView)
                  _buildCustomGridGraph()
                else
                  InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(1000),
                    minScale: 0.1,
                    maxScale: 3.0,
                    child: Padding(
                      padding: const EdgeInsets.all(64.0),
                      child: GraphView(
                        key: ValueKey(
                            '${_isFullGraphView}_${_selectedGraphSubject ?? ""}'),
                        graph: _buildSubGraph(_selectedGraphSubject!),
                        algorithm: SugiyamaAlgorithm(SugiyamaConfiguration()
                          ..nodeSeparation = 80
                          ..levelSeparation = 150
                          ..orientation =
                              SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT),
                        paint: Paint()
                          ..color = AppColors.warning.withOpacity(0.5)
                          ..strokeWidth = 2
                          ..style = PaintingStyle.stroke,
                        builder: (Node node) {
                          var subId = node.key!.value as String;
                          var sub = widget.curriculumData.subjects
                              .firstWhere((s) => s.code == subId);
                          return _buildCoordinateNode(
                            sub,
                            highlight:
                                true, // Only show for prerequisite flow, so target is always highlighted contextually
                          );
                        },
                      ),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateNode(Subject sub, {bool highlight = false}) {
    final reqs = _parsePrerequisites(sub.preRequisite);
    final isCritical = reqs.isNotEmpty;

    bool isComboSubject = false;
    for (var combo in widget.curriculumData.combos) {
      if (combo.subjects?.any((s) => s.code == sub.code) == true) {
        isComboSubject = true;
        break;
      }
    }

    Color borderColor;
    Color bgColor;
    Color textColor;

    if (highlight) {
      borderColor = AppColors.primary;
      bgColor = AppColors.primary.withOpacity(0.1);
      textColor = AppColors.primaryDark;
    } else if (isComboSubject) {
      borderColor = AppColors.success.withOpacity(0.5);
      bgColor = AppColors.success.withOpacity(0.05);
      textColor = AppColors.success;
    } else if (isCritical) {
      borderColor = Colors.orange.withOpacity(0.5);
      bgColor = Colors.orange.withOpacity(0.05);
      textColor = Colors.orange.shade800;
    } else {
      borderColor = AppColors.primary.withOpacity(0.2);
      bgColor = Colors.white;
      textColor = AppColors.primaryDark;
    }

    return InkWell(
      onTap: () => _showSyllabus(sub.code),
      child: Container(
        width: 200,
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: highlight ? 3.0 : 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sub.code,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                sub.name,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSub, height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
