import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/stock_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final StockService _stockService = StockService();
  List<dynamic> inventoryItems = [];
  List<dynamic> dailyReports = [];
  bool _loading = true;
  bool _showReports = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

 Future<void> _loadData() async {
  try {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    // Load inventory items
    final items = await _stockService.getAllItems();
    debugPrint('Fetched items: $items');

    // Load daily reports, but don't fail the entire page if this fails
    List<dynamic> reports = [];
    try {
      // Format the date as YYYY-MM-DD
      final today = DateTime.now().toIso8601String().split('T')[0];
      reports = await _stockService.getDailyReports(date: today);
      debugPrint('Fetched reports: $reports');
    } catch (e) {
      debugPrint('Failed to fetch daily reports: $e');
      setState(() {
        _errorMessage = 'Failed to load daily reports. Inventory items are still available.';
      });
    }

    setState(() {
      inventoryItems = items;
      dailyReports = reports;
      _loading = false;
    });
  } catch (e) {
    debugPrint('Error in _loadData: $e');
    setState(() {
      _loading = false;
      _errorMessage = 'Failed to load inventory items: ${e.toString().replaceFirst('Exception: ', '')}';
      if (_errorMessage!.contains('401')) {
        _errorMessage = 'Session expired. Please log in again.';
      }
    });
  }
}
  Future<void> _addInventoryItem(Map<String, dynamic> newItem) async {
    try {
      final response = await _stockService.addItem(
        newItem['itemName'],
        newItem['quantity1_5'],
        newItem['quantity6_8'],
      );

      if (response['statusCode'] == 201) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add item: ${response['statusMessage']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateInventoryItem(int id, Map<String, dynamic> updates) async {
    try {
      final response = await _stockService.updateItem(id, updates);
      if (response['statusCode'] == 200) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update item: ${response['statusMessage']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteInventoryItem(int id) async {
    try {
      final response = await _stockService.deleteItemById(id);
      if (response['statusCode'] == 200) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete item: ${response['statusMessage']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AddInventoryItemDialog(
        onAdd: _addInventoryItem,
      ),
    );
  }

  void _showEditItemDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => EditInventoryItemDialog(
        item: item,
        onUpdate: (updates) => _updateInventoryItem(item['id'], updates),
      ),
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr).toUtc().add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Map<int, Map<String, double>> _calculateUsedQuantities() {
    final usedQuantities = <int, Map<String, double>>{};
    for (var report in dailyReports) {
      final itemsUsed = report['itemsUsed'] as Map<String, dynamic>? ?? {};
      debugPrint('Items used in report ${report['id']}: $itemsUsed');
      final classGroup = report['classGroup']?.toString() ?? '';
      for (var itemIdStr in itemsUsed.keys) {
        final itemId = int.tryParse(itemIdStr.toString()) ?? 0;
        debugPrint('Parsed itemId: $itemId from $itemIdStr');
        if (itemId == 0) continue;
        final usage = itemsUsed[itemIdStr] as Map<String, dynamic>? ?? {};
        usedQuantities[itemId] ??= {'quantity1_5': 0.0, 'quantity6_8': 0.0};
        if (classGroup == '1-5') {
          usedQuantities[itemId]!['quantity1_5'] = (usedQuantities[itemId]!['quantity1_5'] ?? 0.0) + (usage['quantity1_5']?.toDouble() ?? 0.0);
        } else if (classGroup == '6-8') {
          usedQuantities[itemId]!['quantity6_8'] = (usedQuantities[itemId]!['quantity6_8'] ?? 0.0) + (usage['quantity6_8']?.toDouble() ?? 0.0);
        }
      }
    }
    return usedQuantities;
  }

  @override
  Widget build(BuildContext context) {
    final usedQuantities = _calculateUsedQuantities();

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory - ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
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
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(_showReports ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showReports = !_showReports),
            tooltip: _showReports ? 'Hide Reports' : 'Show Reports',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _stockService.deleteJwtToken();
              Navigator.pushReplacementNamed(context, '/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _showAddItemDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("New Item"),
          ),
          const SizedBox(height: 10),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (_showReports && dailyReports.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("Report ID")),
                    DataColumn(label: Text("Menu")),
                    DataColumn(label: Text("Class Group")),
                    DataColumn(label: Text("Total Students")),
                    DataColumn(label: Text("Items Used")),
                  ],
                  rows: dailyReports.map((report) {
                    final menu = report['Menu'] as Map<String, dynamic>? ?? {};
                    final itemsUsed = report['itemsUsed'] as Map<String, dynamic>? ?? {};
                    final itemsUsedStr = itemsUsed.entries.map((e) => 'Item ${e.key}: 1-5: ${e.value['quantity1_5'] ?? 0}, 6-8: ${e.value['quantity6_8'] ?? 0}').join('; ');
                    return DataRow(cells: [
                      DataCell(Text(report['id']?.toString() ?? '')),
                      DataCell(Text(menu['dishName']?.toString() ?? '')),
                      DataCell(Text(report['classGroup']?.toString() ?? '')),
                      DataCell(Text(report['totalStudents']?.toString() ?? '')),
                      DataCell(Text(itemsUsedStr)),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : inventoryItems.isEmpty
                    ? const Center(child: Text('No inventory items found.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("Item ID")),
                            DataColumn(label: Text("Item Name")),
                            DataColumn(label: Text("Menu Items")),
                            DataColumn(label: Text("Class Group 1-5")),
                            DataColumn(label: Text("Used 1-5")),
                            DataColumn(label: Text("Remaining 1-5")),
                            DataColumn(label: Text("Class Group 6-8")),
                            DataColumn(label: Text("Used 6-8")),
                            DataColumn(label: Text("Remaining 6-8")),
                            DataColumn(label: Text("Created At")),
                            DataColumn(label: Text("Updated At")),
                            DataColumn(label: Text("Actions")),
                          ],
                          rows: inventoryItems.map((item) {
                            final menuNames = (item['Menus'] as List?)?.map((menu) => menu['dishName']?.toString() ?? '').join(', ') ?? '';
                            final itemId = item['id'] as int;
                            final used = usedQuantities[itemId] ?? {'quantity1_5': 0.0, 'quantity6_8': 0.0};
                            final remaining1_5 = (item['quantity1_5']?.toDouble() ?? 0.0) - used['quantity1_5']!;
                            final remaining6_8 = (item['quantity6_8']?.toDouble() ?? 0.0) - used['quantity6_8']!;
                            return DataRow(cells: [
                              DataCell(Text(item['id']?.toString() ?? '')),
                              DataCell(Text(item['itemName']?.toString() ?? '')),
                              DataCell(Text(menuNames)),
                              DataCell(Text(item['quantity1_5'] != null ? item['quantity1_5'].toStringAsFixed(2) : '')),
                              DataCell(Text(used['quantity1_5']!.toStringAsFixed(2))),
                              DataCell(Text(remaining1_5.toStringAsFixed(2), style: TextStyle(color: remaining1_5 < 0 ? Colors.red : null))),
                              DataCell(Text(item['quantity6_8'] != null ? item['quantity6_8'].toStringAsFixed(2) : '')),
                              DataCell(Text(used['quantity6_8']!.toStringAsFixed(2))),
                              DataCell(Text(remaining6_8.toStringAsFixed(2), style: TextStyle(color: remaining6_8 < 0 ? Colors.red : null))),
                              DataCell(Text(_formatDateTime(item['createdAt']))),
                              DataCell(Text(_formatDateTime(item['updatedAt']))),
                              DataCell(Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditItemDialog(item),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteInventoryItem(item['id']),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              )),
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

class AddInventoryItemDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;

  const AddInventoryItemDialog({super.key, required this.onAdd});

  @override
  State<AddInventoryItemDialog> createState() => _AddInventoryItemDialogState();
}

class _AddInventoryItemDialogState extends State<AddInventoryItemDialog> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _group1to5Controller = TextEditingController();
  final TextEditingController _group6to8Controller = TextEditingController();
  bool _isSubmitting = false;

  void _submit() {
    final itemName = _itemNameController.text.trim();
    final group1 = double.tryParse(_group1to5Controller.text.trim()) ?? 0.0;
    final group2 = double.tryParse(_group6to8Controller.text.trim()) ?? 0.0;

    if (itemName.isEmpty || group1 <= 0 || group2 <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid item details')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    widget.onAdd({
      'itemName': itemName,
      'quantity1_5': group1,
      'quantity6_8': group2,
    });

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Inventory Item"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: "Item Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _group1to5Controller,
              decoration: const InputDecoration(
                labelText: "Quantity (Class 1-5)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _group6to8Controller,
              decoration: const InputDecoration(
                labelText: "Quantity (Class 6-8)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Add"),
        ),
      ],
    );
  }
}

class EditInventoryItemDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) onUpdate;

  const EditInventoryItemDialog({super.key, required this.item, required this.onUpdate});

  @override
  State<EditInventoryItemDialog> createState() => _EditInventoryItemDialogState();
}

class _EditInventoryItemDialogState extends State<EditInventoryItemDialog> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _group1to5Controller = TextEditingController();
  final TextEditingController _group6to8Controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _itemNameController.text = widget.item['itemName']?.toString() ?? '';
    _group1to5Controller.text = widget.item['quantity1_5'] != null ? widget.item['quantity1_5'].toString() : '';
    _group6to8Controller.text = widget.item['quantity6_8'] != null ? widget.item['quantity6_8'].toString() : '';
  }

  void _submit() {
    final itemName = _itemNameController.text.trim();
    final group1 = double.tryParse(_group1to5Controller.text.trim()) ?? 0.0;
    final group2 = double.tryParse(_group6to8Controller.text.trim()) ?? 0.0;

    if (itemName.isEmpty || group1 <= 0 || group2 <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid item details')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    widget.onUpdate({
      'itemName': itemName,
      'quantity1_5': group1,
      'quantity6_8': group2,
    });

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Inventory Item"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: "Item Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _group1to5Controller,
              decoration: const InputDecoration(
                labelText: "Quantity (Class 1-5)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _group6to8Controller,
              decoration: const InputDecoration(
                labelText: "Quantity (Class 6-8)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Update"),
        ),
      ],
    );
  }
}