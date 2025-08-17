import 'package:flutter/material.dart';
import 'dart:convert';
import '../../model/student_model.dart';
import '../../model/subject_model.dart';
import '../services/api_client.dart';
import 'dart:developer' as developer;

class AssignMarkPage extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String studentId;
  final Map<String, dynamic>? existingResult;

  const AssignMarkPage({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.studentId,
    this.existingResult, required String semester,
  });

  @override
  _AssignMarkPageState createState() => _AssignMarkPageState();
}

class _AssignMarkPageState extends State<AssignMarkPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Formative Assessment Controllers
  final _dailyObservationController = TextEditingController();
  final _oralWorkController = TextEditingController();
  final _practicalExperimentsController = TextEditingController();
  final _activitiesController = TextEditingController();
  final _projectController = TextEditingController();
  final _examinationWrittenController = TextEditingController();
  final _selfStudyController = TextEditingController();
  final _othersController = TextEditingController();

  // Summative Assessment Controllers
  final _oralController = TextEditingController();
  final _practicalController = TextEditingController();
  final _writtenController = TextEditingController();

  final _specialProgressController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _areasOfImprovementController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  String? _selectedSemester = '1'; // Default to Semester 1

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if existing result is provided
    if (widget.existingResult != null) {
      final subjectData = widget.existingResult!['subjects']?[widget.subjectId];
      if (subjectData != null) {
        final formative = subjectData['formativeAssessment'] ?? {};
        _dailyObservationController.text = formative['dailyObservation']?.toString() ?? '';
        _oralWorkController.text = formative['oralWork']?.toString() ?? '';
        _practicalExperimentsController.text = formative['practicalExperiments']?.toString() ?? '';
        _activitiesController.text = formative['activities']?.toString() ?? '';
        _projectController.text = formative['project']?.toString() ?? '';
        _examinationWrittenController.text = formative['examination (written)']?.toString() ?? '';
        _selfStudyController.text = formative['selfStudy']?.toString() ?? '';
        _othersController.text = formative['others']?.toString() ?? '';

        final summative = subjectData['summativeAssessment'] ?? {};
        _oralController.text = summative['oral']?.toString() ?? '';
        _practicalController.text = summative['practical']?.toString() ?? '';
        _writtenController.text = summative['written']?.toString() ?? '';
      }
      _specialProgressController.text = widget.existingResult!['specialProgress'] ?? '';
      _hobbiesController.text = widget.existingResult!['hobbies'] ?? '';
      _areasOfImprovementController.text = widget.existingResult!['areasOfImprovement'] ?? '';
      // Set the semester based on existing result if available
      _selectedSemester = widget.existingResult!['id'].toString().contains('sem1') ? '1' : '2';
    }
  }

  @override
  void dispose() {
    _dailyObservationController.dispose();
    _oralWorkController.dispose();
    _practicalExperimentsController.dispose();
    _activitiesController.dispose();
    _projectController.dispose();
    _examinationWrittenController.dispose();
    _selfStudyController.dispose();
    _othersController.dispose();
    _oralController.dispose();
    _practicalController.dispose();
    _writtenController.dispose();
    _specialProgressController.dispose();
    _hobbiesController.dispose();
    _areasOfImprovementController.dispose();
    super.dispose();
  }

  Future<void> _submitMarks() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Parse formative assessment fields
      final dailyObservation = double.tryParse(_dailyObservationController.text.trim()) ?? 0.0;
      final oralWork = double.tryParse(_oralWorkController.text.trim()) ?? 0.0;
      final practicalExperiments = double.tryParse(_practicalExperimentsController.text.trim()) ?? 0.0;
      final activities = double.tryParse(_activitiesController.text.trim()) ?? 0.0;
      final project = double.tryParse(_projectController.text.trim()) ?? 0.0;
      final examinationWritten = double.tryParse(_examinationWrittenController.text.trim()) ?? 0.0;
      final selfStudy = double.tryParse(_selfStudyController.text.trim()) ?? 0.0;
      final others = double.tryParse(_othersController.text.trim()) ?? 0.0;

      // Parse summative assessment fields
      final oral = double.tryParse(_oralController.text.trim()) ?? 0.0;
      final practical = double.tryParse(_practicalController.text.trim()) ?? 0.0;
      final written = double.tryParse(_writtenController.text.trim()) ?? 0.0;

      // Validate inputs
      if ([dailyObservation, oralWork, practicalExperiments, activities, project, examinationWritten, selfStudy, others, oral, practical, written].any((value) => value < 0)) {
        setState(() {
          errorMessage = 'Marks cannot be negative.';
          isLoading = false;
        });
        return;
      }
      if ([dailyObservation, oralWork, practicalExperiments, activities, project, examinationWritten, selfStudy, others, oral, practical, written].any((value) => value.isNaN || value.isInfinite)) {
        setState(() {
          errorMessage = 'Invalid marks format. Please enter valid numbers.';
          isLoading = false;
        });
        return;
      }

      final formativeTotal = dailyObservation + oralWork + practicalExperiments + activities + project + examinationWritten + selfStudy + others;
      final summativeTotal = oral + practical + written;
      final total = formativeTotal + summativeTotal;

      final subjectData = {
        'subjectName': widget.subjectName,
        'formativeAssessment': {
          'dailyObservation': dailyObservation,
          'oralWork': oralWork,
          'practicalExperiments': practicalExperiments,
          'activities': activities,
          'project': project,
          'examination (written)': examinationWritten,
          'selfStudy': selfStudy,
          'others': others,
        },
        'summativeAssessment': {
          'oral': oral,
          'practical': practical,
          'written': written,
        },
        'formativeAssesment': formativeTotal, // Backend expects this directly
        'summativeAssesment': summativeTotal, // Backend expects this directly
        'total': total,
        'grade': _calculateGrade(total),
      };

      final payload = {
        'studentId': widget.studentId,
        'schoolId': 'AIZTSSM004',
        'semester': _selectedSemester,
        'specialProgress': _specialProgressController.text.trim(),
        'hobbies': _hobbiesController.text.trim(),
        'areasOfImprovement': _areasOfImprovementController.text.trim(),
        'subjects': {widget.subjectId: subjectData},
      };

      developer.log('Submitting payload: ${jsonEncode(payload)}', name: 'AssignMarkPage');

      final response = widget.existingResult == null
          ? await _apiService.createResult({}, studentId: '', schoolId: '', semester: '', subjects: {})
          : await _apiService.updateResult(
              id: widget.existingResult!['id'].toString(),
              semester: _selectedSemester,
              specialProgress: _specialProgressController.text.trim(),
              hobbies: _hobbiesController.text.trim(),
              areasOfImprovement: _areasOfImprovementController.text.trim(),
            );

      developer.log('API response: ${jsonEncode(response)}', name: 'AssignMarkPage');

      if (response['success'] == true) {
        if (widget.existingResult != null) {
          final updateResponse = await _apiService.updateStudentSubject(
            {},
            studentId: widget.studentId,
            subjectId: widget.subjectId,
            formativeAssesment: {'value': formativeTotal},
            summativeAssesment: {'value': summativeTotal},
            jsonObject: jsonEncode(subjectData),
          );
          developer.log('Update subject marks response: ${jsonEncode(updateResponse)}', name: 'AssignMarkPage');
          if (!updateResponse['success']) {
            setState(() {
              errorMessage = updateResponse['message'] ?? 'Failed to update subject marks';
              isLoading = false;
            });
            return;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingResult == null ? 'Marks assigned successfully' : 'Marks updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to submit marks';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error submitting marks: $e';
        isLoading = false;
      });
      developer.log('Submission error: $e', name: 'AssignMarkPage');
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
    String label,
    TextEditingController controller, {
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
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
        title: Text('Sem ${_selectedSemester == '1' ? '1' : '2'} Marks - ${widget.subjectName}'),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedSemester,
                        decoration: const InputDecoration(
                          labelText: 'Select Semester',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: '1', child: Text('Semester 1')),
                          DropdownMenuItem(value: '2', child: Text('Semester 2')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSemester = value;
                          });
                        },
                      ),
                    ),
                    const Text(
                      'Formative Assessment',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    _buildInputField(
                      'Daily Observation',
                      _dailyObservationController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    _buildInputField(
                      'Oral Work',
                      _oralWorkController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    _buildInputField(
                      'Practical Experiments',
                      _practicalExperimentsController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    _buildInputField(
                      'Activities',
                      _activitiesController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    _buildInputField(
                      'Project',
                      _projectController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    _buildInputField(
                      'Examination (Written)',
                      _examinationWrittenController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    _buildInputField(
                      'Self Study',
                      _selfStudyController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    _buildInputField(
                      'Others',
                      _othersController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Summative Assessment',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    _buildInputField(
                      'Oral',
                      _oralController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    _buildInputField(
                      'Practical',
                      _practicalController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    _buildInputField(
                      'Written',
                      _writtenController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final num = double.tryParse(val);
                          if (num == null) return 'Enter a valid number';
                          if (num < 0) return 'Marks cannot be negative';
                          if (num.isNaN || num.isInfinite) return 'Invalid number format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      'Special Progress',
                      _specialProgressController,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      'Hobbies',
                      _hobbiesController,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      'Areas of Improvement',
                      _areasOfImprovementController,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitMarks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(widget.existingResult == null ? 'Assign Marks' : 'Update Marks'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}