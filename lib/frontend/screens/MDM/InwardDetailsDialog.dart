import 'package:flutter/material.dart';

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
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedItemName.isNotEmpty ? _selectedItemName : null,
              decoration: const InputDecoration(labelText: 'Item Name'),
              items: widget.availableItemNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
              onChanged: (value) => setState(() => _selectedItemName = value!),
              validator: (value) => value == null || value.isEmpty ? 'Select an item' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedClassGroup,
              decoration: const InputDecoration(labelText: 'Class Group'),
              items: widget.availableClassGroups.map((group) => DropdownMenuItem(value: group, child: Text(group))).toList(),
              onChanged: (value) => setState(() => _selectedClassGroup = value!),
              validator: (value) => value == null || value.isEmpty ? 'Select a class group' : null,
            ),
            TextFormField(
              controller: _inwardQtyController,
              decoration: const InputDecoration(labelText: 'Inward Quantity'),
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
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
          child: const Text('Submit'),
        ),
      ],
    );
  }
}