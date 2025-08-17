// File: assign_class_to_teacher.dart
import 'package:flutter/material.dart';
import '../../model/user_model.dart';
import '../../model/class_model.dart';
import '../services/api_client.dart';

class AssignClassToTeacherPage extends StatefulWidget {
  const AssignClassToTeacherPage({super.key});

  @override
  State<AssignClassToTeacherPage> createState() => _AssignClassToTeacherPageState();
}

class _AssignClassToTeacherPageState extends State<AssignClassToTeacherPage> {
  final ApiService _apiService = ApiService();
  List<User> teachers = [];
  List<ClassModel> classes = [];
  User? selectedTeacher;
  ClassModel? selectedClass;
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
      final teachersResponse = await _apiService.getAllUsers(schoolId: '');
      if (teachersResponse['success'] && teachersResponse['data'] != null) {
        teachers = (teachersResponse['data'] as List)
            .where((t) => t['role'].toString().toLowerCase() == 'teacher')
            .map((t) => User.fromJson(t))
            .where((t) => t.id != null)
            .toList();
        if (teachers.isEmpty) _showSnack('No valid teachers found');
      } else {
        _showSnack(teachersResponse['message'] ?? 'Failed to load teachers');
      }

      final classesResponse = await _apiService.getAllClasses(schoolId: '');
      if (classesResponse['success'] && classesResponse['data'] != null) {
        classes = (classesResponse['data'] as List)
            .map((c) => ClassModel.fromJson(c))
            .where((c) => c.id.isNotEmpty)
            .toList();
        if (classes.isEmpty) _showSnack('No valid classes found');
      } else {
        _showSnack(classesResponse['message'] ?? 'Failed to load classes');
      }
    } catch (e) {
      _showSnack('Error fetching data: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> _assignClass() async {
    if (selectedTeacher == null || selectedClass == null) {
      return _showSnack('Please select both a teacher and a class');
    }

    setState(() => isLoading = true);

    try {
      final response = await _apiService.addTeachersToClass(
        classId: selectedClass!.id,
        teacherIds: [selectedTeacher!.id.toString()], userId: '',
        
      );

      if (response['success'] == true) {
        _showSnack(
          'Assigned class ${selectedClass!.name} to ${selectedTeacher!.name}',
          color: Colors.green,
        );
        setState(() {
          selectedTeacher = null;
          selectedClass = null;
        });
      } else {
        _showSnack(response['message'] ?? 'Failed to assign class');
      }
    } catch (e) {
      _showSnack('Error assigning class: $e');
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Class to Teacher', style: TextStyle(color: Colors.white)),
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
                      DropdownButtonFormField<User>(
                        value: selectedTeacher,
                        hint: const Text('Select a teacher'),
                        items: teachers
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text('${t.name} (ID: ${t.id})'),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => selectedTeacher = val),
                        decoration: InputDecoration(
                          labelText: 'Teacher',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.person, color: Colors.blue),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ClassModel>(
                        value: selectedClass,
                        hint: const Text('Select a class'),
                        items: classes
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => selectedClass = val),
                        decoration: InputDecoration(
                          labelText: 'Class',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.class_, color: Colors.blue),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: (selectedTeacher != null && selectedClass != null && !isLoading)
                            ? _assignClass
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
                            : const Text('Assign Class', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}