import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../../model/student_model.dart'; // Use Student from student_model.dart
import '../../model/model.dart' hide Student; // Keep for User and ClassModel
import 'assigned_subjects.dart';
import 'view_student_record.dart';
import './result/sem_one.dart';
import './result/sem_two.dart';
import 'student_attendence.dart';

class TeacherHomePage extends StatefulWidget {
  final String teacherId;
  const TeacherHomePage({super.key, required this.teacherId});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final ApiService _apiService = ApiService();
  User? _teacher;
  List<ClassModel> _classes = [];
  List<Student> _students = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTeacherData();
    _fetchStudents();
  }

  Future<void> _fetchTeacherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userResponse = await _apiService.getUserById(widget.teacherId);
      final classesResponse = await _apiService.getClassesByTeacherId(widget.teacherId);

      setState(() {
        if (userResponse['success'] == true) {
          _teacher = User.fromJson(userResponse['data'] as Map<String, dynamic>);
        }
        if (classesResponse['success'] == true && classesResponse['data'] is List) {
          _classes = (classesResponse['data'] as List)
              .map((e) => ClassModel.fromJson(e as Map<String, dynamic>))
              .toList();
        } else {
          _classes = [];
        }
        _isLoading = false;
      });
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

  Future<void> _fetchStudents() async {
    try {
      final response = await _apiService.getAllStudents();
      if (response['success'] == true && response['data'] is List) {
        setState(() {
          _students = (response['data'] as List)
              .map((e) => Student.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load students: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final response = await _apiService.logout();
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged out successfully', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showSnackBar(response['message'] ?? 'Logout failed');
      }
    } on DioException catch (e) {
      _showSnackBar(e.response?.data['message'] ?? e.message ?? 'An error occurred');
      if (e.response?.statusCode == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showStudentSelectionDialog(BuildContext context, String destination) async {
    if (_students.isEmpty) {
      _showSnackBar('No students available. Please try again later.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Student', style: GoogleFonts.poppins()),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _students.length,
            itemBuilder: (context, index) {
              final student = _students[index];
              return ListTile(
                title: Text(student.name, style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  if (destination == 'sem1') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Sem1ResultPage(student: student),
                      ),
                    );
                  } else if (destination == 'sem2') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Sem2ResultPage(student: student),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
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
          title: Text(
            _teacher != null ? 'Welcome, ${_teacher!.name}' : 'Teacher Dashboard',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red)))
                : RefreshIndicator(
                    onRefresh: _fetchTeacherData,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assigned Classes',
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _classes
                                .map((cls) => SizedBox(
                                      width: 150,
                                      height: 100,
                                      child: Card(
                                        shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(12))),
                                        child: Center(
                                          child: Text(
                                            cls.name,
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                          Text('Actions',
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.5,
                              children: [
                                _buildNavCard(
                                  context,
                                  'Assigned Subjects',
                                  Icons.book,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AssignedSubjectsPage(teacherId: widget.teacherId),
                                    ),
                                  ),
                                ),
                                _buildNavCard(
                                  context,
                                  'Student Attendance',
                                  Icons.event_available,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StudentAttendanceScreen(),
                                    ),
                                  ),
                                ),
                                _buildNavCard(
                                  context,
                                  'Semester 1 Results',
                                  Icons.assessment,
                                  () => _showStudentSelectionDialog(context, 'sem1'),
                                ),
                                _buildNavCard(
                                  context,
                                  'Semester 2 Results',
                                  Icons.assessment_outlined,
                                  () => _showStudentSelectionDialog(context, 'sem2'),
                                ),
                                // Commenting out ResultReportPage until defined
                                /*
                                _buildNavCard(
                                  context,
                                  'Result Report',
                                  Icons.report,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ResultReportPage(teacherId: widget.teacherId),
                                    ),
                                  ),
                                ),
                                */
                                _buildNavCard(
                                  context,
                                  'Final Results',
                                  Icons.grade,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ViewStudentRecordPage(teacherId: widget.teacherId),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildNavCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}