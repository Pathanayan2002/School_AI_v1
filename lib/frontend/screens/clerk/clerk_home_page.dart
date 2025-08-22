// File: clerk_home_page.dart
import 'package:Ai_School_App/frontend/screens/admin/view_student_record.dart';
import 'package:flutter/material.dart';
import '../teacher/result_report.dart';
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
    final dateStr =
        "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

    final dashboardItems = [
      _DashboardItem(Icons.person_search, 'Student Attendance Records',
          Colors.indigo, const ClerkAttendanceRecordPage()),
      _DashboardItem(Icons.group, 'Teacher Attendance', Colors.orange,
          const TeacherAttendanceScreen()),
      _DashboardItem(Icons.person_add_alt_1, 'Add Student', Colors.pink,
          const AddNewStudent()),
      _DashboardItem(Icons.book, 'Assign Subject', Colors.green,
          const AssignSubjectToStudentPage()),
      _DashboardItem(Icons.class_, 'Assign Class', Colors.teal,
          const AssignClassToTeacherPage()),
      _DashboardItem(Icons.bar_chart, 'Result Report', Colors.purple,
          const ClerkResultReportPage()),
      _DashboardItem(Icons.school, 'View Student Record', Colors.deepPurple,
          const AdminClerkStudentViewPage(initialClassId: null)),
      _DashboardItem(Icons.restaurant, 'Food Management', Colors.blue,
          const MDMHomePage()),
    ];

    final drawerItems = [
      _DrawerItem(Icons.person, 'Profile', const ProfilePage()),
      _DrawerItem(Icons.book, 'Assign Subject', const AssignSubjectToStudentPage()),
      _DrawerItem(Icons.book_online, 'Teacher Record', const ClerkTeacherAttendanceRecordPage()),
      _DrawerItem(Icons.class_, 'Assign Class', const AssignClassToTeacherPage()),
      _DrawerItem(Icons.dashboard, 'Dashboard', ClerkHomePage(clerkId: clerkId)),
      _DrawerItem(Icons.security, 'Add Role', const RolePage()),
      _DrawerItem(Icons.class_outlined, 'Manage Classes', const ManageClasses()),
      _DrawerItem(Icons.menu_book, 'Manage Subjects', const ManageSubjectsScreen()),
      _DrawerItem(Icons.bar_chart, 'Result Report', const ClerkResultReportPage()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Clerk Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade800,
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, size: 28, color: Colors.blue.shade800),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
        ],
      ),
      drawer: _buildDrawer(context, drawerItems),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome, Clerk ',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: $dateStr',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                itemCount: dashboardItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: 1.1,
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
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Navigation Menu',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 0, color: Colors.grey.shade300),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Icon(item.icon, color: Colors.blue.shade700),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context, MaterialPageRoute(builder: (_) => item.page));
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
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 40, color: item.color),
              const SizedBox(height: 14),
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
