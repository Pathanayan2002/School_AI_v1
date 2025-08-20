import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/api_client.dart';
import '../../model/class_model.dart';
import '../../model/student_model.dart';
import 'assign_marks.dart';

class TeacherDashboardPage extends StatefulWidget {
  static const routeName = '/teacherDashboard';
  const TeacherDashboardPage({super.key});

  @override
  _TeacherDashboardPageState createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> assignedSubjects = [];
  List<ClassModel> classes = [];
  Map<String, List<Student>> classStudents = {};
  Map<String, Map<String, dynamic>> resultCache = {};
  bool isLoading = true;
  String? errorMessage;
  String? teacherId;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

      final schoolId = await _apiService.getCurrentSchoolId();
      if (schoolId == null) {
        setState(() {
          errorMessage = 'School ID not found. Please login again.';
          isLoading = false;
        });
        return;
      }

      final subjectsResponse = await _apiService.getAllSubjects(schoolId: schoolId);
      developer.log('Subjects response: ${jsonEncode(subjectsResponse)}', name: 'TeacherDashboardPage');
      if (subjectsResponse['success'] && subjectsResponse['data'] != null) {
        assignedSubjects = subjectsResponse['data']
            .where((sub) => sub['teacherId']?.toString() == teacherId)
            .toList();
        developer.log('Loaded ${assignedSubjects.length} subjects for teacher $teacherId: $assignedSubjects',
            name: 'TeacherDashboardPage');
      } else {
        setState(() {
          errorMessage = subjectsResponse['message'] ?? 'Failed to load subjects';
        });
      }

      final classesResponse = await _apiService.getClassesByTeacherId(teacherId!);
      developer.log('Classes response: ${jsonEncode(classesResponse)}', name: 'TeacherDashboardPage');
      if (classesResponse['success'] && classesResponse['data'] != null) {
        final classData = classesResponse['data'] as List<dynamic>;
        classes = classData.map((classJson) => ClassModel.fromJson(classJson)).toList();
        classStudents = {
          for (var classJson in classData)
            ClassModel.fromJson(classJson).id: (classJson['students'] as List<dynamic>?)?.map((s) => Student.fromJson(s)).toList() ?? []
        };
        developer.log('Loaded ${classes.length} classes for teacher $teacherId', name: 'TeacherDashboardPage');
      } else {
        setState(() {
          errorMessage = classesResponse['message'] ?? 'Failed to load classes';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading data: $e';
      });
      developer.log('Error loading data: $e', name: 'TeacherDashboardPage');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchResult(String studentId, String subjectId, String semester) async {
    final cacheKey = '${studentId}_${subjectId}_$semester';
    if (resultCache.containsKey(cacheKey)) {
      return resultCache[cacheKey];
    }

    try {
      final response = await _apiService.getResultById(studentId, subjectId);
      developer.log('Fetch result response: ${jsonEncode(response)}', name: 'TeacherDashboardPage');
      if (response['success'] && response['data'] != null) {
        resultCache[cacheKey] = response['data'];
        return response['data'];
      } else {
        developer.log('No result found: ${response['message']}', name: 'TeacherDashboardPage');
        return null;
      }
    } catch (e) {
      developer.log('Error fetching result: $e', name: 'TeacherDashboardPage');
      if (e is DioException && e.response?.statusCode == 403) {
        setState(() {
          errorMessage = 'Access denied: You do not have permission to view this result';
        });
      }
      return null;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadData,
        ),
      ),
    );
  }

  void _navigateToAssignMarks(String subjectId, String subjectName, String studentId, {Map<String, dynamic>? result}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignMarkPage(
          subjectId: subjectId,
          subjectName: subjectName,
          studentId: studentId,
          semester: '1',
          existingResult: result,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Subjects'),
            Tab(text: 'Classes'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assigned Subjects',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            assignedSubjects.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('No subjects assigned'),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: assignedSubjects.length,
                                    itemBuilder: (context, index) {
                                      final subject = assignedSubjects[index];
                                      return Card(
                                        child: ListTile(
                                          title: Text(subject['name'] ?? 'Unnamed Subject'),
                                          subtitle: Text('ID: ${subject['id']}'),
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assigned Classes',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            classes.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('No classes assigned'),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: classes.length,
                                    itemBuilder: (context, index) {
                                      final classItem = classes[index];
                                      final students = classStudents[classItem.id] ?? [];
                                      return Card(
                                        elevation: 2,
                                        child: ExpansionTile(
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
                                                    onTap: () {
                                                      if (assignedSubjects.isEmpty) {
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
                                                              itemCount: assignedSubjects.length,
                                                              itemBuilder: (ctx, idx) {
                                                                final subject = assignedSubjects[idx];
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
                                                                    _navigateToAssignMarks(
                                                                      subject['id'].toString(),
                                                                      subject['name'] ?? 'Unnamed Subject',
                                                                      student.id.toString(),
                                                                      result: result,
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
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}