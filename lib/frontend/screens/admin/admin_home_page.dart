import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import 'add_new_user.dart';
import 'admin_profile.dart';
import 'manage_subject.dart';
import 'manage_user.dart';
import 'roles.dart';
import 'manage_classes.dart';
import 'assign_class.dart';
import 'assign_subject.dart';

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No user session found. Please log in.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final response = await _apiService.getUserById(userId);
      final success = response['success'] as bool?;

      if (success != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Authorization failed: Invalid user data',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final userRole = response['data']?['role'] as String?;
      if (userRole != 'Admin') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Access denied: Admin role required',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error checking authorization: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

 Future<void> _fetchClasses() async {
  setState(() => _isLoading = true);
  try {
   final schoolId = await _storage.read(key: 'school_id') ?? '';

    if (schoolId.isEmpty) {
      _showSnackBar('No school ID found. Please log in again.');
      setState(() => _isLoading = false);
      return;
    }

final response = await _apiService.getAllClasses(schoolId: schoolId);


    if (response['success'] && response['data'] is List) {
      setState(() {
        classes = (response['data'] as List)
            .whereType<Map<String, dynamic>>() // Safety check
            .map((cls) => {
                  ...cls,
                  'id': cls['id'] ?? cls['_id'],
                })
            .toList();
        _isLoading = false;
      });
    } else {
      _showSnackBar(response['message'] ?? 'Failed to load classes');
      setState(() => _isLoading = false);
    }
  } catch (e) {
    _showSnackBar('Error loading classes: $e');
    setState(() => _isLoading = false);
  }
}

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    try {
      final response = await _apiService.logout();
      if (response['success']) {
        await _storage.deleteAll();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showSnackBar(response['message'] ?? 'Logout failed');
      }
    } catch (e) {
      _showSnackBar('Error logging out: $e');
    }
  }

  Future<String?> _getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  Widget _drawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 14),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: GoogleFonts.poppins(color: Colors.white)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      child: Scaffold(
        drawer: Drawer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Dashboard',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your school',
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Profile / प्रोफाइल',
                  onTap: () async {
                    final userId = await _getUserId();
                    if (userId != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)));
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard / डैशबोर्ड',
                  onTap: () => Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => const AdminHomePage())),
                ),
                const Divider(color: Colors.white54),
                _drawerSectionTitle('User Management'),
                _buildDrawerItem(
                  icon: Icons.assignment_ind,
                  title: 'Add Role / भूमिका जोडा',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolePage())),
                ),
                _buildDrawerItem(
                  icon: Icons.people,
                  title: 'Manage User / वापरकार्ता',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUser())),
                ),
                _buildDrawerItem(
                  icon: Icons.person_add,
                  title: 'Add New User / नवीन वापरकर्ता जोडा',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddNewUser())),
                ),
               
                // _buildDrawerItem(
                //   icon: Icons.book,
                //   title: 'Manage Subject / विषय व्यवस्था',
                //   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSubjectsScreen())),
                // ),
                _buildDrawerItem(
                  icon: Icons.book_online,
                  title: 'Assign Subject / विषय नियुक्ति',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignClassAndSubjectPage())),
                ),
                _buildDrawerItem(
                  icon: Icons.class_,
                  title: 'Assign Class / वर्ग नियुक्ति',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignClassPage())),
                ),
                const Divider(color: Colors.white54),
                _buildDrawerItem(
                  icon: Icons.insert_chart,
                  title: 'Result Report / निकाल अहवाल',
                  onTap: () => _showSnackBar('Result Report coming soon!'),
                ),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout / लॉगआउट',
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                  title: const Text('Admin Dashboard'),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'स्वागत आहे, अॅड्मिन!',
                                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Manage classes, users, and subjects below.',
                                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: classes.length,
                                  itemBuilder: (context, index) {
                                    final cls = classes[index];
                                    return Card(
                                      elevation: 5,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      child: ListTile(
                                        title: Text(cls['name'] ?? 'N/A'),
                                        subtitle: Text('ID: ${cls['id'] ?? 'N/A'}'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}