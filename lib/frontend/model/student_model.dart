class Student {
  final int id; // <-- Changed from String to int
  final String enrollmentNo;
  final String name;
  final String studentClass; // e.g., "1-A"
  final String division;
  final String year;

  Student({
    required this.id,
    required this.enrollmentNo,
    required this.name,
    required this.studentClass,
    required this.division,
    required this.year,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: int.tryParse(json['_id']?.toString() ?? '') ?? 0,
      enrollmentNo: json['enrollmentId'] ?? '',
      name: json['name'] ?? '',
      studentClass: json['class'] ?? '',
      division: json['division'] ?? '',
      year: json['year'] ?? '',
    );
  }
}