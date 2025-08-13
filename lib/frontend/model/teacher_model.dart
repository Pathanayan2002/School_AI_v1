class Teacher {
  final int id;
  final String name;

  Teacher({required this.id, required this.name});

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'Unknown',
    );
  }
}