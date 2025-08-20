import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class InventoryCalculationDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final List<String> classGroups;
  final List<Map<String, dynamic>> menus;

  const InventoryCalculationDialog({
    super.key,
    required this.onSubmit,
    required this.classGroups,
    required this.menus,
  });

  @override
  State<InventoryCalculationDialog> createState() => _InventoryCalculationDialogState();
}

class _InventoryCalculationDialogState extends State<InventoryCalculationDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? selectedMenu;
  String? selectedClassGroup;
  final _classNameController = TextEditingController();
  final _totalStudentsController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.menus.isNotEmpty) {
      selectedMenu = widget.menus.first;
    }
    if (widget.classGroups.isNotEmpty) {
      selectedClassGroup = widget.classGroups.first;
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _totalStudentsController.dispose();
    super.dispose();
  }

 Future<void> _submitReport() async {
  if (!_formKey.currentState!.validate() || selectedMenu == null || selectedClassGroup == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill all fields correctly')),
    );
    return;
  }

  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    if (kDebugMode) {
      debugPrint('Submitting report with: menu=${selectedMenu?['dishName']}, '
          'classGroup=$selectedClassGroup, className=${_classNameController.text}, '
          'totalStudents=${_totalStudentsController.text}');
    }

    // Fetch stock data for validation
    final stocksData = await _apiService.getAllStocks();
    if (!stocksData['success']) {
      throw Exception(stocksData['message'] ?? 'Failed to fetch stock data');
    }
    final stocks = List<Map<String, dynamic>>.from(stocksData['data'] ?? []);
    final totalStudents = int.parse(_totalStudentsController.text);
    final menuItems = (selectedMenu!['Items'] as List<dynamic>?) ?? [];

    if (menuItems.isEmpty) {
      throw Exception('Selected menu has no items assigned');
    }

    // Validate stock availability
    for (final item in menuItems) {
      final itemId = item['id']?.toString();
      final itemName = item['itemName']?.toString() ?? 'Unknown';
      final qtyPerStudent = selectedClassGroup == '1-5' ? item['quantity1_5'] : item['quantity6_8'];
      if (qtyPerStudent == null || qtyPerStudent <= 0) {
        throw Exception('Invalid quantity for $itemName in group $selectedClassGroup');
      }
      final requiredQty = qtyPerStudent * totalStudents;

      final matchingStock = stocks.firstWhere(
        (s) => s['ItemId']?.toString() == itemId && s['classGroup'] == selectedClassGroup,
        orElse: () => {},
      );

      if (matchingStock.isEmpty) {
        throw Exception('Stock not found for $itemName in group $selectedClassGroup. Please add stock first.');
      }

      final totalStock = (matchingStock['totalStock'] is num
              ? (matchingStock['totalStock'] as num).toDouble()
              : double.tryParse(matchingStock['totalStock']?.toString() ?? '0')) ??
          0.0;

      if (totalStock < requiredQty) {
        throw Exception(
            'Insufficient stock for $itemName in group $selectedClassGroup. Available: $totalStock, Required: $requiredQty');
      }
    }

    // ✅ Properly send report data
    final today = DateFormat('dd-mm-yyyy').format(DateTime.now());
    final reportData = {
      'date': today,
      'menuId': selectedMenu!['id'].toString(),
      'totalStudents': totalStudents,
      'className': _classNameController.text.trim(),
    };

    if (kDebugMode) debugPrint('Report payload: $reportData');

  final reportResponse = await _apiService.createReport(
  date: today,
  menuId: selectedMenu!['id'], 
  totalStudent: totalStudents,
  className: _classNameController.text.trim(),
);


    if (reportResponse['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report created successfully')),
      );
      widget.onSubmit({
        ...reportData,
        'itemsUsed': reportResponse['data']['report']?['itemsUsed'] ?? [],
        'classGroup': reportResponse['data']['report']?['classGroup'] ?? selectedClassGroup,
        'Menu': {'dishName': reportResponse['data']['MenuName'] ?? selectedMenu!['dishName']},
      });
      Navigator.pop(context);
    } else {
      throw Exception(reportResponse['message'] ?? 'Failed to create report');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Report creation error: $e');
    setState(() => errorMessage = e.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $errorMessage')),
    );
  } finally {
    setState(() => isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Inventory Report'),
      content: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(
                        labelText: 'Select Menu',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedMenu,
                      items: widget.menus.isEmpty
                          ? [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('No menus available'),
                                enabled: false,
                              ),
                            ]
                          : widget.menus
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m['dishName']?.toString() ?? 'Unknown'),
                                  ))
                              .toList(),
                      onChanged: widget.menus.isEmpty
                          ? null
                          : (value) {
                              setState(() => selectedMenu = value);
                            },
                      validator: (value) => value == null ? 'Please select a menu' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Class Group',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedClassGroup,
                      items: widget.classGroups
                          .map((group) => DropdownMenuItem(
                                value: group,
                                child: Text(group),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedClassGroup = value);
                      },
                      validator: (value) => value == null ? 'Please select a class group' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _classNameController,
                      decoration: const InputDecoration(
                        labelText: 'Class Number (e.g., 3 or 3_A)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter class number';
                        }
                        final classNumberStr = value.trim().split('_')[0];
                        final classNumber = int.tryParse(classNumberStr);
                        if (classNumber == null || classNumber < 1 || classNumber > 8) {
                          return 'Class number must be between 1 and 8';
                        }
                        if (selectedClassGroup == '1-5' && classNumber > 5) {
                          return 'Class number must be 1-5';
                        }
                        if (selectedClassGroup == '6-8' && classNumber < 6) {
                          return 'Class number must be 6-8';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalStudentsController,
                      decoration: const InputDecoration(
                        labelText: 'Total Students',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter total students';
                        }
                        final num = int.tryParse(value);
                        if (num == null || num <= 0) {
                          return 'Enter a valid number of students';
                        }
                        return null;
                      },
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
          onPressed: isLoading ? null : _submitReport,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}