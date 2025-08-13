import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../admin/admin_profile.dart';
import '../admin/manage_classes.dart';
import '../admin/manage_subject.dart';
import '../admin/manage_user.dart';
import '../admin/roles.dart';
import 'add_new_student.dart';
import 'teacher_presenty.dart';
import 'student_record.dart';
import '../teacher/view_student_record.dart';
import '../MDM/MDM_home_page.dart';
import 'teacher_att_recored.dart';

class ClerkHomePage extends StatefulWidget {
  final int clerkId;

  const ClerkHomePage({super.key, required this.clerkId});

  @override
  State<ClerkHomePage> createState() => _ClerkHomePageState();
}

class _ClerkHomePageState extends State<ClerkHomePage> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;
  String? _schoolId;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userRole = await _storage.read(key: 'user_role');
      final token = await _storage.read(key: 'token'); // Use 'token' to match LoginPage
      _schoolId = await _storage.read(key: 'school_id');

      if (token == null || userRole != 'Clerk' || _schoolId == null || _schoolId!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid session or role. Please log in again.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      // Fetch user data using clerkId
      final response = await _apiService.getUserById(widget.clerkId.toString());
      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _userData = response['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to fetch user data';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching user data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      final response = await _apiService.logout();
      if (response['success'] == true) {
        await _storage.deleteAll();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Logout failed',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error logging out: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4A00E0), size: 26),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: const Color(0xFF4A00E0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Clerk Dashboard',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4A00E0),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF4A00E0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clerk Dashboard',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userData?['name'] ?? 'Clerk',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              title: 'Add New Student',
              icon: Icons.person_add,
              onTap: () {
                if (_schoolId == null || _schoolId!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'School ID not found. Please log in again.',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddNewStudent(schoolId: _schoolId!),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              title: 'Teacher Attendance',
              icon: Icons.event_available,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TeacherAttendanceScreen()),
                );
              },
            ),
            _buildDrawerItem(
              title: 'Teacher Attendance Records',
              icon: Icons.event_note,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TeacherAttendanceRecord()),
                );
              },
            ),
            _buildDrawerItem(
              title: 'Student Record',
              icon: Icons.school,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudentRecord()),
                );
              },
            ),
            _buildDrawerItem(
              title: 'View Student Record',
              icon: Icons.visibility,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewStudentRecordPage(teacherId: widget.clerkId.toString()),
                  ),
                );
              },
            ),
            // _buildDrawerItem(
            //   title: 'Manage Subjects',
            //   icon: Icons.book,
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => const ManageSubjectsScreen()),
            //     );
            //   },
            // ),
            _buildDrawerItem(
              title: 'Manage Roles',
              icon: Icons.admin_panel_settings,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RolePage()),
                );
              },
            ),
            _buildDrawerItem(
              title: 'MDM Dashboard',
              icon: Icons.food_bank,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TeacherDashboardWireframe()),
                );
              },
            ),
            _buildDrawerItem(
              title: 'Logout',
              icon: Icons.logout,
              onTap: _logout,
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
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _checkAuthorization,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A00E0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFF4A00E0),
                      child: Column(
                        children: [
                          Text(
                            'Welcome, ${_userData?['name'] ?? 'Clerk'}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ID: ${widget.clerkId} | Email: ${_userData?['email'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          _buildDrawerItem(
                            title: 'Add New Student',
                            icon: Icons.person_add,
                            onTap: () {
                              if (_schoolId == null || _schoolId!.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'School ID not found. Please log in again.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddNewStudent(schoolId: _schoolId!),
                                ),
                              );
                            },
                          ),
                          _buildDrawerItem(
                            title: 'Teacher Attendance',
                            icon: Icons.event_available,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TeacherAttendanceScreen()),
                              );
                            },
                          ),
                          _buildDrawerItem(
                            title: 'Teacher Attendance Records',
                            icon: Icons.event_note,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TeacherAttendanceRecord()),
                              );
                            },
                          ),
                          _buildDrawerItem(
                            title: 'Student Record',
                            icon: Icons.school,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const StudentRecord()),
                              );
                            },
                          ),
                          _buildDrawerItem(
                            title: 'View Student Record',
                            icon: Icons.visibility,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewStudentRecordPage(teacherId: widget.clerkId.toString()),
                                ),
                              );
                            },
                          ),
                          // _buildDrawerItem(
                          //   title: 'Manage Subjects',
                          //   icon: Icons.book,
                          //   onTap: () {
                          //     Navigator.push(
                          //       context,
                          //       MaterialPageRoute(builder: (context) => const ManageSubjectsScreen()),
                          //     );
                          //   },
                          // ),
                          _buildDrawerItem(
                            title: 'Manage Roles',
                            icon: Icons.admin_panel_settings,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RolePage()),
                              );
                            },
                          ),
                          _buildDrawerItem(
                            title: 'MDM Dashboard',
                            icon: Icons.food_bank,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TeacherDashboardWireframe()),
                              );
                            },
                          ),
                          _buildDrawerItem(
                            title: 'Logout',
                            icon: Icons.logout,
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}