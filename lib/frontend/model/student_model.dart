class Student {
  final String id;
  final String name;
  final String? enrollmentNo;
  final String studentClass;
  final int? rollNo;
  final DateTime? dob;
  final DateTime? admissionDate;

  Student({
    required this.id,
    required this.name,
    this.enrollmentNo,
    required this.studentClass,
    this.rollNo,
    this.dob,
    this.admissionDate,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    print('Parsing student JSON: $json');
    if (json['message'] != null) {
      print('Unexpected message in JSON: $json');
      throw FormatException('Invalid student data: contains message field');
    }

    final id = json['id']?.toString();
    if (id == null || id.isEmpty) {
      print('Invalid student ID in JSON: $json');
      throw FormatException('Invalid or missing student ID');
    }

    final name = json['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      print('Invalid student data in JSON: $json');
      throw FormatException('Missing name');
    }

    final enrollmentNo = json['registerNumber']?.toString().trim();
    final studentClass = json['classId']?.toString() ?? 'N/A';
    final rollNo = json['rollNo'] != null
        ? int.tryParse(json['rollNo'].toString())
        : null;

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return Student(
      id: id,
      name: name,
      enrollmentNo: enrollmentNo,
      studentClass: studentClass,
      rollNo: rollNo,
      dob: parseDate(json['dob']),
      admissionDate: parseDate(json['admissionDate']),
    );
  }

  String get classId => studentClass;

  Map<String, dynamic> toJson() {
    String? formatDate(DateTime? date) =>
        date != null ? date.toIso8601String().split('T').first : null;

    return {
      'id': id,
      'name': name,
      'registerNumber': enrollmentNo,
      'classId': studentClass,
      'rollNo': rollNo,
      'dob': formatDate(dob),
      'admissionDate': formatDate(admissionDate),
    };
  }
}