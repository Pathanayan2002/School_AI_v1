import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/api_client.dart';

class AttendanceRecordScreen extends StatefulWidget {
  const AttendanceRecordScreen({super.key});

  @override
  State<AttendanceRecordScreen> createState() => _AttendanceRecordScreenState();
}

class _AttendanceRecordScreenState extends State<AttendanceRecordScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> teacherAttendances = [];
  List<Map<String, dynamic>> filteredTeachers = [];
  bool isLoading = false;
  String? userRole;
  String selectedMonth = 'All';
  String selectedYear = DateTime.now().year.toString();

  final months = [
    'All', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      final userId = await _apiService.getCurrentUserId();
      if (userId != null) {
        final userResponse = await _apiService.getUserById(userId);
        if (userResponse != null && userResponse['data'] != null) {
          userRole = userResponse['data']['role']?.toString().toLowerCase();
        }
      }
      await _loadAttendances();
    } catch (e) {
      _showSnackBar('Error loading user data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAttendances() async {
    try {
      final response = await _apiService.getAllAttendances();
      if (response != null) {
        teacherAttendances = List<Map<String, dynamic>>.from(
          response['teacherAttendances'] ?? [],
        );
        _filterAttendances();
      } else {
        _showSnackBar('Failed to load attendance records');
      }
    } catch (e) {
      _showSnackBar('Error loading attendance records: $e');
    }
  }

  /// FIXED FILTER — Shows all on first load, trims and ignores case
  void _filterAttendances() {
    setState(() {
      filteredTeachers = teacherAttendances.where((teacher) {
        final monthString = (teacher['month'] ?? '').toString().trim();
        final parts = monthString.split(RegExp(r'\s+')); // split by space(s)

        // If month format isn't "Month Year", just keep the record
        if (parts.length != 2) return true;

        final recordMonth = parts[0].trim();
        final recordYear = parts[1].trim();

        // If year field is empty, don't filter by year
        if (selectedYear.trim().isEmpty) {
          if (selectedMonth == 'All') return true;
          return recordMonth.toLowerCase() == selectedMonth.toLowerCase();
        }

        // Year must match
        if (recordYear != selectedYear.trim()) return false;

        // Month match or "All"
        if (selectedMonth == 'All' || selectedMonth.trim().isEmpty) return true;

        return recordMonth.toLowerCase() == selectedMonth.toLowerCase();
      }).toList();
    });
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> teachers, {bool isYearly = false}) async {
    if (teachers.isEmpty) {
      _showSnackBar('No attendance records available for ${isYearly ? 'year' : selectedMonth}');
      return;
    }

    setState(() => isLoading = true);

    try {
      final excel = Excel.createExcel();
      final sheetName = isYearly ? 'Yearly_Attendance' : 'Teacher_Attendance_$selectedMonth';
      final sheet = excel[sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName];

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final headers = [
        TextCellValue('Teacher ID'),
        TextCellValue('Name'),
        TextCellValue('Month'),
        TextCellValue('Present Days'),
        TextCellValue('Total Days'),
        TextCellValue('Attendance %'),
      ];

      sheet.appendRow(headers);
      sheet.row(0).forEach((cell) {
        if (cell != null) cell.cellStyle = headerStyle;
      });

      for (var teacher in teachers) {
        final id = teacher['teacherId']?.toString() ?? 'N/A';
        final name = teacher['teachers']?['name']?.toString() ?? 'Unknown';
        final month = teacher['month']?.toString() ?? '-';
        final present = teacher['presentDays'] as int? ?? 0;
        final total = teacher['totalDays'] as int? ?? 0;
        final percent = total > 0 ? (present / total) * 100 : 0.0;

        final row = [
          TextCellValue(id),
          TextCellValue(name),
          TextCellValue(month),
          IntCellValue(present),
          IntCellValue(total),
          DoubleCellValue(percent / 100),
        ];

        sheet.appendRow(row);
        final lastRow = sheet.maxRows - 1;
        final percentCell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 5, rowIndex: lastRow));
        percentCell.cellStyle = CellStyle(numberFormat: NumFormat.custom(formatCode: '0.00%'));
      }

      final bytes = await excel.encode();
      if (bytes == null) throw Exception('Failed to generate Excel file');

      final dir = await getApplicationDocumentsDirectory();
      final fileName = isYearly
          ? 'Teacher_Yearly_Attendance_${selectedYear}_${DateTime.now().toIso8601String().split('T')[0]}.xlsx'
          : 'Teacher_Attendance_${selectedMonth.replaceAll(' ', '_')}_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      _showSnackBar('Excel file saved to ${file.path}', color: Colors.green);
    } catch (e) {
      _showSnackBar('Failed to export Excel file: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Attendance Records'),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Filter Controls
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                          ),
                          items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              selectedMonth = value;
                              _filterAttendances();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          initialValue: selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            selectedYear = value;
                            _filterAttendances();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Download Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _exportToExcel(filteredTeachers),
                          icon: const Icon(Icons.download),
                          label: const Text('Month'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _exportToExcel(teacherAttendances, isYearly: true),
                          icon: const Icon(Icons.download),
                          label: const Text('Yearly'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Attendance List
                  Expanded(
                    child: filteredTeachers.isEmpty
                        ? const Center(child: Text('No teacher attendance records'))
                        : ListView.separated(
                            itemCount: filteredTeachers.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final attendance = filteredTeachers[index];
                              final percent = (attendance['totalDays'] != null &&
                                      attendance['totalDays'] > 0)
                                  ? ((attendance['presentDays'] / attendance['totalDays']) * 100)
                                      .toStringAsFixed(1)
                                  : '0.0';

                              return ListTile(
                                title: Text(
                                  attendance['teachers']?['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                subtitle: Text(
                                  'ID: ${attendance['teacherId']} • Month: ${attendance['month']}\n'
                                  'Present: ${attendance['presentDays']} / ${attendance['totalDays']} days\n'
                                  'Attendance: $percent%',
                                ),
                                trailing: (userRole == 'admin' || userRole == 'clerk')
                                    ? IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Delete Attendance'),
                                              content: const Text(
                                                  'Are you sure you want to delete this record?'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context, false),
                                                    child: const Text('Cancel')),
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context, true),
                                                    child: const Text('Confirm')),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            setState(() => isLoading = true);
                                            final response = await _apiService
                                                .deleteAttendance(attendance['id'].toString());
                                            setState(() => isLoading = false);
                                            if (response != null && response['success'] == true) {
                                              _showSnackBar('Deleted successfully',
                                                  color: Colors.green);
                                              await _loadAttendances();
                                            } else {
                                              _showSnackBar(
                                                  'Failed to delete: ${response?['message'] ?? 'Unknown error'}');
                                            }
                                          }
                                        },
                                      )
                                    : null,
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
