class Student {
  final int id;
  final String name;
  final String? enrollmentNo; // nullable if backend may send null
  final String studentClass;
  final int? rollNo;
  final DateTime? dob; // optional date field
  final DateTime? admissionDate; // optional date field

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

    // Ignore API error responses
    if (json['message'] != null) {
      print('Unexpected message in JSON: $json');
      throw FormatException('Invalid student data: contains message field');
    }

    // Parse ID
    final id = int.tryParse(json['id']?.toString() ?? '');
    if (id == null || id == 0) {
      print('Invalid student ID in JSON: $json');
      throw FormatException('Invalid or missing student ID');
    }

    // Parse required name
    final name = json['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      print('Invalid student data in JSON: $json');
      throw FormatException('Missing name');
    }

    // Parse optional fields
    final enrollmentNo = json['registerNumber']?.toString().trim();
    final studentClass = json['classId']?.toString() ?? 'N/A';
    final rollNo = json['rollNo'] != null
        ? int.tryParse(json['rollNo'].toString())
        : null;

    // Parse date fields safely
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

  get classId => null;

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
