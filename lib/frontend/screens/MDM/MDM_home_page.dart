import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import 'total_inventory_page.dart';
import 'MDM_inventory.dart';
import 'MDM_menu_items.dart';
import 'MDM_Material_stock.dart';
import 'carryforward.dart';
import 'MDM_Report.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';

class MDMHomePage extends StatefulWidget {
  const MDMHomePage({super.key});

  @override
  State<MDMHomePage> createState() => _MDMHomePageState();
}

class _MDMHomePageState extends State<MDMHomePage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> reports = [];
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> menus = [];
  List<Map<String, dynamic>> stocks = [];
  int totalStudentsToday = 0;
  int totalInventoryItems = 0;
  int totalMenuItems = 0;
  double totalStockQuantity = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);
    try {
      final reportsResult = await _apiService.getAllReports();
      final itemsResult = await _apiService.getAllItems();
      final menusResult = await _apiService.getAllMenus();
      final stocksResult = await _apiService.getAllStocks();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayReports = List<Map<String, dynamic>>.from(reportsResult['data'] ?? []).where((report) {
        final reportDate = report['date'] != null ? DateTime.tryParse(report['date']) : null;
        return reportDate != null && DateFormat('yyyy-MM-dd').format(reportDate) == today;
      }).toList();

      int students = todayReports.fold(0, (sum, report) {
        final totalStudents = report['totalStudents'];
        return sum + (totalStudents is int ? totalStudents : int.tryParse(totalStudents?.toString() ?? '0') ?? 0);
      });

      double stockQuantity = List<Map<String, dynamic>>.from(stocksResult['data'] ?? []).fold(0, (sum, stock) {
        final quantity = stock['totalStock'];
        return sum + (quantity is num ? quantity.toDouble() : double.tryParse(quantity?.toString() ?? '0') ?? 0);
      });

      setState(() {
        reports = List<Map<String, dynamic>>.from(reportsResult['data'] ?? []);
        items = List<Map<String, dynamic>>.from(itemsResult['data'] ?? []);
        menus = List<Map<String, dynamic>>.from(menusResult['data'] ?? []);
        stocks = List<Map<String, dynamic>>.from(stocksResult['data'] ?? []);
        totalStudentsToday = students;
        totalInventoryItems = items.length;
        totalMenuItems = menus.length;
        totalStockQuantity = stockQuantity;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _downloadExcel(List<Map<String, dynamic>> reports, String filterType) async {
    if (reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No reports to download')));
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Reports'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Class Name'),
      TextCellValue('Total Students'),
      TextCellValue('Menu'),
      TextCellValue('Items Used'),
      TextCellValue('Class Group'),
    ]);

    for (final report in reports) {
      final itemsUsed = (report['itemsUsed'] as List?)
          ?.map((item) => '${item['itemName']}: ${item['requiredQuantity']}')
          .join(', ') ?? '';
      final formattedDate = report['date'] != null
          ? DateFormat('dd-MM-yyyy').format(DateTime.parse(report['date']))
          : '';
      sheet.appendRow([
        TextCellValue(formattedDate),
        TextCellValue(report['className']?.toString() ?? ''),
        TextCellValue(report['totalStudents']?.toString() ?? '0'),
        TextCellValue(report['Menu']?['dishName']?.toString() ?? ''),
        TextCellValue(itemsUsed),
        TextCellValue(report['classGroup']?.toString() ?? ''),
      ]);
    }

    final excelBytes = excel.encode();
    if (excelBytes != null) {
      final fileName = 'MDM_Reports_${filterType}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(excelBytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel downloaded: $fileName')));
    }
  }

  Widget _buildCard({required String title, required String value, required IconData icon}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.teal),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, color: Colors.teal)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MDM Dashboard'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              final todayReports = reports.where((report) {
                final reportDate = report['date'] != null ? DateTime.tryParse(report['date']) : null;
                return reportDate != null && DateFormat('yyyy-MM-dd').format(reportDate) == today;
              }).toList();
              _downloadExcel(todayReports, 'Daily');
            },
            tooltip: 'Download Today\'s Reports',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text('MDM Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.teal),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.teal),
              title: const Text('Total Inventory'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TotalInventoryPage())),
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.teal),
              title: const Text('Reports'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MDMReportsPage())),
            ),
            ListTile(
              leading: const Icon(Icons.storage, color: Colors.teal),
              title: const Text('Inventory Items'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MDMInventoryPage())),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.teal),
              title: const Text('Menu Items'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuItemsPage())),
            ),
            ListTile(
              leading: const Icon(Icons.warehouse, color: Colors.teal),
              title: const Text('Material Stock'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MDMMaterialStockPage())),
            ),
            ListTile(
              leading: const Icon(Icons.sync, color: Colors.teal),
              title: const Text('Carry Forward'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarryForwardPage())),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.teal),
              title: const Text('Logout'),
              onTap: () async {
                await _apiService.deleteJwtToken();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today\'s Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildCard(title: 'Students Served', value: totalStudentsToday.toString(), icon: Icons.people),
                        _buildCard(title: 'Inventory Items', value: totalInventoryItems.toString(), icon: Icons.inventory_2),
                        _buildCard(title: 'Menu Items', value: totalMenuItems.toString(), icon: Icons.menu_book),
                        _buildCard(title: 'Total Stock Qty', value: totalStockQuantity.toStringAsFixed(2), icon: Icons.warehouse),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}