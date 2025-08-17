import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class TotalInventoryPage extends StatefulWidget {
  const TotalInventoryPage({super.key});

  @override
  State<TotalInventoryPage> createState() => _TotalInventoryPageState();
}

class _TotalInventoryPageState extends State<TotalInventoryPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> menus = [];
  List<Map<String, dynamic>> stocks = [];
  Map<String, dynamic>? selectedMenu;
  String? selectedClassGroup;
  int totalStudents = 0;
  String className = '';
  List<Map<String, dynamic>> remainingStockList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMenusAndStocks();
  }

  Future<void> _loadMenusAndStocks() async {
    setState(() => isLoading = true);
    try {
      final menusData = await _apiService.getAllMenus();
      final stocksData = await _apiService.getAllStocks();
      setState(() {
        menus = List<Map<String, dynamic>>.from(menusData['data'] ?? []);
        stocks = List<Map<String, dynamic>>.from(stocksData['data'] ?? []);
      });
    } catch (e) {
      debugPrint('Error loading menu/stock data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitReport() async {
    if (selectedMenu == null || selectedClassGroup == null || totalStudents <= 0 || className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly')),
      );
      return;
    }

    final classNumber = int.tryParse(className);
    if (classNumber == null || classNumber < 1 || classNumber > 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class number must be between 1 and 8')),
      );
      return;
    }
    if ((selectedClassGroup == '1-5' && classNumber > 5) ||
        (selectedClassGroup == '6-8' && classNumber < 6)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class number must match selected class group (1-5 or 6-8)')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final updatedStockList = <Map<String, dynamic>>[];
      for (final item in (selectedMenu!['Items'] as List)) {
        final itemId = item['id'];
        final itemName = item['itemName'];
        final qtyPerStudent = selectedClassGroup == '1-5' ? item['quantity1_5'] : item['quantity6_8'];
        final requiredQty = qtyPerStudent * totalStudents;

        final matchingStock = stocks.firstWhere(
          (s) => s['ItemId'] == itemId && s['classGroup'] == selectedClassGroup,
          orElse: () => {},
        );

        if (matchingStock.isEmpty) {
          throw Exception('Stock not found for $itemName in group $selectedClassGroup');
        }

        final updatedStock = {
          'previousStock': matchingStock['previousStock'] as double,
          'inwardMaterial': matchingStock['inwardMaterial'] as double,
          'outwardMaterial': (matchingStock['outwardMaterial'] as double) + requiredQty,
          'totalStock': matchingStock['previousStock'] +
              matchingStock['inwardMaterial'] -
              ((matchingStock['outwardMaterial'] as double) + requiredQty),
          'classGroup': matchingStock['classGroup'],
        };

        await _apiService.updateStock(
          id: matchingStock['id'].toString(),
          previousStock: updatedStock['previousStock'],
          inwardMaterial: updatedStock['inwardMaterial'],
          outwardMaterial: updatedStock['outwardMaterial'],
          totalStock: updatedStock['totalStock'],
          classGroup: updatedStock['classGroup'], updates: {},
        );

        updatedStockList.add({
          'itemName': itemName,
          'remainingStock': updatedStock['totalStock'],
        });
      }

      final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final response = await _apiService.createReport(
        date: today,
        menuId: selectedMenu!['id'].toString(),
        totalStudents: totalStudents,
        className: className,
      );

      if (response['statusCode'] == 201) {
        setState(() => remainingStockList = updatedStockList);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report created and stock updated')),
        );
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to create report');
      }
    } catch (e) {
      debugPrint('Report error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Inventory Report'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedMenu,
                        decoration: const InputDecoration(labelText: 'Select Menu'),
                        items: menus
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m['dishName'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => selectedMenu = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedClassGroup,
                        decoration: const InputDecoration(labelText: 'Select Class Group'),
                        items: ['1-5', '6-8']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) => setState(() => selectedClassGroup = val),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Class Number (1-8)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setState(() => className = val.trim()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Total Students',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => totalStudents = int.tryParse(val.trim()) ?? 0,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt),
                          onPressed: _submitReport,
                          label: const Text('Submit Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (remainingStockList.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Remaining Stock:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                )),
                            const SizedBox(height: 8),
                            ...remainingStockList.map((s) => Text(
                                  '${s['itemName']}: ${s['remainingStock']}',
                                  style: const TextStyle(fontSize: 14),
                                )),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}