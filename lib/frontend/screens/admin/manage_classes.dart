import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import 'dart:async';

class ManageClassesWithDivision extends StatefulWidget {
  const ManageClassesWithDivision({super.key});

  @override
  State<ManageClassesWithDivision> createState() => _ManageClassesWithDivisionState();
}

class _ManageClassesWithDivisionState extends State<ManageClassesWithDivision> {
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
          SnackBar(
            content: Text(result['message'] ?? '❌ Failed to load classes'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching classes: $e'),
          backgroundColor: Colors.redAccent,
        ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Text(
            'Add New Class',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.indigo[900],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Class Name (e.g., 5)',
                  hintText: 'Enter class name',
                  prefixIcon: const Icon(Icons.class_, color: Colors.indigo),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.text,
                onChanged: (value) => newClassName = value,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: divisionController,
                decoration: InputDecoration(
                  labelText: 'Divisions (e.g., A,B,C)',
                  hintText: 'Enter divisions, comma-separated',
                  prefixIcon: const Icon(Icons.group, color: Colors.indigo),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (newClassName.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("⚠️ Please enter a valid class name"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                final divisions = divisionController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                try {
                  final result = await _apiService.createClass(
                    name: newClassName.trim(),
               
                    schoolId: '',
                  );
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Class added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _fetchClasses();
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['message'] ?? 'Failed to add class',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding class: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add Class',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(String classId, String currentName, List<dynamic>? currentDivisions) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    final TextEditingController divisionController = TextEditingController(
      text: currentDivisions?.join(', ') ?? '',
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Text(
            'Edit Class',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.indigo[900],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Class Name',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: divisionController,
                decoration: InputDecoration(
                  labelText: 'Divisions (e.g., A,B,C)',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedName = nameController.text.trim();
                if (updatedName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("⚠️ Class name cannot be empty"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                final divisions = divisionController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                try {
                  final result = await _apiService.updateClass(
                    id: classId,
                    name: updatedName,
                    division: divisions.isNotEmpty ? divisions : null,
                  );
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Class updated'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _fetchClasses();
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['message'] ?? 'Failed to update class',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating class: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: Text(
                'Save Changes',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
          SnackBar(
            content: Text(result['message'] ?? 'Class deleted'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchClasses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete class'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting class: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<bool> showDeleteConfirmationDialog(BuildContext context) async {
    final completer = Completer<bool>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          'Confirm Delete',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.indigo[900],
          ),
        ),
        content: Text(
          'Are you sure you want to delete this class? This action cannot be undone.',
          style: GoogleFonts.poppins(color: Colors.grey[800]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              completer.complete(false);
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              completer.complete(true);
              Navigator.of(context).pop();
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return completer.future;
  }

  Widget _buildClassTable() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manage Classes',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[900],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    'Add New Class',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.indigo,
                  strokeWidth: 3,
                ),
              )
            else if (_classes.isEmpty)
              Center(
                child: Text(
                  'No classes found. Tap "+" to add one.',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.indigo[50]),
                  dataRowHeight: 60,
                  columns: [
                    DataColumn(
                      label: Text(
                        'ID',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Class Name',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Divisions',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Actions',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  rows: _classes.map((cls) {
                    final String? classId = cls['_id']?.toString() ?? cls['id']?.toString();
                    final List<dynamic>? divisions = cls['division'];
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            classId ?? 'N/A',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        DataCell(
                          Text(
                            cls['name'] ?? 'N/A',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        DataCell(
                          Text(
                            divisions?.join(', ') ?? 'None',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.indigo),
                                tooltip: 'Edit',
                                onPressed: () => _showEditDialog(classId ?? '', cls['name'] ?? '', cls['division']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                tooltip: 'Delete',
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
        backgroundColor: Colors.indigo[700],
        title: Text(
          'Manage Classes',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo[700]!, Colors.indigo[200]!],
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
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'View, edit, or delete school classes and their divisions.',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
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