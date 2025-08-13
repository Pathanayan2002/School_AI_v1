import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../services/api_client.dart';
import '../../model/model.dart';

class StudentAttendancePage extends StatefulWidget {
  final String teacherId;
  const StudentAttendancePage({super.key, required this.teacherId});

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  final ApiService _apiService = ApiService();
  List<ClassModel> _classes = [];
  List<Student> _students = [];
  String? _selectedClassId;
  DateTime? _selectedMonth;
  Map<String, Map<String, int>> _attendance = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final classesResponse = await _apiService.getClassesByTeacherId(widget.teacherId);
      final studentsResponse = await _apiService.getAllStudents();
      if (classesResponse['data'] != null && studentsResponse['data'] != null) {
        setState(() {
          _classes = (classesResponse['data'] as List<dynamic>)
              .map((e) => ClassModel.fromJson(e))
              .toList();
          _students = (studentsResponse['data'] as List<dynamic>)
              .map((e) => Student.fromJson(e))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = classesResponse['message'] ?? studentsResponse['message'] ?? 'Failed to load data';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = e.response?.data['message'] ?? e.message ?? 'An error occurred';
        _isLoading = false;
        if (e.response?.statusCode == 401) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

 Future<void> _saveAttendance() async {
  if (_selectedClassId == null || _selectedMonth == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please select a class and month', style: GoogleFonts.poppins())),
    );
    return;
  }
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });
  try {
    for (var student in _students.where((s) => s.classId == _selectedClassId)) {
      final attendanceData = _attendance[student.id];
      if (attendanceData != null) {
        final month = DateFormat('yyyy-MM').format(_selectedMonth!);
        await _apiService.createAttendance(
  studentId: student.id,
  month: month,
  totalDays: attendanceData['totalDays']!,
  presentDays: attendanceData['presentDays']!,
  status: '', date: '',
);

      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attendance saved successfully', style: GoogleFonts.poppins())),
    );
    _fetchData(); // Refresh data
  } on DioException catch (e) {
    setState(() {
      _errorMessage = e.response?.data['message'] ?? e.message ?? 'An error occurred';
      _isLoading = false;
      if (e.response?.statusCode == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  } catch (e) {
    setState(() {
      _errorMessage = e.toString();
      _isLoading = false;
    });
  }
}

  Future<void> _selectMonth() async {
    final selected = await showMonthPicker(
      context: context,
      initialDate: _selectedMonth ?? DateTime.now(),
    );
    if (selected != null) {
      setState(() {
        _selectedMonth = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Attendance', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButton<String>(
                        hint: Text('Select Class', style: GoogleFonts.poppins()),
                        value: _selectedClassId,
                        isExpanded: true,
                        items: _classes
                            .map((cls) => DropdownMenuItem(
                                  value: cls.id,
                                  child: Text(cls.name, style: GoogleFonts.poppins()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedClassId = value;
                            _attendance.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _selectMonth,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: Text(
                          _selectedMonth == null
                              ? 'Select Month'
                              : DateFormat('MMMM yyyy').format(_selectedMonth!),
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: _selectedClassId == null
                            ? Center(child: Text('Select a class to view students', style: GoogleFonts.poppins()))
                            : ListView.builder(
                                itemCount: _students.where((s) => s.classId == _selectedClassId).length,
                                itemBuilder: (context, index) {
                                  final student = _students.where((s) => s.classId == _selectedClassId).elementAt(index);
                                  final attendanceData = _attendance[student.id] ?? {'totalDays': 30, 'presentDays': 0};
                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    child: ListTile(
                                      title: Text(student.name, style: GoogleFonts.poppins()),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Roll No: ${student.rollNo}', style: GoogleFonts.poppins(color: Colors.grey)),
                                          TextField(
                                            decoration: InputDecoration(
                                              labelText: 'Total Days',
                                              labelStyle: GoogleFonts.poppins(),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              setState(() {
                                                _attendance[student.id] ??= {'totalDays': 30, 'presentDays': 0};
                                                _attendance[student.id]!['totalDays'] = int.tryParse(value) ?? 30;
                                              });
                                            },
                                            controller: TextEditingController(text: attendanceData['totalDays'].toString()),
                                          ),
                                          TextField(
                                            decoration: InputDecoration(
                                              labelText: 'Present Days',
                                              labelStyle: GoogleFonts.poppins(),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              setState(() {
                                                _attendance[student.id] ??= {'totalDays': 30, 'presentDays': 0};
                                                _attendance[student.id]!['presentDays'] = int.tryParse(value) ?? 0;
                                              });
                                            },
                                            controller: TextEditingController(text: attendanceData['presentDays'].toString()),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _saveAttendance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Save Attendance', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                ),
    );
  }
}