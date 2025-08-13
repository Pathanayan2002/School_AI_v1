import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class InwardDetailsDialog extends StatefulWidget {
  final List<String> availableClassGroups;
  final List<String> availableItemNames;

  const InwardDetailsDialog({
    Key? key,
    required this.availableClassGroups,
    required this.availableItemNames,
  }) : super(key: key);

  @override
  State<InwardDetailsDialog> createState() => _InwardDetailsDialogState();
}

class _InwardDetailsDialogState extends State<InwardDetailsDialog> {
  String? selectedClassGroup;
  String? selectedItemName;
  final TextEditingController quantityController = TextEditingController();
  String? message;
  bool isSubmitting = false;

  final StockService _stockService = StockService();

  Future<void> _submitInward() async {
    if (selectedClassGroup == null || selectedItemName == null || quantityController.text.isEmpty) {
      setState(() => message = 'Please fill all fields');
      return;
    }

    setState(() {
      isSubmitting = true;
      message = null;
    });

    try {
      final itemList = await _stockService.getAllItems();
      final matchedItem = itemList.firstWhere(
        (item) => item['itemName'] == selectedItemName,
        orElse: () => {},
      );

      if (matchedItem.isEmpty) {
        setState(() => message = 'Selected item not found');
        return;
      }

      final itemId = matchedItem['id'];
      final inwardQty = double.tryParse(quantityController.text);

      if (inwardQty == null || inwardQty <= 0) {
        setState(() => message = 'Enter a valid quantity greater than 0');
        return;
      }

      final result = await _stockService.updateStockInward({
        'ItemId': itemId,
        'classGroup': selectedClassGroup,
        'inwardMaterial': inwardQty,
      });

      if (result['statusCode'] == 200) {
        Navigator.of(context).pop();
      } else {
        setState(() => message = result['statusMessage']);
      }
    } catch (e) {
      setState(() => message = 'Error submitting inward: $e');
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Add Inward Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedClassGroup,
            items: widget.availableClassGroups
                .map((group) => DropdownMenuItem(value: group, child: Text(group)))
                .toList(),
            onChanged: (val) => setState(() => selectedClassGroup = val),
            decoration: const InputDecoration(labelText: 'Class Group'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedItemName,
            items: widget.availableItemNames
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (val) => setState(() => selectedItemName = val),
            decoration: const InputDecoration(labelText: 'Item Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Inward Quantity'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isSubmitting ? null : _submitInward,
            child: isSubmitting ? const CircularProgressIndicator() : const Text('Submit'),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(message!, style: const TextStyle(color: Colors.red)),
            )
        ],
      ),
    );
  }
}
