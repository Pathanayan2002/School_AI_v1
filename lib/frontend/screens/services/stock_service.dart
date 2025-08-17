import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class StockService {
  static const String _baseUrl = 'http://devschool.aiztsinfotech.com:8001/api/mdm';
  static const Duration _timeout = Duration(seconds: 10);
  final Dio _dio;
  final FlutterSecureStorage _storage;
  late final CookieJar cookieJar;

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
      _storage = const FlutterSecureStorage() {
    _initializeCookieJar();
  }

Future<void> _initializeCookieJar() async {
    if (kIsWeb) {
      cookieJar = CookieJar();
    } else {
      final directory = await getApplicationDocumentsDirectory();
      cookieJar = PersistCookieJar(
        storage: FileStorage('${directory.path}/.cookies/'),
      );
    }
    _dio.interceptors.add(CookieManager(cookieJar));
  }
  Future<String?> _getAuthToken() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      debugPrint('Retrieved JWT token: ${token != null ? 'Present' : 'Null'}');
      return token;
    } catch (e) {
      debugPrint('Error reading JWT token: $e');
      return null;
    }
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

  Future<bool> _isAuthenticated() async {
    final token = await _getAuthToken();
    final isAuthenticated = token != null;
    debugPrint('Authentication check: $isAuthenticated');
    return isAuthenticated;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {
          'username': username,
          'password': password,
        },
        options: Options(headers: {
          'Content-Type': 'application/json',
          if (kIsWeb) 'Accept': '*/*',
        }),
      );
      final result = await _handleResponse(response);
      debugPrint('Login result: $result');
      if (result['statusCode'] == 200 && result['data']['token'] != null) {
        final token = result['data']['token'].toString();
        await _storage.write(key: 'token', value: token);
        debugPrint('JWT token stored successfully');
        return result;
      }
      throw Exception('Login failed: ${result['statusMessage']}');
    } catch (e) {
      debugPrint('Error in login: $e');
      throw Exception('Login error: $e');
    }
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
    if (statusCode != 200 && statusCode != 201) {
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
      debugPrint('Error adding item: $e');
      throw Exception('Error adding item: $e');
    }
  }

  Future<Map<String, dynamic>> createItem(String itemName, double previousStock, double inward, double outward, double d, String classGroup) async {
    try {
      final response = await _dio.post(
        '/addItem',
        data: {
          'itemName': itemName,
          'quantity1_5': 0.0,
          'quantity6_8': 0.0,
        },
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      debugPrint('Error creating item: $e');
      throw Exception('Error creating item: $e');
    }
  }

  Future<List<dynamic>> getAllItems() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '/getAllItem',
        options: Options(headers: headers),
      );
      final result = await _handleResponse(response);
      if (result['statusCode'] == 200) {
        return result['data'];
      }
      throw Exception('Failed to fetch items: ${result['statusMessage']}');
    } catch (e) {
      debugPrint('Error in getAllItems: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> updateItem(int id, String itemName, double qty1, double qty6) async {
    try {
      final response = await _dio.put(
        '/updateItem/$id',
        data: {
          'itemName': itemName,
          'quantity1_5': qty1,
          'quantity6_8': qty6,
        },
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      debugPrint('Error updating item: $e');
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
      debugPrint('Error deleting item: $e');
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
      debugPrint('Error adding menu: $e');
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
        final menus = result['data'];
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
      debugPrint('Error updating menu: $e');
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
      debugPrint('Error deleting menu: $e');
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
      debugPrint('Error assigning items to menu: $e');
      throw Exception('Error assigning items to menu: $e');
    }
  }

  Future<Map<String, dynamic>> createStock(Map<String, dynamic> stockData) async {
    try {
      final response = await _dio.post(
        '/createStock',
        data: stockData,
        options: Options(headers: await _getHeaders()),
      );
      return await _handleResponse(response);
    } catch (e) {
      debugPrint('Error creating stock: $e');
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
        final stocks = result['data'];
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
      debugPrint('Error updating stock: $e');
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
      debugPrint('Error deleting stock: $e');
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
      debugPrint('Error updating stock inward: $e');
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
      debugPrint('Error creating report: $e');
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
        final reports = result['data'];
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

  Future<dynamic> getDailyReports({required String date}) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.post(
        '/daily',
        data: {'date': date},
        options: Options(headers: headers),
      );
      final result = await _handleResponse(response);
      if (result['statusCode'] == 200) {
        return result['data'];
      }
      return result;
    } catch (e) {
      debugPrint('Error in getDailyReports: $e');
      rethrow;
    }
  }
  
  Future<dynamic> getMonthlyReports({required String month, required String year}) async {
    try {
      final headers = await _getHeaders();
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final monthIndex = months.indexOf(month);
      if (monthIndex == -1) {
        throw Exception('Invalid month name');
      }
      final formattedMonth = (monthIndex + 1).toString().padLeft(2, '0');
      final response = await _dio.post(
        '/monthly',
        data: {'month': formattedMonth, 'year': year},
        options: Options(headers: headers),
      );
      final result = await _handleResponse(response);
      if (result['statusCode'] == 200) {
        return result['data'];
      }
      return result;
    } catch (e) {
      debugPrint('Error in getMonthlyReports: $e');
      rethrow;
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
      debugPrint('Error carrying forward stock: $e');
      throw Exception('Error carrying forward stock: $e');
    }
  }

  Future<String?> _getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<Map<String, dynamic>> getAllSubjects() async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '/subject/All',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (e) {
      print('Error in getAllSubjects: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getClassesByTeacherId(String teacherId) async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '/class/All',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (e) {
      print('Error in getClassesByTeacherId: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAllStudents() async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '/student/All',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (e) {
      print('Error in getAllStudents: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createResult(Map<String, dynamic> payload) async {
    try {
      final token = await _getToken();
      print('Sending createResult payload: $payload');
      final response = await _dio.post(
        '/register',
        data: payload,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      print('createResult response: ${response.data}');
      return response.data;
    } catch (e) {
      print('Error in createResult: $e');
      rethrow;
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
      debugPrint('Error calculating inventory: $e');
      throw Exception('Error calculating inventory: $e');
    }
  }

  Future<void> deleteJwtToken() async {
    try {
      await _storage.delete(key: 'auth_token');
      debugPrint('JWT token deleted');
    } catch (e) {
      debugPrint('Error deleting JWT token: $e');
      throw Exception('Error deleting JWT token: $e');
    }
  }
}