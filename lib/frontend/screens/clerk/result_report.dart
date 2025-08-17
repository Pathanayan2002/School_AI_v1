import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import '../../model/class_model.dart';
import '../../model/student_model.dart';
import '../services/api_client.dart';
import '../teacher/assign_marks.dart';

class ClerkResultReportScreen extends StatefulWidget {
  static const routeName = '/clerkResultReport';
  const ClerkResultReportScreen({super.key});

  @override
  State<ClerkResultReportScreen> createState() => _ClerkResultReportScreenState();
}

class _ClerkResultReportScreenState extends State<ClerkResultReportScreen> {
  final ApiService _apiService = ApiService();
  List<ClassModel> classes = [];
  Map<String, List<Student>> classStudents = {};
  bool isLoading = true;
  String? errorMessage;
  Student? selectedStudent;
  Map<String, dynamic>? studentResult;
  List<String> subjectIds = [];
  Map<String, String> subjectIdToName = {};
  String? selectedSubjectId;
  Map<String, Map<String, dynamic>> studentResults = {};

  final Map<String, String> marathiTranslations = {
    'Student Result Report': 'विद्यार्थ्यांचा निकाल अहवाल',
    'Name': 'नाव',
    'Enrollment ID': 'नावनोंदणी आयडी',
    'Semester': 'सत्र',
    'Total': 'एकूण',
    'Grade': 'श्रेणी',
    'Subject Name': 'विषयाचे नाव',
    'Formative': 'रचनात्मक',
    'Summative': 'संक्षेपात्मक',
    'Results for Subject': 'विषयासाठी निकाल',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // Replace '' with actual schoolId or handle as needed
      final subjectsResponse = await _apiService.getAllSubjects(schoolId: '1'); // Assuming schoolId is a string
      if (subjectsResponse['success'] != true) throw Exception('विषय लोड करण्यात अयशस्वी');
      final subjectList = subjectsResponse['data'] as List<dynamic>;
      subjectIds = subjectList.map((s) => s['id'].toString()).toList();
      subjectIdToName = {for (var s in subjectList) s['id'].toString(): s['name']?.toString() ?? 'Unknown'};
      selectedSubjectId = subjectIds.isNotEmpty ? subjectIds.first : null;

      final classesResponse = await _apiService.getAllClasses(schoolId: '1'); // Assuming schoolId is a string
      if (classesResponse['success'] != true) throw Exception('वर्ग लोड करण्यात अयशस्वी');
      final classList = classesResponse['data'] as List<dynamic>;
      classes = classList.map((c) => ClassModel.fromJson(c)).toList();
      classStudents = {
        for (var c in classList)
          c['id'].toString(): (c['students'] as List<dynamic>?)?.map((s) => Student.fromJson(s)).toList() ?? []
      };

      if (classes.isEmpty || subjectIds.isEmpty) errorMessage = 'कोणतेही वर्ग किंवा विषय उपलब्ध नाहीत';
    } catch (e) {
      errorMessage = 'डेटा लोड करण्यात त्रुटी: $e';
      developer.log('Error in _loadData: $e', name: 'ClerkResultReportScreen');
    }
    setState(() => isLoading = false);
  }

  Future<void> _loadStudentResult(Student student) async {
    setState(() {
      isLoading = true;
      selectedStudent = student;
      studentResult = null;
    });

    try {
      final result = await _apiService.getFinalResultByStudentId(student.id.toString());
      if (result['success'] != true) throw Exception('निकाल प्राप्त करण्यात अयशस्वी');

      final semesterWise = Map<String, dynamic>.from(result['data']?['semesterWise'] ?? {});
      final filteredSemesterWise = <String, dynamic>{};
      for (var sem in ['1', '2']) {
        if (semesterWise.containsKey(sem)) {
          final subjects = Map<String, dynamic>.from(semesterWise[sem]['subjects'] ?? {})
              .entries
              .where((e) => subjectIds.contains(e.key))
              .fold<Map<String, dynamic>>({}, (map, e) => map..[e.key] = e.value);
          if (subjects.isNotEmpty) {
            final totalMarks = subjects.values.fold<double>(0, (sum, s) => sum + (s['total']?.toDouble() ?? 0));
            filteredSemesterWise[sem] = {
              'subjects': subjects,
              'totalMarks': totalMarks,
              'grade': _calculateGrade(totalMarks > 0 ? (totalMarks / (subjects.length * 100)) * 100 : 0),
            };
          }
        }
      }

      studentResult = {
        'semesterWise': filteredSemesterWise,
        'grandTotal': filteredSemesterWise.values.fold<double>(0, (sum, s) => sum + (s['totalMarks'] ?? 0)),
      };
      setState(() {});
      if (filteredSemesterWise.isEmpty) _showError('निकाल उपलब्ध नाहीत');
    } catch (e) {
      _showError('निकाल प्राप्त करण्यात त्रुटी: $e');
      setState(() => errorMessage = 'निकाल प्राप्त करण्यात त्रुटी: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _calculateGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version?.sdkInt ?? 0;

    if (sdkInt < 30) {
      if (await Permission.storage.request().isGranted) return true;
    } else if (sdkInt <= 33) {
      if (await Permission.manageExternalStorage.request().isGranted) return true;
    } else {
      if ((await Permission.photos.request().isGranted) &&
          (await Permission.videos.request().isGranted) &&
          (await Permission.audio.request().isGranted)) return true;
    }
    _showError('स्टोरेज परवानगी नाकारली');
    return false;
  }

  Future<Uint8List?> _generateExcelForStudent(Student student, String sheetName) async {
    return compute(_generateExcelForStudentInIsolate, {
      'student': {'id': student.id.toString(), 'name': student.name, 'enrollmentNo': student.enrollmentNo},
      'studentResult': studentResult,
      'sheetName': sheetName,
      'subjectIdToName': subjectIdToName,
      'marathiTranslations': marathiTranslations,
    });
  }

  static Future<Uint8List?> _generateExcelForStudentInIsolate(Map<String, dynamic> params) async {
    final student = params['student'] as Map<String, dynamic>;
    final studentResult = params['studentResult'] as Map<String, dynamic>?;
    final sheetName = params['sheetName'] as String;
    final subjectIdToName = params['subjectIdToName'] as Map<String, String>;
    final marathiTranslations = params['marathiTranslations'] as Map<String, String>;

    final excel = Excel.createExcel();
    final sheet = excel[sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName];

    String getMarathi(String english) => marathiTranslations[english] ?? english;

    sheet.appendRow([TextCellValue(getMarathi('Student Result Report'))]);
    sheet.appendRow([
      TextCellValue(getMarathi('Name')),
      TextCellValue(getMarathi('Enrollment ID')),
      TextCellValue(getMarathi('Semester')),
      TextCellValue(getMarathi('Subject Name')),
      TextCellValue(getMarathi('Formative')),
      TextCellValue(getMarathi('Summative')),
      TextCellValue(getMarathi('Total')),
      TextCellValue(getMarathi('Grade')),
    ]);

    bool hasData = false;
    final semesterWise = studentResult?['semesterWise'] ?? {};
    for (var sem in ['1', '2']) {
      if (semesterWise.containsKey(sem)) {
        final subjects = Map<String, dynamic>.from(semesterWise[sem]['subjects'] ?? {});
        for (var subjectEntry in subjects.entries) {
          final subjectData = subjectEntry.value;
          sheet.appendRow([
            TextCellValue(student['name']?.toString() ?? 'Unknown'),
            TextCellValue(student['enrollmentNo']?.toString() ?? '-'),
            TextCellValue('${getMarathi('Semester')} $sem'),
            TextCellValue(subjectIdToName[subjectEntry.key] ?? 'Unknown'),
            TextCellValue(subjectData['formativeAssesment']?.toString() ?? '-'),
            TextCellValue(subjectData['summativeAssesment']?.toString() ?? '-'),
            TextCellValue(subjectData['total']?.toString() ?? '-'),
            TextCellValue(subjectData['grade']?.toString() ?? '-'),
          ]);
          hasData = true;
        }
      }
    }

    if (!hasData) return null;
    return Uint8List.fromList(await excel.encode() ?? []);
  }

  Future<void> _exportToExcel(Student student) async {
    if (studentResult == null || studentResult!['semesterWise'].isEmpty) {
      _showError('निकाल डेटा उपलब्ध नाही');
      return;
    }
    if (!await _requestStoragePermission()) return;

    setState(() => isLoading = true);
    try {
      final fileBytes = await _generateExcelForStudent(student, 'निकाल_${student.name ?? 'Student'}');
      if (fileBytes == null) throw Exception('एक्सेल फाइल तयार करण्यात अयशस्वी');

      final fileName = 'निकाल_${student.name ?? 'Student'}_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final result = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: fileBytes,
        ext: 'xlsx',
        mimeType: MimeType.custom,
        customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('एक्सेल फाइल डाउनलोड झाली'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError('एक्सेल निर्यात अयशस्वी: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<Uint8List?> _generateExcelForAllStudents(String subjectId, String sheetName) async {
    return compute(_generateExcelForAllStudentsInIsolate, {
      'subjectId': subjectId,
      'sheetName': sheetName,
      'studentResults': studentResults,
      'classStudents': classStudents,
      'subjectIdToName': subjectIdToName,
      'marathiTranslations': marathiTranslations,
    });
  }

  static Future<Uint8List?> _generateExcelForAllStudentsInIsolate(Map<String, dynamic> params) async {
    final subjectId = params['subjectId'] as String;
    final sheetName = params['sheetName'] as String;
    final studentResults = params['studentResults'] as Map<String, Map<String, dynamic>>;
    final classStudents = params['classStudents'] as Map<String, List<Student>>;
    final subjectIdToName = params['subjectIdToName'] as Map<String, String>;
    final marathiTranslations = params['marathiTranslations'] as Map<String, String>;

    final excel = Excel.createExcel();
    final sheet = excel[sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName];

    String getMarathi(String english) => marathiTranslations[english] ?? english;

    sheet.appendRow([TextCellValue('${getMarathi('Results for Subject')}: ${subjectIdToName[subjectId] ?? 'Unknown'}')]);
    sheet.appendRow([
      TextCellValue(getMarathi('Name')),
      TextCellValue(getMarathi('Enrollment ID')),
      TextCellValue(getMarathi('Semester')),
      TextCellValue(getMarathi('Formative')),
      TextCellValue(getMarathi('Summative')),
      TextCellValue(getMarathi('Total')),
      TextCellValue(getMarathi('Grade')),
    ]);

    bool hasData = false;
    for (var students in classStudents.values) {
      for (var student in students) {
        final semesterWise = studentResults[student.id.toString()]?['semesterWise'] ?? {};
        for (var sem in ['1', '2']) {
          if (semesterWise.containsKey(sem) && semesterWise[sem]['subjects']?.containsKey(subjectId) == true) {
            final subjectData = semesterWise[sem]['subjects'][subjectId];
            sheet.appendRow([
              TextCellValue(student.name?.toString() ?? 'Unknown'),
              TextCellValue(student.enrollmentNo?.toString() ?? '-'),
              TextCellValue('${getMarathi('Semester')} $sem'),
              TextCellValue(subjectData['formativeAssesment']?.toString() ?? '-'),
              TextCellValue(subjectData['summativeAssesment']?.toString() ?? '-'),
              TextCellValue(subjectData['total']?.toString() ?? '-'),
              TextCellValue(subjectData['grade']?.toString() ?? '-'),
            ]);
            hasData = true;
          }
        }
      }
    }

    if (!hasData) return null;
    return Uint8List.fromList(await excel.encode() ?? []);
  }

  Future<void> _exportAllStudentsResults(String subjectId) async {
    if (subjectId.isEmpty) {
      _showError('विषय निवडा');
      return;
    }
    if (!await _requestStoragePermission()) return;

    setState(() => isLoading = true);
    try {
      studentResults.clear();
      for (var classModel in classes) {
        final students = classStudents[classModel.id.toString()] ?? [];
        for (var student in students) {
          final result = await _apiService.getFinalResultByStudentId(student.id.toString());
          if (result['success'] == true) {
            studentResults[student.id.toString()] = Map<String, dynamic>.from(result['data']?['semesterWise'] ?? {})
                .map((sem, data) => MapEntry(sem, {
                      'subjects': Map<String, dynamic>.from(data['subjects'] ?? {})
                          .entries
                          .where((e) => e.key == subjectId)
                          .fold({}, (map, e) => map..[e.key] = e.value),
                    }));
          }
        }
      }

      if (studentResults.values.every((result) => result.isEmpty)) {
        _showError('विषय ${subjectIdToName[subjectId] ?? 'Unknown'} साठी निकाल उपलब्ध नाहीत');
        setState(() => isLoading = false);
        return;
      }

      final fileBytes = await _generateExcelForAllStudents(subjectId, 'निकाल_${subjectIdToName[subjectId] ?? 'Subject'}');
      if (fileBytes == null) throw Exception('एक्सेल फाइल तयार करण्यात अयशस्वी');

      final fileName = 'निकाल_${subjectIdToName[subjectId] ?? 'Subject'}_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final result = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: fileBytes,
        ext: 'xlsx',
        mimeType: MimeType.custom,
        customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('एक्सेल फाइल डाउनलोड झाली'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError('निकाल निर्यात अयशस्वी: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _editStudentResult(String subjectId, String semester, Map<String, dynamic> subjectData) {
    if (selectedStudent == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignMarkPage(
          subjectId: subjectId,
          subjectName: subjectIdToName[subjectId] ?? 'Unknown',
          studentId: selectedStudent!.id.toString(),
          existingResult: {'subjects': {subjectId: subjectData}},
          semester: semester,
        ),
      ),
    ).then((_) => _loadStudentResult(selectedStudent!));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('क्लर्क निकाल अहवाल'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null && selectedStudent != null
              ? Center(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {
                              selectedStudent = null;
                              studentResult = null;
                              errorMessage = null;
                            }),
                            child: const Text('परत'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : classes.isEmpty || subjectIds.isEmpty
                  ? const Center(child: Text('कोणतेही वर्ग किंवा विषय नाहीत'))
                  : Column(
                      children: [
                        if (selectedStudent == null && subjectIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: selectedSubjectId,
                                    items: subjectIds
                                        .map((id) => DropdownMenuItem(value: id, child: Text(subjectIdToName[id] ?? 'Unknown')))
                                        .toList(),
                                    onChanged: (value) => setState(() => selectedSubjectId = value),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: selectedSubjectId != null ? () => _exportAllStudentsResults(selectedSubjectId!) : null,
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: selectedStudent == null
                              ? ListView.builder(
                                  itemCount: classes.length,
                                  itemBuilder: (context, index) {
                                    final classItem = classes[index];
                                    final students = classStudents[classItem.id.toString()] ?? [];
                                    return Card(
                                      margin: const EdgeInsets.all(8),
                                      child: ExpansionTile(
                                        title: Text('वर्ग ${classItem.name}'),
                                        subtitle: Text('${students.length} विद्यार्थी'),
                                        children: students
                                            .map((student) => ListTile(
                                                  title: Text(student.name ?? 'अज्ञात'),
                                                  subtitle: Text('रोल: ${student.rollNo ?? 'N/A'}'),
                                                  trailing: IconButton(
                                                    icon: const Icon(Icons.visibility),
                                                    onPressed: () => _loadStudentResult(student),
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    );
                                  },
                                )
                              : ListView(
                                  padding: const EdgeInsets.all(8),
                                  children: [
                                    Card(
                                      child: ListTile(
                                        title: Text(selectedStudent!.name ?? 'अज्ञात'),
                                        subtitle: Text('आयडी: ${selectedStudent!.enrollmentNo ?? '-'}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.arrow_back),
                                          onPressed: () => setState(() {
                                            selectedStudent = null;
                                            studentResult = null;
                                          }),
                                        ),
                                      ),
                                    ),
                                    if (studentResult == null || studentResult!['semesterWise'].isEmpty)
                                      const Card(child: ListTile(title: Text('निकाल उपलब्ध नाही')))
                                    else
                                      Card(
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('सत्र')),
                                            DataColumn(label: Text('विषय')),
                                            DataColumn(label: Text('रचनात्मक')),
                                            DataColumn(label: Text('संक्षेपात्मक')),
                                            DataColumn(label: Text('एकूण')),
                                            DataColumn(label: Text('श्रेणी')),
                                            DataColumn(label: Text('क्रिया')),
                                          ],
                                          rows: Map<String, dynamic>.from(studentResult!['semesterWise'])
                                              .entries
                                              .expand((entry) => (entry.value['subjects'] as Map<String, dynamic>)
                                                  .entries
                                                  .map((s) => DataRow(cells: [
                                                        DataCell(Text('सत्र ${entry.key}')),
                                                        DataCell(Text(subjectIdToName[s.key] ?? '-')),
                                                        DataCell(Text(s.value['formativeAssesment']?.toString() ?? '-')),
                                                        DataCell(Text(s.value['summativeAssesment']?.toString() ?? '-')),
                                                        DataCell(Text(s.value['total']?.toString() ?? '-')),
                                                        DataCell(Text(s.value['grade']?.toString() ?? '-')),
                                                        DataCell(IconButton(
                                                          icon: const Icon(Icons.edit),
                                                          onPressed: () => _editStudentResult(s.key, entry.key, s.value),
                                                        )),
                                                      ])))
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
      floatingActionButton: selectedStudent != null && studentResult != null && studentResult!['semesterWise'].isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _exportToExcel(selectedStudent!),
              child: const Icon(Icons.download),
            )
          : null,
    );
  }
}