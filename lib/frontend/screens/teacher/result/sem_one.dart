import 'package:flutter/material.dart';
import '../../../model/student_model.dart';
import '../../../model/subject_model.dart'; // Import SubjectItem model

class Sem1ResultPage extends StatelessWidget {
  final Student student;
  final SubjectItem subject; // Add subject parameter

  const Sem1ResultPage({super.key, required this.student, required this.subject});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sem1 Result - ${subject.subjectName}"), // Display subject name
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField("Student ID", initialValue: student.enrollmentNo),
            _buildInputField("विद्यार्थ्यांचे नाव:", initialValue: "अल्लोळी आरती अमरीश"),
            // ... (rest of the form fields remain unchanged)
            Center(
              child: ElevatedButton(
                onPressed: () {
                  print('Updating Sem1 marks for ${subject.subjectName}...');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text("Update Marks"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, {String? initialValue}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildDropdownWithList(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            items: items
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {},
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}