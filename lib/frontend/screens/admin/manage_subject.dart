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

  Future<void> _fetchSubjects() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getAllSubjects(schoolId: '');

    if (result['success'] == true && result['data'] is List) {
      final List<Map<String, dynamic>> subjectList =
          List<Map<String, dynamic>>.from(result['data']);
      setState(() {
        _subjects = subjectList;
        _filteredSubjects = subjectList;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load subjects: ${result['message'] ?? 'Unknown error'}")),
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

  void _showAddSubjectDialog() {
    String newSubjectName = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (newSubjectName.isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a valid subject name")),
                        );
                        return;
                      }

                      setState(() => _isSubmitting = true);
                      final result = await _apiService.registerSubject(name: newSubjectName, subjectName: '', classId: '', schoolId: '');
                      setState(() => _isSubmitting = false);

                      if (!mounted) return;
                      if (result['success'] == true ||
                          (result['message']?.toString().toLowerCase().contains("created") ?? false)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Subject added successfully")),
                        );
                        Navigator.pop(context);
                        _fetchSubjects();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to add subject: ${result['message'] ?? 'Unknown error'}")),
                        );
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditSubjectDialog(int subjectId, String currentName) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Subject name cannot be empty")),
                        );
                        return;
                      }

                      setState(() => _isSubmitting = true);
                      final result = await _apiService.updateSubject(id: subjectId.toString(), name: updatedName, subjectName: '', classId: '', schoolId: '');
                      setState(() => _isSubmitting = false);

                      if (!mounted) return;
                      if (result['success'] == true ||
                          (result['message']?.toString().toLowerCase().contains("updated") ?? false)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Subject updated successfully")),
                        );
                        Navigator.pop(context);
                        _fetchSubjects();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to update subject: ${result['message'] ?? 'Unknown error'}")),
                        );
                      }
                    },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSubject(int subjectId, String subjectName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: Text("Are you sure you want to delete '$subjectName'?"),
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
                      setState(() => _isSubmitting = true);
                      final result = await _apiService.deleteSubject(subjectId.toString());
                      setState(() => _isSubmitting = false);

                      if (!mounted) return;
                      if (result['success'] == true ||
                          (result['message']?.toString().toLowerCase().contains("deleted") ?? false)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Subject deleted successfully")),
                        );
                        Navigator.pop(context);
                        _fetchSubjects();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to delete subject: ${result['message'] ?? 'Unknown error'}")),
                        );
                      }
                    },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubjectTable() {
    return Expanded(
      child: Card(
        elevation: 5,
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
                        DataColumn(label: Text("ID", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Subject Name", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
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
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: "Edit",
                                    onPressed: () {
                                      if (id != null) {
                                        _showEditSubjectDialog(id, name);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
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
        title: const Text("Manage Subjects"),
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
