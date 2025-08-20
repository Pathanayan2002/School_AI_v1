import 'package:flutter/material.dart';
import '../../../model/student_model.dart';
import '../../../model/subject_model.dart';
import '../../services/api_client.dart';

class Sem2ResultPage extends StatefulWidget {
  final Student student;
  final SubjectItem subject;

  const Sem2ResultPage({super.key, required this.student, required this.subject});

  @override
  State<Sem2ResultPage> createState() => _Sem2ResultPageState();
}

class _Sem2ResultPageState extends State<Sem2ResultPage> {
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
  void dispose() {
    _formativeController.dispose();
    _summativeController.dispose();
    _specialProgressController.dispose();
    _hobbiesController.dispose();
    _areasOfImprovementController.dispose();
    super.dispose();
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
        errorMessage = 'School ID not found. Please log in again.';
        isLoading = false;
      });
      return;
    }

    final formative = double.tryParse(_formativeController.text.trim());
    final summative = double.tryParse(_summativeController.text.trim());

    if (formative == null || summative == null) {
      setState(() {
        errorMessage = 'Invalid marks entered. Please enter valid numbers.';
        isLoading = false;
      });
      return;
    }
    if (formative < 0 || summative < 0) {
      setState(() {
        errorMessage = 'Marks cannot be negative.';
        isLoading = false;
      });
      return;
    }
    if (formative.isNaN || summative.isNaN || formative.isInfinite || summative.isInfinite) {
      setState(() {
        errorMessage = 'Invalid marks format. Please enter valid numbers.';
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

    final payload = {
      'studentId': widget.student.id.toString(),
      'schoolId': schoolId,
      'semester': '2', // Hardcoded for Sem2
      'subjects': subjectData,
      'specialProgress': _specialProgressController.text.trim(),
      'hobbies': _hobbiesController.text.trim(),
      'areasOfImprovement': _areasOfImprovementController.text.trim(),
    };

    final response = await _apiService.createResult(payload);

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result submitted successfully'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      setState(() {
        errorMessage = response['message'] ?? 'Failed to submit result';
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = 'Error submitting result: $e';
    });
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

  Widget _buildInputField(String label, {String? initialValue, TextEditingController? controller, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return '$label is required';
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sem2 Result - ${widget.subject.subjectName}"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
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
              _buildInputField("Student ID", initialValue: widget.student.enrollmentNo),
              _buildInputField("विद्यार्थ्यांचे नाव:", initialValue: widget.student.name),
              _buildInputField("Formative Assessment", controller: _formativeController, keyboardType: TextInputType.number),
              _buildInputField("Summative Assessment", controller: _summativeController, keyboardType: TextInputType.number),
              _buildInputField("Special Progress", controller: _specialProgressController),
              _buildInputField("Hobbies", controller: _hobbiesController),
              _buildInputField("Areas of Improvement", controller: _areasOfImprovementController),
              Center(
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitResult,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Update Marks"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}