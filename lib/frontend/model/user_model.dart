class User {
  final int? id;
  final String name;
  final String? email;
  final String? phone;
  final String? enrollmentId;
  final String? role;

  User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.enrollmentId,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      enrollmentId: json['enrollmentId'] as String?,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'enrollmentId': enrollmentId,
      'role': role,
    };
  }
}