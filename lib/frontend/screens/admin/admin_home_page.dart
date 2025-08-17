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
        _redirectToLogin(response['message'] ?? 'Access denied: Admin role required');
      }
    } catch (e) {
      _redirectToLogin('Error checking authorization: $e');
    }
  }

  void _redirectToLogin(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    try {
      final response = await _apiService.logout();
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out successfully')));
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: ${response['message']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error during logout: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard', style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: Text('Admin Menu', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.deepPurple),
              title: Text('Add New User', style: GoogleFonts.poppins()),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddNewUser())),
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts, color: Colors.deepPurple),
              title: Text('Manage Users', style: GoogleFonts.poppins()),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUser())),
            ),
            ListTile(
              leading: const Icon(Icons.subject, color: Colors.deepPurple),
              title: Text('Manage Subjects', style: GoogleFonts.poppins()),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSubjectsScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.class_, color: Colors.deepPurple),
              title: Text('Manage Classes', style: GoogleFonts.poppins()),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageClassesWithDivision())),
            ),
            ListTile(
              leading: const Icon(Icons.assignment, color: Colors.deepPurple),
              title: Text('Assign Subjects & Classes', style: GoogleFonts.poppins()),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignClassAndSubjectPage())),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.deepPurple),
              title: Text('Assigned Subjects', style: GoogleFonts.poppins()),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignedSubjectTeacherPage())),
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.deepPurple),
              title: Text('Manage Roles', style: GoogleFonts.poppins()),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePage())),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.deepPurple),
              title: Text('Profile', style: GoogleFonts.poppins()),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchClasses,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                        child: Text('Retry', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                )
              : classes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('No classes found.', style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageClassesWithDivision())),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                            child: Text('Add Class', style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        children: [
                          Text('Welcome, Admin!', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Manage classes, users, and subjects below.', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ...classes.map((cls) => _buildClassCard(cls)).toList(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls) {
    final List<dynamic> teachers = cls['teachers'] ?? [];
    final List<dynamic> students = cls['students'] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cls['name'] ?? 'Class', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Teachers', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            if (teachers.isNotEmpty)
              ...teachers.map((t) => _buildListItem('${t['name']} (${t['email']})'))
            else
              _buildListItem('No teachers assigned.'),
            const SizedBox(height: 8),
            Text('Students', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            if (students.isNotEmpty)
              ...students.map((s) => _buildListItem('${s['name']} (Roll: ${s['rollNo']})'))
            else
              _buildListItem('No students assigned.'),
          ],
        ),
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
          Expanded(child: Text(content, style: GoogleFonts.poppins())),
        ],
      ),
    );
  }
}