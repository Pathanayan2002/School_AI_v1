import 'package:flutter/material.dart';
import '../../../model/student_model.dart';

class Sem1ResultPage extends StatelessWidget {
  final Student student;

  const Sem1ResultPage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sem1 Result"),
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
            Row(
              children: [
                Expanded(child: _buildInputField("इयत्ता:", initialValue: "पाचवी")),
                const SizedBox(width: 8),
                Expanded(child: _buildInputField("आईचे नाव:", initialValue: "सुरेखा")),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildInputField("जात:", initialValue: "OPEN")),
                const SizedBox(width: 8),
                Expanded(child: _buildInputField("पत्ता:", initialValue: "ओज (मं)")),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildInputField("परीक्षा नंबर:", initialValue: "1")),
                const SizedBox(width: 8),
                Expanded(child: _buildInputField("रजि. नंबर:", initialValue: "3021")),
              ],
            ),
            const SizedBox(height: 12),
            const Text("प्रथम सत्र sem 1", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),

            const Text("(अ) आकलन हेतु गुणांक : Formative Assessment",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildInputField("दैवटिंग निरीक्षण:"),
            _buildInputField("प्रात्यक्षिक प्रयोग:"),
            _buildInputField("उपक्रम/कृती:"),
            _buildInputField("प्रकल्प:"),
            _buildInputField("चाचणी (लेखी):"),
            _buildInputField("स्वाध्याय / वर्गकार्य"),
            _buildInputField("इतर"),
            _buildInputField("एकूण अ:"),
            const Divider(),

            const Text("(ब) संकलित मूल्यांकन : Section 2",
                style: TextStyle(fontWeight: FontWeight.bold)),
            _buildInputField("तोंडी:"),
            _buildInputField("प्रात्य:"),
            _buildInputField("लेखी:"),
            _buildInputField("एकूण  ब:"),
            _buildInputField("अ + ब = एकूण  (१):"),
            _buildInputField("श्रेणी grade:"),
            const Divider(),

            _buildDropdownWithList("विषय प्रवत्ती", [
              'गणित शिक्षण प्रवत्ती',
              'वाचन कक्षा',
              'कहानि कक्षा',
              'चित्रकला प्रवत्ती',
              'हस्तकला प्रवत्ती',
              'पाठयपुस्तकावरून शिक्षण',
              'गट क्रियाकलाप',
              'आवाजातील वाचन',
              'नाट्य कक्षा',
            ]),

            _buildDropdownWithList("छंद", [
              'स्वत: अभ्यास करणे',
              'चित्र काढणे',
              'धावणे',
              'कविता म्हणणे',
              'स्वतंत्र वाचन',
              'संगीत',
            ]),

            _buildDropdownWithList("छंद", [
              'स्वत: अभ्यास करणे',
              'चित्र काढणे',
              'धावणे',
              'कविता म्हणणे',
              'संगीत',
            ]),

            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  print('Updating marks...');
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
