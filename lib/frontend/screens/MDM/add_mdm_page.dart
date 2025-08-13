import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class AddItemPage extends StatefulWidget {
  @override
  _AddItemPageState createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final TextEditingController _itemNameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final StockService stockService = StockService();

  bool isSubmitting = false;

  Future<void> _submit() async {
    final itemName = _itemNameController.text.trim();
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      final response = await stockService.createItem(itemName);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Item added successfully')),
      );
      _itemNameController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add item: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add New Item")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _itemNameController,
                decoration: InputDecoration(labelText: "Item Name"),
                validator: (value) =>
                    value == null || value.isEmpty ? "Please enter item name" : null,
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text("Add Item"),
                onPressed: isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
