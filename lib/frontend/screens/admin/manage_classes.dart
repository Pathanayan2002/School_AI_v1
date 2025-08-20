import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';

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
          _classes = data.map((item) => {
                'id': item['id'] ?? item['_id'],
                'name': item['name'] ?? 'Unknown',
                'divisions': item['divisions'] ?? [],
              }).toList();
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
                        content: Text(result['message'] ?? 'Failed to add class'),
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
                  labelText: 'Divisions',
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
            ElevatedButton.icon(
              onPressed: () async {
                final updatedName = nameController.text.trim();
                final divisions = divisionController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (updatedName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("⚠️ Please enter a valid class name"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                try {
                  final result = await _apiService.updateClass(
                    id: classId,
                    name: updatedName,
                   
                    schoolId: '',
                  );
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Class updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _fetchClasses();
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Failed to update class'),
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
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(
                'Update Class',
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

  void _confirmDeleteClass(String classId, String className) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Delete Class',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.indigo[900],
            ),
          ),
          content: Text(
            'Are you sure you want to delete class $className?',
            style: GoogleFonts.poppins(),
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
                try {
                  final result = await _apiService.deleteClass(classId);
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Class deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _fetchClasses();
                    Navigator.of(context).pop();
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
              },
              icon: const Icon(Icons.delete, color: Colors.white),
              label: Text(
                'Delete',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Classes',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.indigo[700],
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddDialog,
            tooltip: 'Add Class',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: _classes.isEmpty
                        ? Center(
                            child: Text(
                              'No classes found',
                              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _classes.length,
                            itemBuilder: (context, index) {
                              final classData = _classes[index];
                              final classId = classData['id'].toString();
                              final className = classData['name'] ?? 'Unknown';
                              final divisions = List<String>.from(classData['divisions'] ?? []);

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  title: Text(
                                    className,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Divisions: ${divisions.isEmpty ? 'None' : divisions.join(', ')}',
                                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _showEditDialog(classId, className, divisions),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _confirmDeleteClass(classId, className),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}