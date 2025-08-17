// File: add_new_student.dart
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

  // For class dropdown
  List<Map<String, dynamic>> _classList = [];
  bool _isLoadingClasses = false;

  Future<void> _fetchClasses() async {
    setState(() {
      _isLoadingClasses = true;
    });

    try {
      final result = await _apiService.getAllClasses(schoolId: '');

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

  Future<void> selectAdmissionDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        admissionDateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (studentPhoto == null || aadharPhoto == null || passbookPhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सर्व आवश्यक फोटो अपलोड करा')),
        );
        return;
      }

      // Format DOB
      String? formattedDob;
      if (dobController.text.trim().isNotEmpty) {
        try {
          final parsedDob = DateFormat('dd/MM/yyyy').parse(dobController.text.trim());
          formattedDob = DateFormat('yyyy-MM-dd').format(parsedDob);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('अवैध जन्मतारीख स्वरूप')),
          );
          return;
        }
      }

      // Format Admission Date
      String? formattedAdmissionDate;
      if (admissionDateController.text.trim().isNotEmpty) {
        try {
          final parsedAdmission = DateFormat('dd/MM/yyyy').parse(admissionDateController.text.trim());
          formattedAdmissionDate = DateFormat('yyyy-MM-dd').format(parsedAdmission);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('अवैध प्रवेश तारीख स्वरूप')),
          );
          return;
        }
      }

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
        admissionDate: formattedAdmissionDate,
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

      if (response['success'] == true ||
          response['message']?.toString().toLowerCase().contains("created") == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("विद्यार्थी यशस्वीरित्या नोंदविला गेला")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("त्रुटी: ${response['message'] ?? 'नोंदणी अयशस्वी'}")),
        );
      }
    }
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.blue.shade50,
          prefixIcon: Icon(Icons.edit, color: Colors.blue),
        ),
      ),
    );
  }

  Widget buildImageUploader(String label, XFile? image, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.blue.shade50,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(image == null ? label : 'Image selected', style: const TextStyle(color: Colors.blue)),
              const Icon(Icons.upload, color: Colors.blue),
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
        title: const Text('Add New Student', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  buildTextField('Register Number:', registrController),
                  buildTextField('Roll Number:', rollController),
                  buildTextField('Name:', nameController),
                  buildTextField('Mother Name:', motherController),
                  buildTextField('Father Name:', fatherController),
                  buildTextField('Phone Number:', phoneController, keyboardType: TextInputType.phone),
                  buildTextField('Address:', addressController),
                  buildTextField('Sub Caste:', subCasteController),
                  buildTextField('APAR ID:', aparIdController),
                  buildTextField('SARAL ID:', saralIdController),
                  buildTextField('Mother Tongue:', motherTongueController),
                  buildTextField('Previous School:', previousSchoolController),
                  buildTextField('Parents Phone:', parentsPhnoController, keyboardType: TextInputType.phone),
                  buildTextField('School ID:', schoolIdController),
                  const SizedBox(height: 16),
                  if (_isLoadingClasses)
                    const Center(child: CircularProgressIndicator(color: Colors.blue))
                  else
                    DropdownButtonFormField<String>(
                      value: selectedClass,
                      hint: const Text("Select Class"),
                      decoration: InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.blue.shade50,
                        prefixIcon: const Icon(Icons.class_, color: Colors.blue),
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
                  buildTextField('Division:', divisionController),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCaste,
                    decoration: InputDecoration(
                      labelText: 'Caste',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      prefixIcon: const Icon(Icons.category, color: Colors.blue),
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
                    decoration: InputDecoration(
                      labelText: 'Sex',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      prefixIcon: const Icon(Icons.person, color: Colors.blue),
                    ),
                    items: sexOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedSex = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: dobController,
                    readOnly: true,
                    onTap: selectDOB,
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: admissionDateController,
                    readOnly: true,
                    onTap: selectAdmissionDate,
                    decoration: InputDecoration(
                      labelText: 'Admission Date',
                      prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildTextField('Aadhar Number:', aadharNumberController, keyboardType: TextInputType.number),
                  buildImageUploader("Upload Student Photo", studentPhoto, () {
                    pickImage(ImageSource.gallery, 'photo');
                  }),
                  buildImageUploader("Upload Aadhar Card", aadharPhoto, () {
                    pickImage(ImageSource.gallery, 'aadhar');
                  }),
                  buildImageUploader("Upload Passbook Photo", passbookPhoto, () {
                    pickImage(ImageSource.gallery, 'passbook');
                  }),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Register Student", style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}