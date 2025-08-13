import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:convert';

class AssignClassPage extends StatefulWidget {
  const AssignClassPage({super.key});

  @override
  State<AssignClassPage> createState() => _AssignClassPageState();
}

class _AssignClassPageState extends State<AssignClassPage> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasError = false;
  String? currentUserRole;
  String? schoolId;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    final userId = await _storage.read(key: 'user_id');
    if (!mounted || userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }
    setState(() => currentUserId = userId);
    try {
      final response = await _apiService.getUserById(userId);
      if (!mounted) return;
      if (response['success'] && ['Admin', 'Clerk'].contains(response['data']['role']?.toString())) {
        setState(() {
          currentUserRole = response['data']['role']?.toString();
          schoolId = response['data']['schoolId']?.toString();
        });
        await _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: Only Admins or Clerks can assign classes')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking authorization: $e')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _fetchData() async {
    if (!mounted || schoolId == null || schoolId!.isEmpty || currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: School ID or User ID not found')),
        );
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
      _classes = [];
      _users = [];
      _assignments = [];
    });
    try {
      final classResult = await _apiService.getAllClasses(schoolId: schoolId!);
      final userResult = await _apiService.getAllUsers(schoolId: schoolId!);
      if (!mounted) return;
      if (kDebugMode) {
        print('Class data: ${jsonEncode(classResult['data'])}');
        print('User data: ${jsonEncode(userResult['data'])}');
      }
      if (classResult['success'] && userResult['success']) {
        final classes = (classResult['data'] as List<dynamic>? ?? [])
            .cast<Map<dynamic, dynamic>>()
            .map((cls) => {...cls.cast<String, dynamic>(), 'id': (cls['id'] ?? cls['_id'])?.toString()})
            .where((cls) => cls['schoolId']?.toString() == schoolId)
            .toList();
        final users = (userResult['data'] as List<dynamic>? ?? [])
            .cast<Map<dynamic, dynamic>>()
            .map((user) => {...user.cast<String, dynamic>(), 'id': (user['id'] ?? user['_id'])?.toString()})
            .where((user) => user['role']?.toLowerCase() == 'teacher')
            .toList();
        final assignments = classes.expand((cls) {
          final teachers = (cls['teachers'] as List<dynamic>? ?? []).map((t) {
            final teacherId = t is Map ? t.cast<String, dynamic>()['id']?.toString() : t.toString();
            final teacher = users.firstWhere(
              (u) => u['id'] == teacherId,
              orElse: () => {'id': teacherId, 'name': 'Unknown'},
            );
            return {
              'id': teacherId,
              'name': teacher['name']?.toString() ?? 'Unknown',
            };
          }).cast<Map<String, dynamic>>().toList();
          if (kDebugMode) {
            print('Class ${cls['id']}: Teachers = ${jsonEncode(teachers)}');
          }
          return teachers.map((teacher) {
            return {
              'classId': cls['id']?.toString() ?? '',
              'className': cls['name']?.toString() ?? 'N/A',
              'teacherId': teacher['id']?.toString() ?? '',
              'teacherName': teacher['name']?.toString() ?? 'N/A',
            };
          }).toList();
        }).toList();
        if (kDebugMode) {
          print('Assignments: ${jsonEncode(assignments)}');
        }
        setState(() {
          _classes = classes.cast<Map<String, dynamic>>();
          _users = users.cast<Map<String, dynamic>>();
          _assignments = assignments;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(classResult['message'] ?? userResult['message'] ?? 'Failed to load data')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  void _showAssignDialog() {
    Map<String, dynamic>? selectedClass;
    List<Map<String, dynamic>> selectedTeachers = [];
    bool isDialogSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Assign Teachers to Class', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: InputDecoration(
                      labelText: 'Select Class',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    items: _classes.map((cls) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: cls,
                        child: Text(cls['name']?.toString() ?? 'N/A'),
                      );
                    }).toList(),
                    onChanged: isDialogSubmitting ? null : (value) => setDialogState(() => selectedClass = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Select Teachers',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    items: _users
                        .where((user) => !_assignments.any((a) => a['classId'] == selectedClass?['id'] && a['teacherId'] == user['id']))
                        .map((user) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: user,
                        child: Text('${user['name']?.toString() ?? 'N/A'} (${user['enrollmentId']?.toString() ?? 'N/A'})'),
                      );
                    }).toList(),
                    onChanged: isDialogSubmitting
                        ? null
                        : (value) {
                            if (value != null && !selectedTeachers.contains(value)) {
                              setDialogState(() => selectedTeachers.add(value));
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: selectedTeachers.map((teacher) {
                      return Chip(
                        label: Text(teacher['name']?.toString() ?? 'N/A'),
                        onDeleted: isDialogSubmitting
                            ? null
                            : () => setDialogState(() => selectedTeachers.remove(teacher)),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogSubmitting ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isDialogSubmitting || selectedClass == null || selectedTeachers.isEmpty || currentUserId == null
                      ? null
                      : () async {
                          setDialogState(() => isDialogSubmitting = true);
                          setState(() => _isSubmitting = true);
                          try {
                            final response = await _apiService.addTeachersToClass(
                              classId: selectedClass!['id']!.toString(),
                              teacherIds: selectedTeachers.map((t) => t['id']!.toString()).toList(),
                              userId: currentUserId!,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            if (response['success']) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(response['data']['message'] ?? 'Teachers assigned successfully')),
                              );
                              await _fetchData();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(response['message'] ?? 'Failed to assign teachers')),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error assigning teachers: $e')),
                            );
                          } finally {
                            setDialogState(() => isDialogSubmitting = false);
                            if (mounted) setState(() => _isSubmitting = false);
                          }
                        },
                  child: Text('Assign', style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _showUnassignConfirmationDialog(String teacherName, String className) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Unassign Teacher', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Unassign $teacherName from $className?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Unassign', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

 Future<void> _unassignTeacher(String classId, String teacherId, String className, String teacherName) async {
  if (!mounted || classId.isEmpty || teacherId.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid class or teacher ID')),
      );
    }
    return;
  }

  // Show confirmation dialog
  final shouldUnassign = await _showUnassignConfirmationDialog(teacherName, className);
  if (!mounted || !shouldUnassign) return;

  setState(() => _isSubmitting = true);
  try {
    // Fetch the latest class data to validate the assignment
    if (kDebugMode) {
      print('Fetching class data for validation: classId=$classId');
    }
    final classData = await _apiService.getClassById(classId);
    if (!mounted) return;
    if (kDebugMode) {
      print('Class data response: ${jsonEncode(classData)}');
    }
    if (!classData['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to verify class: ${classData['message'] ?? 'Unknown error'}')),
      );
      return;
    }
    final teachers = (classData['data']['teachers'] as List<dynamic>? ?? [])
        .map((t) => t is Map ? t['id']?.toString() : t.toString())
        .toList();
    if (!teachers.contains(teacherId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$teacherName is not assigned to $className')),
      );
      await _fetchData(); // Refresh UI to remove stale assignment
      return;
    }

    // Attempt to unassign the teacher from the class
    if (kDebugMode) {
      print('Unassigning teacher: classId=$classId, teacherId=$teacherId');
    }
    final result = await _apiService.removeTeachersFromClass(
      classId,
      teacherIds: [teacherId],
    );
    if (!mounted) return;
    if (kDebugMode) {
      print('Unassign response: ${jsonEncode(result)}');
    }

    // Check backend response
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['data']['message'] ?? 'Teacher unassigned successfully')),
      );
      
      // Now update the UI by removing the teacher from the _assignments list
      setState(() {
        _assignments.removeWhere(
          (assignment) => assignment['classId'] == classId && assignment['teacherId'] == teacherId,
        );
      });

      // Optionally, fetch the data again to ensure the UI stays in sync with the backend
      await _fetchData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.contains('not assigned')
                ? '$teacherName is no longer assigned to $className. Refreshing data.'
                : (result['message'] ?? 'Failed to unassign teacher: ${result['error'] ?? 'Unknown error'}'),
          ),
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    if (kDebugMode) {
      print('Error during unassignment: $e');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error unassigning teacher: $e')),
    );
    await _fetchData(); // Refresh data on error to recover
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}

  Widget _buildAssignmentTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Class Assignments',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading || _isSubmitting ? null : _showAssignDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Assign Teachers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading || _isSubmitting ? null : _fetchData,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _hasError
                ? Center(
                    child: Column(
                      children: [
                        Text('Failed to load assignments', style: GoogleFonts.poppins(color: Colors.white)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _fetchData,
                          child: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  )
                : _assignments.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.class_outlined, size: 60, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text('No class assignments found', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                        ],
                      )
                    : Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
                            columns: const [
                              DataColumn(label: Text('Class')),
                              DataColumn(label: Text('Teacher')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _assignments.map((assignment) {
                              return DataRow(cells: [
                                DataCell(Text(assignment['className']?.toString() ?? 'N/A')),
                                DataCell(Text(assignment['teacherName']?.toString() ?? 'N/A')),
                                DataCell(IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Unassign',
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _unassignTeacher(
                                            assignment['classId']?.toString() ?? '',
                                            assignment['teacherId']?.toString() ?? '',
                                            assignment['className']?.toString() ?? '',
                                            assignment['teacherName']?.toString() ?? '',
                                          ),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                  title: const Text('Assign Classes'),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(child: _buildAssignmentTable()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}