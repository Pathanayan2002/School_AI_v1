// attendence_recore.dart (corrected: use 'month' instead of 'date' for filtering, string comparison)

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:csv/csv.dart';
import 'package:universal_io/io.dart' show File;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_client.dart'; // Ensure this import matches your project structure

class StudentAttendanceRecordScreen extends StatefulWidget {
  final String subjectId; // Subject ID to filter students
  final String schoolId; // School ID to filter classes and subjects
  const StudentAttendanceRecordScreen({
    super.key,
    required this.subjectId,
    required this.schoolId,
  });

  @override
  State<StudentAttendanceRecordScreen> createState() => _StudentAttendanceRecordScreenState();
}

class _StudentAttendanceRecordScreenState extends State<StudentAttendanceRecordScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> filteredStudents = [];
  Map<String, List<Map<String, dynamic>>> attendanceRecords = {};
  DateTime selectedMonth = DateTime.now();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudentsAndAttendance();
  }

  // Load students and their attendance records
  Future<void> _loadStudentsAndAttendance() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Get current teacher's ID
      final teacherId = await _apiService.getCurrentUserId();
      debugPrint('Teacher ID: $teacherId');
      if (teacherId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Teacher ID not found. Please log in again.")),
        );
        Navigator.pushReplacementNamed(context, '/login'); // Adjust route as per your app
        return;
      }

      // Fetch students for the specific subject
      final response = await _apiService.getStudentsBySubject(widget.subjectId);
      debugPrint('getStudentsBySubject response: ${response.toString()}');

      if (response['success'] == true && response['data'] is List) {
        filteredStudents = List<Map<String, dynamic>>.from(response['data'])
            .where((student) => student['schoolId'] == widget.schoolId)
            .toList();

        // Fetch attendance records for each student
        for (var student in filteredStudents) {
          final studentId = student['id'].toString();
          final attendanceResponse = await _apiService.getAttendanceByStudentId(studentId);
          debugPrint('Attendance for student $studentId: ${attendanceResponse.toString()}');
          if (attendanceResponse['success'] == true && attendanceResponse['data'] is List) {
            final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);
            attendanceRecords[studentId] = List<Map<String, dynamic>>.from(attendanceResponse['data'])
                .where((record) => record['month'] == monthStr)
                .toList();
          }
        }

        setState(() {
          isLoading = false;
        });

        if (filteredStudents.isEmpty) {
          debugPrint('No students found for subject ${widget.subjectId} in school ${widget.schoolId}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No students found for this subject in your school.")),
          );
        }
      } else {
        debugPrint('Failed to load students: ${response['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? "Failed to load students")),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading students or attendance: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading data: $e")),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  // Open month picker to select a different month
  void _selectMonth(BuildContext context) {
    showMonthPicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: selectedMonth,
    ).then((pickedMonth) {
      if (pickedMonth != null) {
        setState(() {
          selectedMonth = pickedMonth;
        });
        _loadStudentsAndAttendance(); // Reload attendance for the new month
      }
    });
  }

  // Export attendance records as CSV
  Future<void> _exportToCsv() async {
    try {
      // Request storage permission (for non-web platforms)
      if (!kIsWeb) {
        var status = await Permission.storage.request();
        if (status != PermissionStatus.granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Storage permission denied. Cannot export CSV.")),
          );
          return;
        }
      }

      // Prepare CSV data
      List<List<dynamic>> csvData = [
        ['Student ID', 'Student Name', 'Month', 'Total Days', 'Present Days', 'Attendance Percentage'],
      ];

      for (var student in filteredStudents) {
        final studentId = student['id'].toString();
        final studentName = student['name'] ?? 'Unknown';
        final records = attendanceRecords[studentId] ?? [];
        
        for (var record in records) {
          final totalDays = record['totalDays'] ?? 0;
          final presentDays = record['presentDays'] ?? 0;
          final percentage = totalDays > 0 ? ((presentDays / totalDays) * 100).toStringAsFixed(2) : '0.00';
          
          csvData.add([
            studentId,
            studentName,
            DateFormat('MMMM yyyy').format(selectedMonth),
            totalDays,
            presentDays,
            '$percentage%',
          ]);
        }
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(csvData);

      // Save or share the CSV file
      if (kIsWeb) {
        // For web, use share_plus to trigger download
        final bytes = utf8.encode(csv);
        final file = XFile.fromData(Uint8List.fromList(bytes), mimeType: 'text/csv', name: 'attendance_${DateFormat('yyyyMM').format(selectedMonth)}.csv');
        await Share.shareXFiles([file], text: 'Attendance Records for ${DateFormat('MMMM yyyy').format(selectedMonth)}');
      } else {
        // For mobile, save to device and share
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/attendance_${DateFormat('yyyyMM').format(selectedMonth)}.csv';
        final file = File(path);
        await file.writeAsString(csv);
        
        await Share.shareXFiles([XFile(path)], text: 'Attendance Records for ${DateFormat('MMMM yyyy').format(selectedMonth)}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance records exported successfully")),
      );
    } catch (e, stackTrace) {
      debugPrint('Error exporting CSV: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error exporting CSV: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Records', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () => _selectMonth(context),
            tooltip: 'Select Month',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportToCsv,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance for ${DateFormat('MMMM yyyy').format(selectedMonth)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                    ? const Center(child: Text("No attendance records found for this subject and month"))
                    : Expanded(
                        child: ListView.builder(
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            final studentId = student['id'].toString();
                            final studentName = student['name'] ?? 'Unknown';
                            final records = attendanceRecords[studentId] ?? [];

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ExpansionTile(
                                title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("ID: $studentId"),
                                children: records.isEmpty
                                    ? [const ListTile(title: Text("No attendance records for this month"))]
                                    : records.map((record) {
                                        final totalDays = record['totalDays'] ?? 0;
                                        final presentDays = record['presentDays'] ?? 0;
                                        final percentage = totalDays > 0
                                            ? ((presentDays / totalDays) * 100).toStringAsFixed(2)
                                            : '0.00';
                                        return ListTile(
                                          title: Text("Total Days: $totalDays, Present: $presentDays"),
                                          subtitle: Text("Attendance: $percentage%"),
                                        );
                                      }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}