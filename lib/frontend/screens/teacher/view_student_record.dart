import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../../model/model.dart';


class ViewStudentRecordPage extends StatefulWidget {
  final String? teacherId;
  const ViewStudentRecordPage({super.key, this.teacherId});

  @override
  State<ViewStudentRecordPage> createState() => _ViewStudentRecordPageState();
}

class _ViewStudentRecordPageState extends State<ViewStudentRecordPage> {
  final ApiService _apiService = ApiService();
  List<Student> _students = [];
  List<ClassModel> _classes = [];
  String? _selectedClassId;
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
      if (widget.teacherId != null) {
        final userResponse = await _apiService.getUserById(widget.teacherId!);
        if (userResponse['data'] == null) {
          throw Exception(userResponse['message'] ?? 'Failed to load teacher data');
        }
        final user = User.fromJson(userResponse['data']);
        if (user.role != 'Teacher') {
          throw Exception('Access restricted to Teachers only');
        }
      }
      final studentsResponse = await _apiService.getAllStudents();
      final classesResponse = widget.teacherId != null
          ? await _apiService.getClassesByTeacherId(widget.teacherId!)
          : await _apiService.getAllClasses(schoolId: '');
      if (studentsResponse['data'] != null && classesResponse['data'] != null) {
        setState(() {
          _students = (studentsResponse['data'] as List<dynamic>)
              .map((e) => Student.fromJson(e))
              .toList();
          _classes = (classesResponse['data'] as List<dynamic>)
              .map((e) => ClassModel.fromJson(e))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = studentsResponse['message'] ?? classesResponse['message'] ?? 'Failed to load data';
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: const Color(0xFF1E88E5),
        scaffoldBackgroundColor: Colors.grey[100],
        cardTheme: const CardThemeData(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Student Records', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: _selectedClassId == null
                              ? Center(child: Text('Select a class to view students', style: GoogleFonts.poppins()))
                              : ListView.builder(
                                  itemCount: _students.where((s) => s.classId == _selectedClassId).length,
                                  itemBuilder: (context, index) {
                                    final student = _students.where((s) => s.classId == _selectedClassId).elementAt(index);
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      child: ListTile(
                                        title: Text(student.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                        subtitle: Text(
                                          'Roll No: ${student.rollNo}\n'
                                          'Parent\'s Phone: ${student.parentsPhno ?? 'N/A'}',
                                          style: GoogleFonts.poppins(color: Colors.grey),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.assessment, color: Color(0xFF1E88E5)),
                                          onPressed: () async {
                                            if (widget.teacherId == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Teacher ID is required to view results', style: GoogleFonts.poppins())),
                                              );
                                              return;
                                            }
                                            try {
                                              final resultResponse = await _apiService.getOverallResult(student.id);
                                              if (resultResponse['data'] == null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(resultResponse['message'] ?? 'No results available', style: GoogleFonts.poppins())),
                                                );
                                                return;
                                              }
                                            
                                            } on DioException catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error: ${e.response?.data['message'] ?? e.message ?? 'An error occurred'}', style: GoogleFonts.poppins())),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
                                              );
                                            }
                                          },
                                          tooltip: 'View Results',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}