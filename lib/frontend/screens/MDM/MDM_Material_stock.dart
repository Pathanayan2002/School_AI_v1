import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/stock_service.dart';
import 'InwardDetailsDialog.dart';

class MaterialStockPage extends StatefulWidget {
  const MaterialStockPage({super.key});

  @override
  State<MaterialStockPage> createState() => _MaterialStockPageState();
}

class _MaterialStockPageState extends State<MaterialStockPage> {
  final StockService _stockService = StockService();
  final ApiService _apiClient = ApiService();

  List<dynamic> stockData = [];
  List<String> classGroups = [];
  List<String> itemNames = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

 Future<void> _loadInitialData() async {
  try {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final stocks = await _stockService.getAllStocks();
    final itemData = await _stockService.getAllItems();

    // Fixed class groups
    final classList = ['1-5', '6-8'];

    final itemList = itemData
        .map((e) => e['itemName']?.toString())
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    setState(() {
      stockData = stocks;
      classGroups = classList;
      itemNames = itemList;
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _loading = false;
      _errorMessage = 'Failed to load data: ${e.toString()}';
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Material Stock"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              print("Available Class Groups: $classGroups");

              showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InwardDetailsDialog(
                    availableClassGroups: classGroups,
                    availableItemNames: itemNames,
                  ),
                ),
              ).then((_) => _loadInitialData());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Add Inward Stock"),
          ),
          const SizedBox(height: 10),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : stockData.isEmpty
                    ? const Center(child: Text('No stock data found.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("Stock ID")),
                            DataColumn(label: Text("Item Name")),
                            DataColumn(label: Text("Class")),
                            DataColumn(label: Text("Previous")),
                            DataColumn(label: Text("Inward")),
                            DataColumn(label: Text("Outward")),
                            DataColumn(label: Text("Total")),
                          ],
                          rows: stockData.map((item) {
                            return DataRow(cells: [
                              DataCell(Text(item['id']?.toString() ?? '')),
                              DataCell(Text(item['Items']?['itemName'] ?? '')),
                              DataCell(Text(item['classGroup'] ?? '')),
                              DataCell(Text(item['previousStock']?.toString() ?? '')),
                              DataCell(Text(item['inwardMaterial']?.toString() ?? '')),
                              DataCell(Text(item['outwardMaterial']?.toString() ?? '')),
                              DataCell(Text(item['totalStock']?.toString() ?? '')),
                            ]);
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
