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
import 'assign_marks.dart';

class ResultReportScreen extends StatefulWidget {
  static const routeName = '/resultReport';
  const ResultReportScreen({super.key});

  @override
  State<ResultReportScreen> createState() => _ResultReportScreenState();
}

class _ResultReportScreenState extends State<ResultReportScreen> {
  final ApiService _apiService = ApiService();

  List<ClassModel> classes = [];
  Map<String, List<Student>> classStudents = {};
  String? teacherId;
  bool isLoading = true;
  String? errorMessage;
  Student? selectedStudent;
  Map<String, dynamic>? studentResult;
  List<String> teacherSubjectIds = [];
  Map<String, String> subjectIdToName = {};
  String? selectedSubjectId;

  // Marathi translations for Excel
  final Map<String, String> marathiTranslations = {
    'Student Result Report': 'विद्यार्थ्यांचा निकाल अहवाल',
    'Student Information': 'विद्यार्थी माहिती',
    'Name': 'नाव',
    'Enrollment ID': 'नावनोंदणी आयडी',
    'Semester-wise Performance': 'सत्रनिहाय कामगिरी',
    'Semester': 'सत्र',
    'Total Marks': 'एकूण गुण',
    'Percentage': 'टक्केवारी',
    'Grade': 'श्रेणी',
    'Hobbies': 'छंद',
    'Special Progress': 'विशेष प्रगती',
    'Areas of Improvement': 'सुधारणेची क्षेत्रे',
    'Subject Details': 'विषय तपशील',
    'Subject ID': 'विषय आयडी',
    'Subject Name': 'विषयाचे नाव',
    'Formative': 'रचनात्मक',
    'Summative': 'संक्षेपात्मक',
    'Total': 'एकूण',
    'Subject Summary (Combined Semesters)': 'विषय सारांश (एकत्रित सत्रे)',
    'Sem1': 'सत्र १',
    'Sem2': 'सत्र २',
    'Avg': 'सरासरी',
    'Overall Summary': 'एकूण सारांश',
    'Grand Total': 'महा एकूण',
    'Class': 'वर्ग',
    'Student Name': 'विद्यार्थ्याचे नाव',
    'Results for Subject': 'विषयासाठी निकाल',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      teacherId = await _apiService.getCurrentUserId();
      if (teacherId == null) {
        throw Exception('प्रयोक्ता लॉग इन नाही आहे');
      }

      final subjectsResponse = await _apiService.getAllSubjects(schoolId: '');
      if (subjectsResponse['success'] != true || subjectsResponse['data'] == null) {
        throw Exception(subjectsResponse['message'] ?? 'विषय लोड करण्यात अयशस्वी');
      }
      final subjectList = subjectsResponse['data'] as List<dynamic>;
      teacherSubjectIds = subjectList
          .where((subject) => subject['teacherId']?.toString() == teacherId)
          .map((subject) => subject['id'].toString())
          .toList();
      subjectIdToName = {
        for (var subject in subjectList.where((subject) => subject['teacherId']?.toString() == teacherId))
          subject['id'].toString(): subject['name'].toString(),
      };
      developer.log('Teacher $teacherId assigned subjects: $teacherSubjectIds', name: 'ResultReportScreen');

      if (teacherSubjectIds.isEmpty) {
        errorMessage = 'या शिक्षकाला कोणतेही विषय नियुक्त केलेले नाहीत';
      } else {
        selectedSubjectId = teacherSubjectIds.first; // Default to first subject
      }

      final classesResponse = await _apiService.getClassesByTeacherId(teacherId!);
      if (classesResponse['success'] != true || classesResponse['data'] == null) {
        throw Exception(classesResponse['message'] ?? 'वर्ग लोड करण्यात अयशस्वी');
      }

      final classList = classesResponse['data'] as List<dynamic>;
      classes.clear();
      classStudents.clear();

      for (var classJson in classList) {
        final classModel = ClassModel.fromJson(classJson);
        final studentList = (classJson['students'] as List<dynamic>?)?.map((s) => Student.fromJson(s)).toList() ?? [];
        classes.add(classModel);
        classStudents[classModel.id] = studentList;
      }

      if (classes.isEmpty) {
        errorMessage = 'या शिक्षकाला कोणतेही वर्ग नियुक्त केलेले नाहीत';
      }
    } catch (e) {
      errorMessage = 'डेटा लोड करण्यात त्रुटी: $e';
      developer.log('Error in _loadData: $e', name: 'ResultReportScreen');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadStudentResult(Student student) async {
    setState(() {
      isLoading = true;
      selectedStudent = student;
      studentResult = null;
      errorMessage = null;
    });

    try {
      final result = await _apiService.getFinalResultByStudentId(student.id.toString());
      developer.log('API Response for student ${student.id}: $result', name: 'ResultReportScreen');

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'निकाल प्राप्त करण्यात अयशस्वी');
      }

      final semesterWise = Map<String, dynamic>.from(result['data']['semesterWise'] ?? {});
      final filteredSemesterWise = <String, dynamic>{};

      for (var sem in ['1', '2']) {
        if (semesterWise.containsKey(sem)) {
          final subjects = Map<String, dynamic>.from(semesterWise[sem]['subjects'] ?? {});
          final filteredSubjects = subjects
              .entries
              .where((entry) => teacherSubjectIds.contains(entry.key))
              .fold<Map<String, dynamic>>({}, (map, entry) {
                map[entry.key] = entry.value;
                return map;
              });

          if (filteredSubjects.isNotEmpty) {
            final totalMarks = filteredSubjects.values.fold<double>(
                0, (sum, subject) => sum + (subject['total'] ?? 0));
            filteredSemesterWise[sem] = {
              ...semesterWise[sem],
              'subjects': filteredSubjects,
              'totalMarks': totalMarks,
              'percentage': totalMarks > 0 ? (totalMarks / (filteredSubjects.length * 100)) * 100 : 0,
              'grade': _calculateGrade(totalMarks > 0 ? (totalMarks / (filteredSubjects.length * 100)) * 100 : 0),
            };
          }
        }
      }

      final filteredResult = {
        'semesterWise': filteredSemesterWise,
        'subjectDetails': List<Map<String, dynamic>>.from(result['data']['subjectDetails'] ?? [])
            .where((s) => teacherSubjectIds.contains(s['subjectId']?.toString()))
            .toList(),
        'grandTotal': filteredSemesterWise.values.fold<double>(0, (sum, sem) => sum + (sem['totalMarks'] ?? 0)),
        'grandPercentage': filteredSemesterWise.isNotEmpty
            ? (filteredSemesterWise.values.fold<double>(0, (sum, sem) => sum + (sem['totalMarks'] ?? 0)) /
                    (filteredSemesterWise.values.fold<int>(0, (sum, sem) => sum + (sem['subjects'].length as int)) * 100)) *
                100
            : 0,
        'grandGrade': _calculateGrade(filteredSemesterWise.isNotEmpty
            ? (filteredSemesterWise.values.fold<double>(0, (sum, sem) => sum + (sem['totalMarks'] ?? 0)) /
                (filteredSemesterWise.values.fold<int>(0, (sum, sem) => sum + (sem['subjects'].length as int)) * 100)) *
                100
            : 0),
      };

      setState(() {
        studentResult = filteredResult;
      });

      if (filteredSemesterWise.isEmpty) {
        _showError('${student.name ?? 'अज्ञात'} साठी या शिक्षकाद्वारे शिकवलेल्या विषयांमध्ये निकाल उपलब्ध नाहीत');
      }
    } catch (e) {
      final errorMsg = '${student.name ?? 'अज्ञात'} साठी निकाल प्राप्त करण्यात अयशस्वी: $e';
      _showError(errorMsg);
      setState(() {
        errorMessage = errorMsg;
      });
      developer.log(errorMsg, name: 'ResultReportScreen', error: e);
    } finally {
      setState(() {
        isLoading = false;
      });
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

  Future<bool> _showPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('डाउनलोडसाठी स्टोरेज परवानगी'),
        content: const Text(
          'निकाल अहवाल एक्सेल फाइल म्हणून डाउनलोड करण्यासाठी स्टोरेज परवानगी आवश्यक आहे. कृपया परवानगी द्या किंवा सेटिंग्जमधून सक्षम करा.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('रद्द करा'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('परवानगी द्या'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) {
      developer.log('No storage permission needed for non-Android platform', name: 'ResultReportScreen');
      return true;
    }

    // Show permission explanation dialog
    if (!await _showPermissionDialog()) {
      _showError('परवानगी रद्द केली');
      developer.log('User cancelled permission dialog', name: 'ResultReportScreen');
      return false;
    }

    // Check Android version
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    developer.log('Android SDK: $sdkInt', name: 'ResultReportScreen');

    if (sdkInt < 30) {
      // Android 10 or below: Request legacy storage permissions
      final status = await Permission.storage.request();
      if (status.isGranted) {
        developer.log('Storage permission granted', name: 'ResultReportScreen');
        return true;
      }
      if (status.isPermanentlyDenied) {
        _showError('कृपया सेटिंग्जमधून स्टोरेज परवानगी सक्षम करा');
        developer.log('Storage permission permanently denied, opening settings', name: 'ResultReportScreen');
        await openAppSettings();
        return false;
      }
    } else if (sdkInt <= 33) {
      // Android 11-13: Request MANAGE_EXTERNAL_STORAGE
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        developer.log('Manage external storage permission granted', name: 'ResultReportScreen');
        return true;
      }
      if (status.isPermanentlyDenied) {
        _showError('कृपया सेटिंग्जमधून सर्व फाइल्स परवानगी सक्षम करा');
        developer.log('Manage external storage permanently denied, opening settings', name: 'ResultReportScreen');
        await openAppSettings();
        return false;
      }
    } else {
      // Android 14+: Request media permissions
      final photoStatus = await Permission.photos.request();
      final videoStatus = await Permission.videos.request();
      final audioStatus = await Permission.audio.request();
      if (photoStatus.isGranted && videoStatus.isGranted && audioStatus.isGranted) {
        developer.log('Media permissions granted', name: 'ResultReportScreen');
        return true;
      }
      if (photoStatus.isPermanentlyDenied || videoStatus.isPermanentlyDenied || audioStatus.isPermanentlyDenied) {
        _showError('कृपया सेटिंग्जमधून मीडियावर प्रवेश परवानगी सक्षम करा');
        developer.log('Media permissions permanently denied, opening settings', name: 'ResultReportScreen');
        await openAppSettings();
        return false;
      }
    }

