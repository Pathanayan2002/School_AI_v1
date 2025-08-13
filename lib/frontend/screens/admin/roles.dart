import 'package:flutter/material.dart';
import '../services/api_client.dart';

class RolePage extends StatefulWidget {
  const RolePage({super.key});

  @override
  State<RolePage> createState() => _RolePageState();
}

class _RolePageState extends State<RolePage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final res = await _apiService.getRequest('/user/All');
    if (res['success'] == true && res['data'] is List) {
      setState(() {
        allUsers = List<Map<String, dynamic>>.from(res['data']);
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> getUsersByRole(String role) {
    return allUsers.where((u) => u['role'] == role).toList();
  }

  Future<void> _showAddDialog(String role) async {
    Map<String, dynamic>? selectedUser;

    List<Map<String, dynamic>> eligibleUsers =
        allUsers.where((u) => u['role'] != role).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Assign role: $role'),
          content: DropdownButtonFormField<Map<String, dynamic>>(
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Select User',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: eligibleUsers.map((user) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: user,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${user['name']}'),
                    Text(
                      '${user['enrollmentId']} (${user['email']})',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              selectedUser = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedUser != null) {
                  final userId = selectedUser!['id'].toString();
                  await _apiService.putRequest(
                    '/user/update-role/$userId',
                    data: { "role": role },
                  );

                  _fetchUsers();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
              ),
              child: const Text('Assign'),
            )
          ],
        );
      },
    );
  }

  Widget buildRoleTable(String roleName) {
    final users = getUsersByRole(roleName);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$roleName Users',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A00E0),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddDialog(roleName),
                  icon: Icon(Icons.add, size: 16),
                  label: Text("Add $roleName"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A00E0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (users.isEmpty)
              Center(
                child: Text(
                  'No users assigned yet.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
                  columns: const [
                    DataColumn(label: Text('Enrollment ID')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                  ],
                  rows: users.map((user) {
                    return DataRow(
                      cells: [
                        DataCell(Text(user['enrollmentId'].toString())),
                        DataCell(Text(user['name'].toString())),
                        DataCell(Text(user['email'].toString())),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A00E0),
        title: const Text('Role Management', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Roles & Assign Users',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      buildRoleTable("Admin"),
                      buildRoleTable("Teacher"),
                      buildRoleTable("Clark"),
                      buildRoleTable("Food Manager"),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}