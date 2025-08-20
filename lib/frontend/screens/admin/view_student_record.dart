import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class AdminClerkStudentViewPage extends StatefulWidget {
  const AdminClerkStudentViewPage({super.key, required initialClassId});

  @override
  State<AdminClerkStudentViewPage> createState() =>
      _AdminClerkStudentViewPageState();
}

class _AdminClerkStudentViewPageState
    extends State<AdminClerkStudentViewPage> {
  final ApiService _apiService = ApiService();
  String? _userId;
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
      _userId = await _apiService.getCurrentUserId();
      _schoolId = await _apiService.getCurrentSchoolId();

      if (_userId == null || _schoolId == null) {
        setState(() {
          _errorMessage = 'User or school not found. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final classResponse = await _apiService.getAllClasses(schoolId: '');
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
          _studentDetails[studentId] =
              response['data'] as Map<String, dynamic>;
        });
      } else {
        setState(() {
          _studentDetails[studentId] = null;
          _errorMessage =
              response['message'] ?? 'Failed to load student details.';
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

  /// ✅ Avatar widget (fixed)
  Widget buildAvatar(String? photoUrl, {double radius = 26}) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: Icon(Icons.person, size: radius, color: Colors.grey),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, size: radius, color: Colors.grey);
          },
        ),
      ),
    );
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildAvatar(student['photo']?.toString(), radius: 60),
              const SizedBox(height: 16),
              Text(
                student['name']?.toString() ?? 'Unknown Student',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 12),
              Divider(thickness: 1, color: Colors.grey[300]),
              const SizedBox(height: 8),

              // Info rows
              _buildDetailRow(Icons.confirmation_number, 'Roll No',
                  student['rollNo']),
              _buildDetailRow(Icons.phone, 'Parent Phone',
                  student['parentsPhno']),
              _buildDetailRow(Icons.people, 'Caste', student['caste']),
              _buildDetailRow(Icons.person, 'Sex', student['sex']),
              _buildDetailRow(Icons.credit_card, 'Apar ID', student['aparId']),
              _buildDetailRow(Icons.badge, 'Saral ID', student['saralId']),
              _buildDetailRow(Icons.phone_android, 'Mobile',
                  student['mobileNumber']),
              _buildDetailRow(
                  Icons.cake,
                  'DOB',
                  student['dob'] != null
                      ? dateFormatter.format(DateTime.parse(student['dob']))
                      : null),
              _buildDetailRow(
                  Icons.calendar_today,
                  'Admission Date',
                  student['admissionDate'] != null
                      ? dateFormatter
                          .format(DateTime.parse(student['admissionDate']))
                      : null),
              _buildDetailRow(Icons.home, 'Address', student['address']),
              _buildDetailRow(
                  Icons.school, 'Previous School', student['previousSchool']),
              _buildDetailRow(Icons.numbers, 'Register Number',
                  student['registerNumber']),
              _buildDetailRow(
                  Icons.family_restroom, 'Mother\'s Name', student['motherName']),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Text(
            "$label:",
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Records',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent))
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
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: DropdownButtonFormField<String>(
                                value: _selectedClassId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Class',
                                  border: InputBorder.none,
                                ),
                                items: _classes.map((classData) {
                                  return DropdownMenuItem<String>(
                                    value: classData['id'].toString(),
                                    child: Text(
                                      classData['name']?.toString() ??
                                          'Unknown Class',
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
                          const Text(
                            "Students",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: _buildStudentList()),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStudentList() {
    if (_selectedClassId == null) {
      return const Center(child: Text("Please select a class."));
    }

    final selectedClass = _classes.firstWhere(
      (classData) => classData['id'].toString() == _selectedClassId,
      orElse: () => <String, dynamic>{},
    );
    final students = (selectedClass['students'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    if (students.isEmpty) {
      return const Center(child: Text("No students available in this class."));
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
            leading: buildAvatar(student['photo']?.toString()),
            title: Text(
              student['name']?.toString() ?? 'Unknown Student',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              "Roll No: ${student['rollNo'] ?? 'N/A'}",
              style: const TextStyle(color: Colors.black54),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.blueAccent),
            onTap: () async {
              await _loadStudentDetails(studentId);
              _showStudentDetailsDialog(context, studentId);
            },
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
          const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Retry", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Text("No classes available.",
          style: TextStyle(fontSize: 16, color: Colors.grey)),
    );
  }
}
