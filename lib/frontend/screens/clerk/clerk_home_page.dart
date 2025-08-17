import 'package:Ai_School_App/frontend/screens/teacher/result_report.dart';
import 'package:flutter/material.dart';
import '../admin/admin_profile.dart';
import '../admin/manage_classes.dart';
import '../admin/manage_subject.dart';
import '../admin/roles.dart';
import '../teacher/student_attendence.dart';
import '../MDM/MDM_home_page.dart';
import 'add_new_student.dart';
import 'assign_class_to_teacher.dart';
import 'assign_subject_to_student.dart';
import 'student_record.dart';
import 'teacher_presenty.dart';
import 'teacher_att_recored.dart';
import 'result_report.dart';

class ClerkHomePage extends StatelessWidget {
  final int clerkId;

  const ClerkHomePage({super.key, required this.clerkId});

  @override
  Widget build(BuildContext context) {
    final dateStr = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

    final dashboardItems = [
      _DashboardItem(Icons.person_search, 'Student Records', Colors.indigo, const StudentRecord()),
      _DashboardItem(Icons.group, 'Teacher Attendance', Colors.orange, const TeacherAttendanceScreen()),
      _DashboardItem(Icons.person_add_alt_1, 'Add Student', Colors.pink, const AddNewStudent()),
      _DashboardItem(Icons.book, 'Assign Subject', Colors.green, const AssignSubjectToStudentPage()),
      _DashboardItem(Icons.class_, 'Assign Class', Colors.teal, const AssignClassToTeacherPage()),
      _DashboardItem(Icons.bar_chart, 'Result Report', Colors.purple, const ResultReportScreen()),
      _DashboardItem(Icons.restaurant, 'Food Management', Colors.blue, const MDMHomePage()),
    ];

    final drawerItems = [
      _DrawerItem(Icons.person, 'Profile', const ProfilePage()),
      _DrawerItem(Icons.book, 'Assign Subject', const AssignSubjectToStudentPage()),
      _DrawerItem(Icons.book_online, 'Teacher Record', const AttendanceRecordScreen()),
      _DrawerItem(Icons.class_, 'Assign Class', const AssignClassToTeacherPage()),
      _DrawerItem(Icons.dashboard, 'Dashboard', ClerkHomePage(clerkId: clerkId)),
      _DrawerItem(Icons.security, 'Add Role', const RolePage()),
      _DrawerItem(Icons.class_outlined, 'Manage Classes', const ManageClassesWithDivision()),
      _DrawerItem(Icons.menu_book, 'Manage Subjects', const ManageSubjectsScreen()),
      _DrawerItem(Icons.bar_chart, 'Result Report', const ClerkResultReportScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clerk Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
        ],
      ),
      drawer: _buildDrawer(context, drawerItems),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome, Clerk!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF1E6FE8))),
            const SizedBox(height: 8),
            Text('Date: $dateStr', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                itemCount: dashboardItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  return _DashboardCard(item: dashboardItems[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context, List<_DrawerItem> items) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade700),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Navigation Menu',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Icon(item.icon, color: Colors.blue.shade700),
                  title: Text(item.title, style: const TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => item.page));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardItem {
  final IconData icon;
  final String label;
  final Color color;
  final Widget page;
  _DashboardItem(this.icon, this.label, this.color, this.page);
}

  class _DashboardCard extends StatelessWidget {
  final _DashboardItem item;
  const _DashboardCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.blue.withOpacity(0.1),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: const Color(0xFFF5F7FA),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 38, color: Color(0xFF1E88E5)),
              const SizedBox(height: 12),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String title;
  final Widget page;
  _DrawerItem(this.icon, this.title, this.page);
}
