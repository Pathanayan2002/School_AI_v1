import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class TeacherAttendanceRecord extends StatefulWidget {
  const TeacherAttendanceRecord({super.key});

  @override
  State<TeacherAttendanceRecord> createState() => _TeacherAttendanceRecordState();
}

class _TeacherAttendanceRecordState extends State<TeacherAttendanceRecord> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? selectedMonth = 'All Months';
  String? selectedTeacherId;
  final List<String> monthList = [
    'All Months',
    ...List.generate(
      12,
      (i) => DateFormat('MMMM yyyy').format(DateTime(DateTime.now().year, i + 1)),
    ),
  ];
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> filteredTeachers = [];
  List<Map<String, dynamic>> allTeachers = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _presentDaysController = TextEditingController();
  final TextEditingController _totalDaysController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    _loadTeachers();
    loadTeacherRecords();
    _searchController.addListener(() => _applyFilters());
  }

  Future<void> _checkAuthorization() async {
    final userId = await _storage.read(key: 'user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to access teacher records')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final response = await _apiService.getUserById(userId);
    if (!response['success'] || response['data']['role'] != 'Clerk') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access denied: Only Clerks can view teacher records')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _loadTeachers() async {
    try {
      final res = await _apiService.getAllUsers(schoolId: '');
      if (kDebugMode) print('getAllUsers response: $res');
      if (res['success'] && res['data'] is List) {
        setState(() {
          allTeachers = List<Map<String, dynamic>>.from(res['data'])
              .where((user) => user['role'] == 'Teacher')
              .toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to load teachers')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error loading teachers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading teachers: $e')),
      );
    }
  }

  Future<void> loadTeacherRecords() async {
    setState(() => _isLoading = true);
    try {
      final res = selectedTeacherId == null
          ? await _apiService.getAllAttendances()
          : await _apiService.getAttendanceByTeacherId(selectedTeacherId!);
      if (kDebugMode) print('Attendance response: $res');
      if (res['success']) {
        setState(() {
          teachers = selectedTeacherId == null
              ? List<Map<String, dynamic>>.from(res['data']['teacherAttendances'] ?? [])
              : List<Map<String, dynamic>>.from(res['data'] ?? []);
          _applyFilters();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'No teacher attendance records available')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error loading teacher records: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load teacher records: $e')),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      filteredTeachers = teachers.where((teacher) {
        final name = teacher['teachers']?['name']?.toString().toLowerCase() ?? '';
        final enrollmentId = teacher['teachers']?['enrollmentId']?.toString().toLowerCase() ?? '';
        final month = teacher['month']?.toString() ?? '';
        final query = _searchController.text.toLowerCase();

        final matchesSearch = name.contains(query) || enrollmentId.contains(query);
        final matchesMonth = selectedMonth == 'All Months' || month == selectedMonth;

        return matchesSearch && matchesMonth;
      }).toList();
      if (kDebugMode) print('Filtered teachers: $filteredTeachers');
    });
  }

  Future<void> _addAttendance() async {
    if (_monthController.text.isEmpty ||
        _presentDaysController.text.isEmpty ||
        _totalDaysController.text.isEmpty ||
        selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select a teacher')),
      );
      return;
    }

    try {
      final res = await _apiService.createTeacherAttendance(
        teacherId: selectedTeacherId!,
        month: _monthController.text,
        totalDays: int.parse(_totalDaysController.text),
        presentDays: int.parse(_presentDaysController.text), status: '',
      );
      if (kDebugMode) print('createTeacherAttendance response: $res');
      if (res['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance added successfully')),
        );
        _monthController.clear();
        _presentDaysController.clear();
        _totalDaysController.clear();
        await loadTeacherRecords();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to add attendance')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error adding attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding attendance: $e')),
      );
    }
  }

  Future<void> _editAttendance(String id, int presentDays, int totalDays) async {
    _presentDaysController.text = presentDays.toString();
    _totalDaysController.text = totalDays.toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Attendance', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _presentDaysController,
              decoration: InputDecoration(labelText: 'Present Days', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _totalDaysController,
              decoration: InputDecoration(labelText: 'Total Days', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Save', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final res = await _apiService.updateAttendance(
          id: id,
          presentDays: int.parse(_presentDaysController.text),
          totalDays: int.parse(_totalDaysController.text),
        );
        if (kDebugMode) print('updateAttendance response: $res');
        if (res['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance updated successfully')),
          );
          await loadTeacherRecords();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to update attendance')),
          );
        }
      } catch (e) {
        if (kDebugMode) print('Error updating attendance: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating attendance: $e')),
        );
      }
    }
  }

  Future<void> _deleteAttendance(String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Attendance', style: GoogleFonts.poppins()),
        content: Text('Are you sure you want to delete this attendance record?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final res = await _apiService.deleteAttendance(id);
        if (kDebugMode) print('deleteAttendance response: $res');
        if (res['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance deleted successfully')),
          );
          await loadTeacherRecords();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to delete attendance')),
          );
        }
      } catch (e) {
        if (kDebugMode) print('Error deleting attendance: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting attendance: $e')),
        );
      }
    }
  }

  Future<void> _showAddAttendanceDialog() async {
    _monthController.text = selectedMonth == 'All Months' ? '' : selectedMonth!;
    _presentDaysController.clear();
    _totalDaysController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Teacher Attendance', style: GoogleFonts.poppins()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedTeacherId,
                decoration: InputDecoration(
                  labelText: 'Select Teacher',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: allTeachers
                    .map((teacher) => DropdownMenuItem<String>(
                          value: teacher['id'].toString(),
                          child: Text(
                            '${teacher['name']} (${teacher['enrollmentId']})',
                            style: GoogleFonts.poppins(),
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => selectedTeacherId = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _monthController,
                decoration: InputDecoration(labelText: 'Month (e.g., August 2025)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _presentDaysController,
                decoration: InputDecoration(labelText: 'Present Days', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _totalDaysController,
                decoration: InputDecoration(labelText: 'Total Days', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              _addAttendance();
              Navigator.pop(context);
            },
            child: Text('Add', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> teachers) async {
    final excel = Excel.createExcel();
    final sheet = excel['TeacherAttendance'];

    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Enrollment ID'),
      TextCellValue('Month'),
      TextCellValue('Present Days'),
      TextCellValue('Total Days'),
      TextCellValue('Attendance %'),
    ]);

    for (var teacher in teachers) {
      final id = teacher['teacherId']?.toString() ?? '';
      final name = teacher['teachers']?['name']?.toString() ?? '';
      final enrollmentId = teacher['teachers']?['enrollmentId']?.toString() ?? '';
      final month = teacher['month']?.toString() ?? '';
      final present = teacher['presentDays'] ?? 0;
      final total = teacher['totalDays'] ?? 0;
      final percent = total > 0 ? (present / total) * 100 : 0;

      sheet.appendRow([
        TextCellValue(id),
        TextCellValue(name),
        TextCellValue(enrollmentId),
        TextCellValue(month),
        IntCellValue(present),
        IntCellValue(total),
        TextCellValue('${percent.toStringAsFixed(2)}%'),
      ]);
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final monthPart = selectedMonth == 'All Months' ? 'all_months' : selectedMonth!.replaceAll(' ', '_').toLowerCase();
      final filePath = '${directory.path}/teacher_attendance_${monthPart}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      await OpenFile.open(filePath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel file exported successfully')),
      );
    } catch (e) {
      if (kDebugMode) print('Error exporting to Excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting to Excel: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                  title: Text(
                    'Teacher Attendance Records',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.file_download, color: Colors.white),
                      onPressed: filteredTeachers.isEmpty ? null : () => _exportToExcel(filteredTeachers),
                      tooltip: 'Export to Excel',
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: _showAddAttendanceDialog,
                      tooltip: 'Add Attendance',
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedTeacherId,
                        decoration: InputDecoration(
                          labelText: 'Select Teacher',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white24,
                          labelStyle: GoogleFonts.poppins(color: Colors.white70),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Teachers', style: TextStyle(color: Colors.white)),
                          ),
                          ...allTeachers.map((teacher) => DropdownMenuItem<String>(
                                value: teacher['id'].toString(),
                                child: Text(
                                  '${teacher['name']} (${teacher['enrollmentId']})',
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => selectedTeacherId = value);
                          loadTeacherRecords();
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedMonth,
                        decoration: InputDecoration(
                          labelText: 'Select Month',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white24,
                          labelStyle: GoogleFonts.poppins(color: Colors.white70),
                        ),
                        items: monthList
                            .map((month) => DropdownMenuItem<String>(
                                  value: month,
                                  child: Text(month, style: GoogleFonts.poppins(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: _isLoading ? null : (value) {
                          setState(() => selectedMonth = value);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search teachers by name or enrollment ID...',
                          prefixIcon: const Icon(Icons.search, color: Colors.white),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white24,
                          hintStyle: GoogleFonts.poppins(color: Colors.white70),
                        ),
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : filteredTeachers.isEmpty
                            ? Center(
                                child: Text(
                                  'No teacher attendance records found',
                                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 16,
                                  headingRowColor: MaterialStateColor.resolveWith((states) => Colors.white24),
                                  columns: [
                                    DataColumn(
                                        label: Text('ID', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white))),
                                    DataColumn(
                                        label: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white))),
                                    DataColumn(
                                        label: Text('Enrollment ID',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white))),
                                    DataColumn(
                                        label: Text('Month', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white))),
                                    DataColumn(
                                        label: Text('Present', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white))),
                                    DataColumn(
                                        label: Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white))),
                                    DataColumn(
                                        label: Text('Attendance %',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white))),
                                    DataColumn(
                                        label: Text('Actions',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white))),
                                  ],
                                  rows: filteredTeachers.map((teacher) {
                                    final id = teacher['teacherId']?.toString() ?? '';
                                    final name = teacher['teachers']?['name']?.toString() ?? '';
                                    final enrollmentId = teacher['teachers']?['enrollmentId']?.toString() ?? '';
                                    final month = teacher['month']?.toString() ?? '';
                                    final present = teacher['presentDays'] ?? 0;
                                    final total = teacher['totalDays'] ?? 0;
                                    final percent = total > 0 ? (present / total) * 100 : 0;
                                    final attendanceId = teacher['id']?.toString() ?? '';

                                    Color statusColor = Colors.red;
                                    if (percent >= 75) {
                                      statusColor = Colors.green;
                                    } else if (percent >= 50) {
                                      statusColor = Colors.orange;
                                    }

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(id, style: GoogleFonts.poppins(color: Colors.white))),
                                        DataCell(Text(name, style: GoogleFonts.poppins(color: Colors.white))),
                                        DataCell(Text(enrollmentId, style: GoogleFonts.poppins(color: Colors.white))),
                                        DataCell(Text(month, style: GoogleFonts.poppins(color: Colors.white))),
                                        DataCell(Text(present.toString(), style: GoogleFonts.poppins(color: Colors.white))),
                                        DataCell(Text(total.toString(), style: GoogleFonts.poppins(color: Colors.white))),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${percent.toStringAsFixed(1)}%',
                                              style: GoogleFonts.poppins(color: statusColor, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        DataCell(Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.white),
                                              onPressed: () => _editAttendance(attendanceId, present, total),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteAttendance(attendanceId),
                                            ),
                                          ],
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _monthController.dispose();
    _presentDaysController.dispose();
    _totalDaysController.dispose();
    super.dispose();
  }
}