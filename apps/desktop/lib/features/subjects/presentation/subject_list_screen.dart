import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/subject.dart';
import '../domain/subject_display.dart';
import 'subject_detail_screen.dart';

enum SubjectViewMode { grid, list }

enum PrerequisiteFilter { all, hasPrerequisite, noPrerequisite }

class SubjectListScreen extends StatefulWidget {
  const SubjectListScreen({
    super.key,
    required this.curriculumCode,
    required this.subjects,
    this.controllerFactory = createSubjectController,
  });

  final String curriculumCode;
  final List<Subject> subjects;
  final SubjectControllerFactory controllerFactory;

  @override
  State<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends State<SubjectListScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  int? _semester;
  String? _credits;
  PrerequisiteFilter _prerequisite = PrerequisiteFilter.all;
  SubjectViewMode _viewMode = SubjectViewMode.grid;

  List<int> get _semesters =>
      (widget.subjects.map((subject) => subject.semester).toSet().toList()
        ..sort());
  List<String> get _creditValues =>
      (widget.subjects.map((subject) => subject.credits).toSet().toList()..sort(
        (a, b) => (int.tryParse(a) ?? 999).compareTo(int.tryParse(b) ?? 999),
      ));

  List<Subject> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return widget.subjects
        .where((subject) {
          final name = subjectDisplayName(subject);
          final matchesQuery =
              query.isEmpty ||
              subject.code.toLowerCase().contains(query) ||
              subject.name.toLowerCase().contains(query) ||
              name.primary.toLowerCase().contains(query) ||
              (name.secondary?.toLowerCase().contains(query) ?? false);
          final matchesSemester =
              _semester == null || subject.semester == _semester;
          final matchesCredits =
              _credits == null || subject.credits == _credits;
          final matchesPrerequisite = switch (_prerequisite) {
            PrerequisiteFilter.all => true,
            PrerequisiteFilter.hasPrerequisite => hasPrerequisite(subject),
            PrerequisiteFilter.noPrerequisite => !hasPrerequisite(subject),
          };
          return matchesQuery &&
              matchesSemester &&
              matchesCredits &&
              matchesPrerequisite;
        })
        .toList(growable: false);
  }

  bool get _hasFilters =>
      _search.text.isNotEmpty ||
      _semester != null ||
      _credits != null ||
      _prerequisite != PrerequisiteFilter.all;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _semester = null;
      _credits = null;
      _prerequisite = PrerequisiteFilter.all;
    });
  }

  Future<void> _open(Subject subject) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubjectDetailScreen(
          curriculumCode: widget.curriculumCode,
          subject: subject,
          controllerFactory: widget.controllerFactory,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _filtered;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _FocusSearchIntent(),
      },
      child: Actions(
        actions: {
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) => _searchFocus.requestFocus(),
          ),
        },
        child: Scaffold(
          appBar: AppBar(title: Text('${widget.curriculumCode} · Subjects')),
          body: widget.subjects.isEmpty
              ? const Center(
                  child: Text('No subjects were provided for this curriculum.'),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 720;
                    final effectiveMode = narrow
                        ? SubjectViewMode.list
                        : _viewMode;
                    return Column(
                      children: [
                        _BrowserHeader(
                          curriculumCode: widget.curriculumCode,
                          total: widget.subjects.length,
                          semesterCount: _semesters.length,
                          search: _search,
                          searchFocus: _searchFocus,
                          semesters: _semesters,
                          selectedSemester: _semester,
                          credits: _creditValues,
                          selectedCredits: _credits,
                          prerequisite: _prerequisite,
                          viewMode: _viewMode,
                          resultCount: subjects.length,
                          hasFilters: _hasFilters,
                          narrow: narrow,
                          onChanged: () => setState(() {}),
                          onSemester: (value) =>
                              setState(() => _semester = value),
                          onCredits: (value) =>
                              setState(() => _credits = value),
                          onPrerequisite: (value) =>
                              setState(() => _prerequisite = value),
                          onViewMode: (value) =>
                              setState(() => _viewMode = value),
                          onClear: _clearFilters,
                        ),
                        Expanded(
                          child: subjects.isEmpty
                              ? _EmptyResults(onClear: _clearFilters)
                              : effectiveMode == SubjectViewMode.grid
                              ? GridView.builder(
                                  key: const PageStorageKey('subject-grid'),
                                  controller: _scroll,
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    8,
                                    24,
                                    24,
                                  ),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 520,
                                        mainAxisExtent: 210,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  itemCount: subjects.length,
                                  itemBuilder: (_, index) => _SubjectCard(
                                    subject: subjects[index],
                                    showSemester: _semester == null,
                                    onTap: () => _open(subjects[index]),
                                  ),
                                )
                              : ListView.separated(
                                  key: const PageStorageKey('subject-list'),
                                  controller: _scroll,
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    8,
                                    24,
                                    24,
                                  ),
                                  itemCount: subjects.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, index) => _SubjectCard(
                                    subject: subjects[index],
                                    showSemester: _semester == null,
                                    compact: true,
                                    onTap: () => _open(subjects[index]),
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _BrowserHeader extends StatelessWidget {
  const _BrowserHeader({
    required this.curriculumCode,
    required this.total,
    required this.semesterCount,
    required this.search,
    required this.searchFocus,
    required this.semesters,
    required this.selectedSemester,
    required this.credits,
    required this.selectedCredits,
    required this.prerequisite,
    required this.viewMode,
    required this.resultCount,
    required this.hasFilters,
    required this.narrow,
    required this.onChanged,
    required this.onSemester,
    required this.onCredits,
    required this.onPrerequisite,
    required this.onViewMode,
    required this.onClear,
  });

  final String curriculumCode;
  final int total;
  final int semesterCount;
  final TextEditingController search;
  final FocusNode searchFocus;
  final List<int> semesters;
  final int? selectedSemester;
  final List<String> credits;
  final String? selectedCredits;
  final PrerequisiteFilter prerequisite;
  final SubjectViewMode viewMode;
  final int resultCount;
  final bool hasFilters;
  final bool narrow;
  final VoidCallback onChanged;
  final ValueChanged<int?> onSemester;
  final ValueChanged<String?> onCredits;
  final ValueChanged<PrerequisiteFilter> onPrerequisite;
  final ValueChanged<SubjectViewMode> onViewMode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$total subjects across $semesterCount semesters'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('subject-search'),
            controller: search,
            focusNode: searchFocus,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: 'Search by code, name (English or Vietnamese)…',
              suffixIcon: search.text.isEmpty
                  ? const Tooltip(
                      message: 'Focus search: Ctrl+K',
                      child: Icon(Icons.keyboard),
                    )
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        search.clear();
                        onChanged();
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: selectedSemester == null,
                  onSelected: (_) => onSemester(null),
                ),
                const SizedBox(width: 8),
                for (final semester in semesters) ...[
                  ChoiceChip(
                    label: Text(semester == 0 ? 'Prep' : 'Sem $semester'),
                    selected: selectedSemester == semester,
                    onSelected: (_) => onSemester(semester),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownMenu<String?>(
                key: const Key('credits-filter'),
                width: 150,
                label: const Text('Credits'),
                initialSelection: selectedCredits,
                onSelected: onCredits,
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'All credits'),
                  ...credits.map(
                    (value) => DropdownMenuEntry(value: value, label: value),
                  ),
                ],
              ),
              DropdownMenu<PrerequisiteFilter>(
                key: const Key('prerequisite-filter'),
                width: 190,
                label: const Text('Prerequisite'),
                initialSelection: prerequisite,
                onSelected: (value) {
                  if (value != null) onPrerequisite(value);
                },
                dropdownMenuEntries: const [
                  DropdownMenuEntry(
                    value: PrerequisiteFilter.all,
                    label: 'All',
                  ),
                  DropdownMenuEntry(
                    value: PrerequisiteFilter.hasPrerequisite,
                    label: 'Has prerequisite',
                  ),
                  DropdownMenuEntry(
                    value: PrerequisiteFilter.noPrerequisite,
                    label: 'No prerequisite',
                  ),
                ],
              ),
              if (!narrow)
                SegmentedButton<SubjectViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: SubjectViewMode.grid,
                      icon: Icon(Icons.grid_view_outlined),
                      label: Text('Grid'),
                    ),
                    ButtonSegment(
                      value: SubjectViewMode.list,
                      icon: Icon(Icons.view_list_outlined),
                      label: Text('List'),
                    ),
                  ],
                  selected: {viewMode},
                  onSelectionChanged: (values) => onViewMode(values.first),
                ),
              Text('$resultCount result${resultCount == 1 ? '' : 's'}'),
              if (hasFilters)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear filters'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.showSemester,
    required this.onTap,
    this.compact = false,
  });
  final Subject subject;
  final bool showSemester;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final name = subjectDisplayName(subject);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.code,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text('${subject.credits} credits'),
                ],
              ),
              const SizedBox(height: 10),
              Text(name.primary, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (name.secondary case final secondary?)
                Text(
                  secondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              if (!compact) const Spacer() else const SizedBox(height: 10),
              Row(
                children: [
                  if (showSemester)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        subject.semester == 0
                            ? 'Prep'
                            : 'Semester ${subject.semester}',
                      ),
                    ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward,
                    semanticLabel: 'Open subject',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onClear});
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.search_off_outlined, size: 48),
        const SizedBox(height: 12),
        const Text('No subjects match these filters.'),
        TextButton(onPressed: onClear, child: const Text('Clear filters')),
      ],
    ),
  );
}
