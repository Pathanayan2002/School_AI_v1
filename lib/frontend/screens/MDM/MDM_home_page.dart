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
  int totalStockQuantity = 0;

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
        final reportDate = report['date'] != null ? DateTime.parse(report['date']) : null;
        return reportDate != null && DateFormat('yyyy-MM-dd').format(reportDate) == today;
      }).toList();

      int students = todayReports.fold(0, (sum, report) {
        final totalStudents = report['totalStudents'];
        return sum + (totalStudents is int ? totalStudents : int.tryParse(totalStudents?.toString() ?? '0') ?? 0);
      });

      int stockQuantity = List<Map<String, dynamic>>.from(stocksResult['data'] ?? []).fold(0, (sum, stock) {
        final quantity = stock['totalStock'];
        return sum + (quantity is int ? quantity : int.tryParse(quantity?.toString() ?? '0') ?? 0);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _downloadExcel(List<Map<String, dynamic>> reports, String filterType) async {
    if (reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reports to download'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Reports'];

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Class Name'),
      TextCellValue('Total Students'),
      TextCellValue('Menu'),
      TextCellValue('Items Used'),
      TextCellValue('Class Group'),
    ]);

    for (var report in reports) {
      final itemsUsed = (report['itemsUsed'] as List?)
              ?.map((item) => '${item['itemName']}: ${item['requiredQuantity']}')
              .join(', ') ??
          '';
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
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel downloaded: $fileName'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MDM Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Today\'s Reports',
            onPressed: () {
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              final todayReports = reports.where((report) {
                final reportDate = report['date'] != null ? DateTime.parse(report['date']) : null;
                return reportDate != null && DateFormat('yyyy-MM-dd').format(reportDate) == today;
              }).toList();
              _downloadExcel(todayReports, 'Daily');
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Today\'s Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildCard(
                        title: 'Students Served',
                        value: totalStudentsToday.toString(),
                        icon: Icons.people,
                        color: Colors.indigo,
                      ),
                      _buildCard(
                        title: 'Inventory Items',
                        value: totalInventoryItems.toString(),
                        icon: Icons.inventory_2,
                        color: Colors.green,
                      ),
                      _buildCard(
                        title: 'Menu Items',
                        value: totalMenuItems.toString(),
                        icon: Icons.menu_book,
                        color: Colors.deepOrange,
                      ),
                      _buildCard(
                        title: 'Stock Qty',
                        value: totalStockQuantity.toString(),
                        icon: Icons.warehouse,
                        color: Colors.teal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required String title, required String value, required IconData icon, required Color color}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 24,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo.shade700),
            child: const Text('MDM Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          _buildDrawerTile(Icons.home, 'Dashboard', () => Navigator.pop(context)),
          _buildDrawerTile(Icons.inventory, 'Total Inventory',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TotalInventoryPage()))),
          _buildDrawerTile(Icons.calculate, 'Create Report',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MDMReportsPage()))),
          _buildDrawerTile(Icons.storage, 'MDM Inventory',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MDMInventoryPage()))),
          _buildDrawerTile(Icons.menu_book, 'Menu Items',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuItemsPage()))),
          _buildDrawerTile(Icons.warehouse, 'Material Stock',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MDMMaterialStockPage()))),
          _buildDrawerTile(Icons.sync, 'Carry Forward',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarryForwardPage()))),
          _buildDrawerTile(Icons.logout, 'Logout', () async {
            // Assuming deleteJwtToken is implemented in ApiService
            await _apiService.deleteJwtToken();
            Navigator.pushReplacementNamed(context, '/login');
          }),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title),
      onTap: onTap,
    );
  }
}