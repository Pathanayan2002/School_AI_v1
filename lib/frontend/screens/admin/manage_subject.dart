import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';

class ManageSubjectsScreen extends StatefulWidget {
  const ManageSubjectsScreen({Key? key}) : super(key: key);

  @override
  State<ManageSubjectsScreen> createState() => _ManageSubjectsScreenState();
}

class _ManageSubjectsScreenState extends State<ManageSubjectsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _filteredSubjects = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
    _searchController.addListener(() {
      _filterSubjects(_searchController.text);
    });
  }

  /// ✅ Flexible success checker
  bool _isSuccess(dynamic result) {
    if (result == null) return false;

    // If API has "success" key
    if (result['success'] == true ||
        result['success'] == 'true' ||
        result['success'] == 1) {
      return true;
    }

    // If API uses "status"
    if (result['status'] == 200 ||
        result['status'] == '200' ||
        result['status'] == true) {
      return true;
    }

    // If API uses "code"
    if (result['code'] == 200) {
      return true;
    }

    return false;
  }

  Future<void> _fetchSubjects() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getAllSubjects(schoolId: '');

    debugPrint("Fetch Subjects Response: $result");

    if (_isSuccess(result) && result['data'] is List) {
      final List<Map<String, dynamic>> subjectList =
          List<Map<String, dynamic>>.from(result['data']);
      setState(() {
        _subjects = subjectList;
        _filteredSubjects = subjectList;
      });
    } else {
      _showMessage(
        result['message']?.toString() ?? "Failed to load subjects",
        isError: true,
      );
    }

    setState(() => _isLoading = false);
  }

  void _filterSubjects(String query) {
    setState(() {
      _filteredSubjects = _subjects.where((subject) {
        final name = subject['name']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

 void _showAddSubjectDialog() {
  String newSubjectName = '';
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Subject'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Subject Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => newSubjectName = value.trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (newSubjectName.isEmpty) {
                        _showMessage("Subject name cannot be empty",
                            isError: true);
                        return;
                      }

                      setDialogState(() => _isSubmitting = true);
                      final schoolId = await _apiService.getCurrentSchoolId() ?? '';
                      final result = await _apiService.registerSubject(
                        name: newSubjectName,
                        subjectName: newSubjectName, // Use same as name if backend expects it
                        classId: '', // Provide classId if required
                        schoolId: schoolId,
                      );
                      setDialogState(() => _isSubmitting = false);

                      debugPrint("Add Subject Response: $result");

                      if (_isSuccess(result)) {
                        setState(() {
                          _subjects.add({
                            "id": result['data']?['id'] ??
                                DateTime.now().millisecondsSinceEpoch,
                            "name": newSubjectName,
                          });
                          _filteredSubjects = _subjects;
                        });
                        _showMessage("Subject added successfully");
                        Navigator.pop(context);
                      } else {
                        _showMessage(
                          result['message']?.toString() ?? "Failed to add subject",
                          isError: true,
                        );
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      );
    },
  );
}

void _showEditSubjectDialog(int subjectId, String currentName) {
  final TextEditingController nameController =
      TextEditingController(text: currentName);
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Subject'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: "Subject Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final updatedName = nameController.text.trim();
                      if (updatedName.isEmpty) {
                        _showMessage("Subject name cannot be empty",
                            isError: true);
                        return;
                      }

                      setDialogState(() => _isSubmitting = true);
                      final schoolId = await _apiService.getCurrentSchoolId() ?? '';
                      final result = await _apiService.updateSubject(
                        id: subjectId.toString(),
                        name: updatedName,
                        subjectName: updatedName, // Use same as name if backend expects it
                        classId: '', // Provide classId if required
                        schoolId: schoolId,
                      );
                      setDialogState(() => _isSubmitting = false);

                      debugPrint("Update Subject Response: $result");

                      if (_isSuccess(result)) {
                        setState(() {
                          final index = _subjects
                              .indexWhere((subj) => subj['id'] == subjectId);
                          if (index != -1) {
                            _subjects[index]['name'] = updatedName;
                          }
                          _filteredSubjects = _subjects;
                        });
                        _showMessage("Subject updated successfully");
                        Navigator.pop(context);
                      } else {
                        _showMessage(
                          result['message']?.toString() ?? "Failed to update subject",
                          isError: true,
                        );
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Save"),
            ),
          ],
        ),
      );
    },
  );
}
  void _confirmDeleteSubject(int subjectId, String subjectName) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("Confirm Delete"),
            content: Text("Are you sure you want to delete '$subjectName' ?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => _isSubmitting = true);
                        final result = await _apiService
                            .deleteSubject(subjectId.toString());
                        setDialogState(() => _isSubmitting = false);

                        debugPrint("Delete Subject Response: $result");

                        if (_isSuccess(result)) {
                          setState(() {
                            _subjects.removeWhere(
                                (subj) => subj['id'] == subjectId);
                            _filteredSubjects = _subjects;
                          });
                          _showMessage("Subject deleted successfully");
                          Navigator.pop(context);
                        } else {
                          _showMessage(
                            result['message']?.toString() ??
                                "Failed to delete subject",
                            isError: true,
                          );
                        }
                      },
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Delete"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubjectTable() {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search subjects...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _showAddSubjectDialog,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text("Add Subject"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_filteredSubjects.isEmpty)
                const Text("No subjects found.")
              else
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(
                          label: Text("ID",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text("Subject Name",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text("Actions",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                      rows: _filteredSubjects.map((subject) {
                        final int? id = subject['id'] is int
                            ? subject['id']
                            : int.tryParse(subject['id']?.toString() ?? '');
                        final String name = subject['name'] ?? "N/A";

                        return DataRow(
                          cells: [
                            DataCell(Text(id?.toString() ?? "N/A")),
                            DataCell(Text(name)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    tooltip: "Edit",
                                    onPressed: () {
                                      if (id != null) {
                                        _showEditSubjectDialog(id, name);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    tooltip: "Delete",
                                    onPressed: () {
                                      if (id != null) {
                                        _confirmDeleteSubject(id, name);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Subjects", style: GoogleFonts.poppins()),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSubjectTable(),
            ],
          ),
        ),
      ),
    );
  }
}
