import 'package:flutter/material.dart';
import 'dart:convert';
import '../../model/student_model.dart';
import '../../model/subject_model.dart';
import '../services/api_client.dart';

class ResultEntryPage extends StatefulWidget {
  final Student student;
  final SubjectItem subject;
  final String semester;

  const ResultEntryPage({
    super.key,
    required this.student,
    required this.subject,
    required this.semester,
  });

  @override
  _ResultEntryPageState createState() => _ResultEntryPageState();
}

class _ResultEntryPageState extends State<ResultEntryPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _formativeController = TextEditingController();
  final _summativeController = TextEditingController();
  final _specialProgressController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _areasOfImprovementController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() {
      isLoading = true;
    });
    try {
      final teacherId = await _apiService.getCurrentUserId();
      if (teacherId == null) {
        setState(() {
          errorMessage = 'Teacher ID not found. Please log in again.';
          isLoading = false;
        });
        return;
      }
      final response = await _apiService.getSubjectById(widget.subject.id.toString());
      if (response['success'] && response['data'] != null) {
        if (response['data']['teacherId']?.toString() != teacherId) {
          setState(() {
            errorMessage = 'You do not have permission to assign marks for this subject.';
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage!)),
          );
          Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
        }
      } else {
        setState(() {
          errorMessage = 'Failed to verify permission.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error checking permission: $e';
        isLoading = false;
      });
    }
  }

 Future<void> _submitResult() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final schoolId = await _apiService.getCurrentSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      setState(() {
        errorMessage = 'शाळेचा आयडी सापडला नाही. कृपया पुन्हा लॉग इन करा.';
        isLoading = false;
      });
      return;
    }

    final formativeText = _formativeController.text.trim();
    final summativeText = _summativeController.text.trim();

    final formative = double.tryParse(formativeText);
    final summative = double.tryParse(summativeText);

    if (formative == null || summative == null) {
      setState(() {
        errorMessage = 'अवैध गुण प्रविष्ट केले. कृपया वैध संख्या प्रविष्ट करा.';
        isLoading = false;
      });
      return;
    }
    if (formative < 0 || summative < 0) {
      setState(() {
        errorMessage = 'गुण नकारात्मक असू शकत नाहीत.';
        isLoading = false;
      });
      return;
    }
    if (formative.isNaN || summative.isNaN || formative.isInfinite || summative.isInfinite) {
      setState(() {
        errorMessage = 'अवैध गुण स्वरूप. कृपया वैध संख्या प्रविष्ट करा.';
        isLoading = false;
      });
      return;
    }

    final total = formative + summative;
    final subjectData = {
      widget.subject.id.toString(): {
        'subjectName': widget.subject.subjectName,
        'formativeAssesment': formative,
        'summativeAssesment': summative,
        'total': total,
        'grade': _calculateGrade(total),
      }
    };

    // Construct the payload
    final payload = {
      'studentId': widget.student.id.toString(),
      'schoolId': schoolId,
      'semester': widget.semester,
      'subjects': subjectData,
      'specialProgress': _specialProgressController.text.trim(),
      'hobbies': _hobbiesController.text.trim(),
      'areasOfImprovement': _areasOfImprovementController.text.trim(),
    };

    print('Submitting payload: ${jsonEncode(payload)}');

    // Call createResult with positional argument
    final response = await _apiService.createResult(payload);

    print('API response: ${jsonEncode(response)}');

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('निकाल यशस्वीरित्या सबमिट केला'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      setState(() {
        errorMessage = response['message'] ?? 'निकाल सबमिट करण्यात अयशस्वी';
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = 'निकाल सबमिट करण्यात त्रुटी: $e';
    });
    print('Submission error: $e');
  } finally {
    setState(() {
      isLoading = false;
    });
  }
} 
  
  String _calculateGrade(double total) {
    if (total >= 90) return 'A+';
    if (total >= 80) return 'A';
    if (total >= 70) return 'B+';
    if (total >= 60) return 'B';
    if (total >= 50) return 'C';
    return 'F';
  }

  Widget _buildInputField(
    String label, {
    String? initialValue,
    TextEditingController? controller,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: controller == null ? initialValue : null,
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sem${widget.semester} Result - ${widget.subject.subjectName}'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),
                    _buildInputField('Student ID', initialValue: widget.student.enrollmentNo, enabled: false),
                    _buildInputField('Student Name', initialValue: widget.student.name, enabled: false),
                    _buildInputField(
                      'Formative Assessment',
                      controller: _formativeController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Formative Assessment is required';
                        final num = double.tryParse(val);
                        if (num == null) return 'Enter a valid number';
                        if (num < 0) return 'Marks cannot be negative';
                        if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      'Summative Assessment',
                      controller: _summativeController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Summative Assessment is required';
                        final num = double.tryParse(val);
                        if (num == null) return 'Enter a valid number';
                        if (num < 0) return 'Marks cannot be negative';
                        if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildInputField('Special Progress', controller: _specialProgressController),
                    const SizedBox(height: 16),
                    _buildInputField('Hobbies', controller: _hobbiesController),
                    const SizedBox(height: 16),
                    _buildInputField('Areas of Improvement', controller: _areasOfImprovementController),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitResult,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Submit Result'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _formativeController.dispose();
    _summativeController.dispose();
    _specialProgressController.dispose();
    _hobbiesController.dispose();
    _areasOfImprovementController.dispose();
    super.dispose();
  }
}