// File: teacher_presenty.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

// Minimal Teacher model based on getAllUsers response
class Teacher {
  final String id;
  final String name;
  final String enrollmentId;
  final String role;

  Teacher({
    required this.id,
    required this.name,
    required this.enrollmentId,
    required this.role,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      enrollmentId: json['enrollmentId'] ?? '',
      role: json['role'] ?? '',
    );
  }
}

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  late List<String> monthList;
  List<Teacher> teachers = [];
  String? selectedTeacherId;
  bool isLoading = false;
  bool isSubmitting = false;
  final TextEditingController _totalDaysController = TextEditingController();
  final TextEditingController _presentDaysController = TextEditingController();
  String? schoolId;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    _initMonthList();
  }

  Future<void> _checkAuthorization() async {
    final userId = await _storage.read(key: 'user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final response = await _apiService.getUserById(userId);
    if (response['success'] && response['data'] != null) {
      final role = response['data']['role']?.toLowerCase();
      schoolId = response['data']['schoolId']?.toString();
      if (role != 'clerk') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: Only Clerks can manage attendance')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        loadTeachers();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user data')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _initMonthList() {
    monthList = List.generate(
      12,
      (i) => DateFormat('MMMM yyyy').format(DateTime(DateTime.now().year, i + 1)),
    );
  }

  Future<void> loadTeachers() async {
    setState(() {
      isLoading = true;
      selectedTeacherId = null;
      teachers.clear();
    });

    try {
      if (schoolId == null) {
        throw Exception('School ID not found');
      }
      final res = await _apiService.getAllUsers(schoolId: schoolId!);
      if (res['success'] && res['data'] is List) {
        setState(() {
          teachers = List<dynamic>.from(res['data'])
              .where((item) => item['role']?.toLowerCase() == 'teacher')
              .map((item) => Teacher.fromJson(item))
              .toList();
          isLoading = false;
        });

        if (teachers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No teachers found in the system. Please add teachers first.')),
          );
        }
      } else {
        throw Exception('Failed to load teachers: ${res['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading teachers: $e')),
      );
    }
  }

  Future<void> submitAttendance() async {
    if (selectedTeacherId == null ||
        _totalDaysController.text.trim().isEmpty ||
        _presentDaysController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a teacher and fill all fields')),
      );
      return;
    }

    final totalDays = int.tryParse(_totalDaysController.text.trim());
    final presentDays = int.tryParse(_presentDaysController.text.trim());

    if (totalDays == null || presentDays == null || totalDays < 0 || presentDays < 0 || presentDays > totalDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid total or present days')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final response = await _apiService.createTeacherAttendance(
        teacherId: selectedTeacherId!,
        month: selectedMonth,
        presentDays: presentDays,
        totalDays: totalDays, status: '',
      );

      if (!mounted) return;

      setState(() => isSubmitting = false);

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Attendance submitted successfully')),
        );
        _totalDaysController.clear();
        _presentDaysController.clear();
        setState(() => selectedTeacherId = null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to submit attendance')),
        );
      }
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting attendance: $e')),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hintText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.blue.shade50,
          prefixIcon: const Icon(Icons.edit, color: Colors.blue),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Attendance', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMonth,
                  decoration: InputDecoration(
                    labelText: 'Select Month',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    prefixIcon: const Icon(Icons.calendar_month, color: Colors.blue),
                  ),
                  items: monthList
                      .map((month) => DropdownMenuItem<String>(
                            value: month,
                            child: Text(month),
                          ))
                      .toList(),
                  onChanged: isSubmitting ? null : (val) => setState(() => selectedMonth = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedTeacherId,
                  decoration: InputDecoration(
                    labelText: 'Select Teacher',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    prefixIcon: const Icon(Icons.person, color: Colors.blue),
                  ),
                  items: teachers.isEmpty
                      ? [
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text('No teachers available', style: const TextStyle(color: Colors.grey)),
                          )
                        ]
                      : teachers.map((teacher) {
                          return DropdownMenuItem<String>(
                            value: teacher.id,
                            child: Text('${teacher.name} (${teacher.enrollmentId})'),
                          );
                        }).toList(),
                  onChanged: teachers.isEmpty || isSubmitting
                      ? null
                      : (val) => setState(() => selectedTeacherId = val),
                ),
                const SizedBox(height: 16),
                _buildTextField('Total Days', _totalDaysController, hintText: 'Enter total working days'),
                _buildTextField('Present Days', _presentDaysController, hintText: 'Enter days present'),
                const SizedBox(height: 20),
                isLoading || isSubmitting
                    ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                    : ElevatedButton(
                        onPressed: teachers.isEmpty ? null : submitAttendance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Submit Attendance',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _totalDaysController.dispose();
    _presentDaysController.dispose();
    super.dispose();
  }
}