import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class MDMMaterialStockPage extends StatefulWidget {
  const MDMMaterialStockPage({super.key});

  @override
  State<MDMMaterialStockPage> createState() => _MDMMaterialStockPageState();
}

class _MDMMaterialStockPageState extends State<MDMMaterialStockPage> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> stockList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStockData();
  }

  Future<void> _loadStockData() async {
    setState(() => isLoading = true);
    try {
      final response = await _apiService.getAllStocks();
      if (response['success'] == true && response['data'] is List) {
        setState(() {
          stockList = List<Map<String, dynamic>>.from(response['data']);
        });
      } else {
        setState(() => stockList = []);
        throw Exception(response['message'] ?? 'Failed to load stock data');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in _loadStockData: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load stock data: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _openInwardDialog() async {
    try {
      final itemsResponse = await _apiService.getAllItems();
      if (!itemsResponse['success'] || itemsResponse['data'] == null) {
        throw Exception(itemsResponse['message'] ?? 'Failed to load items');
      }

      final items = List<Map<String, dynamic>>.from(itemsResponse['data']);
      final dialogResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => InwardDetailsDialog(
          availableClassGroups: const ['1-5', '6-8'],
          availableItemNames: items.map<String>((item) => item['itemName'] as String).toList(),
        ),
      );

      if (dialogResult == null) return;

      final selectedItem = items.firstWhere(
        (item) => item['itemName'].toString().trim().toLowerCase() == dialogResult['itemName'].toString().trim().toLowerCase(),
        orElse: () => {},
      );

      if (selectedItem.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected item not found')));
        return;
      }

      final itemId = selectedItem['id'];
      final classGroup = dialogResult['classGroup'];
      final inwardQty = double.parse(dialogResult['inwardQty'].toString());

      setState(() => isLoading = true);
      final existingStock = stockList.firstWhere(
        (stock) => stock['ItemId'] == itemId && stock['classGroup'] == classGroup,
        orElse: () => {},
      );

      if (existingStock.isNotEmpty) {
        final response = await _apiService.updateStockInward(
          itemId: itemId.toString(),
          classGroup: classGroup,
          inwardMaterial: inwardQty,
        );

        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inward stock updated successfully')));
          await _loadStockData();
        } else {
          throw Exception(response['message'] ?? 'Failed to update inward stock');
        }
      } else {
        final createResponse = await _apiService.createStock(
          itemId: int.parse(itemId.toString()),
          previousStock: 0.0,
          inwardMaterial: inwardQty,
          outwardMaterial: 0.0,
          totalStock: inwardQty,
          classGroup: classGroup,
        );

        if (createResponse['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock created and inward updated')));
          await _loadStockData();
        } else {
          throw Exception(createResponse['message'] ?? 'Stock creation failed');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in _openInwardDialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _editStock(Map<String, dynamic> stock) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EditStockDialog(
        stock: stock,
        availableClassGroups: const ['1-5', '6-8'],
      ),
    );

    if (result == null) return;

    setState(() => isLoading = true);
    try {
      final response = await _apiService.updateStock(
        id: stock['id'].toString(),
        previousStock: result['previousStock'],
        inwardMaterial: result['inwardMaterial'],
        outwardMaterial: result['outwardMaterial'],
        totalStock: result['previousStock'] + result['inwardMaterial'] - result['outwardMaterial'],
        classGroup: result['classGroup'],
      );

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock updated')));
        await _loadStockData();
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to update stock');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteStock(String id, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Stock'),
        content: Text('Are you sure you want to delete the stock for $itemName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      final response = await _apiService.deleteStock(id);
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock deleted')));
        await _loadStockData();
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to delete stock');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Stock'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openInwardDialog,
            tooltip: 'Add Inward Stock',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStockData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stock List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    stockList.isEmpty
                        ? const Center(child: Text('No stock available'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Item Name')),
                                DataColumn(label: Text('Class Group')),
                                DataColumn(label: Text('Previous Stock')),
                                DataColumn(label: Text('Inward')),
                                DataColumn(label: Text('Outward')),
                                DataColumn(label: Text('Total Stock')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: stockList.map((s) {
                                return DataRow(cells: [
                                  DataCell(Text(s['Items']?['itemName']?.toString() ?? 'N/A')),
                                  DataCell(Text(s['classGroup']?.toString() ?? 'N/A')),
                                  DataCell(Text(s['previousStock']?.toStringAsFixed(2) ?? '0.00')),
                                  DataCell(Text(s['inwardMaterial']?.toStringAsFixed(2) ?? '0.00')),
                                  DataCell(Text(s['outwardMaterial']?.toStringAsFixed(2) ?? '0.00')),
                                  DataCell(Text(s['totalStock']?.toStringAsFixed(2) ?? '0.00')),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _editStock(s),
                                        tooltip: 'Edit Stock',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteStock(s['id'].toString(), s['Items']?['itemName']?.toString() ?? 'N/A'),
                                        tooltip: 'Delete Stock',
                                      ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}

class InwardDetailsDialog extends StatefulWidget {
  final List<String> availableItemNames;
  final List<String> availableClassGroups;

  const InwardDetailsDialog({
    super.key,
    required this.availableItemNames,
    required this.availableClassGroups,
  });

  @override
  State<InwardDetailsDialog> createState() => _InwardDetailsDialogState();
}

class _InwardDetailsDialogState extends State<InwardDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedItemName;
  late String _selectedClassGroup;
  final _inwardQtyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedItemName = widget.availableItemNames.isNotEmpty ? widget.availableItemNames.first : '';
    _selectedClassGroup = widget.availableClassGroups.isNotEmpty ? widget.availableClassGroups.first : '';
  }

  @override
  void dispose() {
    _inwardQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Inward Entry'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedItemName.isNotEmpty ? _selectedItemName : null,
                decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                items: widget.availableItemNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                onChanged: (value) => setState(() => _selectedItemName = value!),
                validator: (value) => value == null || value.isEmpty ? 'Select an item' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedClassGroup,
                decoration: const InputDecoration(labelText: 'Class Group', border: OutlineInputBorder()),
                items: widget.availableClassGroups.map((group) => DropdownMenuItem(value: group, child: Text(group))).toList(),
                onChanged: (value) => setState(() => _selectedClassGroup = value!),
                validator: (value) => value == null || value.isEmpty ? 'Select a class group' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _inwardQtyController,
                decoration: const InputDecoration(labelText: 'Inward Quantity', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter quantity';
                  final qty = num.tryParse(value);
                  if (qty == null || qty <= 0) return 'Enter valid quantity';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'itemName': _selectedItemName,
                'classGroup': _selectedClassGroup,
                'inwardQty': double.parse(_inwardQtyController.text),
              });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class EditStockDialog extends StatefulWidget {
  final Map<String, dynamic> stock;
  final List<String> availableClassGroups;

  const EditStockDialog({super.key, required this.stock, required this.availableClassGroups});

  @override
  State<EditStockDialog> createState() => _EditStockDialogState();
}

class _EditStockDialogState extends State<EditStockDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _previousStockController;
  late TextEditingController _inwardMaterialController;
  late TextEditingController _outwardMaterialController;
  late String _selectedClassGroup;

  @override
  void initState() {
    super.initState();
    _previousStockController = TextEditingController(text: widget.stock['previousStock']?.toString() ?? '0');
    _inwardMaterialController = TextEditingController(text: widget.stock['inwardMaterial']?.toString() ?? '0');
    _outwardMaterialController = TextEditingController(text: widget.stock['outwardMaterial']?.toString() ?? '0');
    _selectedClassGroup = widget.stock['classGroup']?.toString() ?? widget.availableClassGroups.first;
  }

  @override
  void dispose() {
    _previousStockController.dispose();
    _inwardMaterialController.dispose();
    _outwardMaterialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Stock for ${widget.stock['Items']?['itemName']?.toString() ?? 'N/A'}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _previousStockController,
                decoration: const InputDecoration(labelText: 'Previous Stock', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter previous stock';
                  final qty = num.tryParse(value);
                  if (qty == null || qty < 0) return 'Enter valid quantity';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _inwardMaterialController,
                decoration: const InputDecoration(labelText: 'Inward Material', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter inward material';
                  final qty = num.tryParse(value);
                  if (qty == null || qty < 0) return 'Enter valid quantity';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _outwardMaterialController,
                decoration: const InputDecoration(labelText: 'Outward Material', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter outward material';
                  final qty = num.tryParse(value);
                  if (qty == null || qty < 0) return 'Enter valid quantity';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedClassGroup,
                decoration: const InputDecoration(labelText: 'Class Group', border: OutlineInputBorder()),
                items: widget.availableClassGroups.map((group) => DropdownMenuItem(value: group, child: Text(group))).toList(),
                onChanged: (value) => setState(() => _selectedClassGroup = value!),
                validator: (value) => value == null || value.isEmpty ? 'Select a class group' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final previousStock = double.parse(_previousStockController.text);
              final inwardMaterial = double.parse(_inwardMaterialController.text);
              final outwardMaterial = double.parse(_outwardMaterialController.text);
              if (previousStock + inwardMaterial - outwardMaterial < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Total stock cannot be negative')),
                );
                return;
              }
              Navigator.pop(context, {
                'previousStock': previousStock,
                'inwardMaterial': inwardMaterial,
                'outwardMaterial': outwardMaterial,
                'classGroup': _selectedClassGroup,
              });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          child: const Text('Update'),
        ),
      ],
    );
  }
}