import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

class Student {
  final String id;
  final String name;
  final String rollNo;
  final String className;

  Student({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.className,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      rollNo: json['rollNo'] ?? '',
      className: json['className'] ?? '',
    );
  }
}

class StudentRecordScreen extends StatefulWidget {
  const StudentRecordScreen({Key? key}) : super(key: key);

  @override
  State<StudentRecordScreen> createState() => _StudentRecordScreenState();
}

class _StudentRecordScreenState extends State<StudentRecordScreen> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool isLoading = false;
  List<Student> students = [];

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    loadStudents();
  }

  Future<void> _checkAuthorization() async {
    final userId = await _storage.read(key: 'user_id');
    if (userId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> loadStudents() async {
    setState(() => isLoading = true);

    try {
      final res = await _apiService.getAllStudents();
      if (res['success'] && res['data'] is List) {
        setState(() {
          students = List<dynamic>.from(res['data'])
              .map((item) => Student.fromJson(item))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception(res['message'] ?? 'Failed to load students');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
    }
  }

 Future<void> exportToExcel() async {
  final excel = Excel.createExcel();
  final sheet = excel['Students'];

  // Header
  sheet.appendRow([
    TextCellValue('ID'),
    TextCellValue('Name'),
    TextCellValue('Roll No'),
    TextCellValue('Class'),
  ]);

  // Data rows
  for (var student in students) {
    sheet.appendRow([
      TextCellValue(student.id),
      TextCellValue(student.name),
      TextCellValue(student.rollNo),
      TextCellValue(student.className),
    ]);
  }

  final fileBytes = excel.encode();
  if (fileBytes != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel file generated successfully')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: students.isEmpty ? null : exportToExcel,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
              ? const Center(child: Text('No students found'))
              : ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(student.rollNo),
                        ),
                        title: Text(student.name),
                        subtitle: Text('Class: ${student.className}'),
                      ),
                    );
                  },
                ),
    );
  }
}
