import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import 'dart:convert';  // For jsonEncode in debugPrint
import 'package:flutter/foundation.dart' show debugPrint;

class ManageClasses extends StatefulWidget {
  const ManageClasses({super.key});

  @override
  State<ManageClasses> createState() => _ManageClassesState();
}

class _ManageClassesState extends State<ManageClasses> {
  late ApiService _apiService;
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _fetchClasses();
  }

  bool _isSuccess(dynamic result) {
    if (result == null) return false;
    if (result['success'] == true || result['success'] == 'true' || result['success'] == 1) return true;
    if (result['status'] == 200 || result['status'] == '200' || result['status'] == true) return true;
    if (result['code'] == 200) return true;
    if (result['statusCode'] == 200 || result['statusCode'] == 201) return true;
    return false;
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    final schoolId = await _apiService.getCurrentSchoolId() ?? '';
    if (schoolId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('School ID not found. Please login again.'), backgroundColor: Colors.redAccent),
      );
      setState(() => _isLoading = false);
      return;
    }
    try {
      final result = await _apiService.getAllClasses(schoolId: schoolId);
      debugPrint('Fetch Classes Response: ${jsonEncode(result)}');
      if (_isSuccess(result)) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _classes = data.map((item) => {
                'id': item['id'] ?? item['_id'],
                'name': item['name'] ?? 'Unknown',
              }).toList();
        });
      } else {
        debugPrint('Fetch Classes Error: ${result['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? '❌ Failed to load classes'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      debugPrint('Fetch Classes Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching classes: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkClassExists(String className) async {
    final schoolId = await _apiService.getCurrentSchoolId() ?? '';
    if (schoolId.isEmpty) return false;
    try {
      final result = await _apiService.getAllClasses(schoolId: schoolId);
      if (_isSuccess(result)) {
        final List<dynamic> data = result['data'] ?? [];
        return data.any((item) => (item['name']?.toString().toLowerCase() ?? '') == className.toLowerCase());
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _showAddDialog() {
    String newClassName = '';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Text('Add New Class', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.indigo[900])),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Class Name (e.g., 1A)',
                    hintText: 'Enter class name like 1A, 2B',
                    prefixIcon: const Icon(Icons.class_, color: Colors.indigo),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  keyboardType: TextInputType.text,
                  onChanged: (value) => newClassName = value,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600]))),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () async {
                  final trimmedName = newClassName.trim();
                  if (trimmedName.isEmpty || !RegExp(r'^\d+[A-Z]$').hasMatch(trimmedName)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("⚠️ Please enter a valid class name (e.g., 1A, 2B)"), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  final schoolId = await _apiService.getCurrentSchoolId() ?? '';
                  if (schoolId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("⚠️ School ID not found"), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  final classExists = await _checkClassExists(trimmedName);
                  if (classExists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("⚠️ Class $trimmedName already exists"), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  setDialogState(() => _isSubmitting = true);
                  try {
                    final result = await _apiService.createClass(name: trimmedName, schoolId: schoolId);
                    debugPrint('Add Class Response: ${jsonEncode(result)}');
                    if (_isSuccess(result)) {
                      setState(() {
                        _classes.add({
                          'id': result['data']?['id'] ?? result['id'] ?? DateTime.now().millisecondsSinceEpoch,
                          'name': trimmedName,
                        });
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message']?.toString() ?? 'Class added successfully'), backgroundColor: Colors.green),
                      );
                      Navigator.pop(context);
                      await _fetchClasses();  // Optional fallback refresh
                    } else {
                      debugPrint('Add Class Error: ${result['message']}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message']?.toString() ?? 'Failed to add class'), backgroundColor: Colors.redAccent),
                      );
                    }
                  } catch (e) {
                    debugPrint('Add Class Exception: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding class: $e'), backgroundColor: Colors.redAccent),
                    );
                  } finally {
                    setDialogState(() => _isSubmitting = false);
                  }
                },
                icon: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add, color: Colors.white),
                label: Text('Add Class', style: GoogleFonts.poppins(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(String classId, String currentName) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Text('Edit Class', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.indigo[900])),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Class Name (e.g., 1A)',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600]))),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () async {
                  final updatedName = nameController.text.trim();
                  if (updatedName.isEmpty || !RegExp(r'^\d+[A-Z]$').hasMatch(updatedName)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("⚠️ Please enter a valid class name (e.g., 1A, 2B)"), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  final schoolId = await _apiService.getCurrentSchoolId() ?? '';
                  if (schoolId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("⚠️ School ID not found"), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  final classExists = await _checkClassExists(updatedName);
                  if (classExists && updatedName != currentName) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("⚠️ Class $updatedName already exists"), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  setDialogState(() => _isSubmitting = true);
                  try {
                    final result = await _apiService.updateClass(id: classId, name: updatedName, schoolId: schoolId);
                    debugPrint('Update Class Response: ${jsonEncode(result)}');
                    if (_isSuccess(result)) {
                      setState(() {
                        final index = _classes.indexWhere((c) => c['id'].toString() == classId);
                        if (index != -1) _classes[index]['name'] = updatedName;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message']?.toString() ?? 'Class updated successfully'), backgroundColor: Colors.green),
                      );
                      Navigator.pop(context);
                      await _fetchClasses();  // Optional fallback refresh
                    } else {
                      debugPrint('Update Class Error: ${result['message']}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message']?.toString() ?? 'Failed to update class'), backgroundColor: Colors.redAccent),
                      );
                    }
                  } catch (e) {
                    debugPrint('Update Class Exception: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating class: $e'), backgroundColor: Colors.redAccent),
                    );
                  } finally {
                    setDialogState(() => _isSubmitting = false);
                  }
                },
                icon: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, color: Colors.white),
                label: Text('Update Class', style: GoogleFonts.poppins(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteClass(String classId, String className) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Delete Class', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.indigo[900])),
            content: Text('Are you sure you want to delete class $className?', style: GoogleFonts.poppins()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600]))),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () async {
                  final schoolId = await _apiService.getCurrentSchoolId() ?? '';
                  if (schoolId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("⚠️ School ID not found"), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  setDialogState(() => _isSubmitting = true);
                  try {
                    final result = await _apiService.deleteClass(classId);
                    debugPrint('Delete Class Response: ${jsonEncode(result)}');
                    if (_isSuccess(result)) {
                      setState(() {
                        _classes.removeWhere((c) => c['id'].toString() == classId);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message']?.toString() ?? 'Class deleted successfully'), backgroundColor: Colors.green),
                      );
                      Navigator.pop(context);
                      await _fetchClasses();  // Optional fallback refresh
                    } else {
                      debugPrint('Delete Class Error: ${result['message']}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message']?.toString() ?? 'Failed to delete class'), backgroundColor: Colors.redAccent),
                      );
                    }
                  } catch (e) {
                    debugPrint('Delete Class Exception: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting class: $e'), backgroundColor: Colors.redAccent),
                    );
                  } finally {
                    setDialogState(() => _isSubmitting = false);
                  }
                },
                icon: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.delete, color: Colors.white),
                label: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Classes', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.indigo[700],
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: _showAddDialog, tooltip: 'Add Class')],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: _classes.isEmpty
                        ? Center(child: Text('No classes found', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _classes.length,
                            itemBuilder: (context, index) {
                              final classData = _classes[index];
                              final classId = classData['id'].toString();
                              final className = classData['name'] ?? 'Unknown';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  title: Text(className, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditDialog(classId, className)),
                                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDeleteClass(classId, className)),
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