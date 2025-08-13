class SubjectItem {
  final int? id;
  final String subjectName;
  final String? standard;

  SubjectItem({
    this.id,
    required this.subjectName,
    this.standard,
  });

  factory SubjectItem.fromJson(Map<String, dynamic> json) {
    return SubjectItem(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      subjectName: json['name'] ?? '',
      standard: json['standard'] ?? json['classId']?.toString(),
    );
  }
}