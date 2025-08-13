import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> allStudents = [];

  // Map: studentId -> Map<dateString, status>
  Map<int, Map<String, String>> attendanceData = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final res = await _apiService.getAllStudents();
    if (res['success'] == true && res['data'] is List) {
      setState(() {
        allStudents = List<Map<String, dynamic>>.from(res['data']);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load students")),
      );
    }
  }

  void _openMonthlyAttendanceDialog(BuildContext context, int studentId, String studentName) {
    DateTime initialDate = DateTime.now();
Future<DateTime?> showMonthPicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final selected = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    initialEntryMode: DatePickerEntryMode.calendarOnly,
    initialDatePickerMode: DatePickerMode.year,
  );
  return selected;
}
    showMonthPicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDate: initialDate,
    ).then((pickedMonth) {
      if (pickedMonth != null) {
        _showDailyAttendanceForMonth(context, studentId, studentName, pickedMonth);
      }
    });
  }

  Future<void> _showDailyAttendanceForMonth(
      BuildContext context, int studentId, String studentName, DateTime month) async {
    final DateFormat monthFormat = DateFormat('yyyy-MM');
    final String monthKey = monthFormat.format(month);

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Initialize map for this student and month if not present
    attendanceData.putIfAbsent(studentId, () => {});

    final Map<String, String> studentAttendance = attendanceData[studentId]!;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text("Attendance for $studentName - ${DateFormat('MMM yyyy').format(month)}"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int day = 1; day <= daysInMonth; day++)
                        _buildDayRow(
                          day: day,
                          month: month,
                          studentAttendance: studentAttendance,
                          dialogSetState: dialogSetState,
                          studentId: studentId,
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    // Save changes and close dialog
                    attendanceData[studentId] = studentAttendance;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDayRow({
    required int day,
    required DateTime month,
    required Map<String, String> studentAttendance,
    required Function dialogSetState,
    required int studentId,
  }) {
    final dateStr = "${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";

    final currentStatus = studentAttendance[dateStr] ?? 'Not Marked';

    return ListTile(
      title: Text("Day $day"),
      subtitle: Text("Status: $currentStatus"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () {
              dialogSetState(() {
                studentAttendance[dateStr] = 'Present';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus == 'Present' ? Colors.green : Colors.grey[400],
            ),
            child: const Text('P'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              dialogSetState(() {
                studentAttendance[dateStr] = 'Absent';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus == 'Absent' ? Colors.red : Colors.grey[400],
            ),
            child: const Text('A'),
          ),
        ],
      ),
    );
  }

  Future<void> submitAllAttendance() async {
    if (attendanceData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No attendance recorded.")),
      );
      return;
    }

    for (var studentEntry in attendanceData.entries) {
      final studentId = studentEntry.key.toString();
      final attendanceMap = studentEntry.value;

      final dates = attendanceMap.keys.toList();
      final statuses = attendanceMap.values.toList();

      final totalDays = dates.length;
      final presentDays = statuses.where((status) => status == 'Present').length;

      final month = DateFormat('MMMM yyyy').format(DateTime.parse(dates.first));

      final res = await _apiService.createAttendance(
        studentId: studentId,
        month: month,
        totalDays: totalDays,
        presentDays: presentDays,
        status: presentDays > 0 ? "Partial" : "None", // Customize logic as needed
        date: dates.join(','), // Join all dates
      );

      if (res['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed for ID: $studentId")),
        );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attendance submitted successfully")),
    );

    attendanceData.clear();
    setState(() {});
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
                      onTap: () => _openMonthlyAttendanceDialog(context, studentId, studentName),
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