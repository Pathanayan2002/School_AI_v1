import 'package:flutter/material.dart';
import '../services/api_client.dart';

class MDMInventoryPage extends StatefulWidget {
  const MDMInventoryPage({super.key});

  @override
  State<MDMInventoryPage> createState() => _MDMInventoryPageState();
}

class _MDMInventoryPageState extends State<MDMInventoryPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantity1_5Controller = TextEditingController();
  final TextEditingController _quantity6_8Controller = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _showAddItemForm = false;
  Map<String, dynamic>? _editingItem;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiService.getAllItems();
      if (response['success']) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(response['data'] ?? []);
        });
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to load items');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addItem() async {
    final itemName = _itemNameController.text.trim();
    final quantity1_5 = double.tryParse(_quantity1_5Controller.text.trim());
    final quantity6_8 = double.tryParse(_quantity6_8Controller.text.trim());

    if (itemName.isEmpty || quantity1_5 == null || quantity6_8 == null) {
      setState(() => _errorMessage = 'Please fill all fields with valid values');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiService.addItem(
        itemName: itemName,
        quantity1_5: quantity1_5,
        quantity6_8: quantity6_8,
      );
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item added')));
        _itemNameController.clear();
        _quantity1_5Controller.clear();
        _quantity6_8Controller.clear();
        setState(() => _showAddItemForm = false);
        await _fetchItems();
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to add item');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateItem(String id) async {
    final itemName = _itemNameController.text.trim();
    final quantity1_5 = double.tryParse(_quantity1_5Controller.text.trim());
    final quantity6_8 = double.tryParse(_quantity6_8Controller.text.trim());

    if (itemName.isEmpty && quantity1_5 == null && quantity6_8 == null) {
      setState(() => _errorMessage = 'At least one field must be updated');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiService.updateItem(
        id: id,
        itemName: itemName.isNotEmpty ? itemName : null,
        quantity1_5: quantity1_5,
        quantity6_8: quantity6_8,
      );
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item updated')));
        _itemNameController.clear();
        _quantity1_5Controller.clear();
        _quantity6_8Controller.clear();
        setState(() {
          _editingItem = null;
          _showAddItemForm = false;
        });
        await _fetchItems();
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to update item');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.deleteItem(id);
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted')));
        await _fetchItems();
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to delete item');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Items'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(_showAddItemForm ? Icons.close : Icons.add),
            onPressed: () {
              setState(() {
                _showAddItemForm = !_showAddItemForm;
                _editingItem = null;
                _itemNameController.clear();
                _quantity1_5Controller.clear();
                _quantity6_8Controller.clear();
                _errorMessage = null;
              });
            },
            tooltip: _showAddItemForm ? 'Close Form' : 'Add Item',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showAddItemForm) ...[
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _editingItem == null ? 'Add Item' : 'Edit Item',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _itemNameController,
                              decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _quantity1_5Controller,
                              decoration: const InputDecoration(labelText: 'Quantity (Classes 1-5)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _quantity6_8Controller,
                              decoration: const InputDecoration(labelText: 'Quantity (Classes 6-8)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                              ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _editingItem == null
                                      ? _addItem()
                                      : _updateItem(_editingItem!['id'].toString()),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                              child: Text(_editingItem == null ? 'Add' : 'Update'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Inventory Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _items.isEmpty
                      ? const Center(child: Text('No items available'))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              elevation: 2,
                              child: ListTile(
                                title: Text(item['itemName'] ?? 'Unknown Item'),
                                subtitle: Text('Qty 1-5: ${item['quantity1_5']}, Qty 6-8: ${item['quantity6_8']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        setState(() {
                                          _editingItem = item;
                                          _itemNameController.text = item['itemName'] ?? '';
                                          _quantity1_5Controller.text = item['quantity1_5']?.toString() ?? '';
                                          _quantity6_8Controller.text = item['quantity6_8']?.toString() ?? '';
                                          _showAddItemForm = true;
                                          _errorMessage = null;
                                        });
                                      },
                                      tooltip: 'Edit Item',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteItem(item['id'].toString()),
                                      tooltip: 'Delete Item',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantity1_5Controller.dispose();
    _quantity6_8Controller.dispose();
    super.dispose();
  }
}