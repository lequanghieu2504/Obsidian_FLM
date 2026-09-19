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

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    semester: json['semester'] ?? 0,
    code: json['code'] ?? '',
    name: json['name'] ?? '',
    credits: json['credits'] ?? '',
    preRequisite: json['preRequisite'] ?? '',
  );
}
