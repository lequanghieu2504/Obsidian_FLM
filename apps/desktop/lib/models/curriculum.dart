class Curriculum {
  final String code;
  final String name;
  final String description;
  final String decisionNo;
  final String totalCredit;
  final String detailUrl;

  Curriculum({
    required this.code,
    required this.name,
    required this.description,
    required this.decisionNo,
    required this.totalCredit,
    required this.detailUrl,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'description': description,
    'decisionNo': decisionNo,
    'totalCredit': totalCredit,
    'detailUrl': detailUrl,
  };

  factory Curriculum.fromJson(Map<String, dynamic> json) => Curriculum(
    code: json['code'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    decisionNo: json['decisionNo'] ?? '',
    totalCredit: json['totalCredit'] ?? '',
    detailUrl: json['detailUrl'] ?? '',
  );
}
