// File: assign_subject_to_student.dart
import 'package:flutter/material.dart';
import '../../model/subject_model.dart';
import '../../model/student_model.dart';
import '../services/api_client.dart';

class AssignSubjectToStudentPage extends StatefulWidget {
  const AssignSubjectToStudentPage({super.key});

  @override
  State<AssignSubjectToStudentPage> createState() => _AssignSubjectToStudentPageState();
}

class _AssignSubjectToStudentPageState extends State<AssignSubjectToStudentPage> {
  final ApiService _apiService = ApiService();
  List<SubjectItem> subjects = [];
  List<Student> students = [];
  SubjectItem? selectedSubject;
  Student? selectedStudent;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _showSnack(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);

    try {
      // Fetch subjects
      final subjectsResponse = await _apiService.getAllSubjects(schoolId: '');
      if (subjectsResponse['success'] && subjectsResponse['data'] != null) {
        subjects = (subjectsResponse['data'] as List)
            .map((s) => SubjectItem.fromJson(s))
            .where((s) => s.id != null && s.id != 0)
            .toList();
        if (subjects.isEmpty) _showSnack('No valid subjects found');
      } else {
        _showSnack(subjectsResponse['message'] ?? 'Failed to load subjects');
      }

      // Fetch students
      final studentsResponse = await _apiService.getAllStudents();
      if (studentsResponse['success'] && studentsResponse['data'] != null) {
        students = (studentsResponse['data'] as List)
            .map((s) => Student.fromJson(s))
            .where((s) => s.id != 0)
            .toList();
        if (students.isEmpty) _showSnack('No valid students found');
      } else {
        _showSnack(studentsResponse['message'] ?? 'Failed to load students');
      }
    } catch (e) {
      _showSnack('Error fetching data: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> _assignSubject() async {
    if (selectedStudent == null || selectedSubject == null) {
      return _showSnack('Please select both a student and a subject');
    }

    setState(() => isLoading = true);

    try {
      final response = await _apiService.addSubjectToStudent(
        studentId: selectedStudent!.id.toString(),
        subjectId: selectedSubject!.id.toString(),
        marks: '',
        grade: '',
      );

      if (response['success'] == true) {
        _showSnack(
          'Assigned ${selectedSubject!.subjectName} to ${selectedStudent!.name}',
          color: Colors.green,
        );
        setState(() {
          selectedStudent = null;
          selectedSubject = null;
        });
      } else {
        _showSnack(response['message'] ?? 'Failed to assign subject');
      }
    } catch (e) {
      _showSnack('Error assigning subject: $e');
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Subject to Student', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<Student>(
                        value: selectedStudent,
                        hint: const Text('Select a student'),
                        items: students
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('${s.name} (${s.enrollmentNo})'),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => selectedStudent = val),
                        decoration: InputDecoration(
                          labelText: 'Student',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.person, color: Colors.blue),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SubjectItem>(
                        value: selectedSubject,
                        hint: const Text('Select a subject'),
                        items: subjects
                            .map((subj) => DropdownMenuItem(
                                  value: subj,
                                  child: Text(subj.subjectName),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => selectedSubject = val),
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.book, color: Colors.blue),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: (selectedStudent != null && selectedSubject != null && !isLoading)
                            ? _assignSubject
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Assign Subject', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}