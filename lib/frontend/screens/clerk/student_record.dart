import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:universal_io/io.dart' show File;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class ClerkAttendanceRecordPage extends StatefulWidget {
  const ClerkAttendanceRecordPage({super.key});

  @override
  State<ClerkAttendanceRecordPage> createState() => _ClerkAttendanceRecordPageState();
}

class _ClerkAttendanceRecordPageState extends State<ClerkAttendanceRecordPage> {
  final ApiService _apiService = ApiService();
  String? _schoolId;
  List<dynamic> _subjects = [];
  String? _selectedSubjectId;
  List<dynamic> _classes = [];
  String? _selectedClassId;
  List<dynamic> _students = [];
  List<dynamic> _attendanceRecords = [];
  String _selectedMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());
  bool _isLoading = false;
  String? _errorMessage;
  bool _isExporting = false;

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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.init();
      _schoolId = await _apiService.getCurrentSchoolId();

      if (_schoolId == null) {
        setState(() {
          _errorMessage = 'शाळा सापडली नाही. कृपया पुन्हा लॉग इन करा.';
          _isLoading = false;
        });
        return;
      }

      final subjectResponse = await _apiService.getAllSubjects(schoolId: _schoolId!);
      final classResponse = await _apiService.getAllClasses(schoolId: _schoolId!);

      if (kDebugMode) {
        debugPrint('Subject Response: $subjectResponse');
        debugPrint('Class Response: $classResponse');
      }

      setState(() {
        _subjects = subjectResponse['success'] && subjectResponse['data'] != null
            ? List<Map<String, dynamic>>.from(subjectResponse['data'])
            : [];
        _classes = classResponse['success'] && classResponse['data'] != null
            ? List<Map<String, dynamic>>.from(classResponse['data'])
            : [];
        _isLoading = false;
        if (_subjects.isEmpty) {
          _errorMessage = 'या शाळेला कोणतेही विषय नियुक्त केलेले नाहीत.';
        }
        if (_classes.isEmpty) {
          _errorMessage = _errorMessage != null
              ? '$_errorMessage\nया शाळेला कोणतेही वर्ग नियुक्त केलेले नाहीत.'
              : 'या शाळेला कोणतेही वर्ग नियुक्त केलेले नाहीत.';
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

  String _convertMonthYearToServerFormat(String monthYear) {
    // Convert "MMMM YYYY" (e.g., "August 2025") to server-compatible format
    // Assuming server stores "MMMM YYYY" based on createAttendance
    return monthYear;
  }

  Future<void> _loadStudentsAndAttendance(String subjectId, String? classId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final studentsResponse = await _apiService.getAllStudents();
      if (kDebugMode) {
        debugPrint('Students Response: $studentsResponse');
      }
      if (studentsResponse['success'] && studentsResponse['data'] != null) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(studentsResponse['data']);
          if (classId != null) {
            _students = _students.where((student) => student['classId']?.toString() == classId).toList();
          }
          _attendanceRecords = [];
        });

        String serverMonthYear = _convertMonthYearToServerFormat(_selectedMonthYear);

        final attendanceResponse = await _apiService.getAllAttendances();
        if (kDebugMode) {
          debugPrint('Attendance Response: $attendanceResponse');
        }
        if (attendanceResponse['success'] && attendanceResponse['data'] != null) {
          final studentIds = _students.map((s) => s['id'].toString()).toSet();
          final filteredRecords = (attendanceResponse['data']['studentAttendances'] as List<dynamic>)
              .where((record) =>
                  studentIds.contains(record['studentId']?.toString()) &&
                  record['month'] == serverMonthYear &&
                  record['schoolId'] == _schoolId)
              .map((record) => {
                    ...record,
                    'month': _selectedMonthYear // Ensure display format
                  })
              .toList();

          setState(() {
            _attendanceRecords = filteredRecords;
            _errorMessage = _students.isEmpty
                ? 'या वर्गासाठी विद्यार्थी सापडले नाहीत.'
                : _attendanceRecords.isEmpty
                    ? 'निवडलेल्या विषय, वर्ग आणि महिन्यासाठी उपस्थिती रेकॉर्ड सापडले नाहीत.'
                    : null;
          });
        } else {
          setState(() {
            _errorMessage = attendanceResponse['message'] ?? 'उपस्थिती रेकॉर्ड मिळवण्यात अयशस्वी.';
          });
        }
      } else {
        setState(() {
          _errorMessage = studentsResponse['message'] ?? 'विद्यार्थी लोड करण्यात अयशस्वी.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'विद्यार्थी किंवा उपस्थिती लोड करण्यात त्रुटी: $e';
      });
      if (kDebugMode) {
        debugPrint('Error in _loadStudentsAndAttendance: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel() async {
    if (_students.isEmpty || _attendanceRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Attendance'];

      sheet.appendRow([
        TextCellValue('Student Name'),
        TextCellValue('Roll No'),
        TextCellValue('Class'),
        TextCellValue('Month'),
        TextCellValue('Total Days'),
        TextCellValue('Present Days'),
        TextCellValue('Attendance %'),
      ]);

      for (var record in _attendanceRecords) {
        final student = _students.firstWhere(
          (s) => s['id'].toString() == record['studentId'].toString(),
          orElse: () => {'name': 'Unknown', 'rollNo': 'N/A', 'classId': 'N/A'},
        );
        final classData = _classes.firstWhere(
          (c) => c['id'].toString() == student['classId']?.toString(),
          orElse: () => {'name': 'Unknown'},
        );

        final totalDays = record['totalDays'] ?? 0;
        final presentDays = record['presentDays'] ?? 0;
        final percentage = totalDays > 0 ? ((presentDays / totalDays) * 100).toStringAsFixed(2) : '0.00';

        sheet.appendRow([
          TextCellValue(student['name']?.toString() ?? 'Unknown'),
          TextCellValue(student['rollNo']?.toString() ?? 'N/A'),
          TextCellValue(classData['name']?.toString() ?? 'Unknown'),
          TextCellValue(record['month']?.toString() ?? _selectedMonthYear),
          TextCellValue(totalDays.toString()),
          TextCellValue(presentDays.toString()),
          TextCellValue('$percentage%'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Attendance_${_selectedMonthYear.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      await Share.shareXFiles([XFile(filePath)], text: 'Student Attendance Report');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel file exported and shared: $fileName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting to Excel: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Clerk Attendance Records',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            onPressed: _isExporting ? null : _exportToExcel,
            tooltip: 'Export to Excel',
          ),
        ],
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
                        onPressed: () {
                          if (_selectedSubjectId != null && _selectedClassId != null) {
                            _loadStudentsAndAttendance(_selectedSubjectId!, _selectedClassId);
                          } else {
                            _loadInitialData();
                          }
                        },
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
                                        _attendanceRecords = [];
                                        _errorMessage = null;
                                      });
                                      if (_selectedSubjectId != null && value != null) {
                                        _loadStudentsAndAttendance(_selectedSubjectId!, value);
                                      }
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                        _attendanceRecords = [];
                                        _errorMessage = null;
                                      });
                                      if (value != null && _selectedClassId != null) {
                                        _loadStudentsAndAttendance(value, _selectedClassId);
                                      }
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                  _attendanceRecords = [];
                                  _errorMessage = null;
                                  if (_selectedSubjectId != null && _selectedClassId != null) {
                                    _loadStudentsAndAttendance(_selectedSubjectId!, _selectedClassId);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Attendance Records (${_attendanceRecords.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _attendanceRecords.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    _errorMessage ?? 'No attendance records found for the selected subject, class, and month.',
                                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 16,
                                  columns: const [
                                    DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Class', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Total Days', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Present Days', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Attendance %', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _attendanceRecords.map((record) {
                                    final student = _students.firstWhere(
                                      (s) => s['id'].toString() == record['studentId'].toString(),
                                      orElse: () => {'name': 'Unknown', 'rollNo': 'N/A', 'classId': 'N/A'},
                                    );
                                    final classData = _classes.firstWhere(
                                      (c) => c['id'].toString() == student['classId']?.toString(),
                                      orElse: () => {'name': 'Unknown'},
                                    );
                                    final totalDays = record['totalDays'] ?? 0;
                                    final presentDays = record['presentDays'] ?? 0;
                                    final percentage = totalDays > 0 ? ((presentDays / totalDays) * 100).toStringAsFixed(2) : '0.00';

                                    return DataRow(cells: [
                                      DataCell(Text(student['name']?.toString() ?? 'Unknown')),
                                      DataCell(Text(student['rollNo']?.toString() ?? 'N/A')),
                                      DataCell(Text(classData['name']?.toString() ?? 'Unknown')),
                                      DataCell(Text(record['month']?.toString() ?? _selectedMonthYear)),
                                      DataCell(Text(totalDays.toString())),
                                      DataCell(Text(presentDays.toString())),
                                      DataCell(Text('$percentage%')),
                                    ]);
                                  }).toList(),
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
