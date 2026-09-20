class Subject {
  final int semester;
  final String code;
  final String name;
  final String credits;
  final String preRequisite;

  Subject({
    required this.semester,
    required this.code,
    required this.name,
    required this.credits,
    required this.preRequisite,
  });

  Map<String, dynamic> toJson() => {
    'semester': semester,
    'code': code,
    'name': name,
    'credits': credits,
    'preRequisite': preRequisite,
  };

  factory Subject.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'semester': int semester,
        'code': String code,
        'name': String name,
        'credits': String credits,
        'preRequisite': String preRequisite,
      } =>
        Subject(
          semester: semester,
          code: code,
          name: name,
          credits: credits,
          preRequisite: preRequisite,
        ),
      _ => throw const FormatException('Invalid Subject record.'),
    };
  }
}
