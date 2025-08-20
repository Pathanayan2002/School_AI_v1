import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';

class AssignedSubjectTeacherPage extends StatefulWidget {
  const AssignedSubjectTeacherPage({super.key});

  @override
  State<AssignedSubjectTeacherPage> createState() =>
      _AssignedSubjectTeacherPageState();
}

class _AssignedSubjectTeacherPageState
    extends State<AssignedSubjectTeacherPage> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _hasError = false;

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _subjects = [];
  Map<String, List<Map<String, dynamic>>> _teacherSubjects = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final teacherResult = await _apiService.getAllUsers(schoolId: '');
      final subjectResult = await _apiService.getAllSubjects(schoolId: '');

      _teachers = _extractList(teacherResult)
          .where((u) => u['role']?.toString().toLowerCase() == 'teacher')
          .map((u) {
        u['id'] = (u['_id'] ?? u['id']).toString();
        return u;
      }).toList();

      _subjects = _extractList(subjectResult).map((s) {
        s['id'] = (s['_id'] ?? s['id']).toString();
        s['teacherId'] = (s['teacherId'] ?? '').toString();
        return s;
      }).toList();

      _teacherSubjects.clear();
      for (var subject in _subjects) {
        final teacherId = subject['teacherId'].toString();
        if (!_teacherSubjects.containsKey(teacherId)) {
          _teacherSubjects[teacherId] = [];
        }
        _teacherSubjects[teacherId]?.add(subject);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      if (kDebugMode) {
        print('Fetch data error: $e');
      }
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic res) {
    if (res is Map && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    } else if (res is List) {
      return List<Map<String, dynamic>>.from(res);
    }
    return [];
  }

  Future<void> _removeSubjectFromTeacher(String teacherId, String subjectId) async {
    try {
      final res = await _apiService.removeSubjectFromTeacher(
        teacherId: teacherId,
        subjectId: subjectId,
      );

      if (res['message'] == 'Subject unassigned from teacher successfully') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject unassigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unassign: ${res['message'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      if (kDebugMode) {
        print('Unassign subject error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Error loading data", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assigned Subjects to Teachers"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Teachers and Their Assigned Subjects",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            if (_teachers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text("No teachers available", style: TextStyle(color: Colors.grey)),
              ),
            ..._teachers.map((teacher) {
              final teacherId = teacher['id'].toString();
              final assignedSubjects = _teacherSubjects[teacherId] ?? [];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ExpansionTile(
                  title: Text(teacher['name'] ?? 'Unknown'),
                  subtitle: Text(
                    assignedSubjects.isEmpty
                        ? 'No subjects assigned'
                        : assignedSubjects.map((s) => s['name']).join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: [
                    ...assignedSubjects.map((subject) {
                      return ListTile(
                        title: Text(subject['name'] ?? 'Unknown'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeSubjectFromTeacher(
                            teacherId,
                            subject['id'].toString(),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}