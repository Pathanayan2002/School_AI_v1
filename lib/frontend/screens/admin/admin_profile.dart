import 'package:Ai_School_App/frontend/screens/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensured
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

class ProfilePage extends StatefulWidget {
  static String routeName = '/admin_profile';

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? userData;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }
  Future<void> _fetchUserProfile() async {
    try {
      final enrollId = await _storage.read(key: 'enrollment_id');
      if (enrollId == null) {
        _showErrorDialog("Session expired. Please log in again.");
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
        return;
      }

      final response = await _apiService.getRequest('/user/All',);

      if (response['success'] == true && response['data'] is List) {
        final List<dynamic> allUsers = response['data'];

        final user = allUsers.firstWhere(
          (u) => u['enrollmentId'].toString() == enrollId,
          orElse: () => {},
        );

        if (user.isNotEmpty) {
          setState(() {
            userData = user;
            _isLoading = false;
          });
        } else {
          _showErrorDialog("User not found.");
        }
      } else {
        _showErrorDialog("Invalid response from server: ${response['message'] ?? 'Unknown error'}");
      }
    } catch (e) {
      debugPrint('Fetch profile error: $e');
      _showErrorDialog("An error occurred: $e");
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
    style: TextStyle(color: Colors.white),
  ),
),

      ],
    ),
  );

  if (confirm != true) return;

  setState(() {
    _isLoggingOut = true;
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
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        // Replace the current route with LoginPage
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
          duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 2),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoggingOut = false;
      });
    }
  }
}

 void _showErrorDialog(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      thickness: 1,
      color: Colors.deepPurple.shade100,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building ProfilePage, _isLoading: $_isLoading, _isLoggingOut: $_isLoggingOut');
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.person, size: 70, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      userData?['name'] ?? "User",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      userData?['role'] ?? "Role",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: Colors.deepPurple.shade200,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                        child: Column(
                          children: [
                            _buildInfoRow("Registration No",
                                userData?['enrollmentId'] ?? "N/A"),
                            _buildDivider(),
                            _buildInfoRow("Email", userData?['email'] ?? "N/A"),
                            _buildDivider(),
                            _buildInfoRow("Contact", userData?['phone'] ?? "N/A"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: _isLoggingOut ? null : _logout,
                      icon: _isLoggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout),
                      label: Text(_isLoggingOut ? "Logging out..." : "Logout"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}