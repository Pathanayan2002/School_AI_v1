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
          title: Text('Assign Role: $role'),
          content: DropdownButtonFormField<Map<String, dynamic>>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select User',
              border: OutlineInputBorder(),
            ),
            items: eligibleUsers.map((user) {
              return DropdownMenuItem(
                value: user,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${user['name']}'),
                    Text(
                      '${user['enrollmentId']} (${user['email']})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => selectedUser = value,
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedUser != null) {
                  final userId = selectedUser!['id'].toString();
                  await _apiService.putRequest(
                    '/user/update-role/$userId',
                    data: {"role": role},
                  );
                  _fetchUsers();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade900,
              ),
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
  }

  Widget buildRoleTable(String roleName) {
    final users = getUsersByRole(roleName);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$roleName Users',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => _showAddDialog(roleName),
                  icon: const Icon(Icons.add_circle, color: Colors.indigo),
                  tooltip: 'Add $roleName',
                ),
              ],
            ),
            const Divider(),
            if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('No $roleName assigned.', style: TextStyle(color: Colors.grey[600])),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
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
        backgroundColor: Colors.indigo.shade900,
        title: const Text('Role Management', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    buildRoleTable("Admin"),
                    buildRoleTable("Teacher"),
                    buildRoleTable("Clerk"),
                  ],
                ),
              ),
            ),
    );
  }
}