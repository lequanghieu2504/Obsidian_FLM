import '../../../models/subject.dart';

class SubjectDisplayName {
  const SubjectDisplayName({required this.primary, this.secondary});

  final String primary;
  final String? secondary;
}

SubjectDisplayName subjectDisplayName(Subject subject) {
  final separator = subject.name.indexOf('_');
  if (separator < 0) {
    return SubjectDisplayName(primary: subject.name.trim());
  }

  final primary = subject.name.substring(0, separator).trim();
  final secondary = subject.name.substring(separator + 1).trim();
  return SubjectDisplayName(
    primary: primary.isEmpty ? subject.name : primary,
    secondary: secondary.isEmpty ? null : secondary,
  );
}

String prerequisiteDisplay(Subject subject) {
  final value = subject.preRequisite.trim();
  if (hasPrerequisite(subject)) return subject.preRequisite;
  if (value.isEmpty) return 'No prerequisite information';
  return 'No prerequisite';
}

bool hasPrerequisite(Subject subject) {
  final normalized = subject.preRequisite.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'none' ||
      normalized == 'none.' ||
      normalized == 'không') {
    return false;
  }
  return true;
}

String semesterDisplay(int semester) =>
    semester == 0 ? 'OJT / Prep' : 'Semester $semester';

Map<int, List<Subject>> groupSubjectsBySemester(List<Subject> subjects) {
  final grouped = <int, List<Subject>>{};
  for (final subject in subjects) {
    (grouped[subject.semester] ??= []).add(subject);
  }
  final semesters = grouped.keys.toList()..sort();
  return {for (final semester in semesters) semester: grouped[semester]!};
}
