import 'package:flutter/material.dart';

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
  DateTime? date;
  int? totalStudents;
  String? classGroup;
  String? menuId;
  List<Map<String, dynamic>> itemsUsed = [];

  void _calculateRequiredQuantities(Map<String, dynamic> selectedMenu) {
    final selectedClassGroup = classGroup;
    if (selectedClassGroup == null || totalStudents == null) return;

    final items = selectedMenu['Items'] as List<dynamic>;
    itemsUsed = items.map<Map<String, dynamic>>((item) {
      final quantityPerStudent = selectedClassGroup == '1-5'
          ? (item['quantity1_5'] ?? 0.0)
          : (item['quantity6_8'] ?? 0.0);
      return {
        'itemId': item['id'],
        'quantityUsed': quantityPerStudent * totalStudents!,
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
                  date == null ? 'Select Date' : 'Date: ${date!.toString().split(' ')[0]}',
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
                decoration: const InputDecoration(labelText: 'Total Students'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || int.tryParse(value) == null) {
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
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              _formKey.currentState?.save();
              if (date == null || itemsUsed.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select date and menu to calculate.')),
                );
                return;
              }
              widget.onSubmit({
                'date': date!.toString().split(' ')[0],
                'totalStudents': totalStudents!,
                'classGroup': classGroup!,
                'menuId': int.parse(menuId!),
                'itemsUsed': itemsUsed,
                'exportToExcel': true,
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
