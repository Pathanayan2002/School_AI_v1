import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'dart:async';

class ManageClassesWithdivsion extends StatefulWidget {
  const ManageClassesWithdivsion({super.key});

  @override
  State<ManageClassesWithdivsion> createState() => _ManageClassesWithdivsionState();
}

class _ManageClassesWithdivsionState extends State<ManageClassesWithdivsion> {
  late ApiService _apiService;
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getAllClasses(schoolId: '');
      if (result['success'] == true) {
        final List<dynamic> data = result['data'];
        setState(() {
          _classes = data.map((item) => item as Map<String, dynamic>).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '❌ Failed to load classes')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching classes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    String newClassName = '';
    final TextEditingController divisionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Class', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Class Name (e.g. 5)',
                  hintText: 'Enter class name',
                  prefixIcon: Icon(Icons.class_),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.text,
                onChanged: (value) => newClassName = value,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: divisionController,
                decoration: InputDecoration(
                  labelText: 'divsion (comma-separated, e.g. A,B,C)',
                  hintText: 'Enter divsion',
                  prefixIcon: Icon(Icons.group),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (newClassName.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("⚠️ Please enter a valid class name.")),
                  );
                  return;
                }
                final divsion = divisionController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                try {
                  final result = await _apiService.createClass(
                    name: newClassName.trim(),
                    divsion: divsion.isNotEmpty ? divsion : null, schoolId: '',
                  );
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'] ?? 'Class added successfully')),
                    );
                    await _fetchClasses();
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['message'] ?? 'Failed to add class. Please check your permissions or input.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding class: $e')),
                  );
                }
              },
              icon: Icon(Icons.add),
              label: const Text('Add Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(String classId, String currentName, List<dynamic>? currentdivsion) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    final TextEditingController divisionController = TextEditingController(
      text: currentdivsion?.join(', ') ?? '',
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Edit Class"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Class Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: divisionController,
                decoration: InputDecoration(
                  labelText: "divsion (comma-separated, e.g. A,B,C)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final updatedName = nameController.text.trim();
                if (updatedName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("⚠️ Class name cannot be empty.")),
                  );
                  return;
                }
                final divsion = divisionController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                try {
                  final result = await _apiService.updateClass(
                    id: classId,
                    name: updatedName,
                    division: divsion.isNotEmpty ? divsion : null,
                  );
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'] ?? 'Class updated')),
                    );
                    await _fetchClasses();
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['message'] ?? 'Failed to update class. Please check your permissions or input.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating class: $e')),
                  );
                }
              },
              child: const Text("Save Changes"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteClass(String classId) async {
    final shouldDelete = await showDeleteConfirmationDialog(context);
    if (!shouldDelete) return;
    try {
      final result = await _apiService.deleteClass(classId);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Class deleted')),
        );
        await _fetchClasses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to delete class')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting class: $e')),
      );
    }
  }

  Future<bool> showDeleteConfirmationDialog(BuildContext context) async {
    final completer = Completer<bool>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this class? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () {
              completer.complete(false);
              Navigator.of(context).pop();
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              completer.complete(true);
              Navigator.of(context).pop();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    return completer.future;
  }

  Widget _buildClassTable() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manage Classes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo[800]),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: Icon(Icons.add),
                  label: Text("Add New Class"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A00E0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              Center(child: CircularProgressIndicator(color: Colors.indigo))
            else if (_classes.isEmpty)
              Center(
                child: Text(
                  'No classes found. Tap "+" to add one.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Class Name')),
                    DataColumn(label: Text('divsion')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _classes.map((cls) {
                    final String? classId = cls['_id']?.toString() ?? cls['id']?.toString();
                    final List<dynamic>? divsion = cls['division']; // Changed from divsion
                    return DataRow(
                      cells: [
                        DataCell(Text(classId ?? 'N/A')),
                        DataCell(Text(cls['name'] ?? 'N/A')),
                        DataCell(Text(divsion?.join(', ') ?? 'None')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.indigo),
                                tooltip: 'Edit / संपादित करा',
                                onPressed: () => _showEditDialog(classId ?? '', cls['name'] ?? '', cls['division']),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete / हटवा',
                                onPressed: () => _deleteClass(classId ?? ''),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A00E0),
        title: const Text('Manage Classes', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 1,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage School Classes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'View, edit or delete school classes and their divsion.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                _buildClassTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}