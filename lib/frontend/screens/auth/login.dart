import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/api_client.dart';
import '../admin/admin_home_page.dart';
import '../teacher/teacher_home_page.dart';
import '../clerk/clerk_home_page.dart';
import '../MDM/MDM_home_page.dart';
import 'forgot_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _enrollmentController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final token = await _storage.read(key: 'token');
    if (token != null && !JwtDecoder.isExpired(token)) {
      final role = await _storage.read(key: 'user_role');
      final userId = await _storage.read(key: 'user_id');
      if (role != null && userId != null) {
        if (!mounted) return;
        // Verify role to prevent incorrect navigation
        if (['Admin', 'SuperAdmin', 'Teacher', 'Clerk', 'MDM'].contains(role)) {
          _navigateToDashboard(role, userId);
        }
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final enrollment = _enrollmentController.text.trim();
    final password = _passwordController.text.trim();

    if (enrollment.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both enrollment ID and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.login(
        enrollmentId: enrollment,
        password: password,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final userRole = data['role']?.toString();
        final enrollmentId = data['enrollmentId']?.toString();
        final token = data['token']?.toString();

        if (userRole == null || enrollmentId == null || token == null) {
          setState(() {
            _errorMessage = 'Invalid server response';
          });
          return;
        }

        final decodedToken = JwtDecoder.decode(token);
        final userId = decodedToken['id']?.toString();
        final schoolId = decodedToken['schoolId']?.toString();

        if (userId == null) {
          setState(() {
            _errorMessage = 'Invalid user ID in token';
          });
          return;
        }

        // Store token and user data
        await _storage.write(key: 'token', value: token);
        await _storage.write(key: 'user_role', value: userRole);
        await _storage.write(key: 'user_id', value: userId);
        await _storage.write(key: 'school_id', value: schoolId ?? '');
        await _storage.write(key: 'enrollment_id', value: enrollmentId);

        // Verify role before navigating
        if (['Admin', 'SuperAdmin', 'Teacher', 'Clerk', 'MDM'].contains(userRole)) {
          _navigateToDashboard(userRole, userId);
        } else {
          setState(() {
            _errorMessage = 'Access denied: Unrecognized user role';
          });
        }
      } else {
        setState(() {
          _errorMessage = response['statusCode'] == 401
              ? 'Invalid enrollment ID or password'
              : response['message'] ?? 'Login failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred';
      });
    }
  }

  void _navigateToDashboard(String role, String userId) {
    switch (role) {
      case 'Admin':
      case 'SuperAdmin':
        Navigator.pushReplacementNamed(context, '/admin');
        break;
      case 'Teacher':
        Navigator.pushReplacementNamed(context, '/teacher', arguments: {'teacherId': userId});
        break;
      case 'Clerk':
        final clerkId = int.tryParse(userId) ?? 0;
        if (clerkId == 0) {
          setState(() {
            _errorMessage = 'Invalid user ID for Clerk role';
          });
          return;
        }
        Navigator.pushReplacementNamed(context, '/clerk', arguments: {'clerkId': clerkId.toString()});
        break;
      case 'MDM':
        Navigator.pushReplacementNamed(context, '/mdm');
        break;
      default:
        setState(() {
          _errorMessage = 'Access denied: Unrecognized user role';
        });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A00E0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Login to School AI',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                _buildTextField(
                  controller: _enrollmentController,
                  hint: 'Enter Enrollment ID',
                  icon: Icons.person,
                ),
                const SizedBox(height: 20),
                Text(
                  'Password:',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Enter Password',
                  icon: Icons.lock,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4A00E0),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 6,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Color(0xFF4A00E0))
                        : Text(
                            'Sign In',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF4A00E0),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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

  @override
  void dispose() {
    _enrollmentController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}