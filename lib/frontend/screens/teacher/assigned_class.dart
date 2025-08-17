import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../model/class_model.dart';
import '../../model/student_model.dart';
import '../services/api_client.dart';
import 'assign_marks.dart';

class TeacherAssignedClassesPage extends StatefulWidget {
  static const routeName = '/teacherAssignedClasses';
  const TeacherAssignedClassesPage({super.key});

  @override
  _TeacherAssignedClassesPageState createState() => _TeacherAssignedClassesPageState();
}

class _TeacherAssignedClassesPageState extends State<TeacherAssignedClassesPage> {
  final ApiService _apiService = ApiService();
  List<ClassModel> classes = [];
  Map<String, List<Student>> classStudents = {};
  bool isLoading = true;
  String? errorMessage;
  String? teacherId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      teacherId = await _apiService.getCurrentUserId();
      if (teacherId == null) {
        setState(() {
          errorMessage = 'User not logged in';
          isLoading = false;
        });
        return;
      }

      final classesResponse = await _apiService.getClassesByTeacherId(teacherId!);
      developer.log('Classes Response: $classesResponse', name: 'TeacherAssignedClassesPage');

      if (classesResponse['success'] == true && classesResponse['data'] != null) {
        final classList = classesResponse['data'] as List<dynamic>;

        classes.clear();
        classStudents.clear();

        for (var classJson in classList) {
          final classModel = ClassModel.fromJson(classJson);
          final studentList = (classJson['students'] as List<dynamic>? ?? [])
              .map((s) => Student.fromJson(s))
              .toList();

          classes.add(classModel);
          classStudents[classModel.id] = studentList;
        }
      } else {
        setState(() {
          errorMessage = classesResponse['message'] ?? 'Failed to load classes';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: $e';
      });
      developer.log('Fetch error: $e', name: 'TeacherAssignedClassesPage');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSubjectsForTeacher() async {
    final response = await _apiService.getAllSubjects(schoolId: '');
    if (response['success'] && response['data'] != null && teacherId != null) {
      final assignedSubjects = response['data']
          .where((sub) => sub['teacherId']?.toString() == teacherId)
          .toList();
      developer.log('Fetched ${assignedSubjects.length} subjects for teacher $teacherId: $assignedSubjects',
          name: 'TeacherAssignedClassesPage');
      return assignedSubjects;
    }
    developer.log('No subjects fetched for teacher $teacherId', name: 'TeacherAssignedClassesPage');
    return [];
  }

  Future<Map<String, dynamic>?> _fetchResult(String studentId, String subjectId, String semester) async {
    try {
      final response = await _apiService.getResultById(studentId, subjectId,);
      developer.log('Fetch result response: $response', name: 'TeacherAssignedClassesPage');
      if (response['success'] == true && response['data'] != null) {
        return response['data'];
      }
      return null;
    } catch (e) {
      developer.log('Error fetching result: $e', name: 'TeacherAssignedClassesPage');
      return null;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Classes'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
              : classes.isEmpty
                  ? const Center(child: Text('No assigned classes'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: classes.length,
                      itemBuilder: (context, index) {
                        final classItem = classes[index];
                        final students = classStudents[classItem.id] ?? [];
                        return ExpansionTile(
                          title: Text(
                            'Class ${classItem.name}${classItem.divisions != null && classItem.divisions!.isNotEmpty ? " (${classItem.divisions!.join(", ")})" : ""}',
                          ),
                          subtitle: Text('${students.length} student(s)'),
                          children: students.isEmpty
                              ? [const ListTile(title: Text('No students in this class'))]
                              : students.map((student) {
                                  return ListTile(
                                    title: Text(student.name),
                                    subtitle: Text('Roll No: ${student.rollNo ?? 'N/A'}'),
                                    trailing: const Icon(Icons.edit),
                                    onTap: () async {
                                      final subjects = await _fetchSubjectsForTeacher();
                                      if (subjects.isEmpty) {
                                        _showError('No subjects assigned to you');
                                        return;
                                      }
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('Select Subject for ${student.name}'),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: subjects.length,
                                              itemBuilder: (ctx, idx) {
                                                final subject = subjects[idx];
                                                return ListTile(
                                                  title: Text(subject['name'] ?? 'Unnamed Subject'),
                                                  trailing: FutureBuilder<Map<String, dynamic>?>(
                                                    future: _fetchResult(
                                                      student.id.toString(),
                                                      subject['id'].toString(),
                                                      '1',
                                                    ),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                                        return const CircularProgressIndicator(strokeWidth: 2);
                                                      }
                                                      return snapshot.data != null
                                                          ? const Icon(Icons.check_circle, color: Colors.green)
                                                          : const Icon(Icons.add_circle_outline);
                                                    },
                                                  ),
                                                  onTap: () async {
                                                    final result = await _fetchResult(
                                                      student.id.toString(),
                                                      subject['id'].toString(),
                                                      '1',
                                                    );
                                                    Navigator.pop(ctx);
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => AssignMarkPage(
                                                          subjectId: subject['id'].toString(),
                                                          subjectName: subject['name'] ?? 'Unnamed Subject',
                                                          studentId: student.id.toString(),
                                                          semester: '1',
                                                          existingResult: result,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Cancel'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                        );
                      },
                    ),
    );
  }
}