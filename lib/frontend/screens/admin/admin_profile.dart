import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? userData;
  bool _isLoading = true;
  bool _hasError = false;

  static const allowedRoles = ['Admin', 'Teacher', 'Clerk', 'MDM'];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final response = await _apiService.getUserById(widget.userId);
      if (!mounted) return;

      if (response['success'] && response['data'] != null) {
        final role = response['data']['role']?.toString();
        if (!allowedRoles.contains(role)) {
          _showSnackBar('Access denied: Invalid role');
          Navigator.pop(context);
          return;
        }

        setState(() {
          userData = {
            ...response['data'],
            'id': response['data']['id']?.toString() ?? response['data']['_id']?.toString(),
          };
          _isLoading = false;
        });
      } else {
        _handleError(response['message'] ?? 'User not found');
      }
    } catch (e) {
      if (!mounted) return;
      _handleError('Error fetching profile: $e');
    }
  }

  void _handleError(String message) {
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
    _showErrorDialog(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    try {
      final result = await _apiService.logout();
      if (!mounted) return;

      if (result['success']) {
        await _storage.deleteAll();
        _showSnackBar(result['message'] ?? 'Logged out successfully');
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      } else {
        _showErrorDialog(result['message'] ?? 'Logout failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Logout failed: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Error', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
          if (_hasError)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _fetchUserProfile();
              },
              child: Text('Retry', style: GoogleFonts.poppins(color: Colors.deepPurple)),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              "$label:",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

 @override
Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;

  return Theme(
    data: ThemeData(
      primarySwatch: Colors.deepPurple,
      textTheme: GoogleFonts.poppinsTextTheme(),
    ),
    child: Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _hasError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Failed to load profile',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchUserProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.white,
                              child: userData?['photo']?.toString().isNotEmpty ?? false
                                  ? ClipOval(
                                      child: Image.network(
                                        userData!['photo'],
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.person, size: 70, color: Colors.deepPurple),
                                      ),
                                    )
                                  : const Icon(Icons.person, size: 70, color: Colors.deepPurple),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            userData?['name']?.toString() ?? 'User',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            userData?['role']?.toString() ?? 'Role',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                            child: Column(
                              children: [
                                _buildInfoRow('Registration No', userData?['enrollmentId']?.toString() ?? 'N/A'),
                                const Divider(thickness: 1, color: Colors.deepPurple),
                                _buildInfoRow('Email', userData?['email']?.toString() ?? 'N/A'),
                                const Divider(thickness: 1, color: Colors.deepPurple),
                                _buildInfoRow('Contact', userData?['phone']?.toString() ?? 'N/A'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                              shadowColor: Colors.redAccent.withOpacity(0.5),
                              foregroundColor: Colors.white
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
        ),
      ),
    ),
  );
}

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white, size: 60),
          const SizedBox(height: 16),
          Text('Failed to load profile', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchUserProfile,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: Text('Retry', style: GoogleFonts.poppins(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(TextTheme textTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              child: userData?['photo']?.toString().isNotEmpty ?? false
                  ? ClipOval(
                      child: Image.network(
                        userData!['photo'],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 70, color: Colors.deepPurple),
                      ),
                    )
                  : const Icon(Icons.person, size: 70, color: Colors.deepPurple),
            ),
          ),
          const SizedBox(height: 20),

          // Name
          Text(
            userData?['name']?.toString() ?? 'User',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),

          const SizedBox(height: 6),
          Text(
            userData?['role']?.toString() ?? 'Role',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
          ),

          const SizedBox(height: 30),

          // Info Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                children: [
                  _buildInfoRow('Registration No', userData?['enrollmentId']?.toString() ?? 'N/A'),
                  const Divider(thickness: 1, color: Colors.deepPurple),
                  _buildInfoRow('Email', userData?['email']?.toString() ?? 'N/A'),
                  const Divider(thickness: 1, color: Colors.deepPurple),
                  _buildInfoRow('Contact', userData?['phone']?.toString() ?? 'N/A'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Logout button
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 5,
              shadowColor: Colors.redAccent.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
