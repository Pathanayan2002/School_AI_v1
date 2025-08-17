import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class InventoryCalculationDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final List<String> classGroups;
  final List<Map<String, dynamic>> menus;

  const InventoryCalculationDialog({
    required this.onSubmit,
    required this.classGroups,
    required this.menus,
    super.key,
  });

  @override
  _InventoryCalculationDialogState createState() => _InventoryCalculationDialogState();
}

class _InventoryCalculationDialogState extends State<InventoryCalculationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  DateTime? date;
  int? totalStudents;
  String? classGroup;
  String? menuId;
  String? className;
  List<Map<String, dynamic>> itemsUsed = [];

  void _calculateRequiredQuantities(Map<String, dynamic> selectedMenu) {
    final selectedClassGroup = classGroup;
    if (selectedClassGroup == null || totalStudents == null) return;

    final items = selectedMenu['Items'] as List<dynamic>? ?? [];
    itemsUsed = items.map<Map<String, dynamic>>((item) {
      final quantityPerStudent = selectedClassGroup == '1-5'
          ? (item['quantity1_5'] ?? 0.0)
          : (item['quantity6_8'] ?? 0.0);
      return {
        'itemId': item['id'],
        'itemName': item['itemName'],
        'requiredQuantity': quantityPerStudent * totalStudents!,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Calculate Inventory'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  date == null ? 'Select Date' : 'Date: ${DateFormat('dd-MM-yyyy').format(date!)}',
                ),
                onTap: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (selectedDate != null) {
                    setState(() => date = selectedDate);
                  }
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Class Number (1-8)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a class number';
                  }
                  final classNumber = int.tryParse(value.trim());
                  if (classNumber == null || classNumber < 1 || classNumber > 8) {
                    return 'Class number must be between 1 and 8';
                  }
                  return null;
                },
                onSaved: (value) => className = value!.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Total Students'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid number of students';
                  }
                  return null;
                },
                onSaved: (value) => totalStudents = int.parse(value!),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Class Group'),
                value: classGroup,
                validator: (value) => value == null ? 'Please select a class group' : null,
                onChanged: (value) => setState(() => classGroup = value),
                items: widget.classGroups
                    .map((group) => DropdownMenuItem(value: group, child: Text(group)))
                    .toList(),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Menu'),
                value: menuId,
                validator: (value) => value == null ? 'Please select a menu' : null,
                onChanged: (value) {
                  setState(() {
                    menuId = value;
                    final selectedMenu = widget.menus.firstWhere((m) => m['id'].toString() == value);
                    _calculateRequiredQuantities(selectedMenu);
                  });
                },
                items: widget.menus.map((menu) {
                  return DropdownMenuItem(
                    value: menu['id'].toString(),
                    child: Text(menu['dishName']?.toString() ?? ''),
                  );
                }).toList(),
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
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              _formKey.currentState?.save();
              if (date == null || itemsUsed.isEmpty || className == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields and select a menu')),
                );
                return;
              }
              final classNumber = int.parse(className!);
              if ((classGroup == '1-5' && classNumber > 5) || (classGroup == '6-8' && classNumber < 6)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Class number must match selected class group')),
                );
                return;
              }
              try {
                final stocksData = await _apiService.getAllStocks();
                final stocks = stocksData['data'] as List<dynamic>? ?? [];
                for (final item in itemsUsed) {
                  final itemId = item['itemId'];
                  final requiredQty = item['requiredQuantity'] as double;

                  final matchingStock = stocks.firstWhere(
                    (s) => s['ItemId'] == itemId && s['classGroup'] == classGroup,
                    orElse: () => {},
                  );

                  if (matchingStock.isEmpty) {
                    throw Exception('Stock not found for ${item['itemName']} in group $classGroup');
                  }

                  final updatedStock = {
                    'previousStock': matchingStock['previousStock'] as double,
                    'inwardMaterial': matchingStock['inwardMaterial'] as double,
                    'outwardMaterial': (matchingStock['outwardMaterial'] as double) + requiredQty,
                    'totalStock': matchingStock['previousStock'] +
                        matchingStock['inwardMaterial'] -
                        ((matchingStock['outwardMaterial'] as double) + requiredQty),
                    'classGroup': matchingStock['classGroup'],
                  };

                  await _apiService.updateStock(
                    id: matchingStock['id'].toString(),
                    previousStock: updatedStock['previousStock'],
                    inwardMaterial: updatedStock['inwardMaterial'],
                    outwardMaterial: updatedStock['outwardMaterial'],
                    totalStock: updatedStock['totalStock'],
                    classGroup: updatedStock['classGroup'], updates: {},
                  );
                }

                final response = await _apiService.createReport(
                  date: DateFormat('dd-MM-yyyy').format(date!),
                  menuId: menuId!,
                  totalStudents: totalStudents!,
                  className: className!,
                );
                if (response['statusCode'] == 201) {
                  widget.onSubmit({
                    'date': DateFormat('dd-MM-yyyy').format(date!),
                    'totalStudents': totalStudents!,
                    'className': className!,
                    'menuId': int.parse(menuId!),
                    'itemsUsed': itemsUsed,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report created successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create report: ${response['statusMessage']}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error creating report: $e')),
                );
              }
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}