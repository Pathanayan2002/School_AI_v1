import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StockService {
  static const String _baseUrl = 'http://localhost:8001/api/mdm';
  static const Duration _timeout = Duration(seconds: 10);
  final Dio _dio;
  final FlutterSecureStorage _storage;

  StockService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            headers: {
              'Content-Type': 'application/json',
              if (kIsWeb) 'Accept': '*/*',
            },
            connectTimeout: _timeout,
            receiveTimeout: _timeout,
            sendTimeout: _timeout,
            extra: {'withCredentials': true},
          ),
        ),
        _storage = const FlutterSecureStorage();

  Future<String?> _getAuthToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    final headers = {
      'Content-Type': 'application/json',
      if (kIsWeb) 'Accept': '*/*',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      debugPrint('No JWT token found');
    }
    return headers;
  }

  dynamic _normalizeIds(dynamic data) {
    if (data is Map<String, dynamic>) {
      final normalized = <String, dynamic>{};
      data.forEach((key, value) {
        if (key == 'id' || key == 'ItemId' || key == 'MenuId') {
          normalized[key] = value is String ? int.tryParse(value) ?? value : value;
        } else if (value is Map || value is List) {
          normalized[key] = _normalizeIds(value);
        } else {
          normalized[key] = value;
        }
      });
      return normalized;
    } else if (data is List) {
      return data.map((item) => _normalizeIds(item)).toList();
    }
    return data;
  }

  Future<Map<String, dynamic>> _handleResponse(Response response) async {
  final statusCode = response.statusCode;
  final body = response.data;

  debugPrint('Response status: $statusCode');
  debugPrint('Response body: $body');

  final normalizedBody = _normalizeIds(body);

  String statusMessage;
  if (statusCode != 200) {
    statusMessage = 'Request failed with status $statusCode';
    if (normalizedBody is Map<String, dynamic> && normalizedBody['message'] != null) {
      statusMessage = normalizedBody['message'].toString();
    }
    return {
      'statusCode': statusCode,
      'data': null,
      'statusMessage': statusMessage,
    };
  }

  // Extract the 'data' field if it exists, otherwise use the entire body
  final responseData = normalizedBody is Map<String, dynamic> && normalizedBody['data'] != null
      ? normalizedBody['data']
      : normalizedBody;

  if (normalizedBody is Map<String, dynamic> && normalizedBody['message'] != null) {
    statusMessage = normalizedBody['message'].toString();
  } else {
    statusMessage = 'Success';
  }

  return {
    'statusCode': statusCode,
    'data': responseData,
    'statusMessage': statusMessage,
  };
}

