import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/stock_service.dart';

class MenuItemsPage extends StatefulWidget {
  const MenuItemsPage({super.key});

  @override
  State<MenuItemsPage> createState() => _MenuItemsPageState();
}

class _MenuItemsPageState extends State<MenuItemsPage> {
  List<dynamic> menuItems = [];
  List<dynamic> allItems = []; // To store all items for assignment
  final StockService _stockService = StockService();
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

 Future<void> _fetchData() async {
  try {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final menus = await _stockService.getAllMenus();
    debugPrint('Fetched menus: $menus'); // Add this log
    final items = await _stockService.getAllItems();
    debugPrint('Fetched items: $items'); // Add this log

    setState(() {
      menuItems = menus;
      allItems = items;
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _loading = false;
      _errorMessage = 'Failed to load data: ${e.toString().replaceFirst('Exception: ', '')}';
      if (_errorMessage!.contains('401')) {
        _errorMessage = 'Session expired. Please log in again.';
      }
    });
  }
}

  Future<void> _addMenu(String newMenuName) async {
    try {
      final response = await _stockService.addMenu(newMenuName);
      if (response['statusCode'] == 201) {
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu added successfully')),
        );
      } else {
        _showError('Failed to add menu: ${response['statusMessage']}');
      }
    } catch (e) {
      _showError('Failed to add menu: $e');
    }
  }

  Future<void> _updateMenu(int id, String dishName) async {
    try {
      final response = await _stockService.updateMenu(id, dishName);
      if (response['statusCode'] == 200) {
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu updated successfully')),
        );
      } else {
        _showError('Failed to update menu: ${response['statusMessage']}');
      }
    } catch (e) {
      _showError('Failed to update menu: $e');
    }
  }

  Future<void> _deleteMenu(int id) async {
    try {
      final response = await _stockService.deleteMenuById(id);
      if (response['statusCode'] == 200) {
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu deleted successfully')),
        );
      } else {
        _showError('Failed to delete menu: ${response['statusMessage']}');
      }
    } catch (e) {
      _showError('Failed to delete menu: $e');
    }
  }

  Future<void> _assignItemsToMenu(int menuId, List<int> itemIds) async {
    try {
      final response = await _stockService.assignItemsToMenu(menuId, itemIds);
      
      if (response['statusCode'] == 200) {
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items assigned to menu successfully')),
        );
      } else {
        _showError('Failed to assign items: ${response['statusMessage']}');
      }
    } catch (e) {
      _showError('Failed to assign items: $e');
    }
  }

  void _showAddMenuDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMenuDialog(onAdd: _addMenu),
    );
  }

  void _showEditMenuDialog(Map<String, dynamic> menu) {
    showDialog(
      context: context,
      builder: (context) => EditMenuDialog(
        menu: menu,
        onUpdate: (dishName) => _updateMenu(menu['id'], dishName),
      ),
    );
  }

  void _showAssignItemsDialog(int menuId) {
    showDialog(
      context: context,
      builder: (context) => AssignItemsDialog(
        allItems: allItems,
        onAssign: (itemIds) => _assignItemsToMenu(menuId, itemIds),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu Items - ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
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
            onPressed: _fetchData,
            tooltip: 'Refresh',
          ),
         
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _showAddMenuDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("New Menu"),
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
                    onPressed: _fetchData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : menuItems.isEmpty
                    ? const Center(child: Text('No menu items found.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
  columns: const [
    DataColumn(label: Text("Menu ID")),
    DataColumn(label: Text("Dish Name")),
    DataColumn(label: Text("School ID")),
    DataColumn(label: Text("Items")),
    DataColumn(label: Text("Created At")),
    DataColumn(label: Text("Updated At")),
    DataColumn(label: Text("Actions")),
  ],
  rows: menuItems.map((item) {
    final itemNames = (item['Items'] as List?)
        ?.map((i) => i['itemName']?.toString() ?? '')
        .join(', ') ??
        'None';
    return DataRow(cells: [
      DataCell(Text(item['id']?.toString() ?? '')),
      DataCell(Text(item['dishName']?.toString() ?? '')),
      DataCell(Text(item['schoolId']?.toString() ?? '')),
      DataCell(Text(itemNames)),
      DataCell(Text(_formatDateTime(item['createdAt']))),
      DataCell(Text(_formatDateTime(item['updatedAt']))),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _showEditMenuDialog(item),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteMenu(item['id']),
            tooltip: 'Delete',
          ),
          IconButton(
            icon: const Icon(Icons.link, color: Colors.green),
            onPressed: () => _showAssignItemsDialog(item['id']),
            tooltip: 'Assign Items',
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

class AddMenuDialog extends StatefulWidget {
  final Function(String) onAdd;

  const AddMenuDialog({super.key, required this.onAdd});

  @override
  State<AddMenuDialog> createState() => _AddMenuDialogState();
}

class _AddMenuDialogState extends State<AddMenuDialog> {
  final TextEditingController _menuNameController = TextEditingController();
  bool _isSubmitting = false;

  void _submit() {
    final name = _menuNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a menu name')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    widget.onAdd(name);
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Menu"),
      content: TextField(
        controller: _menuNameController,
        decoration: const InputDecoration(
          labelText: "Menu Name",
          border: OutlineInputBorder(),
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

class EditMenuDialog extends StatefulWidget {
  final Map<String, dynamic> menu;
  final Function(String) onUpdate;

  const EditMenuDialog({super.key, required this.menu, required this.onUpdate});

  @override
  State<EditMenuDialog> createState() => _EditMenuDialogState();
}

class _EditMenuDialogState extends State<EditMenuDialog> {
  final TextEditingController _menuNameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _menuNameController.text = widget.menu['dishName']?.toString() ?? '';
  }

  void _submit() {
    final name = _menuNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a menu name')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    widget.onUpdate(name);
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Menu"),
      content: TextField(
        controller: _menuNameController,
        decoration: const InputDecoration(
          labelText: "Menu Name",
          border: OutlineInputBorder(),
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

class AssignItemsDialog extends StatefulWidget {
  final List<dynamic> allItems;
  final Function(List<int>) onAssign;

  const AssignItemsDialog({super.key, required this.allItems, required this.onAssign});

  @override
  State<AssignItemsDialog> createState() => _AssignItemsDialogState();
}

class _AssignItemsDialogState extends State<AssignItemsDialog> {
  final Set<int> _selectedItemIds = {};
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Assign Items to Menu"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.allItems.map((item) {
            final itemId = item['id'] as int;
            return CheckboxListTile(
              title: Text(item['itemName']?.toString() ?? ''),
              value: _selectedItemIds.contains(itemId),
              onChanged: (bool? selected) {
                setState(() {
                  if (selected == true) {
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  if (_selectedItemIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one item')),
                    );
                    return;
                  }
                  setState(() => _isSubmitting = true);
                  widget.onAssign(_selectedItemIds.toList());
                  setState(() => _isSubmitting = false);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Assign"),
        ),
      ],
    );
  }
}