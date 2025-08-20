import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
        if (['Admin', 'Teacher', 'Clerk'].contains(role)) {
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

        await _storage.write(key: 'token', value: token);
        await _storage.write(key: 'user_role', value: userRole);
        await _storage.write(key: 'user_id', value: userId);
        await _storage.write(key: 'school_id', value: schoolId ?? '');
        await _storage.write(key: 'enrollment_id', value: enrollmentId);

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
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6200EA), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'School AI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6200EA),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: _enrollmentController,
                    label: 'Enrollment ID',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[600],
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Color(0xFF6200EA)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6200EA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
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