import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:Ai_School_App/frontend/screens/auth/login.dart';
import 'package:Ai_School_App/frontend/screens/teacher/attendence_recore.dart';
import '../admin/admin_profile.dart';
import '../services/api_client.dart';
import 'assigned_subjects.dart';
import 'result_report.dart';
import 'student_attendence.dart' hide TeacherAttendancePage;
import 'view_student_record.dart';

class TeacherHomePage extends StatefulWidget {
  static const routeName = '/teacherHome';
  final String teacherId;

  const TeacherHomePage({super.key, required this.teacherId});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Confirm Logout"),
      content: const Text("Are you sure you want to log out?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text("Logout"),
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

    if (result['message']?.toString().toLowerCase().contains('successful') == true) {
      await _storage.deleteAll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Logged out successfully"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout failed: ${result['message'] ?? 'Unknown error'}"),
          backgroundColor: Colors.red,
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
      ),
    );
    await _storage.deleteAll();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  } finally {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }
}
  /// Classic Dashboard Card
  Widget _buildDashboardCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: isLoading || teacherId == null ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade700),
            accountName: const Text(
              "Teacher",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text("ID: $teacherId"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('नियुक्त विषय'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: const Text('विद्यार्थ्यांची उपस्थिती'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentAttendanceRecordPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('माझे प्रोफाइल'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('निकाल अहवाल'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResultReportScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('विद्यार्थी रेकॉर्ड पहा'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentRecordViewPage()),
            ),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('लॉगआउट', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: const Text('Teacher Dashboard'),
            centerTitle: true,
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          drawer: _buildDrawer(context),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _buildDashboardCard(
                        'Student Attendance',
                        Icons.event_available,
                        Colors.green,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StudentAttendancePage()),
                        ),
                      ),
                      _buildDashboardCard(
                        'Student Report',
                        Icons.list,
                        Colors.orange,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StudentRecordViewPage()),
                        ),
                      ),
                      _buildDashboardCard(
                        'Assign Marks',
                        Icons.book,
                        Colors.blue,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
                        ),
                      ),
                      _buildDashboardCard(
                        'Result Report',
                        Icons.description,
                        Colors.red,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ResultReportScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        /// Loading overlay
        if (isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
