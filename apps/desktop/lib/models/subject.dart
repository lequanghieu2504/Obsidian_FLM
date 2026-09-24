class Subject {
  final int semester;
  final String code;
  final String name;
  final String credits;
  final String preRequisite;
  final bool isPlaceholder;

  Subject({
    required this.semester,
    required this.code,
    required this.name,
    required this.credits,
    required this.preRequisite,
    this.isPlaceholder = false,
  });

  Map<String, dynamic> toJson() => {
    'semester': semester,
    'code': code,
    'name': name,
    'credits': credits,
    'preRequisite': preRequisite,
    'isPlaceholder': isPlaceholder,
  };

  factory Subject.fromJson(Map<String, dynamic> json) {
    int parsedSemester = 0;
    if (json['semester'] != null) {
      if (json['semester'] is int) {
        parsedSemester = json['semester'];
      } else if (json['semester'] is String) {
        parsedSemester = int.tryParse(json['semester']) ?? 0;
      }
    }

    return Subject(
      semester: parsedSemester,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      credits: json['credits']?.toString() ?? '',
      preRequisite: json['preRequisite']?.toString() ?? json['prerequisite']?.toString() ?? '', // Handle both camelCase and lowercase from extension
      isPlaceholder: json['isPlaceholder'] ?? false,
    );
  }
}
