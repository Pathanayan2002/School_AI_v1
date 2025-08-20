import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class StudentRecordViewPage extends StatefulWidget {
  const StudentRecordViewPage({super.key});

  @override
  State<StudentRecordViewPage> createState() => _StudentRecordViewPageState();
}

class _StudentRecordViewPageState extends State<StudentRecordViewPage> {
  final ApiService _apiService = ApiService();
  String? _teacherId;
  String? _schoolId;
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  Map<String, Map<String, dynamic>?> _studentDetails = {};
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.init();
      _teacherId = await _apiService.getCurrentUserId();
      _schoolId = await _apiService.getCurrentSchoolId();

      if (_teacherId == null || _schoolId == null) {
        setState(() {
          _errorMessage = 'Teacher or school not found. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final classResponse = await _apiService.getClassesByTeacherId(_teacherId!);
      if (kDebugMode) debugPrint('Class Response: $classResponse');

      if (classResponse['success'] && classResponse['data'] != null) {
        _classes = List<Map<String, dynamic>>.from(classResponse['data']);
        if (_classes.isNotEmpty) {
          _selectedClassId = _classes.first['id'].toString();
        }
      } else {
        _errorMessage = classResponse['message'] ?? 'Failed to load classes.';
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
      if (kDebugMode) debugPrint('Error in _loadInitialData: $e');
    }
  }

  Future<void> _loadStudentDetails(String studentId) async {
    try {
      final response = await _apiService.getStudentById(studentId);
      if (kDebugMode) debugPrint('Student Details for $studentId: $response');

      if (response['success'] && response['data'] != null) {
        setState(() {
          _studentDetails[studentId] = response['data'] as Map<String, dynamic>;
        });
      } else {
        setState(() {
          _studentDetails[studentId] = null;
          _errorMessage = response['message'] ?? 'Failed to load student details.';
        });
      }
    } catch (e) {
      setState(() {
        _studentDetails[studentId] = null;
        _errorMessage = 'Error loading student details: $e';
      });
      if (kDebugMode) debugPrint('Error in _loadStudentDetails: $e');
    }
  }

  void _showStudentDetailsDialog(BuildContext context, String studentId) {
    final student = _studentDetails[studentId];
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student details not available.')),
      );
      return;
    }

    final dateFormatter = DateFormat('dd MMM yyyy');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: student['photo'] != null
                      ? NetworkImage(student['photo'] as String)
                      : null,
                  backgroundColor: Colors.grey[200],
                  child: student['photo'] == null
                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  student['name']?.toString() ?? 'Unknown Student',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Student Details',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Roll No', student['rollNo']),
                _buildDetailRow('Parent\'s Phone', student['parentsPhno']),
                _buildDetailRow('Caste', student['caste']),
                _buildDetailRow('Sub-Caste', student['subCaste']),
                _buildDetailRow('Sex', student['sex']),
                _buildDetailRow('Apar ID', student['aparId']),
                _buildDetailRow('Saral ID', student['saralId']),
                _buildDetailRow('Mobile Number', student['mobileNumber']),
                _buildDetailRow(
                  'Date of Birth',
                  student['dob'] != null
                      ? dateFormatter.format(DateTime.parse(student['dob'] as String))
                      : null,
                ),
                _buildDetailRow(
                  'Admission Date',
                  student['admissionDate'] != null
                      ? dateFormatter.format(DateTime.parse(student['admissionDate'] as String))
                      : null,
                ),
                _buildDetailRow('Address', student['address']),
                _buildDetailRow('Mother Tongue', student['motherToung'] ?? student['motherTongue']),
                _buildDetailRow('Previous School', student['previousSchool']),
                _buildDetailRow('Register Number', student['registerNumber']),
                _buildDetailRow('Mother\'s Name', student['motherName']),
                if (student['marks'] != null && student['marks'] is Map)
                  _buildDetailRow('Marks', (student['marks'] as Map).toString()),
                if (student['adharNumber'] != null)
                  _buildDetailRow('Aadhar Card', 'Available (click to view)'),
                if (student['bankPassbook'] != null)
                  _buildDetailRow('Bank Passbook', 'Available (click to view)'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (student['adharNumber'] != null)
                      TextButton(
                        onPressed: () {
                          debugPrint('Open Aadhar: ${student['adharNumber']}');
                        },
                        child: const Text(
                          'View Aadhar',
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                      ),
                    if (student['bankPassbook'] != null)
                      TextButton(
                        onPressed: () {
                          debugPrint('Open Bank Passbook: ${student['bankPassbook']}');
                        },
                        child: const Text(
                          'View Passbook',
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Records',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _errorMessage != null
              ? _buildErrorView()
              : _classes.isEmpty
                  ? _buildEmptyView()
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedClassId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Class',
                                  labelStyle: TextStyle(color: Colors.blueAccent),
                                  border: InputBorder.none,
                                ),
                                items: _classes.map((classData) {
                                  return DropdownMenuItem<String>(
                                    value: classData['id'].toString(),
                                    child: Text(
                                      classData['name']?.toString() ?? 'Unknown Class',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedClassId = value;
                                    _studentDetails.clear();
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Students',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _buildStudentList(),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStudentList() {
    if (_selectedClassId == null) {
      return const Center(
        child: Text(
          'Please select a class.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final selectedClass = _classes.firstWhere(
      (classData) => classData['id'].toString() == _selectedClassId,
      orElse: () => <String, dynamic>{},
    );
    final students = (selectedClass['students'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    if (students.isEmpty) {
      return const Center(
        child: Text(
          'No students available in this class.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final studentId = student['id'].toString();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: GestureDetector(
              onTap: () async {
                await _loadStudentDetails(studentId);
                _showStudentDetailsDialog(context, studentId);
              },
              child: CircleAvatar(
                radius: 24,
                backgroundImage: student['photo'] != null
                    ? NetworkImage(student['photo'] as String)
                    : null,
                backgroundColor: Colors.grey[200],
                child: student['photo'] == null
                    ? const Icon(Icons.person, size: 24, color: Colors.grey)
                    : null,
              ),
            ),
            title: GestureDetector(
              onTap: () async {
                await _loadStudentDetails(studentId);
                _showStudentDetailsDialog(context, studentId);
              },
              child: Text(
                student['name']?.toString() ?? 'Unknown Student',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            subtitle: Text(
              'Roll No: ${student['rollNo']?.toString() ?? 'N/A'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Text(
        'No classes assigned to this teacher.',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}