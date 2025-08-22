import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart'; // Added for consistent UI
import '../services/api_client.dart';

class AssignClassAndSubjectPage extends StatefulWidget {
  const AssignClassAndSubjectPage({super.key});

  @override
  State<AssignClassAndSubjectPage> createState() =>
      _AssignClassAndSubjectPageState();
}

class _AssignClassAndSubjectPageState
    extends State<AssignClassAndSubjectPage> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  bool _hasError = false;
  String? schoolId;
  String? currentUserId;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _classAssignments = [];
  Map<String, List<Map<String, dynamic>>> _teacherSubjects = {};

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    final userId = await _storage.read(key: 'user_id');
    if (userId == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    currentUserId = userId;

    try {
      final response = await _apiService.getUserById(userId);
      final data = response['data'] ?? response;
      if (['Admin', 'Clerk'].contains(data['role']?.toString())) {
        schoolId = data['schoolId']?.toString();
        await _fetchData();
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Authorization error: $e');
      }
    }
  }

 Future<void> _fetchData() async {
  setState(() {
    _isLoading = true;
    _hasError = false;
  });

  try {
    final classResult = await _apiService.getAllClasses(schoolId: schoolId!);
    final userResult = await _apiService.getAllUsers(schoolId: schoolId!);
    final subjectResult = await _apiService.getAllSubjects(schoolId: schoolId!);

    // ✅ Build classes
    _classes = _extractList(classResult).map((c) {
      c['id'] = (c['_id'] ?? c['id']).toString();
      return c;
    }).toList();

    // ✅ Build teachers list
    _users = _extractList(userResult)
        .where((u) => u['role']?.toString().toLowerCase() == 'teacher')
        .map((u) {
      u['id'] = (u['_id'] ?? u['id']).toString();
      return u;
    }).toList();

    // ✅ Build subjects
    _subjects = _extractList(subjectResult).map((s) {
      s['id'] = (s['_id'] ?? s['id']).toString();
      s['teacherId'] = (s['teacherId'] ?? '').toString();
      s['classId'] = (s['classId'] ?? '').toString();
      return s;
    }).toList();

    // ✅ Build class assignments directly from classes API
    _classAssignments.clear();
    for (var cls in _classes) {
      if (cls.containsKey('teachers') && cls['teachers'] is List) {
        for (var t in cls['teachers']) {
          _classAssignments.add({
            'classId': cls['id'],
            'className': cls['name'] ?? 'Unknown',
            'teacherId': (t['_id'] ?? t['id']).toString(),
            'teacherName': t['name'] ?? 'Unknown',
          });
        }
      }
    }

    // ✅ Build teacher subjects
    _teacherSubjects.clear();
    for (var user in _users) {
      final teacherId = user['id'].toString();
      final subjects = await _apiService.getSubjectsForTeacher(teacherId, '', classId: '');
    _teacherSubjects[teacherId] = subjects.map((s) {
  return {
    'subjectId': (s['subjectId'] ?? s['_id'] ?? s['id']).toString(),
    'subjectName': s['name'] ?? 'Unknown',
    'classId': (s['classId'] ?? '').toString(), // ✅ Ensure it's string
  };
}).toList();
    }

    setState(() => _isLoading = false);
  } catch (e) {
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
    if (kDebugMode) {
      print('Fetch data error: $e');
    }
  }
}

  List<Map<String, dynamic>> _extractList(dynamic res) {
    if (res is Map && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    } else if (res is List) {
      return List<Map<String, dynamic>>.from(res);
    }
    return [];
  }

  // ------------------- CLASS ASSIGNMENT --------------------
 void _showAssignClassDialog() {
  Map<String, dynamic>? selectedClass;
  List<Map<String, dynamic>> selectedTeachers = [];
  bool isSubmitting = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) {
        // ✅ Always filter properly
        final availableTeachers = selectedClass == null
            ? _users
            : _users.where((u) {
                return !_classAssignments.any(
                  (a) =>
                      a['classId'].toString() ==
                          selectedClass!['id'].toString() &&
                      a['teacherId'].toString() == u['id'].toString(),
                );
              }).toList();

        return AlertDialog(
          title: const Text("Assign Teachers to Class"),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Select class
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(
                    labelText: "Select Class",
                    border: OutlineInputBorder(),
                  ),
                  value: selectedClass,
                  items: _classes
                      .map((cls) => DropdownMenuItem(
                            value: cls,
                            child: Text(cls['name'] ?? 'Unknown'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setStateDialog(() {
                      selectedClass = val;
                      selectedTeachers.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // ✅ Select teacher
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(
                    labelText: "Select Teacher",
                    border: OutlineInputBorder(),
                  ),
                  items: availableTeachers
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u['name'] ?? 'Unknown'),
                          ))
                      .toList(),
                  onChanged: selectedClass == null
                      ? null
                      : (val) {
                          if (val != null &&
                              !selectedTeachers
                                  .any((t) => t['id'] == val['id'])) {
                            setStateDialog(() {
                              selectedTeachers.add(val);
                            });
                          }
                        },
                  hint: Text(availableTeachers.isEmpty
                      ? 'No teachers available'
                      : 'Select a teacher'),
                  disabledHint: const Text('Select a class first'),
                ),
                const SizedBox(height: 16),

                // ✅ Show selected teachers
                Wrap(
                  spacing: 8,
                  children: selectedTeachers
                      .map((t) => Chip(
                            label: Text(t['name'] ?? 'Unknown'),
                            deleteIcon: const Icon(Icons.cancel, size: 18),
                            onDeleted: () {
                              setStateDialog(() {
                                selectedTeachers.remove(t);
                              });
                            },
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: (selectedClass == null ||
                      selectedTeachers.isEmpty ||
                      isSubmitting)
                  ? null
                  : () async {
                      setStateDialog(() => isSubmitting = true);
                      try {
                        final res = await _apiService.addTeachersToClass(
                          classId: selectedClass!['id'].toString(),
                          teacherIds: selectedTeachers
                              .map((t) => t['id'].toString())
                              .toList(),
                          userId: currentUserId!,
                        );
                        setStateDialog(() => isSubmitting = false);

                        if (res['message'] ==
                            'Teachers added successfully') {
                          Navigator.pop(ctx);
                          await _fetchData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Teachers assigned successfully"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to assign: ${res['message'] ?? 'Unknown error'}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Assign"),
            ),
          ],
        );
      },
    ),
  );
}

 Future<void> _unassignTeacherFromClass(
    String classId, String teacherId, String teacherName, String className) async {
  // Validate if the teacher is assigned to the class
  final isAssigned = _classAssignments.any(
      (a) => a['classId'] == classId && a['teacherId'] == teacherId);
  if (!isAssigned) {
    if (kDebugMode) {
      print('Teacher $teacherId is not assigned to class $classId in _classAssignments');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $teacherName is not assigned to $className'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Confirm Unassign"),
      content: Text("Are you sure you want to unassign $teacherName from $className?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Unassign"),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    if (kDebugMode) {
      print('Unassigning teacher: $teacherId from class: $classId');
    }
    final res = await _apiService.removeTeachersFromClass(
      classId: int.parse(classId), // Ensure classId is an int
      teacherIds: [int.parse(teacherId)], // Send list of ints
    );

    if (kDebugMode) {
      print('Unassign class response: $res');
    }

    // Check the response message correctly
    if (res['message'] == 'Teachers removed successfully') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher unassigned successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Update _classAssignments to remove the unassigned teacher
      setState(() {
        _classAssignments.removeWhere(
          (a) => a['classId'] == classId && a['teacherId'] == teacherId,
        );
      });
      // Optionally, fetch fresh data to ensure consistency
      await _fetchData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unassign: ${res['message'] ?? 'Unknown error'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
    if (kDebugMode) {
      print('Unassign teacher error: $e');
    }
  }
}
  // ------------------- SUBJECT ASSIGNMENT --------------------
  void _showAssignSubjectDialog(String classId) {
  Map<String, dynamic>? selectedTeacher;
  Map<String, dynamic>? selectedSubject;
  bool isSubmitting = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) {
        final teachersInClass =
            _classAssignments.where((a) => a['classId'].toString() == classId.toString()).toList();

        // Show all subjects that belong to this class OR are unassigned
        final availableSubjects = _subjects
            .where((s) => s['classId'].toString() == classId.toString() || s['classId'].toString().isEmpty)
            .toList();

        return AlertDialog(
          title: const Text("Assign Subject to Teacher"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Select Teacher Dropdown
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: "Select Teacher",
                  border: OutlineInputBorder(),
                ),
                items: teachersInClass
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t['teacherName'] ?? 'Unknown'),
                        ))
                    .toList(),
                onChanged: (val) {
                  setStateDialog(() {
                    selectedTeacher = val;
                    selectedSubject = null;
                  });
                },
                validator: (val) => val == null ? 'Please select a teacher' : null,
              ),
              const SizedBox(height: 16),

              // Select Subject Dropdown
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(
                  labelText: "Select Subject",
                  border: OutlineInputBorder(),
                ),
                value: selectedSubject,
                items: availableSubjects.isEmpty
                    ? [
                        const DropdownMenuItem(
                          value: null,
                          enabled: false,
                          child: Text('No subjects available'),
                        )
                      ]
                    : availableSubjects.map((s) {
                        // Check if this subject is already assigned to the selected teacher
                        final assignedSubjects =
                            _teacherSubjects[selectedTeacher?['teacherId']?.toString()] ?? [];
                        final isAlreadyAssigned = assignedSubjects.any(
                          (as) => as['subjectId'].toString() == s['id'].toString(),
                        );

                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            isAlreadyAssigned
                                ? "${s['name']} (Assigned)"
                                : s['name'] ?? 'Unknown',
                          ),
                        );
                      }).toList(),
                onChanged: (val) {
                  setStateDialog(() {
                    selectedSubject = val;
                  });
                },
                validator: (val) => val == null ? 'Please select a subject' : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: (selectedTeacher == null || selectedSubject == null || isSubmitting)
                  ? null
                  : () async {
                      setStateDialog(() => isSubmitting = true);
                      try {
                        final res = await _apiService.assignSubjectToTeacher(
                          teacherId: selectedTeacher!['teacherId'].toString(),
                          subjectId: selectedSubject!['id'].toString(),
                          classId: classId.toString(),
                        );

                        setStateDialog(() => isSubmitting = false);

                        if (res['message'] == 'Subject assigned to teacher successfully') {
                          Navigator.pop(ctx);
                          await _fetchData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Subject assigned successfully"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to assign: ${res['message'] ?? 'Unknown error'}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Assign"),
            ),
          ],
        );
      },
    ),
  );
}

  Future<void> _unassignSubjectFromTeacher(
      String teacherId, String subjectId, String subjectName, String classId) async {
    final teacherName = _users.firstWhere(
      (u) => u['id'] == teacherId,
      orElse: () => {'name': 'Unknown'},
    )['name'];

    // Validate if the subject is assigned to the teacher
    final isAssigned = _teacherSubjects[teacherId]?.any((s) => s['subjectId'] == subjectId) ?? false;
    if (!isAssigned) {
      if (kDebugMode) {
        print('Subject $subjectId is not assigned to teacher $teacherId');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $subjectName is not assigned to $teacherName'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Unassign"),
        content: Text(
          "Are you sure you want to unassign $subjectName from $teacherName?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Unassign"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (kDebugMode) {
        print('Unassigning subject: $subjectId from teacher: $teacherId');
      }
   final res = await _apiService.addSubjectToTeacher(
  teacherId: 'uuid-of-teacher',
  subjectId: '',
);

debugPrint('✅ Result: $res');



      if (kDebugMode) {
        print('Unassign subject response: $res');
      }

      if (res['message'] == 'Subject unassigned from teacher successfully') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject unassigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unassign: ${res['message'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      if (kDebugMode) {
        print('Unassign subject error: $e');
      }
    }
  }

  // ------------------- BUILD UI --------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Error loading data", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Classes & Subjects"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Class Assignments",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                ElevatedButton.icon(
                  onPressed: _showAssignClassDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Assign Class"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_classAssignments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text("No class assignments", style: TextStyle(color: Colors.grey)),
              ),
            ..._classAssignments.map((a) {
              if (kDebugMode) {
                print('Rendering class assignment: ${a['teacherName']} -> ${a['className']} (classId: ${a['classId']})');
              }
              return ListTile(
                title: Text("${a['teacherName']} → ${a['className']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _unassignTeacherFromClass(
                    a['classId'],
                    a['teacherId'],
                    a['teacherName'],
                    a['className'],
                  ),
                ),
              );
            }),
            const Divider(height: 40),
            const Text(
              "Subject Assignments",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            ..._classes.map((cls) {
              final teachers = _classAssignments
                  .where((a) => a['classId'] == cls['id'])
                  .toList();
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ExpansionTile(
                  title: Text(cls['name'] ?? 'Unknown'),
                  subtitle: Text(
                    _subjects
                       .where((s) => s['classId'].toString() == cls['id'].toString())

                        .map((s) => s['name'])
                        .join(", "),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _showAssignSubjectDialog(cls['id']),
                        icon: const Icon(Icons.add),
                        label: const Text("Assign Subject"),
                      ),
                    ),
                    ...teachers.map((t) {
                      final subjects = _teacherSubjects[t['teacherId']] ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              t['teacherName'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...subjects
                             .where((s) => s['classId'].toString() == cls['id'].toString())

                              .map((s) {
                                if (kDebugMode) {
                                  print('Rendering subject assignment: ${s['subjectName']} for teacher ${t['teacherId']} in class ${cls['id']}');
                                }
                                return ListTile(
                                  title: Text(s['subjectName']),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _unassignSubjectFromTeacher(
                                      t['teacherId'],
                                      s['subjectId'],
                                      s['subjectName'],
                                      cls['id'],
                                    ),
                                  ),
                                );
                              }),
                        ],
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}