    _showError('स्टोरेज परवानगी नाकारली');
    developer.log('Storage permission denied', name: 'ResultReportScreen');
    return false;
  }

  Future<Uint8List?> _generateExcelForStudent(Student student, String sheetName) async {
    return compute(_generateExcelForStudentInIsolate, {
      'student': {
        'id': student.id,
        'name': student.name,
        'enrollmentNo': student.enrollmentNo,
      },
      'studentResult': studentResult,
      'sheetName': sheetName,
      'classStudents': {
        for (var classId in classStudents.keys)
          classId: classStudents[classId]!.map((s) => {
                'id': s.id,
                'name': s.name,
                'enrollmentNo': s.enrollmentNo,
              }).toList(),
      },
      'classes': classes.map((c) => {'id': c.id, 'name': c.name, 'divisions': c.divisions}).toList(),
      'subjectIdToName': subjectIdToName,
      'teacherSubjectIds': teacherSubjectIds,
      'marathiTranslations': marathiTranslations,
    });
  }

  static Future<Uint8List?> _generateExcelForStudentInIsolate(Map<String, Object?> params) async {
    final student = params['student'] as Map<String, dynamic>;
    final studentResult = params['studentResult'] as Map<String, dynamic>?;
    final sheetName = params['sheetName'] as String;
    final classStudents = params['classStudents'] as Map<String, List<Map<String, dynamic>>>;
    final classes = params['classes'] as List<Map<String, dynamic>>;
    final subjectIdToName = params['subjectIdToName'] as Map<String, String>;
    final teacherSubjectIds = params['teacherSubjectIds'] as List<String>;
    final marathiTranslations = params['marathiTranslations'] as Map<String, String>;

    try {
      final excel = Excel.createExcel();
      final sheet = excel[sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName];

      // Helper function to get Marathi text
      String getMarathi(String english) => marathiTranslations[english] ?? english;

      // Find the class for the selected student
      String className = 'Unknown';
      for (var classModel in classes) {
        if (classStudents[classModel['id']]?.any((s) => s['id'] == student['id']) ?? false) {
          className = classModel['name'] +
              (classModel['divisions'] != null && classModel['divisions'].isNotEmpty
                  ? " (${classModel['divisions'].join(", ")})"
                  : "");
          break;
        }
      }

      // Title (use first subject name for context, or default to 'Unknown')
      final subjectName = subjectIdToName[teacherSubjectIds.isNotEmpty ? teacherSubjectIds.first : ''] ?? 'Unknown';
      sheet.appendRow([TextCellValue('${getMarathi('Results for Subject')}: $subjectName')]);
      sheet.appendRow([TextCellValue('')]);

      // Table headers
      sheet.appendRow([
        TextCellValue(getMarathi('Class')),
        TextCellValue(getMarathi('Student Name')),
        TextCellValue(getMarathi('Enrollment ID')),
        TextCellValue(getMarathi('Semester')),
        TextCellValue(getMarathi('Formative')),
        TextCellValue(getMarathi('Summative')),
        TextCellValue(getMarathi('Total')),
        TextCellValue(getMarathi('Grade')),
        TextCellValue(getMarathi('Hobbies')),
        TextCellValue(getMarathi('Special Progress')),
        TextCellValue(getMarathi('Areas of Improvement')),
      ]);

      // Table data
      bool hasData = false;
      final semesterWise = Map<String, dynamic>.from(studentResult?['semesterWise'] ?? {});
      for (var sem in ['1', '2']) {
        if (semesterWise.containsKey(sem)) {
          final subjects = Map<String, dynamic>.from(semesterWise[sem]['subjects'] ?? {});
          for (var subjectEntry in subjects.entries) {
            final subjectId = subjectEntry.key;
            final subjectData = subjectEntry.value;
            final total = (subjectData['total'] ?? 0).toDouble();
            final percentage = total > 0 ? (total / 100) * 100 : 0;
            final grade = percentage >= 90
                ? 'A+'
                : percentage >= 80
                    ? 'A'
                    : percentage >= 70
                        ? 'B'
                        : percentage >= 60
                            ? 'C'
                            : percentage >= 50
                                ? 'D'
                                : 'F';

            sheet.appendRow([
              TextCellValue(className),
              TextCellValue(student['name'] ?? 'Unknown'),
              TextCellValue(student['enrollmentNo'] ?? '-'),
              TextCellValue('${getMarathi('Semester')} $sem'),
              TextCellValue(subjectData['formativeAssesment']?.toString() ?? '-'),
              TextCellValue(subjectData['summativeAssesment']?.toString() ?? '-'),
              TextCellValue(subjectData['total']?.toString() ?? '-'),
              TextCellValue(grade),
              TextCellValue(semesterWise[sem]['hobbies']?.toString() ?? '-'),
              TextCellValue(semesterWise[sem]['specialProgress']?.toString() ?? '-'),
              TextCellValue(semesterWise[sem]['areasOfImprovement']?.toString() ?? '-'),
            ]);
            hasData = true;
          }
        }
      }

      if (!hasData) {
        developer.log('No data available for student ${student['id']} in Excel generation', name: 'ResultReportScreen');
        return null;
      }

      // Add empty row at the end
      sheet.appendRow([TextCellValue('')]);

      final fileBytes = await excel.encode();
      if (fileBytes == null) {
        developer.log('Excel encoding failed for student ${student['id']}', name: 'ResultReportScreen');
        return null;
      }
      return Uint8List.fromList(fileBytes);
    } catch (e) {
      developer.log('Error in _generateExcelForStudentInIsolate: $e', name: 'ResultReportScreen');
      return null;
    }
  }

  Future<void> _exportToExcel(Student student) async {
    if (studentResult == null || studentResult!['semesterWise'].isEmpty) {
      _showError('${student.name ?? 'अज्ञात'} साठी निर्यात करण्यासाठी निकाल डेटा उपलब्ध नाही');
      return;
    }

    if (!await _requestStoragePermission()) return;

    setState(() {
      isLoading = true;
    });

    try {
      developer.log('Generating Excel for student ${student.id}', name: 'ResultReportScreen');
      final fileBytes = await _generateExcelForStudent(student, 'निकाल_${student.name ?? 'Student'}');
      if (fileBytes == null) throw Exception('एक्सेल फाइल तयार करण्यात अयशस्वी');

      developer.log('Attempting to save file with FileSaver for student ${student.id}', name: 'ResultReportScreen');
      final fileName = 'निकाल_${student.name ?? 'Student'}_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final result = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: fileBytes,
        ext: 'xlsx',
        mimeType: MimeType.other,
        customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (result == null) {
        throw Exception('फाइल डाउनलोड रद्द केले गेले किंवा त्रुटी आली');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('एक्सेल फाइल यशस्वीरित्या डाउनलोड झाली: $result'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('एक्सेल फाइल डाउनलोड करण्यात अयशस्वी: $e');
      developer.log('Error exporting Excel for student ${student.id}: $e', name: 'ResultReportScreen');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Uint8List?> _generateExcelForAllStudents(String subjectId, String sheetName) async {
    return compute(_generateExcelForAllStudentsInIsolate, {
      'subjectId': subjectId,
      'sheetName': sheetName,
      'classes': classes.map((c) => {'id': c.id, 'name': c.name, 'divisions': c.divisions}).toList(),
      'classStudents': {
        for (var classId in classStudents.keys)
          classId: classStudents[classId]!.map((s) => {
                'id': s.id,
                'name': s.name,
                'enrollmentNo': s.enrollmentNo,
                'semesterWise': {}, // Will be populated in _exportAllStudentsResults
              }).toList(),
      },
      'subjectIdToName': subjectIdToName,
      'marathiTranslations': marathiTranslations,
    });
  }

  static Future<Uint8List?> _generateExcelForAllStudentsInIsolate(Map<String, Object?> params) async {
    final subjectId = params['subjectId'] as String;
    final sheetName = params['sheetName'] as String;
    final classes = params['classes'] as List<Map<String, dynamic>>;
    final classStudents = params['classStudents'] as Map<String, List<Map<String, dynamic>>>;
    final subjectIdToName = params['subjectIdToName'] as Map<String, String>;
    final marathiTranslations = params['marathiTranslations'] as Map<String, String>;

    try {
      final excel = Excel.createExcel();
      final sheet = excel[sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName];

      // Helper function to get Marathi text
      String getMarathi(String english) => marathiTranslations[english] ?? english;

      final subjectName = subjectIdToName[subjectId] ?? 'Unknown';
      sheet.appendRow([TextCellValue('${getMarathi('Results for Subject')}: $subjectName')]);
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue(getMarathi('Class')),
        TextCellValue(getMarathi('Student Name')),
        TextCellValue(getMarathi('Enrollment ID')),
        TextCellValue(getMarathi('Semester')),
        TextCellValue(getMarathi('Formative')),
        TextCellValue(getMarathi('Summative')),
        TextCellValue(getMarathi('Total')),
        TextCellValue(getMarathi('Grade')),
        TextCellValue(getMarathi('Hobbies')),
        TextCellValue(getMarathi('Special Progress')),
        TextCellValue(getMarathi('Areas of Improvement')),
      ]);

      bool hasData = false;
      int studentCount = 0;

      for (var classModel in classes) {
        final students = classStudents[classModel['id']] ?? [];
        studentCount += students.length;
        for (var student in students) {
          final semesterWise = student['semesterWise'] as Map<String, dynamic>? ?? {};
          for (var sem in ['1', '2']) {
            if (semesterWise.containsKey(sem)) {
              final subjects = Map<String, dynamic>.from(semesterWise[sem]['subjects'] ?? {});
              if (subjects.containsKey(subjectId)) {
                final subjectData = subjects[subjectId];
                final total = (subjectData['total'] ?? 0).toDouble();
                final percentage = total > 0 ? (total / 100) * 100 : 0;
                final grade = percentage >= 90
                    ? 'A+'
                    : percentage >= 80
                        ? 'A'
                        : percentage >= 70
                            ? 'B'
                            : percentage >= 60
                                ? 'C'
                                : percentage >= 50
                                    ? 'D'
                                    : 'F';

                sheet.appendRow([
                  TextCellValue(classModel['name'] +
                      (classModel['divisions'] != null && classModel['divisions'].isNotEmpty
                          ? " (${classModel['divisions'].join(", ")})"
                          : "")),
                  TextCellValue(student['name'] ?? 'Unknown'),
                  TextCellValue(student['enrollmentNo'] ?? '-'),
                  TextCellValue('${getMarathi('Semester')} $sem'),
                  TextCellValue(subjectData['formativeAssesment']?.toString() ?? '-'),
                  TextCellValue(subjectData['summativeAssesment']?.toString() ?? '-'),
                  TextCellValue(subjectData['total']?.toString() ?? '-'),
                  TextCellValue(grade),
                  TextCellValue(semesterWise[sem]['hobbies']?.toString() ?? '-'),
                  TextCellValue(semesterWise[sem]['specialProgress']?.toString() ?? '-'),
                  TextCellValue(semesterWise[sem]['areasOfImprovement']?.toString() ?? '-'),
                ]);
                hasData = true;
              }
            }
          }
        }
      }

      developer.log('Processed $studentCount students for subject $subjectId, hasData: $hasData', name: 'ResultReportScreen');

      if (!hasData) {
        developer.log('No data available for subject $subjectId in Excel generation', name: 'ResultReportScreen');
        return null;
      }

      sheet.appendRow([TextCellValue('')]);

      final fileBytes = await excel.encode();
      if (fileBytes == null) {
        developer.log('Excel encoding failed for subject $subjectId', name: 'ResultReportScreen');
        return null;
      }
      return Uint8List.fromList(fileBytes);
    } catch (e) {
      developer.log('Error in _generateExcelForAllStudentsInIsolate for subject $subjectId: $e', name: 'ResultReportScreen');
      return null;
    }
  }

  Future<void> _exportAllStudentsResults(String subjectId) async {
    if (subjectId.isEmpty) {
      _showError('कृपया एक विषय निवडा');
      return;
    }

    if (!await _requestStoragePermission()) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Pre-fetch results for all students to pass to isolate
      final Map<String, List<Map<String, dynamic>>> updatedClassStudents = {};
      for (var classModel in classes) {
        final students = classStudents[classModel.id] ?? [];
        final List<Map<String, dynamic>> studentData = [];
        for (var student in students) {
          developer.log('Fetching result for student ${student.id}', name: 'ResultReportScreen');
          final result = await _apiService.getFinalResultByStudentId(student.id.toString());
          if (result['success'] != true) {
            developer.log('Failed to fetch result for student ${student.id}: ${result['message']}', name: 'ResultReportScreen');
            continue;
          }
          final semesterWise = Map<String, dynamic>.from(result['data']['semesterWise'] ?? {});
          final filteredSemesterWise = <String, dynamic>{};
          for (var sem in ['1', '2']) {
            if (semesterWise.containsKey(sem)) {
              final subjects = Map<String, dynamic>.from(semesterWise[sem]['subjects'] ?? {});
              if (subjects.containsKey(subjectId)) {
                filteredSemesterWise[sem] = {
                  ...semesterWise[sem],
                  'subjects': {subjectId: {...subjects[subjectId], 'subjectName': subjectIdToName[subjectId]}},
                };
              }
            }
          }
          studentData.add({
            'id': student.id,
            'name': student.name,
            'enrollmentNo': student.enrollmentNo,
            'semesterWise': filteredSemesterWise,
          });
        }
        updatedClassStudents[classModel.id] = studentData;
      }

      if (updatedClassStudents.values.every((students) => students.every((s) => s['semesterWise'].isEmpty))) {
        _showError('विषय ${subjectIdToName[subjectId] ?? 'Unknown'} साठी निकाल उपलब्ध नाहीत');
        developer.log('No results available for subject $subjectId', name: 'ResultReportScreen');
        setState(() {
          isLoading = false;
        });
        return;
      }

      developer.log('Passing ${updatedClassStudents.values.fold(0, (sum, list) => sum + list.length)} students to isolate for subject $subjectId', name: 'ResultReportScreen');
      final fileBytes = await _generateExcelForAllStudents(subjectId, 'निकाल_${subjectIdToName[subjectId] ?? 'Subject'}');
      if (fileBytes == null) {
        throw Exception('एक्सेल फाइल तयार करण्यात अयशस्वी: डेटा उपलब्ध नाही किंवा एन्कोडिंग अयशस्वी');
      }

      developer.log('Attempting to save all students results file for subject $subjectId', name: 'ResultReportScreen');
      final fileName = 'निकाल_${subjectIdToName[subjectId] ?? 'Subject'}_सर्व_विद्यार्थी_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final result = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: fileBytes,
        ext: 'xlsx',
        mimeType: MimeType.other,
        customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (result == null) {
        throw Exception('फाइल डाउनलोड रद्द केले गेले किंवा त्रुटी आली');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('एक्सेल फाइल यशस्वीरित्या डाउनलोड झाली: $result'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('निकाल निर्यात करण्यात अयशस्वी: $e');
      developer.log('Error exporting all students results for subject $subjectId: $e', name: 'ResultReportScreen');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _editStudentResult(String subjectId, String semester, Map<String, dynamic> subjectData) {
    if (selectedStudent == null) {
      _showError('कोणताही विद्यार्थी निवडलेला नाही');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignMarkPage(
          subjectId: subjectId,
          subjectName: subjectIdToName[subjectId] ?? 'Unknown',
          studentId: selectedStudent!.id.toString(),
          existingResult: {
            'id': studentResult?['semesterWise'][semester]?['id'] ?? '',
            'subjects': {subjectId: subjectData},
            'specialProgress': studentResult?['semesterWise'][semester]?['specialProgress'] ?? '',
            'hobbies': studentResult?['semesterWise'][semester]?['hobbies'] ?? '',
            'areasOfImprovement': studentResult?['semesterWise'][semester]?['areasOfImprovement'] ?? '',
          },
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
        title: const Text(
          'निकाल अहवाल',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : errorMessage != null && selectedStudent != null
                ? Center(
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => setState(() {
                                selectedStudent = null;
                                studentResult = null;
                                errorMessage = null;
                              }),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('विद्यार्थी यादीकडे परत'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : classes.isEmpty || teacherSubjectIds.isEmpty
                    ? const Center(
                        child: Text(
                          'कोणतेही वर्ग किंवा विषय नियुक्त केलेले नाहीत',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          if (selectedStudent == null && teacherSubjectIds.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: selectedSubjectId,
                                          decoration: InputDecoration(
                                            labelText: 'विषय निवडा',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: teacherSubjectIds.map((id) {
                                            return DropdownMenuItem<String>(
                                              value: id,
                                              child: Text(subjectIdToName[id] ?? 'Unknown'),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedSubjectId = value;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton.icon(
                                        onPressed: selectedSubjectId != null ? () => _exportAllStudentsResults(selectedSubjectId!) : null,
                                        icon: const Icon(Icons.download),
                                        label: const Text('सर्व निर्यात'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade700,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Expanded(
                            child: selectedStudent == null
                                ? ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: classes.length,
                                    itemBuilder: (context, index) {
                                      final classItem = classes[index];
                                      final students = classStudents[classItem.id] ?? [];
                                      return AnimatedOpacity(
                                        opacity: 1.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: Card(
                                          margin: const EdgeInsets.symmetric(vertical: 8),
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: ExpansionTile(
                                            leading: Icon(Icons.class_, color: Colors.blue.shade700),
                                            title: Text(
                                              'वर्ग ${classItem.name}${classItem.divisions != null && classItem.divisions!.isNotEmpty ? " (${classItem.divisions!.join(", ")})" : ""}',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Text('${students.length} विद्यार्थी', style: TextStyle(color: Colors.grey.shade600)),
                                            children: students.isEmpty
                                                ? [
                                                    const ListTile(
                                                      title: Text(
                                                        'या वर्गात कोणतेही विद्यार्थी नाहीत',
                                                        style: TextStyle(color: Colors.grey),
                                                      ),
                                                    ),
                                                  ]
                                                : students.map((student) {
                                                    return ListTile(
                                                      leading: Icon(Icons.person, color: Colors.blue.shade400),
                                                      title: Text(student.name ?? 'अज्ञात'),
                                                      subtitle: Text('रोल नंबर: ${student.rollNo ?? 'N/A'}'),
                                                      trailing: IconButton(
                                                        icon: const Icon(Icons.visibility, color: Colors.blue),
                                                        onPressed: () => _loadStudentResult(student),
                                                      ),
                                                    );
                                                  }).toList(),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Card(
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'विद्यार्थ्यांचा निकाल अहवाल',
                                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.arrow_back, color: Colors.blue),
                                                  onPressed: () => setState(() {
                                                    selectedStudent = null;
                                                    studentResult = null;
                                                    errorMessage = null;
                                                  }),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Card(
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'विद्यार्थी माहिती',
                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                                ),
                                                const SizedBox(height: 8),
                                                Text('नाव: ${selectedStudent!.name ?? 'अज्ञात'}', style: const TextStyle(fontSize: 16)),
                                                Text('नावनोंदणी आयडी: ${selectedStudent!.enrollmentNo ?? '-'}', style: const TextStyle(fontSize: 16)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Card(
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'सर्व निकाल',
                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                                ),
                                                const SizedBox(height: 8),
                                                if (studentResult == null || studentResult!['semesterWise'].isEmpty)
                                                  const Text(
                                                    'या विद्यार्थ्यासाठी तुमच्या विषयांमध्ये निकाल उपलब्ध नाहीत',
                                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                                  )
                                                else
                                                  SingleChildScrollView(
                                                    scrollDirection: Axis.horizontal,
                                                    child: DataTable(
                                                      columnSpacing: 12,
                                                      columns: const [
                                                        DataColumn(label: Text('सत्र', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('विषय आयडी', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('विषयाचे नाव', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('रचनात्मक', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('संक्षेपात्मक', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('एकूण', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('श्रेणी', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('छंद', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('विशेष प्रगती', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('सुधारणेची क्षेत्रे', style: TextStyle(fontWeight: FontWeight.bold))),
                                                        DataColumn(label: Text('क्रिया', style: TextStyle(fontWeight: FontWeight.bold))),
                                                      ],
                                                      rows: [
                                                        ...Map<String, dynamic>.from(studentResult!['semesterWise']).entries.expand((entry) {
                                                          final sem = entry.key;
                                                          final data = entry.value;
                                                          final subjects = Map<String, dynamic>.from(data['subjects'] ?? {});
                                                          return subjects.entries.map((subjectEntry) {
                                                            final subjectId = subjectEntry.key;
                                                            final subjectData = subjectEntry.value;
                                                            return DataRow(cells: [
                                                              DataCell(Text('सत्र $sem')),
                                                              DataCell(Text(subjectId)),
                                                              DataCell(Text(subjectData['subjectName']?.toString() ?? '-')),
                                                              DataCell(Text(subjectData['formativeAssesment']?.toString() ?? '-')),
                                                              DataCell(Text(subjectData['summativeAssesment']?.toString() ?? '-')),
                                                              DataCell(Text(subjectData['total']?.toString() ?? '-')),
                                                              DataCell(Text(subjectData['grade']?.toString() ?? '-')),
                                                              DataCell(Text(data['hobbies']?.toString() ?? '-')),
                                                              DataCell(Text(data['specialProgress']?.toString() ?? '-')),
                                                              DataCell(Text(data['areasOfImprovement']?.toString() ?? '-')),
                                                              DataCell(
                                                                IconButton(
                                                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                                                  onPressed: () => _editStudentResult(subjectId, sem, subjectData),
                                                                ),
                                                              ),
                                                            ]);
                                                          });
                                                        }),
                                                        if (studentResult!['subjectDetails'].isNotEmpty)
                                                          ...List<Map<String, dynamic>>.from(studentResult!['subjectDetails']).map((s) {
                                                            final subjectId = s['subjectId']?.toString() ?? '-';
                                                            return DataRow(cells: [
                                                              DataCell(Text('एकत्रित')),
                                                              DataCell(Text(subjectId)),
                                                              DataCell(Text(subjectIdToName[subjectId] ?? '-')),
                                                              DataCell(Text('-')),
                                                              DataCell(Text('-')),
                                                              DataCell(Text(s['totalBothSem']?.toString() ?? '-')),
                                                              DataCell(Text(s['gradeBothSem']?.toString() ?? '-')),
                                                              DataCell(Text('-')),
                                                              DataCell(Text('-')),
                                                              DataCell(Text('-')),
                                                              DataCell(Text('-')),
                                                            ]);
                                                          }),
                                                        if (studentResult!['semesterWise'].isNotEmpty)
                                                          DataRow(cells: [
                                                            DataCell(Text('एकूण')),
                                                            DataCell(Text('-')),
                                                            DataCell(Text('-')),
                                                            DataCell(Text('-')),
                                                            DataCell(Text('-')),
                                                            DataCell(Text(studentResult!['grandTotal']?.toString() ?? 'N/A')),
                                                            DataCell(Text(studentResult!['grandGrade'] ?? 'N/A')),
                                                            DataCell(Text('-')),
                                                            DataCell(Text('-')),
                                                            DataCell(Text('-')),
                                                            DataCell(Text('-')),
                                                          ]),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
      ),
      floatingActionButton: selectedStudent != null && studentResult != null && studentResult!['semesterWise'].isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _exportToExcel(selectedStudent!),
              icon: const Icon(Icons.download),
              label: const Text('निर्यात'),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}