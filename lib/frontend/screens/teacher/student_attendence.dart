import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({super.key});

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  final ApiService _apiService = ApiService();
  String? _teacherId;
  String? _schoolId;
  List<dynamic> _subjects = [];
  String? _selectedSubjectId;
  List<dynamic> _classes = [];
  String? _selectedClassId;
  String? _selectedMonthYear; // Changed to store "MMMM YYYY"
  List<dynamic> _students = [];
  Map<String, int> _attendanceMap = {};
  Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSubmitting = false;
  int _totalSchoolDays = 30; // Default to 30 for a month
  final TextEditingController _totalDaysController = TextEditingController(text: '30');

  // Generate list of months with current and previous year
  final List<String> _monthYears = _generateMonthYears();

  static List<String> _generateMonthYears() {
    final now = DateTime.now();
    final currentYear = now.year;
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final List<String> monthYears = [];
    for (var year = currentYear - 1; year <= currentYear; year++) {
      for (var month in months) {
        monthYears.add('$month $year');
      }
    }
    return monthYears;
  }

  @override
  void initState() {
    super.initState();
    _selectedMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());
    _loadInitialData();
  }

  @override
  void dispose() {
    _totalDaysController.dispose();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.init();
      _teacherId = await _apiService.getCurrentUserId();
      _schoolId = await _apiService.getCurrentSchoolId();

      if (_teacherId == null || _schoolId == null) {
        setState(() {
          _errorMessage = 'प्रयोक्ता किंवा शाळा सापडली नाही. कृपया पुन्हा लॉग इन करा.';
          _isLoading = false;
        });
        return;
      }

      if (kDebugMode) {
        debugPrint('Teacher ID: $_teacherId, School ID: $_schoolId');
      }

      final subjectResponse = await _apiService.getSubjectsForTeacher(_teacherId!, _schoolId!);
      final classResponse = await _apiService.getClassesByTeacherId(_teacherId!);

      if (kDebugMode) {
        debugPrint('Subject Response: $subjectResponse');
        debugPrint('Class Response: $classResponse');
      }

      setState(() {
        _subjects = subjectResponse.isNotEmpty ? subjectResponse : [];
        if (classResponse['success'] && classResponse['data'] != null) {
          _classes = List<Map<String, dynamic>>.from(classResponse['data']);
        } else {
          _classes = [];
          _errorMessage = classResponse['message'] ?? 'वर्ग मिळवण्यात अयशस्वी.';
        }
        _isLoading = false;
        if (_subjects.isEmpty) {
          _errorMessage = _errorMessage != null
              ? '$_errorMessage\nया शिक्षकाला कोणतेही विषय नियुक्त केलेले नाहीत.'
              : 'या शिक्षकाला कोणतेही विषय नियुक्त केलेले नाहीत.';
        }
        if (_classes.isEmpty) {
          _errorMessage = _errorMessage != null
              ? '$_errorMessage\nया शिक्षकाला कोणतेही वर्ग नियुक्त केलेले नाहीत.'
              : 'या शिक्षकाला कोणतेही वर्ग नियुक्त केलेले नाहीत.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'डेटा लोड करण्यात त्रुटी: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        debugPrint('Error in _loadInitialData: $e');
      }
    }
  }

  Future<void> _loadStudents(String subjectId, String? classId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiService.getStudentsBySubject(subjectId);
      if (kDebugMode) {
        debugPrint('Students Response for Subject $subjectId: $response');
      }
      if (response['success']) {
        setState(() {
          _students = response['data'] ?? [];
          if (classId != null) {
            _students = _students.where((student) => student['classId']?.toString() == classId).toList();
          }
          _attendanceMap = {};
          _controllers = {};
          for (var student in _students) {
            final studentId = student['id'].toString();
            _attendanceMap[studentId] = 0;
            _controllers[studentId] = TextEditingController(text: '0');
          }
          _errorMessage = _students.isEmpty ? 'या विषयासाठी किंवा वर्गासाठी विद्यार्थी सापडले नाहीत.' : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'विद्यार्थी लोड करण्यात अयशस्वी.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'विद्यार्थी लोड करण्यात त्रुटी: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        debugPrint('Error in _loadStudents: $e');
      }
    }
  }

  Future<void> _submitAttendance() async {
    if (_students.isEmpty || _selectedSubjectId == null || _selectedClassId == null || _selectedMonthYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject, class, and month, and ensure students are loaded.')),
      );
      return;
    }

    final totalDays = int.tryParse(_totalDaysController.text) ?? 0;
    if (totalDays <= 0 || totalDays > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total school days must be between 1 and 31.')),
      );
      return;
    }

    bool isValid = true;
    for (var student in _students) {
      final studentId = student['id'].toString();
      final presentDays = _attendanceMap[studentId] ?? 0;
      if (presentDays < 0 || presentDays > totalDays) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid attendance for ${student['name']}: $presentDays days (Max $totalDays).')),
        );
        return;
      }
    }

    if (!isValid) return;

    setState(() => _isSubmitting = true);
    bool allSuccess = true;

    for (var student in _students) {
      final String studentId = student['id'].toString();
      final int presentDays = _attendanceMap[studentId] ?? 0;

      try {
        final response = await _apiService.createAttendance(
          studentId: studentId,
          month: _selectedMonthYear!, // Send as "MMMM YYYY"
          totalDays: totalDays,
          presentDays: presentDays,
        );

        if (!response['success']) {
          allSuccess = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit attendance for ${student['name']}: ${response['message']}')),
          );
        }
      } catch (e) {
        allSuccess = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting attendance for ${student['name']}: $e')),
        );
      }
    }

    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(allSuccess ? 'Attendance submitted successfully!' : 'Some submissions failed.'),
        backgroundColor: allSuccess ? Colors.green : Colors.red,
      ),
    );

    if (allSuccess) {
      setState(() {
        _attendanceMap = {for (var student in _students) student['id'].toString(): 0};
        _controllers.forEach((studentId, controller) => controller.text = '0');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mark Student Attendance ($_selectedMonthYear)',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadInitialData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Class Dropdown
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: DropdownButtonFormField<String>(
                              value: _selectedClassId,
                              decoration: const InputDecoration(
                                labelText: 'Select Class',
                                labelStyle: TextStyle(color: Colors.blueAccent),
                                border: InputBorder.none,
                              ),
                              items: _classes.isEmpty
                                  ? [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('No classes available'),
                                        enabled: false,
                                      ),
                                    ]
                                  : _classes.map((classData) {
                                      return DropdownMenuItem<String>(
                                        value: classData['id'].toString(),
                                        child: Text(classData['name']?.toString() ?? 'Unknown Class'),
                                      );
                                    }).toList(),
                              onChanged: _classes.isEmpty
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedClassId = value;
                                        _students = [];
                                        _attendanceMap = {};
                                        _controllers.forEach((_, controller) => controller.dispose());
                                        _controllers = {};
                                        _errorMessage = null;
                                      });
                                      if (_selectedSubjectId != null && value != null) {
                                        _loadStudents(_selectedSubjectId!, value);
                                      }
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subject Dropdown
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: DropdownButtonFormField<String>(
                              value: _selectedSubjectId,
                              decoration: const InputDecoration(
                                labelText: 'Select Subject',
                                labelStyle: TextStyle(color: Colors.blueAccent),
                                border: InputBorder.none,
                              ),
                              items: _subjects.isEmpty
                                  ? [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('No subjects available'),
                                        enabled: false,
                                      ),
                                    ]
                                  : _subjects.map((subject) {
                                      return DropdownMenuItem<String>(
                                        value: subject['id'].toString(),
                                        child: Text(subject['name']?.toString() ?? 'Unknown Subject'),
                                      );
                                    }).toList(),
                              onChanged: _subjects.isEmpty
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedSubjectId = value;
                                        _students = [];
                                        _attendanceMap = {};
                                        _controllers.forEach((_, controller) => controller.dispose());
                                        _controllers = {};
                                        _errorMessage = null;
                                      });
                                      if (value != null && _selectedClassId != null) {
                                        _loadStudents(value, _selectedClassId);
                                      }
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Month-Year Dropdown
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: DropdownButtonFormField<String>(
                              value: _selectedMonthYear,
                              decoration: const InputDecoration(
                                labelText: 'Select Month and Year',
                                labelStyle: TextStyle(color: Colors.blueAccent),
                                border: InputBorder.none,
                              ),
                              items: _monthYears.map((monthYear) {
                                return DropdownMenuItem<String>(
                                  value: monthYear,
                                  child: Text(monthYear),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedMonthYear = newValue!;
                                  _attendanceMap = {for (var student in _students) student['id'].toString(): 0};
                                  _controllers.forEach((studentId, controller) => controller.text = '0');
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Total School Days Input
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: TextField(
                              controller: _totalDaysController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Total School Days in Month',
                                labelStyle: const TextStyle(color: Colors.blueAccent),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                errorText: (int.tryParse(_totalDaysController.text) ?? 0) <= 0 ||
                                        (int.tryParse(_totalDaysController.text) ?? 0) > 31
                                    ? 'Enter 1–31 days'
                                    : null,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _totalSchoolDays = int.tryParse(value) ?? 30;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Students (${_students.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _students.isEmpty
                            ? const Center(
                                child: Text(
                                  'Select a class, subject, and month to view students',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _students.length,
                                itemBuilder: (context, index) {
                                  final student = _students[index];
                                  final studentId = student['id'].toString();
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blueAccent,
                                        child: Text(
                                          student['name']?[0] ?? '?',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      title: Text(
                                        student['name']?.toString() ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        'Roll No: ${student['rollNo']?.toString() ?? 'N/A'} | Present: ${_attendanceMap[studentId] ?? 0}/$_totalSchoolDays days',
                                      ),
                                      trailing: SizedBox(
                                        width: 100,
                                        child: TextField(
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Days Present',
                                            border: const OutlineInputBorder(),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            errorText: (_attendanceMap[studentId] ?? 0) > _totalSchoolDays
                                                ? 'Max $_totalSchoolDays'
                                                : (_attendanceMap[studentId] ?? 0) < 0
                                                    ? 'Min 0'
                                                    : null,
                                          ),
                                          controller: _controllers[studentId],
                                          onChanged: (value) {
                                            final intValue = int.tryParse(value) ?? 0;
                                            setState(() {
                                              _attendanceMap[studentId] = intValue.clamp(0, _totalSchoolDays);
                                              _controllers[studentId]!.text = _attendanceMap[studentId].toString();
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_students.isNotEmpty && !_isSubmitting) ? _submitAttendance : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blueAccent,
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Submit Attendance',
                                    style: TextStyle(fontSize: 16, color: Colors.white),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }
}