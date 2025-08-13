import 'package:flutter/material.dart';
import '../services/stock_service.dart';

class CarryForwardPage extends StatelessWidget {
  final StockService api = StockService();

  Future<void> carryForward(BuildContext context) async {
    try {
      final res = await api.carryForwardStock();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? "Carry forward successful")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to carry forward")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: ElevatedButton.icon(
          icon: Icon(Icons.sync),
          label: Text("Carry Forward Stocks"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            minimumSize: Size(double.infinity, 50),
            textStyle: TextStyle(fontSize: 16),
          ),
          onPressed: () => carryForward(context),
        ),
      ),
    );
  }
}
