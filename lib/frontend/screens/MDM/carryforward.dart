import 'package:flutter/foundation.dart';
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

  Future<void> _carryForward() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Carry Forward Stocks'),
        content: const Text('This will reset inward and outward materials to 0 and set previous stock to current total stock. Continue?'),
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
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['statusMessage'] ?? 'Carry forward successful')),
        );
      } else {
        throw Exception(response['statusMessage'] ?? 'Unknown error');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Carry forward error: $e');
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
      appBar: AppBar(
        title: const Text('Carry Forward Stocks'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Carry Forward Stocks',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Reset stock values for the new period.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _carryForward,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Carry Forward'),
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