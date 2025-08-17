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
    // Set default values
    _selectedItemName = widget.availableItemNames.isNotEmpty
        ? widget.availableItemNames.first
        : '';
    _selectedClassGroup = widget.availableClassGroups.isNotEmpty
        ? widget.availableClassGroups.first
        : '';
  }

  @override
  void dispose() {
    _inwardQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Inward Entry', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedItemName.isNotEmpty ? _selectedItemName : null,
              decoration: const InputDecoration(labelText: 'Item Name'),
              items: widget.availableItemNames.map((name) {
                return DropdownMenuItem(value: name, child: Text(name));
              }).toList(),
              onChanged: (value) => setState(() => _selectedItemName = value!),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Please select an item' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedClassGroup,
              decoration: const InputDecoration(labelText: 'Class Group'),
              items: widget.availableClassGroups.map((group) {
                return DropdownMenuItem(value: group, child: Text(group));
              }).toList(),
              onChanged: (value) => setState(() => _selectedClassGroup = value!),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Please select a class group' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _inwardQtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Inward Quantity',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter inward quantity';
                final num? qty = num.tryParse(value);
                if (qty == null || qty <= 0) return 'Invalid quantity';
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
