import 'package:flutter/material.dart';

class TeacherProfile extends StatelessWidget {
  const TeacherProfile({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data - replace with actual user data later
    final String regNo = "REG123456";
    final String name = "Talmeez Ahmed";
    final String role = "Admin";
    final String email = "talmeez@example.com";
    final String contact = "+91 9876543210";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(
                  Icons.person,
                  size: 100,
                  color: Colors.black,
                ),
                const SizedBox(height: 16),
                const Text(
                  "User Profile",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 30),

                // Profile fields
                _buildProfileField("Registration No", regNo),
                const SizedBox(height: 16),
                _buildProfileField("Name", name),
                const SizedBox(height: 16),
                _buildProfileField("Role", role),
                const SizedBox(height: 16),
                _buildProfileField("Email", email),
                const SizedBox(height: 16),
                _buildProfileField("Contact", contact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
