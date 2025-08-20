class ResultModel {
  final String id;
  final String studentId;
  final String schoolId;
  final String semester;
  final Map<String, dynamic> subjects;
  final double totalMarks;
  final double percentage;
  final String grade;
  final String? specialProgress;
  final String? hobbies;
  final String? areasOfImprovement;

  ResultModel({
    required this.id,
    required this.studentId,
    required this.schoolId,
    required this.semester,
    required this.subjects,
    required this.totalMarks,
    required this.percentage,
    required this.grade,
    this.specialProgress,
    this.hobbies,
    this.areasOfImprovement,
  });

  factory ResultModel.fromJson(Map<String, dynamic> json) {
    return ResultModel(
      id: json['id'].toString(),
      studentId: json['studentId'].toString(),
      schoolId: json['schoolId'].toString(),
      semester: json['semester'].toString(),
      subjects: Map<String, dynamic>.from(json['subjects'] ?? {}),
      totalMarks: (json['totalMarks'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
      grade: json['grade'] ?? 'F',
      specialProgress: json['specialProgress'],
      hobbies: json['hobbies'],
      areasOfImprovement: json['areasOfImprovement'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'schoolId': schoolId,
      'semester': semester,
      'subjects': subjects,
      'totalMarks': totalMarks,
      'percentage': percentage,
      'grade': grade,
      'specialProgress': specialProgress,
      'hobbies': hobbies,
      'areasOfImprovement': areasOfImprovement,
    };
  }
}