import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:animate_do/animate_do.dart';

class MenuItemsPage extends StatefulWidget {
  const MenuItemsPage({super.key});

  @override
  State<MenuItemsPage> createState() => _MenuItemsPageState();
}

class _MenuItemsPageState extends State<MenuItemsPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _dishNameController = TextEditingController();
  List<Map<String, dynamic>> _menus = [];
  List<Map<String, dynamic>> _items = [];
  List<String> _selectedItemIds = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _showAddMenuForm = false;
  Map<String, dynamic>? _editingMenu;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final menusResponse = await _apiService.getAllMenus();
      final itemsResponse = await _apiService.getAllItems();
      setState(() {
        _menus = List<Map<String, dynamic>>.from(menusResponse['data'] ?? []);
        _items = List<Map<String, dynamic>>.from(itemsResponse['data'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addMenu() async {
    final dishName = _dishNameController.text.trim();
    if (dishName.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a dish name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.addMenu(dishName: dishName);
      if (response['statusCode'] == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['statusMessage'] ?? 'Menu added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _dishNameController.clear();
        setState(() {
          _showAddMenuForm = false;
        });
        await _fetchData();
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to add menu');
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

  Future<void> _updateMenu(String id, String dishName) async {
    if (dishName.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a dish name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.updateMenu(id: id, dishName: dishName);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['statusMessage'] ?? 'Menu updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _editingMenu = null;
          _dishNameController.clear();
        });
        await _fetchData();
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to update menu');
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

  Future<void> _deleteMenu(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Menu'),
        content: const Text('Are you sure you want to delete this menu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.deleteMenu(id);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['statusMessage'] ?? 'Menu deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchData();
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to delete menu');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignItemsToMenu(String menuId) async {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.assignItemsToMenu(menuId: menuId, itemIds: _selectedItemIds);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['statusMessage'] ?? 'Items assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _selectedItemIds = []);
        await _fetchData();
      } else {
        throw Exception(response['statusMessage'] ?? 'Failed to assign items');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openAssignItemsDialog(String menuId) async {
    setState(() {
      _selectedItemIds = [];
      _errorMessage = null;
    });

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Items to Menu'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _items.map((item) {
                final itemId = item['id'].toString();
                return CheckboxListTile(
                  title: Text(item['itemName'] ?? 'Unknown Item'),
                  value: _selectedItemIds.contains(itemId),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        _selectedItemIds.add(itemId);
                      } else {
                        _selectedItemIds.remove(itemId);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _assignItemsToMenu(menuId),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MDM Menu Items',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(_showAddMenuForm ? Icons.close : Icons.add),
            onPressed: () {
              setState(() {
                _showAddMenuForm = !_showAddMenuForm;
                _editingMenu = null;
                _dishNameController.clear();
                _errorMessage = null;
              });
            },
            tooltip: _showAddMenuForm ? 'Close Form' : 'Add Menu',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showAddMenuForm)
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
                                  Text(
                                    _editingMenu == null ? 'Add New Menu' : 'Edit Menu',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _dishNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Dish Name',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _editingMenu == null
                                            ? _addMenu()
                                            : _updateMenu(_editingMenu!['id'].toString(), _dishNameController.text.trim()),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(_editingMenu == null ? 'Add Menu' : 'Update Menu'),
                                  ),
                                  if (_errorMessage != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(color: Colors.red),
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
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (items.isEmpty)
                                                const Text('No items assigned')
                                              else
                                                ...items.map((item) => ListTile(
                                                      title: Text(
                                                        item['itemName'] ?? 'Unknown Item',
                                                        style: TextStyle(color: Colors.grey[800]),
                                                      ),
                                                      subtitle: Text(
                                                        'Qty 1-5: ${item['quantity1_5']}, Qty 6-8: ${item['quantity6_8']}',
                                                        style: TextStyle(color: Colors.grey[600]),
                                                      ),
                                                    )),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                                    onPressed: () {
                                                      setState(() {
                                                        _editingMenu = menu;
                                                        _dishNameController.text = menu['dishName'] ?? '';
                                                        _showAddMenuForm = true;
                                                        _errorMessage = null;
                                                      });
                                                    },
                                                    tooltip: 'Edit Menu',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                    onPressed: () => _deleteMenu(menu['id'].toString()),
                                                    tooltip: 'Delete Menu',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.add_circle, color: Colors.green),
                                                    onPressed: () => _openAssignItemsDialog(menu['id'].toString()),
                                                    tooltip: 'Assign Items',
                                                  ),
                                                ],
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
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showAddMenuForm = !_showAddMenuForm;
            _editingMenu = null;
            _dishNameController.clear();
            _errorMessage = null;
          });
        },
        backgroundColor: Theme.of(context).primaryColor,
        tooltip: _showAddMenuForm ? 'Close Form' : 'Add Menu',
        child: Icon(_showAddMenuForm ? Icons.close : Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    super.dispose();
  }
}