import 'package:flutter/material.dart';
import '../../model/subject_model.dart';
import '../../model/student_model.dart';
import '../services/api_client.dart';
import 'result/sem_one.dart';
import 'result/sem_two.dart';

class AssignMarksPage extends StatefulWidget {
  final SubjectItem subjectItem;

  const AssignMarksPage({super.key, required this.subjectItem});

  @override
  State<AssignMarksPage> createState() => _AssignMarksPageState();
}

class _AssignMarksPageState extends State<AssignMarksPage> {
  late Future<void> _fetchStudentsFuture;
  List<Student> allStudents = [];
  List<Student> filteredStudents = [];
  String selectedClass = 'All';
  String selectedDivision = 'All';
  String selectedYear = 'All';
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchStudentsFuture = _fetchAllStudents();
  }

  Future<void> _fetchAllStudents() async {
    try {
      final response = await _apiService.getAllStudents();
      if (response['success'] == true && response['data'] is List) {
        setState(() {
          allStudents = (response['data'] as List)
              .map((item) => Student.fromJson(item))
              .toList();
          filteredStudents = List.from(allStudents);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load students: ${response['message']}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching students: $e")),
      );
    }
  }

  void filterStudents() {
    setState(() {
      filteredStudents = allStudents.where((student) {
        final matchesClass = selectedClass == 'All' || student.studentClass == selectedClass;
        final matchesDivision = selectedDivision == 'All' || student.division == selectedDivision;
        final matchesYear = selectedYear == 'All' || student.year == selectedYear;
        return matchesClass && matchesDivision && matchesYear;
      }).toList();
    });
  }

  List<String> getClasses() =>
      ['All', ...{...allStudents.map((s) => s.studentClass)}];
  List<String> getDivisions() =>
      ['All', ...{...allStudents.map((s) => s.division)}];
  List<String> getYears() =>
      ['All', ...{...allStudents.map((s) => s.year)}];

  void _navigateToResultPage(BuildContext context, Student student, String type) {
    switch (type) {
      case 'Sem1':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Sem1ResultPage(student: student)),
        );
        break;
      case 'Sem2':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Sem2ResultPage(student: student)),
        );
        break;
      case 'Final':
        // TODO: Implement final result logic
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Record'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            /// 🔍 Filter Row
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedClass,
                        items: getClasses()
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => setState(() => selectedClass = value!),
                        decoration: InputDecoration(
                          labelText: "Class",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedDivision,
                        items: getDivisions()
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => setState(() => selectedDivision = value!),
                        decoration: InputDecoration(
                          labelText: "Division",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedYear,
                        items: getYears()
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => setState(() => selectedYear = value!),
                        decoration: InputDecoration(
                          labelText: "Year",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: filterStudents,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: const Text("Search"),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 📋 Student List (with loading state)
            Expanded(
              child: FutureBuilder(
                future: _fetchStudentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (filteredStudents.isEmpty) {
                    return const Center(child: Text("No students found."));
                  } else {
                    return ListView.builder(
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        return ListTile(
                          title: Text(student.name),
                          subtitle: Text('${student.enrollmentNo} | ${student.studentClass}${student.division}, ${student.year}'),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert),
                            onSelected: (value) => _navigateToResultPage(context, student, value),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'Sem1', child: Text('Sem 1')),
                              PopupMenuItem(value: 'Sem2', child: Text('Sem 2')),
                              PopupMenuItem(value: 'Final', child: Text('Final')),
                            ],
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}