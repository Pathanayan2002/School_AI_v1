// File: admin_home_page.dart
import 'package:Ai_School_App/frontend/screens/admin/view_student_record.dart';
import 'package:Ai_School_App/frontend/screens/auth/login.dart';
import 'package:Ai_School_App/frontend/screens/clerk/result_report.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'add_new_user.dart';
import 'admin_profile.dart';
import 'assign_subject_and_class_to_teacher.dart';
import 'assigned_subject.dart';
import 'manage_classes.dart';
import 'manage_subject.dart';
import 'manage_user.dart';
import 'roles.dart';
import '../services/api_client.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> classes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    _fetchClasses();
  }

  Future<void> _checkAuthorization() async {
    try {
      final token = await _storage.read(key: 'token');
      final userId = await _storage.read(key: 'user_id');
      if (token == null || userId == null) {
        _redirectToLogin('No user session found. Please log in.');
        return;
      }
      final response = await _apiService.getUserById(userId);
      if (response['success'] != true || response['data']?['role'] != 'Admin') {
        _redirectToLogin(
            response['message'] ?? 'Access denied: Admin role required');
      }
    } catch (e) {
      _redirectToLogin('Error checking authorization: $e');
    }
  }

  void _redirectToLogin(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    try {
      final schoolId = await _storage.read(key: 'school_id');
      if (schoolId == null || schoolId.isEmpty) {
        setState(() {
          _errorMessage = 'No school ID found. Please log in again.';
          _isLoading = false;
        });
        return;
      }
      final response = await _apiService.getAllClasses(schoolId: schoolId);
      if (response['success'] && response['data'] is List) {
        setState(() {
          classes = List<Map<String, dynamic>>.from(response['data']).map((cls) {
            return {
              'id': cls['id'] ?? cls['_id'] ?? 'N/A',
              'name': cls['name'] ?? 'Unknown',
              'teachers': cls['teachers'] ?? [],
              'students': cls['students'] ?? [],
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load classes.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading classes: $e';
        _isLoading = false;
      });
    }
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
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout failed: ${result['message'] ?? 'Unknown error'}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
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
      ),
    );
    await _storage.deleteAll();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : classes.isEmpty
                  ? _buildEmptyState()
                  : _buildDashboard(),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.deepPurple),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text('Admin Menu',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          _drawerItem(Icons.person_add, 'Add New User', const AddNewUser()),
          _drawerItem(Icons.manage_accounts, 'Manage Users', const ManageUser()),
          _drawerItem(Icons.subject, 'Manage Subjects',
              const ManageSubjectsScreen()),
          _drawerItem(
              Icons.class_, 'Manage Classes', const ManageClasses()),
          _drawerItem(Icons.assignment, 'Assign Subjects & Classes',
              const AssignClassAndSubjectPage()),
          _drawerItem(Icons.list_alt, 'Assigned Subjects',
              const AssignedSubjectTeacherPage()),
          _drawerItem(Icons.security, 'Manage Roles', const RolePage()),
          _drawerItem(Icons.person, 'Profile', const ProfilePage()),
          _drawerItem(Icons.school, 'View Student Record',
              const AdminClerkStudentViewPage(initialClassId: null)),
          _drawerItem(Icons.bar_chart, 'Student Result Record',
              const ClerkResultReportPage()),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_errorMessage!,
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchClasses,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white),
            child: Text('Retry', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('No classes found.',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ManageClasses())),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white),
            child: Text('Add Class', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  /// Dashboard with summary + class cards
  Widget _buildDashboard() {
    final totalClasses = classes.length;
    final totalTeachers = classes.fold<int>(
      0,
      (sum, cls) => sum + ((cls['teachers'] as List?)?.length ?? 0),
    );
    final totalStudents = classes.fold<int>(
      0,
      (sum, cls) => sum + ((cls['students'] as List?)?.length ?? 0),
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text('Welcome, Admin!',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Manage classes, users, and subjects below.',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 16),

          // Summary Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryCard("Classes", totalClasses, Icons.class_),
              _buildSummaryCard("Teachers", totalTeachers, Icons.person),
              _buildSummaryCard("Students", totalStudents, Icons.school),
            ],
          ),

          const SizedBox(height: 20),

          // Class cards with expandable details
          ...classes.map((cls) => _buildClassCard(cls)).toList(),
        ],
      ),
    );
  }

  /// Small summary cards
  Widget _buildSummaryCard(String title, int count, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(14),
        width: 100,
        child: Column(
          children: [
            Icon(icon, color: Colors.deepPurple, size: 28),
            const SizedBox(height: 6),
            Text("$count",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  /// Class cards with expandable dropdown
  Widget _buildClassCard(Map<String, dynamic> cls) {
    final List<dynamic> teachers = cls['teachers'] ?? [];
    final List<dynamic> students = cls['students'] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        title: Text(
          cls['name'] ?? 'Class',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.deepPurple,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("👨‍🏫 ${teachers.length}",
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text("👩‍🎓 ${students.length}",
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        children: [
          // Teacher list
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Teachers',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          const SizedBox(height: 4),
          if (teachers.isNotEmpty)
            ...teachers
                .map((t) => _buildListItem('${t['name']} (${t['email']})'))
          else
            _buildListItem('No teachers assigned.'),

          const SizedBox(height: 12),

          // Student list
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Students',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          const SizedBox(height: 4),
          if (students.isNotEmpty)
            ...students.map(
                (s) => _buildListItem('${s['name']} (Roll: ${s['rollNo']})'))
          else
            _buildListItem('No students assigned.'),
        ],
      ),
    );
  }

  Widget _buildListItem(String content) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(
              child: Text(content, style: GoogleFonts.poppins(fontSize: 14))),
        ],
      ),
    );
  }
}
