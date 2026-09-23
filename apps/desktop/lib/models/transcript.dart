class TranscriptRecord {
  final int no;
  final String semester;
  final String subjectCode;
  final String subjectName;
  final int credit;
  final String grade;
  final String status;
  final bool isScored;

  // New field for estimation
  double? estimatedGrade;

  TranscriptRecord({
    required this.no,
    required this.semester,
    required this.subjectCode,
    required this.subjectName,
    required this.credit,
    required this.grade,
    required this.status,
    this.isScored = true,
    this.estimatedGrade,
  });

  Map<String, dynamic> toJson() {
    return {
      'no': no,
      'semester': semester,
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'credit': credit,
      'grade': grade,
      'status': status,
      'isScored': isScored,
      'estimatedGrade': estimatedGrade,
    };
  }

  factory TranscriptRecord.fromJson(Map<String, dynamic> json) {
    return TranscriptRecord(
      no: json['no'] ?? 0,
      semester: json['semester'] ?? '',
      subjectCode: json['subjectCode'] ?? '',
      subjectName: json['subjectName'] ?? '',
      credit: json['credit'] ?? 0,
      grade: json['grade'] ?? '',
      status: json['status'] ?? '',
      isScored: json['isScored'] ?? true,
      estimatedGrade: json['estimatedGrade'],
    );
  }
}
