import 'package:Ai_School_App/frontend/screens/MDM/InwardDetailsDialog.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart'; // Import the ApiService
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

class MDMMaterialStockPage extends StatefulWidget {
  const MDMMaterialStockPage({super.key});

  @override
  State<MDMMaterialStockPage> createState() => _MDMMaterialStockPageState();
}

class _MDMMaterialStockPageState extends State<MDMMaterialStockPage> {
  final _apiService = ApiService(); // Use ApiService directly
  List<Map<String, dynamic>> stockList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiService.init().then((_) => _loadStockData()); // Initialize API once
  }

  Future<void> _loadStockData() async {
    setState(() => isLoading = true);
    try {
      final response = await _apiService.getAllStocks();
      if (kDebugMode) {
        debugPrint('getAllStocks response: $response');
      }
      if (response['success'] == true && response['data'] is List) {
        setState(() {
          stockList = List<Map<String, dynamic>>.from(response['data']);
          if (kDebugMode) {
            debugPrint('Stock list updated: ${stockList.length} items');
          }
        });
      } else {
        setState(() => stockList = []); // Clear list on failure
        throw Exception(response['message'] ?? 'Failed to load stock data');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in _loadStockData: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load stock data: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _openInwardDialog() async {
    try {
      final itemsResponse = await _apiService.getAllItems();
      if (kDebugMode) {
        debugPrint('getAllItems response: $itemsResponse');
      }

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
        (item) => item['itemName'].toString().trim().toLowerCase() ==
                  dialogResult['itemName'].toString().trim().toLowerCase(),
        orElse: () => {},
      );

      if (selectedItem.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected item not found')),
        );
        return;
      }

      final itemId = selectedItem['id'];
      final classGroup = dialogResult['classGroup'];
      final inwardQty = double.parse(dialogResult['inwardQty'].toString());

      if (kDebugMode) {
        debugPrint('Attempting to update stock: itemId=$itemId, classGroup=$classGroup, inwardQty=$inwardQty');
      }

      setState(() => isLoading = true); // Show loading indicator
      final updateResponse = await _apiService.updateStockInward(
        itemId: itemId.toString(),
        classGroup: classGroup,
        inwardMaterial: inwardQty,
      );

      if (kDebugMode) {
        debugPrint('updateStockInward response: $updateResponse');
      }

      if (updateResponse['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inward stock updated successfully')),
        );
        await _loadStockData();
        await Future.delayed(const Duration(milliseconds: 300)); // Brief delay for UX
      } else {
        final createResponse = await _apiService.createStock(
          itemId: int.parse(itemId.toString()),
          previousStock: 0.0,
          inwardMaterial: inwardQty,
          outwardMaterial: 0.0,
          totalStock: inwardQty,
          classGroup: classGroup,
        );

        if (kDebugMode) {
          debugPrint('createStock response: $createResponse');
        }

        if (createResponse['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock created and inward updated')),
          );
          await _loadStockData();
          await Future.delayed(const Duration(milliseconds: 300)); // Brief delay for UX
        } else {
          throw Exception(createResponse['message'] ?? 'Stock creation failed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in _openInwardDialog: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _carryForward() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Carry Forward Stocks'),
        content: const Text('This will reset inward/outward and carry forward totals. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      final response = await _apiService.carryForwardStock();
      if (kDebugMode) {
        debugPrint('carryForwardStock response: $response');
      }
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Carry forward successful')),
        );
        await _loadStockData();
        await Future.delayed(const Duration(milliseconds: 300)); // Brief delay for UX
      } else {
        throw Exception(response['message'] ?? 'Failed to carry forward stock');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in _carryForward: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _editStock(Map<String, dynamic> stock) async {
    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EditStockDialog(
        stock: stock,
        availableClassGroups: const ['1-5', '6-8'],
      ),
    );

    if (dialogResult != null) {
      try {
        final totalStock = dialogResult['previousStock'] +
            dialogResult['inwardMaterial'] -
            dialogResult['outwardMaterial'];
        final response = await _apiService.updateStock(
          id: stock['id'].toString(),
          previousStock: dialogResult['previousStock'],
          inwardMaterial: dialogResult['inwardMaterial'],
          outwardMaterial: dialogResult['outwardMaterial'],
          totalStock: totalStock,
          classGroup: dialogResult['classGroup'],
          updates: {},
        );
        if (kDebugMode) {
          debugPrint('updateStock response: $response');
        }
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock updated')),
          );
          await _loadStockData();
          await Future.delayed(const Duration(milliseconds: 300)); // Brief delay for UX
        } else {
          throw Exception(response['message'] ?? 'Failed to update stock');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error in _editStock: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteStock(String stockId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Stock'),
        content: Text('Are you sure you want to delete the stock for "$itemName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      final response = await _apiService.deleteStock(stockId);
      if (kDebugMode) {
        debugPrint('deleteStock response: $response');
      }
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Stock deleted successfully')),
        );
        await _loadStockData();
        await Future.delayed(const Duration(milliseconds: 300)); // Brief delay for UX
      } else {
        throw Exception(response['message'] ?? 'Failed to delete stock');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in _deleteStock: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 Material in Stock'),
        backgroundColor: Colors.indigo,
        centerTitle: true,
        elevation: 4,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Inward'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo),
                        onPressed: _openInwardDialog,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.sync),
                        label: const Text('Carry Forward'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: _carryForward,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        key: ValueKey(stockList.length), // Force rebuild on stockList change
                        headingRowColor: WidgetStateProperty.all(Colors.indigo.shade100),
                        columns: const [
                          DataColumn(label: Text('Item')),
                          DataColumn(label: Text('Class')),
                          DataColumn(label: Text('Prev')),
                          DataColumn(label: Text('Inward')),
                          DataColumn(label: Text('Outward')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('Edit')),
                          DataColumn(label: Text('Delete')),
                        ],
                        rows: stockList.isEmpty
                            ? [
                                const DataRow(cells: [
                                  DataCell(Text('No stocks available')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ])
                              ]
                            : stockList.map((s) {
                                return DataRow(cells: [
                                  DataCell(Text(s['Items']?['itemName']?.toString() ?? 'N/A')),
                                  DataCell(Text(s['classGroup']?.toString() ?? 'N/A')),
                                  DataCell(Text(s['previousStock']?.toString() ?? '0')),
                                  DataCell(Text(s['inwardMaterial']?.toString() ?? '0')),
                                  DataCell(Text(s['outwardMaterial']?.toString() ?? '0')),
                                  DataCell(Text(s['totalStock']?.toString() ?? '0')),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                      onPressed: () => _editStock(s),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () => _deleteStock(s['id'].toString(), s['Items']?['itemName']?.toString() ?? 'N/A'),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildNumberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Enter $label';
          if (double.tryParse(value) == null) return 'Invalid number';
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Stock', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Item: ${widget.stock['Items']?['itemName']?.toString() ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedClassGroup,
                decoration: const InputDecoration(labelText: 'Class Group'),
                items: widget.availableClassGroups.map((group) {
                  return DropdownMenuItem(value: group, child: Text(group));
                }).toList(),
                onChanged: (value) => setState(() => _selectedClassGroup = value!),
                validator: (value) => value == null ? 'Please select a class group' : null,
              ),
              _buildNumberField('Previous Stock', _previousStockController),
              _buildNumberField('Inward Material', _inwardMaterialController),
              _buildNumberField('Outward Material', _outwardMaterialController),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'previousStock': double.parse(_previousStockController.text),
                'inwardMaterial': double.parse(_inwardMaterialController.text),
                'outwardMaterial': double.parse(_outwardMaterialController.text),
                'classGroup': _selectedClassGroup,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}