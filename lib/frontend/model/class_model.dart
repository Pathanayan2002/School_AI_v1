class ClassModel {
  final String id;
  final String name;
  final List<String>? divisions;
  final List<String>? teacherIds;
  final List<String>? studentIds;

  ClassModel({
    required this.id,
    required this.name,
    this.divisions,
    this.teacherIds,
    this.studentIds,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    // Handle students field as either list of IDs or list of student objects
    final studentIds = (json['students'] as List<dynamic>?)?.map((s) {
      return s is Map ? s['id']?.toString() ?? '' : s.toString();
    }).where((id) => id.isNotEmpty).toList();

    return ClassModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      divisions: (json['divisions'] as List<dynamic>?)?.cast<String>(),
      teacherIds: (json['teachers'] as List<dynamic>?)?.map((t) => t.toString()).toList(),
      studentIds: studentIds,
    );
  }
}