import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:developer' as developer;
import '../services/api_client.dart';
import '../../model/result_model.dart';
import '../../model/student_model.dart';
import '../../model/subject_model.dart';

class ResultReportScreen extends StatefulWidget {
  static const routeName = '/resultReport';
  const ResultReportScreen({super.key});

  @override
  _ResultReportScreenState createState() => _ResultReportScreenState();
}

class _ResultReportScreenState extends State<ResultReportScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> results = [];
  bool isLoading = true;
  String? errorMessage;
  String? teacherId;
  List<dynamic> assignedSubjects = [];
  List<dynamic> assignedClasses = [];
  List<dynamic> students = [];

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
        setState(() {
          errorMessage = 'User not logged in';
          isLoading = false;
        });
        return;
      }

      final schoolId = await _apiService.getCurrentSchoolId();
      if (schoolId == null) {
        setState(() {
          errorMessage = 'School ID not found. Please login again.';
          isLoading = false;
        });
        return;
      }

      final subjectsResponse = await _apiService.getAllSubjects(schoolId: schoolId);
      if (subjectsResponse['success'] && subjectsResponse['data'] != null) {
        assignedSubjects = subjectsResponse['data']
            .where((sub) => sub['teacherId']?.toString() == teacherId)
            .toList();
      } else {
        setState(() {
          errorMessage = 'Failed to load assigned subjects';
          isLoading = false;
        });
        return;
      }

      final classesResponse = await _apiService.getClassesByTeacherId(teacherId!);
      if (classesResponse['success'] && classesResponse['data'] != null) {
        assignedClasses = classesResponse['data'];
        final allStudentsResponse = await _apiService.getAllStudents();
        if (allStudentsResponse['success'] && allStudentsResponse['data'] != null) {
          final allStudents = allStudentsResponse['data'] as List<dynamic>;
          final classIds = assignedClasses.map((c) => c['id'].toString()).toSet();
          students = allStudents.where((student) => classIds.contains(student['classId']?.toString())).toList();
        } else {
          setState(() {
            errorMessage = 'Failed to load students';
            isLoading = false;
          });
          return;
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load assigned classes';
          isLoading = false;
        });
        return;
      }

      results = [];
      for (var student in students) {
        final studentId = student['id'].toString();
        try {
          final resultResponse = await _apiService.getOverallResult(studentId);
          if (resultResponse['success'] && resultResponse['data'] != null) {
            final result = resultResponse['data'];
            result['studentName'] = student['name']; // attach name
            if (_isResultForAssignedSubjects(result)) {
              results.add(result);
            }
          }
        } catch (e) {
          developer.log('No result found for student $studentId: $e', name: 'ResultReportScreen');
        }
      }

      if (results.isEmpty) {
        setState(() {
          errorMessage = 'No results found for your assigned subjects';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  bool _isResultForAssignedSubjects(Map<String, dynamic> result) {
    final assignedSubjectIds = assignedSubjects.map((s) => s['id'].toString()).toSet();
    final resultSubjectIds = (result['subjectDetails'] as List<dynamic>? ?? []).map((sd) => sd['subjectId'].toString()).toSet();
    return resultSubjectIds.any((id) => assignedSubjectIds.contains(id));
  }

  CellValue _cell(dynamic v) {
    if (v == null) return TextCellValue('');
    if (v is num) return DoubleCellValue(v.toDouble());
    return TextCellValue(v.toString());
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Results'];

    sheet.appendRow([
      TextCellValue('Student Name'),
      TextCellValue('Grade'),
      TextCellValue('Percentage'),
      TextCellValue('Special Progress'),
      TextCellValue('Hobbies'),
      TextCellValue('Areas of Improvement'),
    ]);

    for (var result in results) {
      sheet.appendRow([
        _cell(result['studentName'] ?? result['studentId']),
        _cell(result['grandGrade']),
        _cell(result['grandPercentage']),
        _cell(result['semesterWise']?['1']?['specialProgress'] ?? result['semesterWise']?['2']?['specialProgress']),
        _cell(result['semesterWise']?['1']?['hobbies'] ?? result['semesterWise']?['2']?['hobbies']),
        _cell(result['semesterWise']?['1']?['areasOfImprovement'] ?? result['semesterWise']?['2']?['areasOfImprovement']),
      ]);
    }

    // Save to documents & downloads
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/results_report.xlsx")
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    // Try saving to Downloads too
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final dlFile = File("${downloads.path}/results_report.xlsx")
          ..createSync(recursive: true)
          ..writeAsBytesSync(excel.encode()!);
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Report saved and ready to share')),
      );
    }

    await Share.shareXFiles([XFile(file.path)], text: 'Results Report');
  }

  Widget _buildAssessmentTile(Map<String, dynamic> resultData, String semester) {
    final Map<String, dynamic> subjects = (semester == '1'
        ? (resultData['semesterWise']?['1']?['subjects'] as Map<String, dynamic>?)
        : (resultData['semesterWise']?['2']?['subjects'] as Map<String, dynamic>?)) ?? {};

    return ExpansionTile(
      title: Text('Semester $semester Subjects'),
      children: subjects.entries
          .where((entry) => assignedSubjects.any((s) => s['id'].toString() == entry.key))
          .map((entry) {
            final subjectDetails = entry.value as Map<String, dynamic>;
            final subjectName = assignedSubjects.firstWhere(
              (s) => s['id'].toString() == entry.key,
              orElse: () => {'name': 'Unknown'},
            )['name'] as String;
            return Card(
              color: Colors.grey.shade50,
              child: ExpansionTile(
                title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Total: ${subjectDetails['total']?.toStringAsFixed(2) ?? 'N/A'} | Grade: ${subjectDetails['grade'] ?? 'N/A'}',
                ),
                children: [
                  _buildAssessmentDetails(subjectDetails['formativeAssesment'], 'Formative Assessment'),
                  _buildAssessmentDetails(subjectDetails['summativeAssesment'], 'Summative Assessment'),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildAssessmentDetails(dynamic assessment, String title) {
    if (assessment is Map<String, dynamic>) {
      double total = assessment.values.fold(0.0, (sum, value) => sum + (value as num));
      return ExpansionTile(
        title: Text(title),
        subtitle: Text('Total: ${total.toStringAsFixed(2)}'),
        children: assessment.entries.map((e) => ListTile(
          title: Text(e.key),
          subtitle: Text(e.value.toString()),
        )).toList(),
      );
    } else {
      return ListTile(
        title: Text(title),
        subtitle: Text('Total: ${assessment?.toStringAsFixed(2) ?? 'N/A'}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Reports'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : results.isEmpty
                  ? const Center(child: Text('No results available for your subjects', style: TextStyle(fontSize: 16)))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ExpansionTile(
                              title: Text(
                                result['studentName'] ?? 'Student',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                'Overall Grade: ${result['grandGrade']} | Overall Percentage: ${result['grandPercentage'].toStringAsFixed(2)}%',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildAssessmentTile(result, '1'),
                                      _buildAssessmentTile(result, '2'),
                                      const SizedBox(height: 8),
                                      Text('Special Progress: ${result['semesterWise']?['1']?['specialProgress'] ?? result['semesterWise']?['2']?['specialProgress'] ?? 'N/A'}', style: const TextStyle(fontSize: 14)),
                                      Text('Hobbies: ${result['semesterWise']?['1']?['hobbies'] ?? result['semesterWise']?['2']?['hobbies'] ?? 'N/A'}', style: const TextStyle(fontSize: 14)),
                                      Text('Areas of Improvement: ${result['semesterWise']?['1']?['areasOfImprovement'] ?? result['semesterWise']?['2']?['areasOfImprovement'] ?? 'N/A'}', style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: results.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.download),
              label: const Text('Export Excel'),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
    );
  }
}
