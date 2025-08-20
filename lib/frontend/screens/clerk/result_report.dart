import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:universal_io/io.dart' show File;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class ClerkResultReportPage extends StatefulWidget {
  static const routeName = '/clerkResultReport';
  const ClerkResultReportPage({super.key});

  @override
  _ClerkResultReportPageState createState() => _ClerkResultReportPageState();
}

class _ClerkResultReportPageState extends State<ClerkResultReportPage> {
  final ApiService _apiService = ApiService();
  String? _schoolId;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _filteredResults = [];
  List<dynamic> _classes = [];
  String? _selectedClassId;
  String _selectedSemester = 'All';
  List<dynamic> _students = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isExporting = false;

  final List<String> _semesters = ['All', '1', '2'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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

      final classesResponse = await _apiService.getAllClasses(schoolId: _schoolId!);
      final studentsResponse = await _apiService.getAllStudents();

      if (kDebugMode) {
        debugPrint('Classes Response: $classesResponse');
        debugPrint('Students Response: $studentsResponse');
      }

      if (classesResponse['success'] && classesResponse['data'] != null) {
        _classes = List<Map<String, dynamic>>.from(classesResponse['data']);
      } else {
        setState(() {
          _errorMessage = 'वर्ग लोड करण्यात अयशस्वी.';
          _isLoading = false;
        });
        return;
      }

      if (studentsResponse['success'] && studentsResponse['data'] != null) {
        _students = List<Map<String, dynamic>>.from(studentsResponse['data']);
      } else {
        setState(() {
          _errorMessage = 'विद्यार्थी लोड करण्यात अयशस्वी.';
          _isLoading = false;
        });
        return;
      }

      _results = [];
      for (var student in _students) {
        final studentId = student['id'].toString();
        try {
          final resultResponse = await _apiService.getOverallResult(studentId);
          if (resultResponse['success'] && resultResponse['data'] != null) {
            final result = resultResponse['data'];
            result['studentName'] = student['name'];
            result['classId'] = student['classId'];
            _results.add(result);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('No result found for student $studentId: $e');
          }
        }
      }

      setState(() {
        _filterResults();
        _isLoading = false;
        _errorMessage = _results.isEmpty ? 'या शाळेसाठी निकाल सापडले नाहीत.' : null;
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

  void _filterResults() {
    setState(() {
      _filteredResults = _results.where((result) {
        final classMatch = _selectedClassId == null || result['classId']?.toString() == _selectedClassId;
        final semesterMatch = _selectedSemester == 'All' ||
            (result['semesterWise'] != null && result['semesterWise'][_selectedSemester] != null);
        return classMatch && semesterMatch;
      }).toList();
      _errorMessage = _filteredResults.isEmpty
          ? 'निवडलेल्या वर्ग आणि सेमेस्टरसाठी निकाल सापडले नाहीत.'
          : null;
    });
  }

  Future<void> _exportToExcel() async {
    if (_filteredResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Results'];

      sheet.appendRow([
        TextCellValue('Student Name'),
        TextCellValue('Roll No'),
        TextCellValue('Class'),
        TextCellValue('Semester'),
        TextCellValue('Grade'),
        TextCellValue('Percentage'),
        TextCellValue('Special Progress'),
        TextCellValue('Hobbies'),
        TextCellValue('Areas of Improvement'),
      ]);

      for (var result in _filteredResults) {
        final student = _students.firstWhere(
          (s) => s['id'].toString() == result['studentId'].toString(),
          orElse: () => {'name': 'Unknown', 'rollNo': 'N/A', 'classId': 'N/A'},
        );
        final classData = _classes.firstWhere(
          (c) => c['id'].toString() == student['classId']?.toString(),
          orElse: () => {'name': 'Unknown'},
        );

        final semesters = _selectedSemester == 'All' ? ['1', '2'] : [_selectedSemester];
        for (var sem in semesters) {
          if (result['semesterWise']?[sem] != null) {
            final semesterData = result['semesterWise'][sem];
            sheet.appendRow([
              TextCellValue(student['name']?.toString() ?? 'Unknown'),
              TextCellValue(student['rollNo']?.toString() ?? 'N/A'),
              TextCellValue(classData['name']?.toString() ?? 'Unknown'),
              TextCellValue(sem),
              TextCellValue(result['grandGrade']?.toString() ?? 'N/A'),
              TextCellValue(result['grandPercentage']?.toStringAsFixed(2) ?? '0.00'),
              TextCellValue(semesterData['specialProgress']?.toString() ?? 'N/A'),
              TextCellValue(semesterData['hobbies']?.toString() ?? 'N/A'),
              TextCellValue(semesterData['areasOfImprovement']?.toString() ?? 'N/A'),
            ]);
          }
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Results_${_selectedClassId ?? 'All'}_${_selectedSemester}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      await Share.shareXFiles([XFile(filePath)], text: 'Student Results Report');

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
          'Students Result Reports',
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
                                  : [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('All Classes'),
                                      ),
                                      ..._classes.map((classData) {
                                        return DropdownMenuItem<String>(
                                          value: classData['id'].toString(),
                                          child: Text(classData['name']?.toString() ?? 'Unknown Class'),
                                        );
                                      }),
                                    ],
                              onChanged: _classes.isEmpty
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedClassId = value;
                                        _filteredResults = [];
                                        _errorMessage = null;
                                        _filterResults();
                                      });
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
                              value: _selectedSemester,
                              decoration: const InputDecoration(
                                labelText: 'Select Semester',
                                labelStyle: TextStyle(color: Colors.blueAccent),
                                border: InputBorder.none,
                              ),
                              items: _semesters.map((semester) {
                                return DropdownMenuItem<String>(
                                  value: semester,
                                  child: Text(semester == 'All' ? 'All Semesters' : 'Semester $semester'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSemester = value!;
                                  _filteredResults = [];
                                  _errorMessage = null;
                                  _filterResults();
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Result Reports (${_filteredResults.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _filteredResults.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    _errorMessage ?? 'No results found for the selected class and semester.',
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
                                    DataColumn(label: Text('Semester', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Special Progress', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Hobbies', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Areas of Improvement', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _filteredResults.expand((result) {
                                    final student = _students.firstWhere(
                                      (s) => s['id'].toString() == result['studentId'].toString(),
                                      orElse: () => {'name': 'Unknown', 'rollNo': 'N/A', 'classId': 'N/A'},
                                    );
                                    final classData = _classes.firstWhere(
                                      (c) => c['id'].toString() == student['classId']?.toString(),
                                      orElse: () => {'name': 'Unknown'},
                                    );

                                    final semesters = _selectedSemester == 'All' ? ['1', '2'] : [_selectedSemester];
                                    return semesters.where((sem) => result['semesterWise']?[sem] != null).map((sem) {
                                      final semesterData = result['semesterWise'][sem];
                                      return DataRow(cells: [
                                        DataCell(Text(student['name']?.toString() ?? 'Unknown')),
                                        DataCell(Text(student['rollNo']?.toString() ?? 'N/A')),
                                        DataCell(Text(classData['name']?.toString() ?? 'Unknown')),
                                        DataCell(Text(sem == 'All' ? 'All Semesters' : 'Semester $sem')),
                                        DataCell(Text(result['grandGrade']?.toString() ?? 'N/A')),
                                        DataCell(Text(result['grandPercentage']?.toStringAsFixed(2) ?? '0.00')),
                                        DataCell(Text(semesterData['specialProgress']?.toString() ?? 'N/A')),
                                        DataCell(Text(semesterData['hobbies']?.toString() ?? 'N/A')),
                                        DataCell(Text(semesterData['areasOfImprovement']?.toString() ?? 'N/A')),
                                      ]);
                                    });
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
