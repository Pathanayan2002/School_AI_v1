import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

// External Packages
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class StudentRecord extends StatefulWidget {
  const StudentRecord({super.key});

  @override
  State<StudentRecord> createState() => _StudentRecordScreenState();
}

class _StudentRecordScreenState extends State<StudentRecord> {
  final ApiService _apiService = ApiService();

  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  final List<String> monthList = List.generate(
    12,
    (i) => DateFormat('MMMM yyyy').format(DateTime(DateTime.now().year, i + 1)),
  );

  List<Map<String, dynamic>> students = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadStudentRecords();
  }

  Future<void> loadStudentRecords() async {
    final res = await _apiService.getAllAttendances();
    if (res['studentAttendances'] != null && res['studentAttendances'] is List) {
      setState(() {
        students = List<Map<String, dynamic>>.from(res['studentAttendances']);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load student records")),
      );
    }
  }

  void _exportToExcel(List<Map<String, dynamic>> students) {
    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];

    // Header Row
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Month'),
      TextCellValue('Present Days'),
      TextCellValue('Total Days'),
      TextCellValue('Attendance %')
    ]);

    // Data Rows
    for (var student in students) {
      final id = student['studentId'];
      final String name = student['students']?['name'] ?? '';
      final String month = student['month'] ?? '';
      final int present = student['presentDays'] ?? 0;
      final int total = student['totalDays'] ?? 0;
      final double percent = total > 0 ? (present / total) * 100 : 0;

      sheet.appendRow([
        TextCellValue(id.toString()),
        TextCellValue(name),
        TextCellValue(month),
        IntCellValue(present),
        IntCellValue(total),
        TextCellValue("${percent.toStringAsFixed(2)}%"),
      ]);
    }

    // Save and Open File
    _saveAndLaunchFile(excel.encode()!, 'attendance_$selectedMonth.xlsx');
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
        .where((student) => student['month'] == selectedMonth)
        .where((student) {
      final name = student['students']?['name']?.toLowerCase() ?? '';
      final query = _searchController.text.toLowerCase();
      return name.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Attendance Records',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.blue,
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Month Dropdown
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Select Month",
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.calendar_month),
                  ),
                  value: selectedMonth,
                  items: monthList.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(m),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => selectedMonth = val ?? selectedMonth),
                  icon: const Icon(Icons.arrow_drop_down),
                  iconSize: 28,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Search Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by student name...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Export Button
            ElevatedButton.icon(
              onPressed: () => _exportToExcel(filteredStudents),
              icon: const Icon(Icons.download),
              label: const Text("Export to Excel"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),

            const SizedBox(height: 16),

            // Table Section
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  child: DataTable(
                    dataRowColor: MaterialStateProperty.all(Colors.grey[200]),
                    columns: const [
                      DataColumn(label: Text("ID", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Month", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Present", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filteredStudents.map((student) {
                      final int id = student['studentId'];
                      final String name = student['students']?['name'] ?? '';
                      final String month = student['month'] ?? '';
                      final int present = student['presentDays'] ?? 0;
                      final int total = student['totalDays'] ?? 0;
                      final double percent = total > 0 ? (present / total) * 100 : 0;

                      Color statusColor = Colors.red;
                      if (percent >= 75) statusColor = Colors.green;
                      else if (percent >= 50) statusColor = Colors.orange;

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
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
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