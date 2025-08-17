// File: student_record.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../services/api_client.dart';

class StudentRecord extends StatefulWidget {
  const StudentRecord({super.key});

  @override
  State<StudentRecord> createState() => _StudentRecordScreenState();
}

class _StudentRecordScreenState extends State<StudentRecord> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  final List<String> monthList = List.generate(
    12,
    (i) => DateFormat('MMMM yyyy').format(DateTime(DateTime.now().year, i + 1)),
  );

  List<Map<String, dynamic>> students = [];

  @override
  void initState() {
    super.initState();
    _loadStudentRecords();
  }

  void _showSnack(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadStudentRecords() async {
    final res = await _apiService.getAllAttendances();
    if (res['studentAttendances'] is List) {
      setState(() {
        students = List<Map<String, dynamic>>.from(res['studentAttendances']);
      });
    } else {
      _showSnack("Failed to load student records");
    }
  }

  void _exportToExcel(List<Map<String, dynamic>> data) {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Attendance'];

      sheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Name'),
        TextCellValue('Month'),
        TextCellValue('Present Days'),
        TextCellValue('Total Days'),
        TextCellValue('Attendance %')
      ]);

      for (var s in data) {
        final id = s['studentId'];
        final name = s['students']?['name'] ?? '';
        final month = s['month'] ?? '';
        final present = s['presentDays'] ?? 0;
        final total = s['totalDays'] ?? 0;
        final percent = total > 0 ? (present / total) * 100 : 0;

        sheet.appendRow([
          TextCellValue(id.toString()),
          TextCellValue(name),
          TextCellValue(month),
          IntCellValue(present),
          IntCellValue(total),
          TextCellValue("${percent.toStringAsFixed(2)}%"),
        ]);
      }

      _saveAndLaunchFile(excel.encode()!, 'attendance_$selectedMonth.xlsx');
    } catch (e) {
      _showSnack("Failed to export: $e");
    }
  }

  Future<void> _saveAndLaunchFile(List<int> bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = students
        .where((s) => s['month'] == selectedMonth)
        .where((s) {
          final name = s['students']?['name']?.toLowerCase() ?? '';
          final query = _searchController.text.toLowerCase();
          return name.contains(query);
        }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Attendance Records',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  value: selectedMonth,
                  decoration: const InputDecoration(
                    labelText: "Select Month",
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.calendar_month, color: Colors.blue),
                  ),
                  items: monthList
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedMonth = val ?? selectedMonth),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by student name...",
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.blue.shade50,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _exportToExcel(filteredStudents),
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text("Export to Excel", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 16,
                    dataRowHeight: 56,
                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade100),
                    columns: const [
                      DataColumn(label: Text("ID", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Month", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Present", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filteredStudents.map((s) {
                      final id = s['studentId'];
                      final name = s['students']?['name'] ?? '';
                      final month = s['month'] ?? '';
                      final present = s['presentDays'] ?? 0;
                      final total = s['totalDays'] ?? 0;
                      final percent = total > 0 ? (present / total) * 100 : 0;

                      Color statusColor = Colors.red;
                      if (percent >= 75) {
                        statusColor = Colors.green;
                      } else if (percent >= 50) {
                        statusColor = Colors.orange;
                      }

                      return DataRow(
                        cells: [
                          DataCell(Text(id.toString())),
                          DataCell(Text(name)),
                          DataCell(Text(month)),
                          DataCell(Text(present.toString())),
                          DataCell(Text(total.toString())),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${percent.toStringAsFixed(1)}%",
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}