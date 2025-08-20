import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:universal_io/io.dart' show File;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class ClerkTeacherAttendanceRecordPage extends StatefulWidget {
  const ClerkTeacherAttendanceRecordPage({super.key});

  @override
  State<ClerkTeacherAttendanceRecordPage> createState() => _ClerkTeacherAttendanceRecordPageState();
}

class _ClerkTeacherAttendanceRecordPageState extends State<ClerkTeacherAttendanceRecordPage> {
  final ApiService _apiService = ApiService();
  String? _schoolId;
  List<Map<String, dynamic>> _teacherAttendances = [];
  List<Map<String, dynamic>> _filteredAttendances = [];
  String _selectedMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());
  bool _isLoading = false;
  String? _errorMessage;
  bool _isExporting = false;

  final List<String> _monthYears = _generateMonthYears();

  static List<String> _generateMonthYears() {
    final now = DateTime.now();
    final currentYear = now.year;
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final List<String> monthYears = [];
    for (var year = currentYear - 1; year <= currentYear; year++) {
      for (var month in months) {
        monthYears.add('$month $year');
      }
    }
    return monthYears;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.init();
      _schoolId = await _apiService.getCurrentSchoolId();

      if (_schoolId == null) {
        setState(() {
          _errorMessage = 'शाळा सापडली नाही. कृपया पुन्हा लॉग इन करा.';
          _isLoading = false;
        });
        return;
      }

      final response = await _apiService.getAllAttendances();
      if (kDebugMode) {
        debugPrint('Attendance Response: $response');
      }

      if (response['success'] && response['data'] != null) {
        setState(() {
          _teacherAttendances = List<Map<String, dynamic>>.from(response['data']['teacherAttendances'] ?? []);
          _filterAttendances();
          _isLoading = false;
          _errorMessage = _teacherAttendances.isEmpty
              ? 'या शाळेसाठी शिक्षक उपस्थिती रेकॉर्ड सापडले नाहीत.'
              : null;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'उपस्थिती रेकॉर्ड मिळवण्यात अयशस्वी.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'डेटा लोड करण्यात त्रुटी: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        debugPrint('Error in _loadInitialData: $e');
      }
    }
  }

  void _filterAttendances() {
    setState(() {
      _filteredAttendances = _teacherAttendances.where((attendance) {
        final monthString = (attendance['month'] ?? '').toString().trim();
        return monthString == _selectedMonthYear;
      }).toList();
      _errorMessage = _filteredAttendances.isEmpty
          ? 'निवडलेल्या महिन्यासाठी शिक्षक उपस्थिती रेकॉर्ड सापडले नाहीत.'
          : null;
    });
  }

  Future<void> _exportToExcel() async {
    if (_filteredAttendances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Teacher_Attendance'];

      sheet.appendRow([
        TextCellValue('Teacher ID'),
        TextCellValue('Name'),
        TextCellValue('Month'),
        TextCellValue('Total Days'),
        TextCellValue('Present Days'),
        TextCellValue('Attendance %'),
      ]);

      for (var record in _filteredAttendances) {
        final id = record['teacherId']?.toString() ?? 'N/A';
        final name = record['teachers']?['name']?.toString() ?? 'Unknown';
        final totalDays = record['totalDays'] as int? ?? 0;
        final presentDays = record['presentDays'] as int? ?? 0;
        final percentage = totalDays > 0 ? ((presentDays / totalDays) * 100).toStringAsFixed(2) : '0.00';

        sheet.appendRow([
          TextCellValue(id),
          TextCellValue(name),
          TextCellValue(record['month']?.toString() ?? _selectedMonthYear),
          TextCellValue(totalDays.toString()),
          TextCellValue(presentDays.toString()),
          TextCellValue('$percentage%'),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Teacher_Attendance_${_selectedMonthYear.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      await Share.shareXFiles([XFile(filePath)], text: 'Teacher Attendance Report');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel file exported and shared: $fileName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting to Excel: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Clerk Teacher Attendance Records',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            onPressed: _isExporting ? null : _exportToExcel,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          _loadInitialData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: DropdownButtonFormField<String>(
                              value: _selectedMonthYear,
                              decoration: const InputDecoration(
                                labelText: 'Select Month and Year',
                                labelStyle: TextStyle(color: Colors.blueAccent),
                                border: InputBorder.none,
                              ),
                              items: _monthYears.map((monthYear) {
                                return DropdownMenuItem<String>(
                                  value: monthYear,
                                  child: Text(monthYear),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedMonthYear = newValue!;
                                  _filteredAttendances = [];
                                  _errorMessage = null;
                                  _filterAttendances();
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Teacher Attendance Records (${_filteredAttendances.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _filteredAttendances.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    _errorMessage ?? 'No teacher attendance records found for the selected month.',
                                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 16,
                                  columns: const [
                                    DataColumn(label: Text('Teacher ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Total Days', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Present Days', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Attendance %', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _filteredAttendances.map((record) {
                                    final id = record['teacherId']?.toString() ?? 'N/A';
                                    final name = record['teachers']?['name']?.toString() ?? 'Unknown';
                                    final totalDays = record['totalDays'] as int? ?? 0;
                                    final presentDays = record['presentDays'] as int? ?? 0;
                                    final percentage = totalDays > 0 ? ((presentDays / totalDays) * 100).toStringAsFixed(2) : '0.00';

                                    return DataRow(cells: [
                                      DataCell(Text(id)),
                                      DataCell(Text(name)),
                                      DataCell(Text(record['month']?.toString() ?? _selectedMonthYear)),
                                      DataCell(Text(totalDays.toString())),
                                      DataCell(Text(presentDays.toString())),
                                      DataCell(Text('$percentage%')),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }
}
