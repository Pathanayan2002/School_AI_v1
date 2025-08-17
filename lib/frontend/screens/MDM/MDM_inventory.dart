import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:animate_do/animate_do.dart';

class MDMInventoryPage extends StatefulWidget {
  const MDMInventoryPage({super.key});

  @override
  _MDMInventoryPageState createState() => _MDMInventoryPageState();
}

class _MDMInventoryPageState extends State<MDMInventoryPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantity15Controller = TextEditingController();
  final TextEditingController _quantity68Controller = TextEditingController();
  List<dynamic> _stocks = [];
  List<dynamic> _items = [];
  List<dynamic> _menus = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _showAddItemForm = false;

  @override
  void initState() {
    super.initState();
    _fetchInventoryData();
  }

  Future<void> _fetchInventoryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stocksResponse = await _apiService.getAllStocks();
      final itemsResponse = await _apiService.getAllItems();
      final menusResponse = await _apiService.getAllMenus();
      setState(() {
        _stocks = List<dynamic>.from(stocksResponse['data'] ?? []);
        _items = List<dynamic>.from(itemsResponse['data'] ?? []);
        _menus = List<dynamic>.from(menusResponse['data'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addItem() async {
    final itemName = _itemNameController.text.trim();
    final quantity15 = double.tryParse(_quantity15Controller.text.trim()) ?? 0.0;
    final quantity68 = double.tryParse(_quantity68Controller.text.trim()) ?? 0.0;

    if (itemName.isEmpty || quantity15 <= 0 || quantity68 <= 0) {
      setState(() {
        _errorMessage = 'Please fill all fields with valid values';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.addItem(
        itemName: itemName,
        quantity1_5: quantity15,
        quantity6_8: quantity68,
      );
      if (response['statusCode'] == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['statusMessage'] ?? 'Item added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _itemNameController.clear();
        _quantity15Controller.clear();
        _quantity68Controller.clear();
        setState(() {
          _showAddItemForm = false;
        });
        await _fetchInventoryData();
      } else {
        setState(() {
          _errorMessage = response['statusMessage'] ?? 'Failed to add item';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MDM Inventory',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showAddItemForm ? Icons.close : Icons.add),
            onPressed: () {
              setState(() {
                _showAddItemForm = !_showAddItemForm;
                _errorMessage = null;
              });
            },
            tooltip: _showAddItemForm ? 'Close Form' : 'Add Item',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).primaryColor.withOpacity(0.1), Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchInventoryData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_showAddItemForm)
                          FadeIn(
                            duration: const Duration(milliseconds: 300),
                            child: Card(
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Add New Item',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _itemNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Item Name',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _quantity15Controller,
                                      decoration: InputDecoration(
                                        labelText: 'Quantity (Classes 1-5)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _quantity68Controller,
                                      decoration: InputDecoration(
                                        labelText: 'Quantity (Classes 6-8)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _isLoading ? null : _addItem,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('Add Item'),
                                    ),
                                    if (_errorMessage != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        FadeIn(
                          duration: const Duration(milliseconds: 400),
                          child: const Text(
                            'Stocks',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _stocks.isEmpty
                            ? const Center(child: Text('No stocks available'))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _stocks.length,
                                itemBuilder: (context, index) {
                                  final stock = _stocks[index];
                                  final item = stock['Items'] ?? {};
                                  return FadeInUp(
                                    duration: Duration(milliseconds: 300 + index * 100),
                                    child: Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ExpansionTile(
                                        title: Text(
                                          item['itemName'] ?? 'Unknown Item',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Class Group: ${stock['classGroup']}',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Previous Stock: ${stock['previousStock']}'),
                                                Text('Inward: ${stock['inwardMaterial']}'),
                                                Text('Outward: ${stock['outwardMaterial']}'),
                                                Text(
                                                  'Total Stock: ${stock['totalStock']}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 24),
                        FadeIn(
                          duration: const Duration(milliseconds: 400),
                          child: const Text(
                            'Menus',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _menus.isEmpty
                            ? const Center(child: Text('No menus available'))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _menus.length,
                                itemBuilder: (context, index) {
                                  final menu = _menus[index];
                                  final items = (menu['Items'] as List<dynamic>?) ?? [];
                                  return FadeInUp(
                                    duration: Duration(milliseconds: 300 + index * 100),
                                    child: Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ExpansionTile(
                                        title: Text(
                                          menu['dishName'] ?? 'Unknown Menu',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Items: ${items.length}',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        children: items.isEmpty
                                            ? [
                                                const Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Text('No items assigned'),
                                                ),
                                              ]
                                            : items.map((item) {
                                                return ListTile(
                                                  title: Text(
                                                    item['itemName'] ?? 'Unknown Item',
                                                    style: TextStyle(color: Colors.grey[800]),
                                                  ),
                                                  subtitle: Text(
                                                    'Qty 1-5: ${item['quantity1_5']}, Qty 6-8: ${item['quantity6_8']}',
                                                    style: TextStyle(color: Colors.grey[600]),
                                                  ),
                                                );
                                              }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showAddItemForm = !_showAddItemForm;
            _errorMessage = null;
          });
        },
        backgroundColor: Theme.of(context).primaryColor,
        tooltip: _showAddItemForm ? 'Close Form' : 'Add Item',
        child: Icon(_showAddItemForm ? Icons.close : Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantity15Controller.dispose();
    _quantity68Controller.dispose();
    super.dispose();
  }
}