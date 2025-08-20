import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class AddNewStudent extends StatefulWidget {
  const AddNewStudent({super.key});

  @override
  State<AddNewStudent> createState() => _AddNewStudentState();
}

class _AddNewStudentState extends State<AddNewStudent> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController registrController = TextEditingController();
  final TextEditingController rollController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController motherController = TextEditingController();
  final TextEditingController fatherController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController aadharNumberController = TextEditingController();
  final TextEditingController divisionController = TextEditingController();
  final TextEditingController subCasteController = TextEditingController();
  final TextEditingController aparIdController = TextEditingController();
  final TextEditingController saralIdController = TextEditingController();
  final TextEditingController admissionDateController = TextEditingController();
  final TextEditingController motherTongueController = TextEditingController();
  final TextEditingController previousSchoolController = TextEditingController();
  final TextEditingController parentsPhnoController = TextEditingController();
  final TextEditingController schoolIdController = TextEditingController();

  // Dropdown selections
  String? selectedCaste;
  String? selectedClass;
  String? selectedSex;

  // Files
  XFile? studentPhoto;
  XFile? aadharPhoto;
  XFile? passbookPhoto;

  // Dropdown options
  final List<String> casteOptions = ['सामान्य', 'ओबीसी', 'एसी', 'एसटी', 'इतर'];
  final List<String> sexOptions = ['Male', 'Female', 'Other'];

  // For class dropdown and loading states
  List<Map<String, dynamic>> _classList = [];
  bool _isLoadingClasses = false;
  bool _isLoading = false;
  String? _rollNumberError; // custom roll number error

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSchoolId();
    });
  }

  Future<void> _fetchSchoolId() async {
    try {
      final schoolId = await _apiService.getCurrentSchoolId();
      if (schoolId != null) {
        setState(() {
          schoolIdController.text = schoolId;
        });
        await _fetchClasses();
      } else {
        _showSnack('Failed to fetch school ID', Colors.red);
      }
    } catch (e) {
      _showSnack('Error fetching school ID: $e', Colors.red);
    }
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoadingClasses = true);

    try {
      final result =
          await _apiService.getAllClasses(schoolId: schoolIdController.text.trim());
      if (result['success'] == true && result['data'] is List) {
        setState(() {
          _classList = List<Map<String, dynamic>>.from(result['data']);
        });
      } else {
        _showSnack('Failed to load classes: ${result['message']}', Colors.red);
      }
    } catch (e) {
      _showSnack('Error fetching classes: $e', Colors.red);
    } finally {
      setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _validateRollNumber() async {
    final rollNo = rollController.text.trim();
    if (rollNo.isEmpty || selectedClass == null) return;

    try {
      final response = await _apiService.getAllStudents();
      if (response['success'] == true && response['data'] is List) {
        final students = List<Map<String, dynamic>>.from(response['data']);
        final exists = students.any((s) =>
            s['rollNo'].toString() == rollNo &&
            s['classId'].toString() == selectedClass);
        setState(() {
          _rollNumberError =
              exists ? 'Roll Number already exists in this class' : null;
        });
      }
    } catch (e) {
      _showSnack('Error checking roll number: $e', Colors.red);
    }
  }

  Future<void> pickImage(ImageSource source, String type) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        if (type == 'photo') studentPhoto = pickedFile;
        if (type == 'aadhar') aadharPhoto = pickedFile;
        if (type == 'passbook') passbookPhoto = pickedFile;
      });
    }
  }

  Future<void> selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rollNumberError != null) {
      _showSnack(_rollNumberError!, Colors.red);
      return;
    }
    if (studentPhoto == null || aadharPhoto == null || passbookPhoto == null) {
      _showSnack('सर्व आवश्यक फोटो अपलोड करा', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formattedDob = dobController.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd')
              .format(DateFormat('dd/MM/yyyy').parse(dobController.text))
          : null;
      final formattedAdmission = admissionDateController.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd')
              .format(DateFormat('dd/MM/yyyy').parse(admissionDateController.text))
          : null;

      final response = await _apiService.registerStudent(
        name: nameController.text.trim(),
        rollNo: rollController.text.trim(),
        parentsPhno: parentsPhnoController.text.trim(),
        caste: selectedCaste,
        subCaste: subCasteController.text.trim(),
        sex: selectedSex,
        aparId: aparIdController.text.trim(),
        saralId: saralIdController.text.trim(),
        mobileNumber: phoneController.text.trim(),
        dob: formattedDob,
        admissionDate: formattedAdmission,
        address: addressController.text.trim(),
        motherToung: motherTongueController.text.trim(),
        previousSchool: previousSchoolController.text.trim(),
        classId: selectedClass,
        registerNumber: registrController.text.trim(),
        motherName: motherController.text.trim(),
        photo: studentPhoto,
        adharNumber: aadharPhoto,
        bankPassbook: passbookPhoto,
        schoolId: schoolIdController.text.trim(),
      );

      if (response['success'] == true) {
        _showSnack('Student registered successfully', Colors.green);
        _formKey.currentState!.reset();
        setState(() {
          selectedCaste = null;
          selectedClass = null;
          selectedSex = null;
          studentPhoto = null;
          aadharPhoto = null;
          passbookPhoto = null;
        });
      } else {
        _showSnack('Failed: ${response['message']}', Colors.red);
      }
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.teal),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.teal.shade50,
        ),
        validator: validator ?? (v) => v!.isEmpty ? '$label is required' : null,
      ),
    );
  }

  Widget buildImageUploader(String label, XFile? file, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.teal),
            borderRadius: BorderRadius.circular(12),
            color: Colors.teal.shade50,
          ),
          child: Row(
            children: [
              file == null
                  ? const Icon(Icons.upload, color: Colors.teal)
                  : Image.file(
                      File(file.path),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  file == null ? label : 'Selected: ${file.name}',
                  overflow: TextOverflow.ellipsis,
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
        title: const Text('Add New Student'),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            buildSectionTitle('Personal Information'),
            buildTextField('Name:', nameController,
                validator: (v) => v!.isEmpty ? 'Name is required' : null),
            buildTextField('Mother Name:', motherController),
            buildTextField('Father Name:', fatherController),
            buildTextField('Phone Number:', phoneController,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    !RegExp(r'^\d{10}$').hasMatch(v ?? '') ? 'Enter valid phone' : null),
            buildTextField('Parents Phone:', parentsPhnoController,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    !RegExp(r'^\d{10}$').hasMatch(v ?? '') ? 'Enter valid phone' : null),
            buildTextField('Address:', addressController),
            buildTextField('Date of Birth:', dobController,
                readOnly: true, onTap: () => selectDate(dobController)),

            buildSectionTitle('Academic Information'),
            buildTextField('Register Number:', registrController),
            TextFormField(
              controller: rollController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _validateRollNumber(),
              decoration: InputDecoration(
                labelText: 'Roll Number',
                errorText: _rollNumberError,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.teal.shade50,
              ),
            ),
            const SizedBox(height: 8),
            _isLoadingClasses
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : DropdownButtonFormField<String>(
                    value: selectedClass,
                    items: _classList.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['id'].toString(),
                        child: Text(c['name'] ?? 'Class'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedClass = v;
                      });
                      _validateRollNumber();
                    },
                    decoration: InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.teal.shade50,
                    ),
                  ),
            buildTextField('Division:', divisionController),
            buildTextField('Previous School:', previousSchoolController),
            buildTextField('Admission Date:', admissionDateController,
                readOnly: true, onTap: () => selectDate(admissionDateController)),

            buildSectionTitle('Additional Information'),
            DropdownButtonFormField<String>(
              value: selectedCaste,
              items: casteOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => selectedCaste = v),
              decoration: InputDecoration(
                labelText: 'Caste',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.teal.shade50,
              ),
            ),
            buildTextField('Sub Caste:', subCasteController),
            DropdownButtonFormField<String>(
              value: selectedSex,
              items: sexOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => selectedSex = v),
              decoration: InputDecoration(
                labelText: 'Sex',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.teal.shade50,
              ),
            ),
            buildTextField('Mother Tongue:', motherTongueController),
            buildTextField('APAR ID:', aparIdController),
            buildTextField('SARAL ID:', saralIdController),
            buildTextField('Aadhar Number:', aadharNumberController,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    !RegExp(r'^\d{12}$').hasMatch(v ?? '') ? 'Enter valid 12-digit Aadhar' : null),

            buildSectionTitle('Upload Documents'),
            buildImageUploader('Upload Student Photo', studentPhoto,
                () => pickImage(ImageSource.gallery, 'photo')),
            buildImageUploader('Upload Aadhar Card', aadharPhoto,
                () => pickImage(ImageSource.gallery, 'aadhar')),
            buildImageUploader('Upload Passbook Photo', passbookPhoto,
                () => pickImage(ImageSource.gallery, 'passbook')),

            const SizedBox(height: 20),
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.teal)
                  : ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Register Student',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    registrController.dispose();
    rollController.dispose();
    nameController.dispose();
    motherController.dispose();
    fatherController.dispose();
    phoneController.dispose();
    addressController.dispose();
    dobController.dispose();
    aadharNumberController.dispose();
    divisionController.dispose();
    subCasteController.dispose();
    aparIdController.dispose();
    saralIdController.dispose();
    admissionDateController.dispose();
    motherTongueController.dispose();
    previousSchoolController.dispose();
    parentsPhnoController.dispose();
    schoolIdController.dispose();
    super.dispose();
  }
}
