import 'package:flutter/material.dart';
import '../services/api_client.dart';

class CarryForwardPage extends StatefulWidget {
  const CarryForwardPage({super.key});

  @override
  State<CarryForwardPage> createState() => _CarryForwardPageState();
}

class _CarryForwardPageState extends State<CarryForwardPage> {
  final ApiService _api = ApiService();
  bool _isLoading = false;

  Future<void> _carryForward(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Carry Forward Stocks'),
        content: const Text(
          'This will reset inward and outward materials to 0 and set previous stock to current total stock for all items. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _api.carryForwardStock();
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['statusMessage'] ?? 'Carry forward successful')),
        );
      } else if (response['statusCode'] == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['statusMessage'] ?? 'No stock records found to carry forward')),
        );
      } else {
        throw Exception(response['statusMessage'] ?? 'Unknown error');
      }
    } catch (e) {
      debugPrint('Carry forward error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to carry forward: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carry Forward Stocks')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        const Text(
                          'Carry Forward Stocks',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This action will reset stock values for the new period.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.sync),
                          label: const Text('Carry Forward'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            minimumSize: const Size(200, 50),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                          onPressed: () => _carryForward(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}