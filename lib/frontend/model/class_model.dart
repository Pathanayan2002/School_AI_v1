class ClassModel {
  final String id;
  final String name;
  final List<String>? divisions; // Added to handle divisions field

  ClassModel({required this.id, required this.name, this.divisions});

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      divisions: json['divsion'] != null ? List<String>.from(json['divsion']) : null, // Handle 'divsion' typo
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (divisions != null) 'divisions': divisions,
    };
  }
}