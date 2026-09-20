import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../../models/subject.dart';
import '../../app/theme/app_colors.dart';

class SubjectsScreen extends StatefulWidget {
  final String curriculumCode;
  final List<Subject> subjects;

  const SubjectsScreen({
    super.key,
    required this.curriculumCode,
    required this.subjects,
  });

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Graph _graph = Graph();
  SugiyamaConfiguration _graphConfig = SugiyamaConfiguration();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _buildGraph();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> _parsePrerequisites(String prereq) {
    if (prereq.isEmpty || prereq.toLowerCase() == 'none' || prereq == '-')
      return [];

    // Loại bỏ phần giải thích trong ngoặc đơn, vd: "(not applied to ...)"
    var cleanPrereq = prereq.replaceAll(RegExp(r'\(.*?\)'), '');

    // Tách bằng phẩy, "and", "or"
    return cleanPrereq
        .split(RegExp(r'[,&]|\bor\b|\band\b', caseSensitive: false))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.toLowerCase().contains('không'))
        .toList();
  }

  void _buildGraph() {
    final nodes = <String, Node>{};

    // Tạo các node cho tất cả môn học
    for (var subject in widget.subjects) {
      if (!nodes.containsKey(subject.code)) {
        nodes[subject.code] = Node.Id(subject.code);
      }
      _graph.addNode(nodes[subject.code]!);
    }

    // Gắn Edge (cạnh) dựa trên môn tiên quyết
    for (var subject in widget.subjects) {
      final reqs = _parsePrerequisites(subject.preRequisite);
      for (var req in reqs) {
        // Nếu môn yêu cầu không có trong danh sách chính, tạo một node ảo
        if (!nodes.containsKey(req)) {
          nodes[req] = Node.Id(req);
          _graph.addNode(nodes[req]!);
        }
        // Thêm edge: từ môn Tiên quyết -> môn hiện tại
        _graph.addEdge(nodes[req]!, nodes[subject.code]!);
      }
    }

    _graphConfig = SugiyamaConfiguration()
      ..nodeSeparation = 40
      ..levelSeparation = 70
      ..orientation = SugiyamaConfiguration
          .ORIENTATION_LEFT_RIGHT; // Từ trái qua phải cho giống lộ trình
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
              Tab(text: 'Graph Lộ trình'),
            ],
          ),
        ),

        // TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics:
                const NeverScrollableScrollPhysics(), // Tắt lướt ngang để không xung đột với cuộn Graph
            children: [
              _buildAllSubjectsTab(),
              _buildPrerequisiteTab(),
              _buildGraphTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllSubjectsTab() {
    return _buildSubjectList(widget.subjects);
  }

  Widget _buildPrerequisiteTab() {
    final preReqSubjects = widget.subjects.where((s) {
      final reqs = _parsePrerequisites(s.preRequisite);
      return reqs.isNotEmpty;
    }).toList();

    return _buildSubjectList(preReqSubjects, highlightPrereq: true);
  }

  Widget _buildSubjectList(List<Subject> list, {bool highlightPrereq = false}) {
    if (list.isEmpty) {
      return const Center(
        child: Text('Không có môn học nào.',
            style: TextStyle(color: AppColors.textSub, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final sub = list[index];
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
              ]),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Code Badge
              Container(
                width: 80,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
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
                        sub.preRequisite != 'none' &&
                        sub.preRequisite != '-') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 16, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Text(
                              'Yêu cầu tiên quyết: ${sub.preRequisite}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildGraphTab() {
    return Container(
        color: AppColors.background,
        child: InteractiveViewer(
          constrained: false,
          boundaryMargin:
              const EdgeInsets.all(double.infinity), // Fix semantics issue
          minScale: 0.1,
          maxScale: 5.0,
          clipBehavior: Clip.none,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: GraphView(
                graph: _graph,
                algorithm: SugiyamaAlgorithm(_graphConfig),
                paint: Paint()
                  ..color = AppColors.primary.withValues(alpha: 0.5)
                  ..strokeWidth = 2
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  // Tìm môn học tương ứng
                  final code = node.key!.value as String;
                  final idx = widget.subjects.indexWhere((s) => s.code == code);
                  if (idx != -1) {
                    return _buildGraphNode(widget.subjects[idx]);
                  } else {
                    // Node ảo (môn bị thiếu trong chương trình nhưng có trong tiên quyết)
                    return _buildVirtualNode(code);
                  }
                },
              ),
            ),
          ),
        ));
  }

  Widget _buildGraphNode(Subject sub) {
    final reqs = _parsePrerequisites(sub.preRequisite);
    final isCritical = reqs.isNotEmpty;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCritical
            ? AppColors.warning.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? AppColors.warning : const Color(0xFFE2E8F0),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sub.code,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isCritical ? AppColors.warning : AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Học kỳ ${sub.semester}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSub),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualNode(String code) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFCBD5E1), width: 1, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Môn ngoài/Ẩn',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
