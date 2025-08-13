import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddNewUser extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AddNewUser({Key? key, this.userData}) : super(key: key);

  @override
  State<AddNewUser> createState() => _AddNewUserState();
}

class _AddNewUserState extends State<AddNewUser> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController enrollmentController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
bool _obscurePassword = true;
bool _obscureConfirmPassword = true;

  bool isEditMode = false;
  bool _isSubmitting = false;
  bool _showPasswordFields = false;
  final List<String> roles = ['Admin', 'Teacher', 'Clerk'];
  String? selectedRole;
  String? currentUserRole;
  String? schoolId;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    if (widget.userData != null) {
      isEditMode = true;
      nameController.text = widget.userData!['name'] ?? '';
      emailController.text = widget.userData!['email'] ?? '';
      phoneController.text = widget.userData!['phone'] ?? '';
      enrollmentController.text = widget.userData!['enrollmentId'] ?? '';
      selectedRole = widget.userData!['role'];
      schoolId = widget.userData!['schoolId'];
    }
  }

  Future<void> _checkAuthorization() async {
    final userId = await _storage.read(key: 'user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final response = await _apiService.getUserById(userId);
    if (response['success'] && response['data']['role'] == 'Admin') {
      setState(() {
        currentUserRole = response['data']['role'];
        schoolId ??= response['data']['schoolId'];
      });
      if (schoolId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: School ID not found')),
        );
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access denied: Only Admins can add/edit users')),
      );
      Navigator.pop(context);
    }
  }

  Future<bool> _isEmailUnique(String email, {String? excludeId}) async {
    final response = await _apiService.getAllUsers(schoolId: '');
    if (response['success'] && response['data'] is List) {
      final users = List<Map<String, dynamic>>.from(response['data']).map((user) {
        return {...user, 'id': user['id'] ?? user['_id']};
      }).toList();
      return !users.any((user) => user['email'] == email && (excludeId == null || user['id'] != excludeId));
    }
    return false;
  }

  Future<bool> _isEnrollmentIdUnique(String enrollmentId, {String? excludeId}) async {
    final response = await _apiService.getAllUsers(schoolId: '');
    if (response['success'] && response['data'] is List) {
      final users = List<Map<String, dynamic>>.from(response['data']).map((user) {
        return {...user, 'id': user['id'] ?? user['_id']};
      }).toList();
      return !users.any((user) => user['enrollmentId'] == enrollmentId && (excludeId == null || user['id'] != excludeId));
    }
    return false;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final userId = isEditMode ? (widget.userData?['id']?.toString() ?? widget.userData?['_id']?.toString()) : null;

      if (isEditMode && userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User ID is missing')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      if (!(await _isEmailUnique(emailController.text, excludeId: userId))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email is already in use')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      if (!(await _isEnrollmentIdUnique(enrollmentController.text, excludeId: userId))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enrollment ID is already in use')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      if (isEditMode) {
        final response = await _apiService.updateUser(
          {} as String,
          name: nameController.text,
          email: emailController.text,
          phone: phoneController.text,
          enrollmentId: enrollmentController.text,
          role: selectedRole,
          password: passwordController.text.isNotEmpty ? passwordController.text : null, id: '', userId: '',
        );

        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'User updated successfully')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update user: ${response['message'] ?? 'Unknown error'}')),
          );
        }
      } else {
        final response = await _apiService.registerUser(
          name: nameController.text,
          email: emailController.text,
          phone: phoneController.text,
          enrollmentId: enrollmentController.text,
          password: passwordController.text,
          role: selectedRole!,
        );

        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'User registered successfully')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to register user: ${response['message'] ?? 'Unknown error'}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    enrollmentController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.deepPurple,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          isEditMode ? 'Edit User' : 'Add New User',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: nameController,
                                  label: 'Name',
                                  icon: Icons.person,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a name';
                                    }
                                    if (value.length < 3) {
                                      return 'Name must be at least 3 characters';
                                    }
                                    return null;
                                  },
                                ),
                                _buildTextField(
                                  controller: emailController,
                                  label: 'Email',
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter an email';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                _buildTextField(
                                  controller: phoneController,
                                  label: 'Phone',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a phone number';
                                    }
                                    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
                                      return 'Please enter a valid phone number';
                                    }
                                    return null;
                                  },
                                ),
                                _buildTextField(
                                  controller: enrollmentController,
                                  label: 'Enrollment ID',
                                  icon: Icons.badge,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter an enrollment ID';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: selectedRole,
                                  items: roles.map((role) => DropdownMenuItem(
                                    value: role,
                                    child: Text(role),
                                  )).toList(),
                                  onChanged: _isSubmitting ? null : (value) => setState(() => selectedRole = value),
                                  decoration: const InputDecoration(
                                    labelText: 'Role',
                                    prefixIcon: Icon(Icons.work),
                                  ),
                                  validator: (value) => value == null ? 'Please select a role' : null,
                                ),
                                const SizedBox(height: 16),
                                if (isEditMode) ..._buildEditPasswordFields()
                                else ..._buildCreatePasswordFields(),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                
                                  child: ElevatedButton.icon(
                                    onPressed: _isSubmitting ? null : _submitForm,
                                    icon: const Icon(Icons.save , color: Colors.white,),
                                  
                                    label: Text(
                                   
                                      _isSubmitting
                                          ? 'Please wait...'
                                          : (isEditMode ? 'Update User' : 'Register User'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: Colors.deepPurple,
                                       foregroundColor: Colors.white,
                                    
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }

  List<Widget> _buildEditPasswordFields() {
    return [
      CheckboxListTile(
        value: _showPasswordFields,
        onChanged: (value) => setState(() => _showPasswordFields = value ?? false),
        title: const Text('Change Password'),
      ),
      if (_showPasswordFields) ..._buildPasswordFields()
    ];
  }

  List<Widget> _buildCreatePasswordFields() {
    return _buildPasswordFields();
  }

  List<Widget> _buildPasswordFields() {
  return [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a password';
          }
          if (value.length < 8) {
            return 'Password must be at least 8 characters';
          }
          if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$%^&*]).{8,}$').hasMatch(value)) {
            return 'Must include uppercase, lowercase, number, special char';
          }
          return null;
        },
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: confirmPasswordController,
        obscureText: _obscureConfirmPassword,
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please confirm the password';
          }
          if (value != passwordController.text) {
            return 'Passwords do not match';
          }
          return null;
        },
      ),
    ),
  ];
}
}
