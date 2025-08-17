import 'package:Ai_School_App/frontend/screens/auth/login.dart';
import 'package:Ai_School_App/frontend/screens/teacher/attendence_recore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../admin/admin_profile.dart';
import '../services/api_client.dart';
import 'assigned_subjects.dart';
import 'result_report.dart';
import 'student_attendence.dart';
import 'view_student_record.dart';

class TeacherHomePage extends StatefulWidget {
  static const routeName = '/teacherHome';
  final String teacherId;

  const TeacherHomePage({super.key, required this.teacherId});

  @override
  _TeacherHomePageState createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();
  String? teacherId;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    teacherId = widget.teacherId;
  }

  Future<void> _logout() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Confirm Logout"),
      content: const Text("Are you sure you want to log out?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            "Logout",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  setState(() {
    isLoading = true;
  });

  try {
    final result = await _apiService.logout();
    debugPrint('Logout response: $result');

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? "Logged out successfully"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 0),
        ),
      );
      await Future.delayed(const Duration(seconds: 0));
      if (mounted) {
        // Replace with LoginPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout failed: ${result['message'] ?? 'Unknown error'}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 0),
        ),
      );
    }
  } catch (e) {
    debugPrint('Logout error: $e');
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Logout failed: $e"),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 0),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }
}


  Widget _buildNavigationCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue.shade700, size: 30),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_forward, color: Colors.blue),
        onTap: isLoading || teacherId == null ? null : onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.shade700),
              child: const Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Assigned Subjects'),
              onTap: isLoading || teacherId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TeacherDashboardPage(teacherId: teacherId!)),
                      ),
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Student Attendance'),
              onTap: isLoading || teacherId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) =>  StudentAttendanceScreen(subjectId: '', schoolId: '',)),
                      ),
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Student Attendance Record'),
              onTap: isLoading || teacherId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const 
                        StudentAttendanceRecordScreen(subjectId: '', schoolId: '',)),
                      ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('My Profile'),
              onTap: isLoading || teacherId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      ),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Result Report'),
              onTap: isLoading || teacherId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ResultReportScreen()),
                      ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('View Student Records'),
              onTap: isLoading || teacherId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StudentRecordScreen()),
                      ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: isLoading || teacherId == null ? null : _logout,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blue.shade700),
            ),
            const SizedBox(height: 16),
            _buildNavigationCard(
              'Student Attendance',
              Icons.event_available,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentAttendanceScreen(subjectId: '', schoolId: '',)),
              ),
            ),
            _buildNavigationCard(
              'Student Report',
              Icons.list,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StudentRecordScreen()),
              ),
            ),
            _buildNavigationCard(
              'Assign Marks',
              Icons.book,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TeacherDashboardPage(teacherId: teacherId!)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}