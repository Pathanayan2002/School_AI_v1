import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';

class AddNewStudent extends StatefulWidget {
  final String schoolId; // Add schoolId as required parameter
  const AddNewStudent({super.key, required this.schoolId});

  @override
  State<AddNewStudent> createState() => _AddNewStudentState();
}

class _AddNewStudentState extends State<AddNewStudent> {
  final ApiService _apiService = ApiService();

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

  // For class dropdown
  List<Map<String, dynamic>> _classList = [];
  bool _isLoadingClasses = false;

  Future<void> _fetchClasses() async {
    setState(() {
      _isLoadingClasses = true;
    });

    try {
      final result = await _apiService.getAllClasses(schoolId: widget.schoolId);

      if (result['success'] == true && result['data'] is List) {
        setState(() {
          _classList = List<Map<String, dynamic>>.from(result['data']);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load classes: ${result['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching classes: $e')),
      );
    } finally {
      setState(() {
        _isLoadingClasses = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchClasses();
    });
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

  Future<void> selectDOB() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _submitForm() async {
    try {
      final formData = FormData.fromMap({
        'name': nameController.text.trim(),
        'rollNo': rollController.text.trim(),
        'parentsPhno': parentsPhnoController.text.trim(),
        if (selectedCaste != null) 'caste': selectedCaste,
        if (subCasteController.text.isNotEmpty) 'subCaste': subCasteController.text.trim(),
        if (selectedSex != null) 'sex': selectedSex,
        if (aparIdController.text.isNotEmpty) 'aparId': aparIdController.text.trim(),
        if (saralIdController.text.isNotEmpty) 'saralId': saralIdController.text.trim(),
        if (phoneController.text.isNotEmpty) 'mobileNumber': phoneController.text.trim(),
        if (dobController.text.isNotEmpty) 'dob': dobController.text.trim(),
        if (admissionDateController.text.isNotEmpty) 'admissionDate': admissionDateController.text.trim(),
        if (addressController.text.isNotEmpty) 'address': addressController.text.trim(),
        if (motherTongueController.text.isNotEmpty) 'motherToung': motherTongueController.text.trim(),
        if (previousSchoolController.text.isNotEmpty) 'previousSchool': previousSchoolController.text.trim(),
        if (selectedClass != null) 'classId': selectedClass,
        if (registrController.text.isNotEmpty) 'registerNumber': registrController.text.trim(),
        if (motherController.text.isNotEmpty) 'motherName': motherController.text.trim(),
        if (studentPhoto != null) 'photo': await MultipartFile.fromFile(studentPhoto!.path, filename: studentPhoto!.name),
        if (aadharPhoto != null) 'adharNumber': await MultipartFile.fromFile(aadharPhoto!.path, filename: aadharPhoto!.name),
        if (passbookPhoto != null) 'bankPassbook': await MultipartFile.fromFile(passbookPhoto!.path, filename: passbookPhoto!.name),
      });

      final response = await _apiService.registerStudent(
        formData,
        name: nameController.text.trim(),
        rollNo: rollController.text.trim(),
        parentsPhno: parentsPhnoController.text.trim(),
        caste: selectedCaste,
        subCaste: subCasteController.text.isNotEmpty ? subCasteController.text.trim() : null,
        sex: selectedSex,
        aparId: aparIdController.text.isNotEmpty ? aparIdController.text.trim() : null,
        saralId: saralIdController.text.isNotEmpty ? saralIdController.text.trim() : null,
        mobileNumber: phoneController.text.isNotEmpty ? phoneController.text.trim() : null,
        dob: dobController.text.isNotEmpty ? dobController.text.trim() : null,
        admissionDate: admissionDateController.text.isNotEmpty ? admissionDateController.text.trim() : null,
        address: addressController.text.isNotEmpty ? addressController.text.trim() : null,
        motherToung: motherTongueController.text.isNotEmpty ? motherTongueController.text.trim() : null,
        previousSchool: previousSchoolController.text.isNotEmpty ? previousSchoolController.text.trim() : null,
        classId: selectedClass,
        registerNumber: registrController.text.isNotEmpty ? registrController.text.trim() : null,
        motherName: motherController.text.isNotEmpty ? motherController.text.trim() : null,
        photo: studentPhoto,
        adharNumber: aadharPhoto,
        bankPassbook: passbookPhoto,
        schoolId: widget.schoolId,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("विद्यार्थी यशस्वीरित्या नोंदविला गेला")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("त्रुटी: ${response['message'] ?? 'नोंदणी अयशस्वी'}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Widget buildTextField(String label, TextEditingController controller,
      {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget buildImageUploader(String label, XFile? image, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: const Text("फाईल निवडा", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 10),
              if (image != null)
                const Icon(Icons.check_circle, color: Colors.teal, size: 24),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4C3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text("नवीन विद्यार्थी जोडा", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              buildTextField('नोंदणी क्रमांक:', registrController),
              buildTextField('रोल नंबर:', rollController),
              buildTextField('नाव:', nameController),
              buildTextField('वडिलांचे नाव:', fatherController),
              buildTextField('आईचे नाव:', motherController),
              buildTextField('मोबाईल नंबर:', phoneController),
              buildTextField('पत्ता:', addressController),
              buildTextField('उपजात:', subCasteController),
              buildTextField('APAR ID:', aparIdController),
              buildTextField('SARAL ID:', saralIdController),
              buildTextField('दाखल दिनांक:', admissionDateController),
              buildTextField('मातृभाषा:', motherTongueController),
              buildTextField('मागील शाळा:', previousSchoolController),
              buildTextField('पालकांचा संपर्क:', parentsPhnoController),

              const SizedBox(height: 16),

              if (_isLoadingClasses)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  value: selectedClass,
                  hint: const Text("Select Class"),
                  decoration: const InputDecoration(
                    labelText: 'इयत्ता',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _classList.map((classItem) {
                    final String className =
                        classItem['name'] ?? 'Class ${classItem['id']}';
                    return DropdownMenuItem<String>(
                      value: classItem['id'].toString(),
                      child: Text(className),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedClass = value;
                    });
                  },
                ),

              const SizedBox(height: 16),

              buildTextField('विभाग:', divisionController),
              DropdownButtonFormField<String>(
                value: selectedCaste,
                decoration: const InputDecoration(
                  labelText: 'जात',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: casteOptions.map((String caste) {
                  return DropdownMenuItem<String>(
                    value: caste,
                    child: Text(caste),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedCaste = value),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedSex,
                decoration: const InputDecoration(
                  labelText: 'लिंग',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: sexOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setState(() => selectedSex = value),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: dobController,
                readOnly: true,
                onTap: selectDOB,
                decoration: const InputDecoration(
                  labelText: 'जन्मतारीख',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              buildTextField('आधार क्रमांक:', aadharNumberController),

              buildImageUploader("विद्यार्थ्याचा फोटो अपलोड करा", studentPhoto, () {
                pickImage(ImageSource.gallery, 'photo');
              }),

              buildImageUploader("आधार कार्ड अपलोड करा", aadharPhoto, () {
                pickImage(ImageSource.gallery, 'aadhar');
              }),

              buildImageUploader("पासबुक फोटो अपलोड करा", passbookPhoto, () {
                pickImage(ImageSource.gallery, 'passbook');
              }),

              const SizedBox(height: 25),

              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text("विद्यार्थी नोंदणी करा"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}