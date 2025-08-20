import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../services/api_client.dart';

class TotalInventoryPage extends StatefulWidget {
  const TotalInventoryPage({super.key});

  @override
  State<TotalInventoryPage> createState() => _TotalInventoryPageState();
}

class _TotalInventoryPageState extends State<TotalInventoryPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
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
        if (menus.isNotEmpty) selectedMenu = menus.first;
        if (['1-5', '6-8'].contains(selectedClassGroup)) selectedClassGroup = '1-5';
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate() || selectedMenu == null || selectedClassGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final itemsUsed = <Map<String, dynamic>>[];
      for (final item in (selectedMenu!['Items'] as List? ?? [])) {
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

        final previousStock = (matchingStock['previousStock'] is int
            ? (matchingStock['previousStock'] as int).toDouble()
            : matchingStock['previousStock'] as double?) ?? 0.0;
        final inwardMaterial = (matchingStock['inwardMaterial'] is int
            ? (matchingStock['inwardMaterial'] as int).toDouble()
            : matchingStock['inwardMaterial'] as double?) ?? 0.0;
        final outwardMaterial = (matchingStock['outwardMaterial'] is int
            ? (matchingStock['outwardMaterial'] as int).toDouble()
            : matchingStock['outwardMaterial'] as double?) ?? 0.0;

        final updatedOutward = outwardMaterial + requiredQty;
        final updatedTotalStock = previousStock + inwardMaterial - updatedOutward;

        if (updatedTotalStock < 0) {
          throw Exception('Insufficient stock for $itemName in group $selectedClassGroup');
        }

        itemsUsed.add({
          'itemId': itemId.toString(),
          'itemName': itemName,
          'requiredQuantity': requiredQty,
        });

        final response = await _apiService.updateStock(
          id: matchingStock['id'].toString(),
          previousStock: previousStock,
          inwardMaterial: inwardMaterial,
          outwardMaterial: updatedOutward,
          totalStock: updatedTotalStock,
          classGroup: selectedClassGroup!,
        );

        if (!response['success']) {
          throw Exception(response['statusMessage'] ?? 'Failed to update stock for $itemName');
        }
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final reportResponse = await _apiService.createReport(
        date: today,

        totalStudent: totalStudents,  menuId: '', className: '',
   
      );

      if (reportResponse['success']) {
        final updatedStockList = itemsUsed.map((item) {
          final matchingStock = stocks.firstWhere(
            (s) => s['ItemId'] == item['itemId'] && s['classGroup'] == selectedClassGroup,
          );
          final previousStock = (matchingStock['previousStock'] is int
              ? (matchingStock['previousStock'] as int).toDouble()
              : matchingStock['previousStock'] as double?) ?? 0.0;
          final inwardMaterial = (matchingStock['inwardMaterial'] is int
              ? (matchingStock['inwardMaterial'] as int).toDouble()
              : matchingStock['inwardMaterial'] as double?) ?? 0.0;
          final outwardMaterial = (matchingStock['outwardMaterial'] is int
              ? (matchingStock['outwardMaterial'] as int).toDouble()
              : matchingStock['outwardMaterial'] as double?) ?? 0.0;
          final totalStock = previousStock + inwardMaterial - (outwardMaterial + item['requiredQuantity']);
          return {
            'itemName': item['itemName'],
            'remainingStock': totalStock,
          };
        }).toList();

        setState(() => remainingStockList = updatedStockList);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report created and stock updated')));
        await _loadMenusAndStocks();
      } else {
        throw Exception(reportResponse['statusMessage'] ?? 'Failed to create report');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Report error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Inventory Report'),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Create Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<Map<String, dynamic>>(
                              decoration: const InputDecoration(labelText: 'Select Menu', border: OutlineInputBorder()),
                              value: selectedMenu,
                              items: menus.map((m) => DropdownMenuItem(value: m, child: Text(m['dishName'] ?? ''))).toList(),
                              onChanged: (val) => setState(() => selectedMenu = val),
                              validator: (val) => val == null ? 'Select a menu' : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Select Class Group', border: OutlineInputBorder()),
                              value: selectedClassGroup,
                              items: const [
                                DropdownMenuItem(value: '1-5', child: Text('Classes 1-5')),
                                DropdownMenuItem(value: '6-8', child: Text('Classes 6-8')),
                              ],
                              onChanged: (val) => setState(() => selectedClassGroup = val),
                              validator: (val) => val == null ? 'Select a class group' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(labelText: 'Class Number (1-8)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() => className = val.trim()),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Enter class number';
                                final num = int.tryParse(val.trim());
                                if (num == null || num < 1 || num > 8) return 'Class number must be between 1 and 8';
                                if (selectedClassGroup == '1-5' && num > 5) return 'Class number must be 1-5';
                                if (selectedClassGroup == '6-8' && num < 6) return 'Class number must be 6-8';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: const InputDecoration(labelText: 'Total Students', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() => totalStudents = int.tryParse(val) ?? 0),
                              validator: (val) {
                                if (val == null || int.tryParse(val) == null || int.parse(val) <= 0) {
                                  return 'Enter valid number of students';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: isLoading ? null : _submitReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Submit Report'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (remainingStockList.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Remaining Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: remainingStockList
                                .map((stock) => ListTile(
                                      title: Text(stock['itemName'] ?? 'Unknown Item'),
                                      subtitle: Text('Remaining: ${stock['remainingStock']?.toStringAsFixed(2) ?? '0'}'),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}