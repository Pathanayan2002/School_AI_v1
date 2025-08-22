import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../services/api_client.dart';

class AssignMarkPage extends StatefulWidget {
  final String studentId;
  final String subjectId;
  final String subjectName;
  final String semester; // '1' or '2'
  final Map<String, dynamic>? existingResult;

  const AssignMarkPage({
    super.key,
    required this.studentId,
    required this.subjectId,
    required this.subjectName,
    required this.semester,
    this.existingResult,
  });

  @override
  State<AssignMarkPage> createState() => _AssignMarkPageState();
}

class _AssignMarkPageState extends State<AssignMarkPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final dailyObservationController = TextEditingController();
  final oralWorkController = TextEditingController();
  final practicalExperimentsController = TextEditingController();
  final activitiesController = TextEditingController();
  final projectController = TextEditingController();
  final examinationWrittenController = TextEditingController();
  final selfStudyController = TextEditingController();
  final otherController = TextEditingController();

  final oralController = TextEditingController();
  final practicalController = TextEditingController();
  final writtenController = TextEditingController();

  final specialProgressController = TextEditingController();
  final hobbiesController = TextEditingController();
  final areasOfImprovementController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  String? teacherId;
  String? studentName; // Variable to store student's name
  Map<String, dynamic>? existingResult;
  late String selectedSemester;

  // Live totals
  double formativeTotal = 0;
  double summativeTotal = 0;
  double overallTotal = 0;
  String overallGrade = '—';

  // number-only formatter (up to 3 digits + optional . + up to 2 decimals)
  final List<TextInputFormatter> _numFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?$')),
  ];

  @override
  void initState() {
    super.initState();
    existingResult = widget.existingResult;
    selectedSemester = widget.semester;

    _hydrateFromExisting();
    _validateTeacherAccess();
    _fetchStudentName();
    _recomputeTotals();
  }

  void _hydrateFromExisting() {
  if (existingResult != null) {
    final subjectsMap = (existingResult!['subjects'] ?? {}) as Map? ?? {};
    final subjectData = subjectsMap[widget.subjectId];

    Map<String, dynamic>? _pickFormative(dynamic src) {
      if (src is Map) {
        if (src['formativeAssessment'] is Map) return Map<String, dynamic>.from(src['formativeAssessment']);
        if (src['formativeAssesment'] is Map) return Map<String, dynamic>.from(src['formativeAssesment']);
      }
      return null;
    }

    Map<String, dynamic>? _pickSummative(dynamic src) {
      if (src is Map) {
        if (src['summativeAssessment'] is Map) return Map<String, dynamic>.from(src['summativeAssessment']);
        if (src['summativeAssesment'] is Map) return Map<String, dynamic>.from(src['summativeAssesment']);
      }
      return null;
    }

    if (subjectData != null) {
      final formative = _pickFormative(subjectData) ?? {};
      final summative = _pickSummative(subjectData) ?? {};

      dailyObservationController.text = (formative['dailyObservation'] ?? '').toString();
      oralWorkController.text = (formative['oralWork'] ?? '').toString();
      practicalExperimentsController.text = (formative['practicalExperiments'] ?? '').toString();
      activitiesController.text = (formative['activities'] ?? '').toString();
      projectController.text = (formative['project'] ?? '').toString();
      examinationWrittenController.text = (formative['examinationWritten'] ?? '').toString();
      selfStudyController.text = (formative['selfStudy'] ?? '').toString();
      otherController.text = (formative['other'] ?? '').toString();

      oralController.text = (summative['oral'] ?? '').toString();
      practicalController.text = (summative['practical'] ?? '').toString();
      writtenController.text = (summative['written'] ?? '').toString();
    }

    // Load specialProgress, hobbies, and areasOfImprovement from root level
    specialProgressController.text = (existingResult!['specialProgress'] ?? '').toString();
    hobbiesController.text = (existingResult!['hobbies'] ?? '').toString();
    areasOfImprovementController.text = (existingResult!['areasOfImprovement'] ?? '').toString();
  }
}
  Future<void> _fetchStudentName() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await _apiService.getStudentById(widget.studentId);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          studentName = response['data']['name']?.toString() ?? 'Unknown Student';
        });
      } else {
        setState(() {
          errorMessage = 'Failed to fetch student name';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching student name: $e';
      });
      developer.log('Error fetching student name: $e', name: 'AssignMarkPage');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    dailyObservationController.dispose();
    oralWorkController.dispose();
    practicalExperimentsController.dispose();
    activitiesController.dispose();
    projectController.dispose();
    examinationWrittenController.dispose();
    selfStudyController.dispose();
    otherController.dispose();
    oralController.dispose();
    practicalController.dispose();
    writtenController.dispose();
    specialProgressController.dispose();
    hobbiesController.dispose();
    areasOfImprovementController.dispose();
    super.dispose();
  }

  Future<void> _validateTeacherAccess() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      teacherId = await _apiService.getCurrentUserId();
      if (teacherId == null) {
        setState(() {
          errorMessage = 'User not logged in';
        });
        return;
      }

      final schoolId = await _apiService.getCurrentSchoolId();
      if (schoolId == null) {
        setState(() {
          errorMessage = 'School ID not found';
        });
        return;
      }

      final subjectsResponse = await _apiService.getAllSubjects(schoolId: schoolId);
      if (subjectsResponse['success'] == true && subjectsResponse['data'] != null) {
        final List data = subjectsResponse['data'];
        final isAssigned = data.any((sub) =>
            sub['id'].toString() == widget.subjectId &&
            sub['teacherId']?.toString() == teacherId);
        if (!isAssigned) {
          setState(() {
            errorMessage = 'You are not assigned to this subject';
          });
          return;
        }
      } else {
        setState(() {
          errorMessage = 'Failed to validate subject assignment';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error validating access: $e';
      });
      developer.log('Validation error: $e', name: 'AssignMarkPage');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _recomputeTotals() {
    final formative = _formativeMap();
    final summative = _summativeMap();

    formativeTotal = formative.values.fold(0.0, (a, b) => a + (b as num).toDouble());
    summativeTotal = summative.values.fold(0.0, (a, b) => a + (b as num).toDouble());
    overallTotal = formativeTotal + summativeTotal;
    overallGrade = _calculateGrade(overallTotal);
    setState(() {});
  }

  Map<String, num> _formativeMap() => {
        'dailyObservation': _toNum(dailyObservationController.text),
        'oralWork': _toNum(oralWorkController.text),
        'practicalExperiments': _toNum(practicalExperimentsController.text),
        'activities': _toNum(activitiesController.text),
        'project': _toNum(projectController.text),
        'examinationWritten': _toNum(examinationWrittenController.text),
        'selfStudy': _toNum(selfStudyController.text),
        'other': _toNum(otherController.text),
      };

  Map<String, num> _summativeMap() => {
        'oral': _toNum(oralController.text),
        'practical': _toNum(practicalController.text),
        'written': _toNum(writtenController.text),
      };

  num _toNum(String s) => double.tryParse(s.trim().isEmpty ? '0' : s.trim()) ?? 0;

  String _calculateGrade(double total) {
    if (total >= 90) return 'A+';
    if (total >= 80) return 'A';
    if (total >= 70) return 'B+';
    if (total >= 60) return 'B';
    if (total >= 50) return 'C';
    return 'F';
  }

 Future<void> _submitMarks() async {
  if (!_formKey.currentState!.validate() || errorMessage != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please correct the errors before submitting'), backgroundColor: Colors.red),
    );
    return;
  }

  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    if (widget.studentId.isEmpty) throw Exception('Student ID is missing');
    final schoolId = await _apiService.getCurrentSchoolId();
    if (schoolId == null || schoolId.isEmpty) throw Exception('School ID is missing');
    if (selectedSemester.isEmpty) throw Exception('Semester is missing');

    final formative = _formativeMap();
    final summative = _summativeMap();

    final total = formative.values.fold<num>(0, (a, b) => a + b) +
        summative.values.fold<num>(0, (a, b) => a + b);
    final grade = _calculateGrade(total.toDouble());

    final subjectNode = {
      'subjectName': widget.subjectName,
      'formative': formativeTotal,
      'summative': summativeTotal,
      'formativeAssessment': formative,
      'summativeAssessment': summative,
      'formativeAssesment': formative, // Keep for backward compatibility
      'summativeAssesment': summative, // Keep for backward compatibility
      'total': total,
      'grade': grade,
    };

    final subjectsFlat = {
      widget.subjectId: subjectNode,
    };

    final payload = {
      "specialProgress": specialProgressController.text.trim(),
      "hobbies": hobbiesController.text.trim(),
      "areasOfImprovement": areasOfImprovementController.text.trim(),
      'studentId': widget.studentId,
      'schoolId': schoolId,
      'semester': selectedSemester,
      'subjects': subjectsFlat,
      'specialProgress': specialProgressController.text.trim(),
      'hobbies': hobbiesController.text.trim(),
      'areasOfImprovement': areasOfImprovementController.text.trim(),
    };

    developer.log('Submitting payload: ${jsonEncode(payload)}', name: 'AssignMarkPage');

    Map<String, dynamic> response;
    if (existingResult != null && (existingResult!['id'] != null)) {
      response = await _apiService.updateResult(payload, id: existingResult!['id'].toString());
    } else {
      response = await _apiService.createResult(payload);
    }

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marks and details saved'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        errorMessage = response['message'] ?? 'Failed to save marks';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage!), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    setState(() {
      errorMessage = 'Error: $e';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
    developer.log('Submit error: $e', name: 'AssignMarkPage');
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Marks – ${widget.subjectName}'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Stack(
        children: [
          if (isLoading)
            const LinearProgressIndicator(minHeight: 2),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (errorMessage != null) _errorBanner(errorMessage!),

                  _summaryHeader(theme),

                  _buildSemesterDropdown(),

                  _sectionCard(
                    title: 'Formative Assessment',
                    children: [
                      _numField('Daily Observation', dailyObservationController, Icons.visibility),
                      _numField('Oral Work', oralWorkController, Icons.record_voice_over),
                      _numField('Practical Experiments', practicalExperimentsController, Icons.science),
                      _numField('Activities', activitiesController, Icons.sports_esports),
                      _numField('Project', projectController, Icons.work_outline),
                      _numField('Examination Written', examinationWrittenController, Icons.edit_document),
                      _numField('Self Study', selfStudyController, Icons.self_improvement),
                      _numField('Other', otherController, Icons.more_horiz),
                    ],
                  ),

                  _sectionCard(
                    title: 'Summative Assessment',
                    children: [
                      _numField('Oral', oralController, Icons.mic),
                      _numField('Practical', practicalController, Icons.build),
                      _numField('Written', writtenController, Icons.menu_book),
                    ],
                  ),

                  _sectionCard(
                    title: 'Additional Details',
                    children: [
                      _textField('Special Progress', specialProgressController, Icons.star),
                      _textField('Hobbies', hobbiesController, Icons.sports_basketball),
                      _textField('Areas of Improvement', areasOfImprovementController, Icons.trending_up),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _totalsCard(),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _submitMarks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      isLoading ? 'Saving...' : 'Submit',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryHeader(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blue.shade50,
              child: Icon(Icons.school, color: Colors.blue.shade700, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.subjectName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      'Student: ${studentName ?? 'Loading...'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
            _gradeChip(overallGrade),
          ],
        ),
      ),
    );
  }

  Widget _gradeChip(String grade) {
    Color bg;
    switch (grade) {
      case 'A+':
      case 'A':
        bg = Colors.green.shade100;
        break;
      case 'B+':
      case 'B':
        bg = Colors.blue.shade100;
        break;
      case 'C':
        bg = Colors.orange.shade100;
        break;
      case 'F':
      default:
        bg = Colors.red.shade100;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        'Grade: $grade',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _totalsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _totBox('Formative', formativeTotal),
            _divider(),
            _totBox('Summative', summativeTotal),
            _divider(),
            _totBox('Total', overallTotal, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.grey.shade300,
      );

  Widget _totBox(String label, double value, {bool bold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 16,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.blue.shade800,
                )),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
        inputFormatters: _numFormatters,
        decoration: _inputDecoration(label, icon),
        onChanged: (_) => _recomputeTotals(),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return '$label is required';
          final v = double.tryParse(value.trim());
          if (v == null) return 'Enter a valid number';
          if (v < 0) return 'Marks cannot be negative';
          return null;
        },
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: null,
        decoration: _inputDecoration(label, icon),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return '$label is required';
          return null;
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.blue.shade700),
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
      ),
    );
  }

  Widget _buildSemesterDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: selectedSemester,
        decoration: InputDecoration(
          labelText: 'Semester',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: Icon(Icons.calendar_month, color: Colors.blue.shade700),
        ),
        items: const ['1', '2']
            .map((v) => DropdownMenuItem<String>(value: v, child: Text('Semester $v')))
            .toList(),
        onChanged: (String? newValue) {
          if (newValue == null) return;
          setState(() {
            selectedSemester = newValue;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please select a semester';
          return null;
        },
      ),
    );
  }
}