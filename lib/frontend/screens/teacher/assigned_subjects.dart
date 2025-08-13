import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../../model/model.dart';

class AssignedSubjectsPage extends StatefulWidget {
  final String teacherId;
  const AssignedSubjectsPage({super.key, required this.teacherId});

  @override
  State<AssignedSubjectsPage> createState() => _AssignedSubjectsPageState();
}

class _AssignedSubjectsPageState extends State<AssignedSubjectsPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _subjectsWithClasses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Get teacher with assigned subjects
final teacher = await _apiService.getUserById(widget.teacherId);
final subjects = teacher['Subjects'] ?? [];


      List<Map<String, dynamic>> subjectsWithClasses = [];

      for (var subj in subjects) {
        final subject = SubjectItem.fromJson(subj);
        ClassModel? classItem;
        if (subject.classId != null) {
          final classRes = await _apiService.getClassById(subject.classId!);
          if (classRes != null && classRes is Map) {
            classItem = ClassModel.fromJson(classRes);
          }
        }
        subjectsWithClasses.add({'subject': subject, 'class': classItem});
      }

      setState(() {
        _subjectsWithClasses = subjectsWithClasses;
        _isLoading = false;
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
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Assigned Subjects', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSubjects,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: GoogleFonts.poppins(color: Colors.red)))
              : _subjectsWithClasses.isEmpty
                  ? Center(child: Text('No subjects assigned', style: GoogleFonts.poppins()))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _subjectsWithClasses.length,
                      itemBuilder: (context, index) {
                        final subjectData = _subjectsWithClasses[index];
                        final subject = subjectData['subject'] as SubjectItem;
                        final classItem = subjectData['class'] as ClassModel?;
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(subject.name,
                                style: GoogleFonts.poppins(fontSize: 16)),
                            subtitle: Text(
                              classItem != null
                                  ? '${classItem.name}${classItem.division != null ? ' - ${classItem.division}' : ''}'
                                  : 'No class assigned',
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