Future<List<Map<String, dynamic>>> getAllClasses() async {
  try {
    final headers = await _getHeaders();
    debugPrint('Headers for getAllClasses: $headers');
    final response = await _dio.get(
      '/class/All',
      options: Options(headers: headers),
    );
    final result = await _handleResponse(response);
    debugPrint('Processed result for getAllClasses: $result');
    if (result['statusCode'] == 200) {
      final classes = result['data'];
      if (classes is List) {
        return List<Map<String, dynamic>>.from(classes);
      }
      throw Exception('Unexpected response format: classes is not a list');
    }
    throw Exception('Failed to fetch classes: ${result['statusMessage']}');
  } catch (e) {
    debugPrint('Error in getAllClasses: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> updateReport(int id, Map<String, dynamic> reportData) async {
  try {
    final headers = await _getHeaders();
    debugPrint('Headers for updateReport: $headers');
    final response = await _dio.put(
      '/updateReport/$id',
      data: reportData,
      options: Options(headers: headers),
    );
    final result = await _handleResponse(response);
    debugPrint('Processed result for updateReport: $result');
    return result;
  } catch (e) {
    debugPrint('Error in updateReport: $e');
    throw Exception('Error updating report: $e');
  }
}

Future<List<Map<String, dynamic>>> getAllItems() async {
  try {
    final headers = await _getHeaders();
    debugPrint('Headers for getAllItems: $headers');
    final response = await _dio.get(
      '/getAllItem',
      options: Options(headers: headers),
    );
    final result = await _handleResponse(response);
    debugPrint('Processed result for getAllItems: $result');
    if (result['statusCode'] == 200) {
      // Adjust for the nested structure: data.items
      final items = result['data']['items']; // Access the nested 'items' list
      if (items is List) {
        return List<Map<String, dynamic>>.from(items);
      }
      throw Exception('Unexpected response format: items is not a list');
    }
    throw Exception('Failed to fetch items: ${result['statusMessage']}');
  } catch (e) {
    debugPrint('Error in getAllItems: $e');
    rethrow;
  }
}


  Future<Map<String, dynamic>> addItem(String itemName, double quantity1_5, double quantity6_8) async {
    try {
      final response = await _dio.post(
        '/addItem',
        data: {
          'itemName': itemName,
          'quantity1_5': quantity1_5,
          'quantity6_8': quantity6_8,
        },
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error adding item: $e');
    }
  }

  Future<Map<String, dynamic>> updateItem(int id, Map<String, dynamic> updates) async {
    try {
      final response = await _dio.put(
        '/updateItem/$id',
        data: updates,
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error updating item: $e');
    }
  }

  Future<Map<String, dynamic>> deleteItemById(int id) async {
    try {
      final response = await _dio.delete(
        '/deleteItem/$id',
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error deleting item: $e');
    }
  }

  Future<Map<String, dynamic>> addMenu(String dishName) async {
    try {
      final response = await _dio.post(
        '/addMenu',
        data: {'dishName': dishName},
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error adding menu: $e');
    }
  }

 Future<List<dynamic>> getAllMenus() async {
  try {
    final headers = await _getHeaders();
    debugPrint('Headers for getAllMenus: $headers');
    final response = await _dio.get(
      '/getAllMenu',
      options: Options(headers: headers),
    );
    final result = await _handleResponse(response);
    debugPrint('Processed result for getAllMenus: $result');
    if (result['statusCode'] == 200) {
      final data = result['data'];
      debugPrint('Extracted data: $data'); // Add this log
      if (data == null || !data.containsKey('menus')) {
        throw Exception('Response does not contain menus data');
      }
      final menus = data['menus'];
      if (menus is List) {
        return menus;
      }
      throw Exception('Unexpected response format: menus is not a list');
    }
    throw Exception('Failed to fetch menus: ${result['statusMessage']}');
  } catch (e) {
    debugPrint('Error in getAllMenus: $e');
    rethrow;
  }
}

  Future<Map<String, dynamic>> updateMenu(int id, String dishName) async {
    try {
      final response = await _dio.put(
        '/updateMenu/$id',
        data: {'dishName': dishName},
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error updating menu: $e');
    }
  }

  Future<Map<String, dynamic>> deleteMenuById(int id) async {
    try {
      final response = await _dio.delete(
        '/deleteMenu/$id',
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error deleting menu: $e');
    }
  }

  Future<Map<String, dynamic>> assignItemsToMenu(int menuId, List<int> itemIds) async {
    try {
      final response = await _dio.post(
        '/assignItemsToMenu',
        data: {
          'menuId': menuId,
          'itemIds': itemIds,
        },
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error assigning items to menu: $e');
    }
  }

  Future<Map<String, dynamic>> createItemStock(Map<String, dynamic> stockData) async {
    try {
      final response = await _dio.post(
        '/createStock',
        data: stockData,
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error creating stock: $e');
    }
  }

 Future<List<dynamic>> getAllStocks() async {
  try {
    final headers = await _getHeaders();
    debugPrint('Headers for getAllStocks: $headers');
    final response = await _dio.get(
      '/getAllStocks',
      options: Options(headers: headers),
    );
    final result = await _handleResponse(response);
    debugPrint('Processed result for getAllStocks: $result');
    if (result['statusCode'] == 200) {
      final data = result['data'];
      if (data == null) {
        throw Exception('Response does not contain stocks data');
      }
      // Handle both possible formats: list or {stocks: [...]}
      final stocks = data is List ? data : (data.containsKey('stocks') ? data['stocks'] : null);
      if (stocks is List) {
        return stocks;
      }
      throw Exception('Unexpected response format: stocks is not a list');
    }
    throw Exception('Failed to fetch stocks: ${result['statusMessage']}');
  } catch (e) {
    debugPrint('Error in getAllStocks: $e');
    rethrow;
  }
}

  Future<Map<String, dynamic>> updateStock(int id, Map<String, dynamic> updates) async {
    try {
      final response = await _dio.put(
        '/updateStock/$id',
        data: updates,
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error updating stock: $e');
    }
  }

  Future<Map<String, dynamic>> deleteStockById(int id) async {
    try {
      final response = await _dio.delete(
        '/deleteStock/$id',
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error deleting stock: $e');
    }
  }

  Future<Map<String, dynamic>> updateStockInward(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        '/updateStockInward',
        data: data,
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error updating stock inward: $e');
    }
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> reportData) async {
    try {
      final response = await _dio.post(
        '/createReport',
        data: reportData,
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error creating report: $e');
    }
  }

 Future<List<dynamic>> getAllInventoryReports() async {
  try {
    final headers = await _getHeaders();
    debugPrint('Headers for getAllInventoryReports: $headers');
    final response = await _dio.get(
      '/getAllReports',
      options: Options(headers: headers),
    );
    final result = await _handleResponse(response);
    debugPrint('Processed result for getAllInventoryReports: $result');
    if (result['statusCode'] == 200) {
      final data = result['data'];
      if (data == null || !data.containsKey('reports')) {
        throw Exception('Response does not contain reports data');
      }
      final reports = data['reports'];
      if (reports is List) {
        return reports;
      }
      throw Exception('Unexpected response format: reports is not a list');
    }
    throw Exception('Failed to fetch reports: ${result['statusMessage']}');
  } catch (e) {
    debugPrint('Error in getAllInventoryReports: $e');
    rethrow;
  }
}

 Future<List<dynamic>> getDailyReports({String? date}) async {
  try {
    final headers = await _getHeaders();
    debugPrint('Headers for getDailyReports: $headers');
    final queryParameters = date != null ? {'date': date} : null;
    final response = await _dio.get(
      '/daily',
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );
    final result = await _handleResponse(response);
    debugPrint('Processed result for getDailyReports: $result');
    if (result['statusCode'] == 200) {
      // Access the nested 'reports' field
      final reports = result['data']['data']['reports'];
      if (reports is List) {
        return reports;
      } else {
        throw Exception('Unexpected response format: reports is not a list');
      }
    }
    throw Exception('Failed to fetch daily reports: ${result['statusMessage']}');
  } catch (e) {
    debugPrint('Error in getDailyReports: $e');
    rethrow;
  }
} 
  
  Future<List<dynamic>> getMonthlyReports() async {
    try {
      final response = await _dio.get(
        '/monthly',
        options: Options(headers: await _getHeaders()),
      );
      final result = await _handleResponse(response);
      if (result['statusCode'] == 200) {
        return result['data']['reports'] ?? [];
      }
      throw Exception('Failed to fetch monthly reports: ${result['statusMessage']}');
    } catch (e) {
      throw Exception('Error fetching monthly reports: $e');
    }
  }

  Future<Map<String, dynamic>> carryForwardStock() async {
    try {
      final response = await _dio.put(
        '/carryForwardStock',
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error carrying forward stock: $e');
    }
  }

  Future<Map<String, dynamic>> calculateInventoryRequirement(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '/createReport',
        data: data,
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      throw Exception('Error calculating inventory: $e');
    }
  }

  Future<void> deleteJwtToken() async {}

  Future createItem(String itemName) async {}

  static Future createStock(Map<String, dynamic> payload) async {}
}