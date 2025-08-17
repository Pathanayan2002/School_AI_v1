// student_attendence.dart (corrected: take subjectId and schoolId, load students by subject, fix attendanceData to store per student per month total/present, submit per month, use Stateful dialog for live percentage, remove global totals)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../services/api_client.dart'; // Make sure this import is correct for your project

class StudentAttendanceScreen extends StatefulWidget {
  final String subjectId;
  final String schoolId;
  const StudentAttendanceScreen({
    super.key,
    required this.subjectId,
    required this.schoolId,
  });

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> allStudents = [];

  // For storing the attendance data: {studentId: {month: {'totalDays': int, 'presentDays': int}}}
  Map<int, Map<String, Map<String, int>>> attendanceData = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  // Method to load students from the API, filtered by subject
  Future<void> _loadStudents() async {
    final response = await _apiService.getStudentsBySubject(widget.subjectId);
    if (response['success'] == true && response['data'] is List) {
      setState(() {
        allStudents = List<Map<String, dynamic>>.from(response['data'])
            .where((student) => student['schoolId'] == widget.schoolId)
            .toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? "Failed to load students")),
      );
    }
  }

  // Method to open the month picker and show the dialog to input attendance data
  void _openAttendanceDialog(BuildContext context, int studentId, String studentName) {
    showMonthPicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    ).then((pickedMonth) {
      if (pickedMonth != null) {
        _showAttendanceInputDialog(context, studentId, studentName, pickedMonth);
      }
    });
  }

  // Method to show the dialog where users can input total school days and absent days
  void _showAttendanceInputDialog(BuildContext context, int studentId, String studentName, DateTime selectedMonth) {
    showDialog(
      context: context,
      builder: (context) => _AttendanceInputDialog(
        studentName: studentName,
        selectedMonth: selectedMonth,
        onSave: (totalDays, absentDays) {
          final presentDays = totalDays - absentDays;
          final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);
          setState(() {
            attendanceData.putIfAbsent(studentId, () => {});
            attendanceData[studentId]![monthStr] = {
              'totalDays': totalDays,
              'presentDays': presentDays,
            };
          });
        },
      ),
    );
  }

  // Method to submit the attendance for all students per month
  Future<void> submitAllAttendance() async {
    if (attendanceData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No attendance recorded.")),
      );
      return;
    }

    bool allSuccess = true;
    for (var studentEntry in attendanceData.entries) {
      final studentId = studentEntry.key;
      final monthsData = studentEntry.value;

      for (var monthEntry in monthsData.entries) {
        final month = monthEntry.key;
        final data = monthEntry.value;
        final totalDays = data['totalDays']!;
        final presentDays = data['presentDays']!;

        final res = await _apiService.createAttendance(
          studentId: studentId.toString(),
          month: month,
          totalDays: totalDays,
          presentDays: presentDays,
          status: '', date: '',
        );

        if (res['success'] != true) {
          allSuccess = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed for ID: $studentId, Month: $month")),
          );
        }
      }
    }

    if (allSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance submitted successfully")),
      );
      setState(() {
        attendanceData.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Attendance', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: allStudents.length,
                itemBuilder: (context, index) {
                  final student = allStudents[index];
                  final int studentId = student['id'];
                  final String studentName = student['name'];

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      title: Text(studentName),
                      subtitle: Text("ID: $studentId"),
                      onTap: () => _openAttendanceDialog(context, studentId, studentName),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: submitAllAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Submit All Attendance", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceInputDialog extends StatefulWidget {
  final String studentName;
  final DateTime selectedMonth;
  final Function(int totalDays, int absentDays) onSave;

  const _AttendanceInputDialog({
    required this.studentName,
    required this.selectedMonth,
    required this.onSave,
  });

  @override
  _AttendanceInputDialogState createState() => _AttendanceInputDialogState();
}

class _AttendanceInputDialogState extends State<_AttendanceInputDialog> {
  final TextEditingController totalDaysController = TextEditingController();
  final TextEditingController absentDaysController = TextEditingController();
  double attendancePercentage = 0.0;

  @override
  void initState() {
    super.initState();
    totalDaysController.addListener(_updatePercentage);
    absentDaysController.addListener(_updatePercentage);
  }

  void _updatePercentage() {
    final totalDays = int.tryParse(totalDaysController.text) ?? 0;
    final absentDays = int.tryParse(absentDaysController.text) ?? 0;
    final presentDays = totalDays - absentDays;
    setState(() {
      attendancePercentage = totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;
    });
  }

  @override
  void dispose() {
    totalDaysController.removeListener(_updatePercentage);
    absentDaysController.removeListener(_updatePercentage);
    totalDaysController.dispose();
    absentDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Attendance for ${widget.studentName} - ${DateFormat('MMM yyyy').format(widget.selectedMonth)}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date selection
          Text("Select the month for attendance: ${DateFormat('MMMM yyyy').format(widget.selectedMonth)}"),
          const SizedBox(height: 16),
          
          // Text fields for inputting total days and absent days
          TextField(
            controller: totalDaysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total School Days',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: absentDaysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Absent Days',
            ),
          ),
          const SizedBox(height: 16),

          // Display attendance percentage
          Text(
            'Attendance Percentage: ${attendancePercentage.toStringAsFixed(2)}%',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final totalDays = int.tryParse(totalDaysController.text) ?? 0;
            final absentDays = int.tryParse(absentDaysController.text) ?? 0;
            widget.onSave(totalDays, absentDays);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}