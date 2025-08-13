import 'package:flutter/material.dart';
import '../admin/admin_home_page.dart';
import '../admin/admin_profile.dart';
import '../teacher/teacher_profile.dart';
import 'MDM_Material_stock.dart';
import 'MDM_inventory.dart';
import 'MDM_menu_items.dart';
import 'inventory_calculation.dart';
import 'total_inventory_page.dart';

class TeacherDashboardWireframe extends StatelessWidget {
  const TeacherDashboardWireframe({super.key});

  @override
  Widget build(BuildContext context) {
    final String today =
        "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menu / मेनू',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              title: Text('Profile / प्रोफाइल'),
            ),
            ListTile(
              title: Text('Settings / सेटिंग्स'),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.person_outline, color: Colors.black),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'स्वागत आहे, शिक्षक!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'आजची तारीख: $today',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),

            // Profile Button
            _buildButton(context, 'Profile', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) =>  ProfilePage(userId: '',)),
              );
            }),
            const SizedBox(height: 20),

            // Menu Item Button
            _buildButton(context, 'Menu Item', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MenuItemsPage()),
              );
            }),
            const SizedBox(height: 20),

            // Inventory Button
            _buildButton(context, 'Inventory', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InventoryPage()),
              );
            }),
            const SizedBox(height: 20),  

            // Material Stock Button
            _buildButton(context, 'Material Stock', () {
              Navigator.push(context, MaterialPageRoute(builder: (context)=>MaterialStockPage(),),);
            }),
            const SizedBox(height: 20),

            // // Ingredients Mapping Button
            // _buildButton(context, 'Ingredients Mapping', () {
            //   //Navigator.push(context, MaterialPageRoute(builder: (context)=>TotalInventoryPage(),),);
            // }),
            // const SizedBox(height: 20),

            // Total Inventory Button
            _buildButton(context, 'Total Inventory', () {
              Navigator.push(context, MaterialPageRoute(builder: (context)=>TotalInventoryPage(),),);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String title, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.black),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
