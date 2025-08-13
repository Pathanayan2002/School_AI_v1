import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class TotalInventoryPage extends StatefulWidget {
  const TotalInventoryPage({Key? key}) : super(key: key);

  @override
  _TotalInventoryPageState createState() => _TotalInventoryPageState();
}

class _TotalInventoryPageState extends State<TotalInventoryPage> {
  List<dynamic> menus = [];
  Map<String, dynamic>? selectedMenu;
  String? selectedClassGroup;
  final List<String> classGroups = ['1-5', '6-8'];
  final TextEditingController studentController = TextEditingController();
  String? message;
  bool isLoading = false;
  List<Map<String, dynamic>> remainingStockList = [];

  @override
  void initState() {
    super.initState();
    loadMenus();
  }

  Future<void> loadMenus() async {
    final stockService = StockService();
    final data = await stockService.getAllMenus();
    setState(() => menus = data);
  }

  Future<void> processAndSubmit() async {
    if (selectedMenu == null || selectedClassGroup == null || studentController.text.isEmpty) {
      setState(() => message = 'Please select menu, class and students');
      return;
    }

    final int totalStudents = int.tryParse(studentController.text) ?? 0;
    final List<dynamic> items = selectedMenu!['Items'];
    final List<Map<String, dynamic>> itemsUsed = [];

    setState(() {
      isLoading = true;
      remainingStockList.clear();
    });

    for (var item in items) {
      final double perStudentQty = selectedClassGroup == '1-5'
          ? double.tryParse(item['quantity1_5'].toString()) ?? 0
          : double.tryParse(item['quantity6_8'].toString()) ?? 0;

      final double requiredQty = perStudentQty * totalStudents;

      final stockService = StockService();
      final allStocks = await stockService.getAllStocks();
      final stock = allStocks.firstWhere(
        (s) => s['ItemId'] == item['id'] && s['classGroup'] == selectedClassGroup,
        orElse: () => null,
      );

      if (stock == null) {
        setState(() => message = 'Stock not found for ${item['itemName']}');
        continue;
      }

      final double prevTotal = double.tryParse(stock['totalStock'].toString()) ?? 0;
      final double newTotal = prevTotal - requiredQty;

      itemsUsed.add({
        'itemId': item['id'],
        'quantityUsed': requiredQty,
      });

      remainingStockList.add({
        'itemName': item['itemName'],
        'required': requiredQty.toStringAsFixed(2),
        'remaining': newTotal.toStringAsFixed(2),
      });

      await stockService.updateStock(stock['id'], {
        'previousStock': stock['previousStock'],
        'inwardMaterial': stock['inwardMaterial'],
        'outwardMaterial': requiredQty,
        'totalStock': newTotal,
        'classGroup': selectedClassGroup,
      });
    }

    // Send one report after all item usage is calculated
    final stockService = StockService();
    await stockService.createReport({
      'menuId': selectedMenu!['id'],
      'classGroup': selectedClassGroup,
      'totalStudents': totalStudents,
      'itemsUsed': itemsUsed,
      'date': DateTime.now().toIso8601String().split('T').first,
    });

    setState(() {
      isLoading = false;
      message = 'Stock updated and report created.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Daily Stock Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<Map<String, dynamic>>(
              value: selectedMenu,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Select Dish'),
              items: menus.map((menu) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: menu,
                  child: Text(menu['dishName']),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedMenu = val),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedClassGroup,
              decoration: const InputDecoration(labelText: 'Select Class Group'),
              items: classGroups.map((group) => DropdownMenuItem(value: group, child: Text(group))).toList(),
              onChanged: (val) => setState(() => selectedClassGroup = val),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: studentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Students'),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: processAndSubmit,
                    child: const Text('Submit Report & Update Stock'),
                  ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, style: const TextStyle(color: Colors.green)),
            ],
            const Divider(height: 30),
            if (remainingStockList.isNotEmpty) const Text('Remaining Stock:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...remainingStockList.map((stock) {
              return ListTile(
                title: Text(stock['itemName']),
                subtitle: Text('Used: ${stock['required']} | Remaining: ${stock['remaining']}'),
              );
            })
          ],
        ),
      ),
    );
  }
}
