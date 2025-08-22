import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:intl/intl.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'dart:convert';
import 'package:universal_io/io.dart' show File;
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory;

/*
 * API Service Routes Overview
 * This class implements all backend routes defined in the Node.js/Express server.
 * Authentication is handled via cookies (JWT token) set by the server.
 *
 * School Routes:
 * - POST /school/register → createSchoolAndAdmin
 * - GET /school/All → getAllSchools
 * - GET /school/fetch/:id → getSchoolById
 * - PUT /school/update/:id → updateSchool
 * - DELETE /school/delete/:id → deleteSchool
 *
 * User Routes:
 * - POST /user/register → registerUser
 * - POST /user/login → login
 * - POST /user/logout → logout
 * - POST /user/forgetPassword → forgetPassword
 * - POST /user/resetPassword → resetPassword
 * - POST /user/assign-subject → assignSubjectToTeacher
 * - POST /user/remove-subject → removeSubjectFromTeacher
 * - GET /user/All → getAllUsers
 * - GET /user/fetch/:id → getUserById
 * - PUT /user/update-role/:id → updateUserRole
 * - PUT /user/update/:id → updateUser
 * - DELETE /user/delete/:id → deleteUser
 *
 * Student Routes:
 * - POST /student/register → registerStudent (multipart/form-data)
 * - POST /student/addsubject-student → addSubjectToStudent
 * - POST /student/removesubject-student → removeSubjectFromStudent
 * - PUT /student/updatesubject-marks/:studentId → updateStudentSubjectMarks
 * - GET /student/All → getAllStudents
 * - GET /student/fetch/:id → getStudentById
 * - PUT /student/update/:id → updateStudent (multipart/form-data)
 * - DELETE /student/delete/:id → deleteStudent
 *
 * Subject Routes:
 * - POST /subject/register → registerSubject
 * - GET /subject/All → getAllSubjects
 * - GET /subject/fetch/:id → getSubjectById
 * - PUT /subject/update/:id → updateSubject
 * - DELETE /subject/delete/:id → deleteSubject
 *
 * Class Routes:
 * - POST /class/create → createClass
 * - GET /class/All → getAllClasses
 * - GET /class/fetch/:id → getClassById
 * - PUT /class/update/:id → updateClass
 * - DELETE /class/delete/:id → deleteClass
 * - GET /class/teacher/:teacherId → getClassesByTeacherId
 * - POST /class/addteacher-class/:classId → addTeachersToClass
 * - POST /class/removeteacher-class/:classId → removeTeachersFromClass
 * - POST /class/addStudent-class/:classId → addStudentsToClass
 * - POST /class/removestudent-class/:studentId → removeStudentFromClass
 * - PUT /class/promotestudent-newclass → promoteStudentToNextClass
 *
 * Attendance Routes:
 * - POST /attendance/register → createAttendance
 * - POST /attendance/registerTA → createTeacherAttendance
 * - GET /attendance/All → getAllAttendances
 * - GET /attendance/fetch/:id → getAttendanceById
 * - GET /attendance/ByStudentID/:studentId → getAttendanceByStudentId
 * - GET /attendance/ByTeacherID/:teacherId → getAttendanceByTeacherId
 * - PUT /attendance/update/:id → updateAttendance
 * - DELETE /attendance/delete/:id → deleteAttendance
 *
 * Result Routes:
 * - POST /result/register → createResult
 * - GET /result/All → getAllResults
 * - GET /result/finalResult/:studentId → getOverallResult
 * - GET /result/fetch/:id → getResultById
 * - PUT /result/update/:id → updateResult
 * - DELETE /result/delete/:id → deleteResult
 *
 * MDM Routes:
 * - POST /mdm/addItem → addItem
 * - GET /mdm/getAllItem → getAllItems
 * - PUT /mdm/updateItem/:id → updateItem
 * - DELETE /mdm/deleteItem/:id → deleteItem
 * - POST /mdm/addMenu → addMenu
 * - GET /mdm/getAllMenu → getAllMenus
 * - PUT /mdm/updateMenu/:id → updateMenu
 * - DELETE /mdm/deleteMenu/:id → deleteMenu
 * - POST /mdm/assignItemsToMenu → assignItemsToMenu
 * - POST /mdm/createStock → createStock
 * - GET /mdm/getAllStocks → getAllStocks
 * - PUT /mdm/updateStock/:id → updateStock
 * - DELETE /mdm/deleteStock/:id → deleteStock
 * - PUT /mdm/updateStockInward → updateStockInward
 * - POST /mdm/createReport → createReport
 * - GET /mdm/getAllReports → getAllReports
 * - GET /mdm/daily → getDailyReports
 * - GET /mdm/monthly → getMonthlyReports
 * - PUT /mdm/carryForwardStock → carryForwardStock
 */

class ApiService {
  late Dio _dio;
  late PersistCookieJar _cookieJar;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isInitialized = false;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: kIsWeb ? 'http://devschool.aiztsinfotech.com:8001/api' : 'http://devschool.aiztsinfotech.com:8001/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    final directory = await getApplicationDocumentsDirectory();
    final cookiePath = '${directory.path}/cookies';
    _cookieJar = PersistCookieJar(storage: FileStorage(cookiePath));
    _dio.interceptors.add(CookieManager(_cookieJar));
    _isInitialized = true;
  }

  Future<Map<String, dynamic>> getRequest(String path, {Map<String, dynamic>? queryParameters}) async {
  await init();
  try {
    if (kDebugMode) {
      final cookies = await _cookieJar.loadForRequest(Uri.parse(_dio.options.baseUrl + path));
      print('Cookies sent with request $path: $cookies');
    }
    final response = await _dio.get(path, queryParameters: queryParameters);
    return {
      'success': true,
      'data': response.data, // Keep the raw response data (could be Map or List)
    };
    
  } catch (e) {
    return _handleError(e);
  }
}
  Future<Map<String, dynamic>> postRequest(String path, {dynamic data}) async {
    await init();
    try {
      if (kDebugMode) {
        final cookies = await _cookieJar.loadForRequest(Uri.parse(_dio.options.baseUrl + path));
        print('Cookies sent with request $path: $cookies');
      }
      final response = await _dio.post(path, data: data);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

 Future<Map<String, dynamic>> putRequest(String path, {dynamic data}) async {
    await init();
    try {
      if (kDebugMode) {
        final cookies = await _cookieJar.loadForRequest(Uri.parse(_dio.options.baseUrl + path));
        print('Cookies sent with request $path: $cookies');
      }
      final response = await _dio.put(path, data: data);
      return _handleResponse(response);  // Changed to use _handleResponse
    } catch (e) {
      return _handleError(e);
    }
  } 

  Future<String?> getCurrentUserId() async {
    return await _storage.read(key: 'user_id');
  }
Future<String?> getCurrentSchoolId() async {
    return await _storage.read(key: 'school_id');
  }


  Map<String, dynamic> handleResponse(Response response) {
    print('API Response: ${response.data}, Status: ${response.statusCode}');
    if (response.data is Map<String, dynamic>) {
      return {
        'success': response.data['success'] ?? true,
        'data': response.data['data'] ?? response.data,
        'message': response.data['message']?.toString() ?? 'Request successful',
        'statusCode': response.statusCode,
      };
    }
    return {
      'success': true,
      'data': response.data,
      'message': 'Request successful',
      'statusCode': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> deleteRequest(String path) async {
    await init();
    try {
      if (kDebugMode) {
        final cookies = await _cookieJar.loadForRequest(Uri.parse(_dio.options.baseUrl + path));
        print('Cookies sent with request $path: $cookies');
      }
      final response = await _dio.delete(path);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Map<String, dynamic> _handleError(dynamic error) {
    if (kDebugMode) {
      print('API Error: $error');
      if (error is DioException) {
        print('Error Response Data: ${error.response?.data}');
        print('Error Status Code: ${error.response?.statusCode}');
      }
    }
    if (error is DioException) {
      return {
        'success': false,
        'message': error.response?.data['message']?.toString() ?? 'Network error occurred',
        'error': error.toString(),
        'statusCode': error.response?.statusCode,
      };
    }
    return {
      'success': false,
      'message': 'An unexpected error occurred',
      'error': error.toString(),
    };
  }
  // School Routes
  Future<Map<String, dynamic>> createSchoolAndAdmin({
    required String schoolName,
    String? referredBy,
    String? registeredDate,
    String? purchaseDate,
    String? expiryDate,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    required String enrollmentId,
  }) async {
    return await postRequest('/school/register', data: {
      'schoolName': schoolName,
      'referredBy': referredBy,
      'registeredDate': registeredDate,
      'purchaseDate': purchaseDate,
      'expiryDate': expiryDate,
      'adminName': adminName,
      'adminEmail': adminEmail,
      'adminPassword': adminPassword,
      'enrollmentId': enrollmentId,
    });
  }

  Future<Map<String, dynamic>> getAllSchools() async {
    return await getRequest('/school/All');
  }

  Future<Map<String, dynamic>> getSchoolById(String id) async {
    return await getRequest('/school/fetch/$id');
  }

  Future<Map<String, dynamic>> updateSchool({
    required String id,
    String? schoolName,
    String? referredBy,
    String? registeredDate,
    String? purchaseDate,
    String? expiryDate,
  }) async {
    return await putRequest('/school/update/$id', data: {
      if (schoolName != null) 'schoolName': schoolName,
      if (referredBy != null) 'referredBy': referredBy,
      if (registeredDate != null) 'registeredDate': registeredDate,
      if (purchaseDate != null) 'purchaseDate': purchaseDate,
      if (expiryDate != null) 'expiryDate': expiryDate,
    });
  }

  Future<Map<String, dynamic>> deleteSchool(String id) async {
    return await deleteRequest('/school/delete/$id');
  }

  // User Routes
  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    required String enrollmentId,
  }) async {
    return await postRequest('/user/register', data: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role,
      'enrollmentId': enrollmentId,
    });
  }

  Future<Map<String, dynamic>> login({
    required String enrollmentId,
    required String password,
  }) async {
    await init();
    try {
      final response = await _dio.post('/user/login', data: {
        'enrollmentId': enrollmentId,
        'password': password,
      });
      if (response.data['success'] == true) {
        await _storage.write(key: 'token', value: response.data['data']['token']);
        if (kDebugMode) {
          final cookies = await _cookieJar.loadForRequest(Uri.parse(_dio.options.baseUrl));
          print('Cookies after login: $cookies');
        }
      }
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> logout() async {
    final response = await postRequest('/user/logout');
    await _storage.delete(key: 'token');
    await _cookieJar.deleteAll();
    return response;
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

  Future<Map<String, dynamic>> forgetPassword( {
    required String email,
  }) async {
    return await postRequest('/user/forgetPassword', data: {
      'email': email,
    });
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return await postRequest('/user/resetPassword', data: {
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<dynamic> assignSubjectToTeacher({
  required String teacherId,
  required String subjectId,
  required String classId,
}) async {
  return await postRequest(
    '/user/assign-subject',
    data: {
      'teacherId': teacherId,
      'subjectId': subjectId,
      'classId': classId,
    },
  );
}

// Remove subject from a teacher
Future<Map<String, dynamic>> removeSubjectFromTeacher({
  required String teacherId,
  required String subjectId,
}) async {
  return await postRequest('/user/remove-subject', data: {
    'teacherId': teacherId,
    'subjectId': subjectId,
  });
}



Future<Map<String, dynamic>> getAllUsers({required String schoolId}) async {
  try {
    final res = await getRequest('/user/All?schoolId=$schoolId');
    return res ?? {'success': false, 'message': 'No response'};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}


Future<Map<String, dynamic>> getUserById(String id) async {
  final response = await getRequest('/user/fetch/$id');
  if (response['success'] == true && response['data'] is Map<String, dynamic>) {
    return {'success': true, 'data': response['data']};
  } else {
    throw Exception("Unexpected response format from /user/fetch/$id");
  }
}


  Future<Map<String, dynamic>> updateUserRole({
    required String id,
    required String role,
  }) async {
    return await putRequest('/user/update-role/$id', data: {
      'role': role,
    });
  }

  Future<Map<String, dynamic>> updateUser(String s, {
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? password,
    String? role,
    String? enrollmentId, required String id,
  }) async {
    return await putRequest('/user/update/$userId', data: {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (password != null) 'password': password,
      if (role != null) 'role': role,
      if (enrollmentId != null) 'enrollmentId': enrollmentId,
    });
  }

  Future<Map<String, dynamic>> deleteUser(String id) async {
    return await deleteRequest('/user/delete/$id');
  }

Future<Map<String, dynamic>> updateUserPassword(String id, String newPassword) async {
  return await putRequest(
    '/user/update/$id',
    data: {
      'password': newPassword,
    },
  );
}





  // Student Routes
 Future<Map<String, dynamic>> registerStudent({
  required String name,
  required String rollNo,
  required String parentsPhno,
  String? caste,
  String? subCaste,
  String? sex,
  String? aparId,
  String? saralId,
  String? mobileNumber,
  String? dob, // already formatted as yyyy-MM-dd
  String? admissionDate, // already formatted as yyyy-MM-dd
  String? address,
  String? motherToung,
  String? previousSchool,
  String? classId,
  String? registerNumber,
  String? motherName,
  Map<String, dynamic>? marks,
  XFile? photo,
  XFile? adharNumber,
  XFile? bankPassbook,
  required String schoolId,
}) async {
  final formData = FormData.fromMap({
    'name': name,
    'rollNo': rollNo,
    'parentsPhno': parentsPhno,
    if (caste != null && caste.isNotEmpty) 'caste': caste,
    if (subCaste != null && subCaste.isNotEmpty) 'subCaste': subCaste,
    if (sex != null && sex.isNotEmpty) 'sex': sex,
    if (aparId != null && aparId.isNotEmpty) 'aparId': aparId,
    if (saralId != null && saralId.isNotEmpty) 'saralId': saralId,
    if (mobileNumber != null && mobileNumber.isNotEmpty) 'mobileNumber': mobileNumber,
    if (dob != null && dob.isNotEmpty) 'dob': dob, // ✅ send directly
    if (admissionDate != null && admissionDate.isNotEmpty) 'admissionDate': admissionDate, // ✅ send directly
    if (address != null && address.isNotEmpty) 'address': address,
    if (motherToung != null && motherToung.isNotEmpty) 'motherToung': motherToung,
    if (previousSchool != null && previousSchool.isNotEmpty) 'previousSchool': previousSchool,
    if (classId != null && classId.isNotEmpty) 'classId': classId,
    if (registerNumber != null && registerNumber.isNotEmpty) 'registerNumber': registerNumber,
    if (motherName != null && motherName.isNotEmpty) 'motherName': motherName,
    if (marks != null) 'marks': jsonEncode(marks),
    if (photo != null)
      'photo': await MultipartFile.fromFile(photo.path, filename: photo.name),
    if (adharNumber != null)
      'adharNumber': await MultipartFile.fromFile(adharNumber.path, filename: adharNumber.name),
    if (bankPassbook != null)
      'bankPassbook': await MultipartFile.fromFile(bankPassbook.path, filename: bankPassbook.name),
    'schoolId': schoolId,
  });

  return await postRequest('/student/register', data: formData);
}

  Future<Map<String, dynamic>> addSubjectToTeacher({
  required String teacherId,
  required String subjectId,
}) async {
  try {
    final body = {
      'teacherId': teacherId,
      'subjectId': subjectId,  
    };

    final res = await postRequest(
      '/user/assign-subject', // ✅ make sure this matches backend route
      data: body,
    );

    return res ?? {'success': false, 'message': 'No response from server'};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

  Future<Map<String, dynamic>> removeSubjectFromStudent({
    required String studentId,
    required String subjectId,
  }) async {
    return await postRequest('/student/removesubject-student', data: {
      'studentId': studentId,
      'subjectId': subjectId,
    });
  }

 Future<Map<String, dynamic>> updateStudentSubjectMarks({
  required String studentId,
  required String subjectId,
  double? marks,
  String? grade,
  required Map<String, Object?> data, // This is redundant now, but kept for compatibility
  String? semester,
}) async {
  return await putRequest('/student/updatesubject-marks/$studentId', data: {
    'subjectId': subjectId,
    if (marks != null) 'marks': marks,
    if (grade != null) 'grade': grade,
    if (semester != null) 'semester': semester,
  });
}
  Future<Map<String, dynamic>> getAllStudents() async {
    return await getRequest('/student/All');
  }


  Future<Map<String, dynamic>> getStudentById(String id) async {
    return await getRequest('/student/fetch/$id');
  }

  Future<Map<String, dynamic>> updateStudent({
    required String id,
    String? name,
    String? rollNo,
    String? parentsPhno,
    String? caste,
    String? subCaste,
    String? sex,
    String? aparId,
    String? saralId,
    String? mobileNumber,
    String? dob,
    String? admissionDate,
    String? address,
    String? motherToung,
    String? previousSchool,
    String? classId,
    String? registerNumber,
    String? motherName,
    Map<String, dynamic>? marks,
    XFile? photo,
    XFile? adharNumber,
    XFile? bankPassbook,
  }) async {
    final formData = FormData.fromMap({
      if (name != null) 'name': name,
      if (rollNo != null) 'rollNo': rollNo,
      if (parentsPhno != null) 'parentsPhno': parentsPhno,
      if (caste != null) 'caste': caste,
      if (subCaste != null) 'subCaste': subCaste,
      if (sex != null) 'sex': sex,
      if (aparId != null) 'aparId': aparId,
      if (saralId != null) 'saralId': saralId,
      if (mobileNumber != null) 'mobileNumber': mobileNumber,
      if (dob != null) 'dob': dob,
      if (admissionDate != null) 'admissionDate': admissionDate,
      if (address != null) 'address': address,
      if (motherToung != null) 'motherToung': motherToung,
      if (previousSchool != null) 'previousSchool': previousSchool,
      if (classId != null) 'classId': classId,
      if (registerNumber != null) 'registerNumber': registerNumber,
      if (motherName != null) 'motherName': motherName,
      if (marks != null) 'marks': jsonEncode(marks),
      if (photo != null) 'photo': await MultipartFile.fromFile(photo.path, filename: photo.name),
      if (adharNumber != null) 'adharNumber': await MultipartFile.fromFile(adharNumber.path, filename: adharNumber.name),
      if (bankPassbook != null) 'bankPassbook': await MultipartFile.fromFile(bankPassbook.path, filename: bankPassbook.name),
    });

    return await putRequest('/student/update/$id', data: formData);
  }

  Future<Map<String, dynamic>> deleteStudent(String id) async {
    return await deleteRequest('/student/delete/$id');
  }

  // Subject Routes
Future<Map<String, dynamic>> registerSubject({
  required String name,
  String? subjectName,
  String? classId,
  String? schoolId,
}) async {
  final response = await _dio.post('/subject/register', data: {
    'name': name,
    if (subjectName != null) 'subjectName': subjectName,
    if (classId != null) 'classId': classId,
    if (schoolId != null) 'schoolId': schoolId,
  });
  return _handleResponse(response);
}

  Future<Map<String, dynamic>> addSubjectToStudent({
  required String studentId,
  required String subjectId,
  required String marks,
  required String grade,
}) async {
  return await postRequest('/student/addsubject-student', data: {
    'studentId': studentId,
    'subjectId': subjectId,
    'marks': marks,
    'grade': grade,
  });
}


Future<Map<String, dynamic>> getAllSubjects({required String schoolId}) async {
  try {
    final res = await getRequest('/subject/All?schoolId=$schoolId');
    return res ?? {'success': false, 'message': 'No response'};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}
  Future<Map<String, dynamic>> getSubjectById(String id) async {
    return await getRequest('/subject/fetch/$id');
  }


Future<List<Map<String, dynamic>>> getSubjectsForTeacher(String teacherId, String schoolId, {String? classId}) async {
  try {
    final response = await getRequest('/subject/All');
    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data'])
          .where((sub) => sub['teacherId']?.toString() == teacherId)
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching subjects for teacher: $e');
    return [];
  }
}



  Future<Map<String, dynamic>> updateSubject({
  required String id,
  String? name,
  double? marks,
  String? grade,
  String? subjectName,
  String? classId,
  String? schoolId,
}) async {
  final response = await _dio.put('/subject/update/$id', data: {
    if (name != null) 'name': name,
    if (marks != null) 'marks': marks,
    if (grade != null) 'grade': grade,
    if (subjectName != null) 'subjectName': subjectName,
    if (classId != null) 'classId': classId,
    if (schoolId != null) 'schoolId': schoolId,
  });
  return _handleResponse(response);
}
 Future<Map<String, dynamic>> deleteSubject(String id) async {
  final response = await _dio.delete('/subject/delete/$id');
  return _handleResponse(response);
}

 Future<Map<String, dynamic>> assignSubjectsToTeacher({
  required int teacherId,
  required int subjectId,  // Accept a single subjectId instead of a list
}) async {
  final body = {
    'teacherId': teacherId,
    'subjectId': subjectId,  // Pass a single subjectId
  };
  return await postRequest('/user/assign-subject', data: body);
}


  // Class Routes
 Future<Map<String, dynamic>> createClass({
  required String name,
  required String schoolId,
}) async {
  final response = await _dio.post('/class/create', data: {
    'name': name,
    'schoolId': schoolId,
  });
  return _handleResponse(response);
}




Future<Map<String, dynamic>> getAllClasses({required String schoolId}) async {
  try {
    final res = await getRequest('/class/All?schoolId=$schoolId');
    return res ?? {'success': false, 'message': 'No response'};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

  Future<Map<String, dynamic>> getClassById(String id) async {
    return await getRequest('/class/fetch/$id');
  }

  Future<Map<String, dynamic>> updateClass({
    required String id,
    String? name,
    String? divisions, List<String>? division, required String schoolId,
  }) async {
    return await putRequest('/class/update/$id', data: {
      if (name != null) 'name': name,
      if (divisions != null) 'divisions': divisions,
    });
  }

  Future<Map<String, dynamic>> deleteClass(String id) async {
    return await deleteRequest('/class/delete/$id');
  }

  Future<Map<String, dynamic>> getClassesByTeacherId(String teacherId) async {
    return await getRequest('/class/teacher/$teacherId');
  }

  Future<Map<String, dynamic>> addTeachersToClass({
  required String classId,
  required List<String> teacherIds, required String userId,
}) async {
  return await postRequest('/class/addTeacher-class/$classId', data: {
    'teacherIds': teacherIds,
  });
}



 Future<Map<String, dynamic>> removeTeachersFromClass({
  required int classId,
  required List<int> teacherIds,
}) async {
  try {
    debugPrint('🟢 Removing teachers from class: $classId');
    debugPrint('📤 Request body: $teacherIds');

    final res = await postRequest(
      '/class/removeteacher-class/$classId', // make sure classId is in URL
      data: {
        'teacherIds': teacherIds, // send as ints
      },
    );

    debugPrint('📥 Server response: $res');
    return res;
  } catch (e, stack) {
    debugPrint('❌ removeTeachersFromClass error: $e');
    debugPrint('Stacktrace: $stack');
    return {
      'success': false,
      'message': 'Error: ${e.toString()}',
    };
  }
}


  Future<Map<String, dynamic>> addStudentsToClass({
    required String classId,
    required List<String> studentIds,
  }) async {
    return await postRequest('/class/addStudent-class/$classId', data: {
      'studentIds': studentIds,
    });
  }

  Future<Map<String, dynamic>> removeStudentFromClass({
    required String studentId,
  }) async {
    return await postRequest('/class/removestudent-class/$studentId');
  }

  Future<Map<String, dynamic>> promoteStudentToNextClass({
    required String studentId,
    required String nextClassId,
  }) async {
    return await putRequest('/class/promotestudent-newclass', data: {
      'studentId': studentId,
      'nextClassId': nextClassId,
    });
  }

  // Attendance Routes
 Future<Map<String, dynamic>> createAttendance({
  required String studentId,
  required String month,
  required int totalDays,
  required int presentDays,
}) async {
  try {
    await _addAuthToken('');
    final response = await _dio.post(
      '/attendance/register',
      data: {
        'studentId': studentId,
        'month': month,
        'totalDays': totalDays,
        'presentDays': presentDays,
      },
      options: Options(extra: {'withCredentials': true}),
    );
    return _handleResponse(response);
  } on DioException catch (e) {
    return _handleError(e);
  } catch (e) {
    return {
      'success': false,
      'message': 'Unexpected error: ${e.toString()}',
      'statusCode': 500,
    };
  }
}

 Future<Map<String, dynamic>> createTeacherAttendance({
  required String teacherId,
  required String month,
  required int totalDays,
  required int presentDays, required String status,
}) async {
  return await postRequest('/attendance/registerTA', data: {
    'teacherId': teacherId,
    'month': month,
    'totalDays': totalDays,
    'presentDays': presentDays,
  });
}
  Future<Map<String, dynamic>> getAllAttendances() async {
    return await getRequest('/attendance/All');
  }

  

  Future<Map<String, dynamic>> getAttendanceById(String id) async {
    return await getRequest('/attendance/fetch/$id');
  }

  Future<Map<String, dynamic>> getAttendanceByStudentId(String studentId) async {
    return await getRequest('/attendance/ByStudentID/$studentId');
  }

  Future<Map<String, dynamic>> getAttendanceByTeacherId(String teacherId) async {
    return await getRequest('/attendance/ByTeacherID/$teacherId');
  }

  Future<Map<String, dynamic>> updateAttendance({
    required String id,
    int? totalDays,
    int? presentDays,
  }) async {
    return await putRequest('/attendance/update/$id', data: {
      if (totalDays != null) 'totalDays': totalDays,
      if (presentDays != null) 'presentDays': presentDays,
    });
  }

  Future<Map<String, dynamic>> deleteAttendance(String id) async {
    return await deleteRequest('/attendance/delete/$id');
  }

 Future<Map<String, dynamic>> createResult(Map<String, dynamic> payload) async {
  return await postRequest('/result/register', data: payload);
}


  Future<Map<String, dynamic>> getAllResults({required Map<String, String?> queryParameters, required int semester}) async {
    return await getRequest('/result/All');
  }

Future<Map<String, dynamic>> getResultById(String studentId, String subjectId) async {
  try {
    final response = await getRequest('/result/finalResult/$studentId');
    if (response['success'] == true && response['data'] != null) {
      final result = response['data'];
      if (result['subjects'] != null && result['subjects'][subjectId] != null) {
        return {'success': true, 'data': result};
      }
      return {'success': false, 'message': 'No result found for subject'};
    }
    return {'success': false, 'message': response['message'] ?? 'Failed to fetch result'};
  } catch (e) {
    debugPrint('Error fetching result: $e');
    return {'success': false, 'message': 'Error fetching result: $e'};
  }
}
    Future<Map<String, dynamic>> getFinalResultByStudentId(String studentId) async {
    return await getRequest('/result/finalResult/$studentId');
  }

  Future<Map<String, dynamic>> getOverallResult(String studentId) async {
    return await getRequest('/result/finalResult/$studentId');
  }

 Future<Map<String, dynamic>> getStudentsBySubject(String subjectId) async {
  try {
    final teacherId = await getCurrentUserId();
    if (teacherId == null) {
      return {'success': false, 'message': 'प्रयोक्ता लॉग इन नाही आहे'};
    }


Future<Map<String, dynamic>> getClassesByTeacher(String teacherId) async {
  try {
    final response = await getRequest('/class/teacher/$teacherId');
    return response;
  } catch (e) {
    debugPrint('Error fetching classes: $e');
    return {'success': false, 'message': 'Error fetching classes: $e'};
  }
}

Future<Map<String, dynamic>> getStudentsByClass(String classId) async {
  try {
    final response = await getRequest('/class/students/$classId');
    return response;
  } catch (e) {
    debugPrint('Error fetching students: $e');
    return {'success': false, 'message': 'Error fetching students: $e'};
  }
}



    final classesResponse = await getRequest('/class/teacher/$teacherId');
    if (!classesResponse['success'] || classesResponse['data'] == null) {
      return {'success': false, 'message': 'वर्ग मिळवण्यात अयशस्वी'};
    }

    final classIds = (classesResponse['data'] as List<dynamic>)
        .map((c) => c['id'].toString())
        .toList();

    final subjectsResponse = await getRequest('/subject/All');
    if (!subjectsResponse['success'] || subjectsResponse['data'] == null) {
      return {'success': false, 'message': 'विषय मिळवण्यात अयशस्वी'};
    }

    final isTeacherSubject = (subjectsResponse['data'] as List<dynamic>)
        .any((sub) => sub['id'].toString() == subjectId && sub['teacherId'].toString() == teacherId);
    if (!isTeacherSubject) {
      return {'success': false, 'message': 'हा विषय शिक्षकाला नियुक्त नाही'};
    }

    final studentsResponse = await getRequest('/student/All');
    if (studentsResponse['success'] && studentsResponse['data'] != null) {
      final students = List<Map<String, dynamic>>.from(studentsResponse['data']);
      final filteredStudents = students.where((student) {
        final studentClassId = student['classId']?.toString();
        return classIds.contains(studentClassId);
      }).toList();

      return {'success': true, 'data': filteredStudents};
    }
    return {'success': false, 'message': 'विद्यार्थी मिळवण्यात अयशस्वी'};
  } catch (e) {
    return {'success': false, 'message': 'विद्यार्थी मिळवण्यात त्रुटी: $e'};
  }
}
 Future<void> _addAuthToken(String baseUrl) async {
    final token = await _storage.read(key: 'auth_token');
    print('Retrieved auth_token: $token');
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      print('Added Authorization header: Bearer $token');
    } else {
      _dio.options.headers.remove('Authorization');
      print('No auth_token found, removed Authorization header');
    }
    final cookies = await _cookieJar.loadForRequest(Uri.parse(baseUrl));
    print('Cookies being sent: $cookies');
  }


Future<Map<String, dynamic>> updateStudentSubject(Map<dynamic, dynamic> map, {
    required String studentId,
    required String subjectId,
    Map<String, dynamic>? formativeAssesment,
    Map<String, dynamic>? summativeAssesment,
    required String jsonObject,
  }) async {
    try {
      // Validate studentId
      int.parse(studentId);
      final response = await _dio.put(
        '/student/updatesubject-marks/$studentId',
        data: {
          'subjectId': subjectId,
          if (formativeAssesment != null) 'formativeAssesment': formativeAssesment,
          if (summativeAssesment != null) 'summativeAssesment': summativeAssesment,
        },
      
      );
      final responseData = _handleResponse(response);

      // Convert studentId to int if returned as string
      if (responseData['data']?['studentSubject']?['studentId'] is String) {
        responseData['data']['studentSubject']['studentId'] =
            int.parse(responseData['data']['studentSubject']['studentId']);
      }

      return responseData;
    } on DioException catch (e) {
      return _handleError(e);
    } catch (e) {
      return {
        'success': false,
        'message': 'Invalid student ID format: $e',
        'statusCode': null,
      };
    }
  }


 Map<String, dynamic> _handleResponse(Response response) {
    if (kDebugMode) print('API Response: ${response.data}, Status: ${response.statusCode}');
    if (response.data is Map<String, dynamic>) {
      return {
        'success': response.data['success'] ?? true,
        'data': response.data['data'] ?? response.data,
        'message': response.data['message']?.toString() ?? 'Request successful',
        'statusCode': response.statusCode,
      };
    }
    return {
      'success': true,
      'data': response.data,
      'message': 'Request successful',
      'statusCode': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> updateResult(Map<String, Object?> data, {
    required String id,
    String? studentId,
    String? schoolId,
    String? semester,
    Map<String, dynamic>? subjects,
    String? specialProgress,
    String? hobbies,
    String? areasOfImprovement,
  }) async {
    return await putRequest('/result/update/$id', data: {
      if (studentId != null) 'studentId': studentId,
      if (schoolId != null) 'schoolId': schoolId,
      if (semester != null) 'semester': semester,
      if (subjects != null) 'subjects': subjects,
      if (specialProgress != null) 'specialProgress': specialProgress,
      if (hobbies != null) 'hobbies': hobbies,
      if (areasOfImprovement != null) 'areasOfImprovement': areasOfImprovement,
    });
  }

  Future<Map<String, dynamic>> deleteResult(String id) async {
    return await deleteRequest('/result/delete/$id');
  }

  // MDM Routes
  Future<Map<String, dynamic>> addItem({
    required String itemName,
    required double quantity1_5,
    required double quantity6_8,
  }) async {
    return await postRequest('/mdm/addItem', data: {
      'itemName': itemName,
      'quantity1_5': quantity1_5,
      'quantity6_8': quantity6_8,
    });
  }

  Future<Map<String, dynamic>> getAllItems() async {
    return await getRequest('/mdm/getAllItem');
  }

  Future<Map<String, dynamic>> updateItem({
    required String id,
    String? itemName,
    double? quantity1_5,
    double? quantity6_8,
  }) async {
    return await putRequest('/mdm/updateItem/$id', data: {
      if (itemName != null) 'itemName': itemName,
      if (quantity1_5 != null) 'quantity1_5': quantity1_5,
      if (quantity6_8 != null) 'quantity6_8': quantity6_8,
    });
  }

  Future<Map<String, dynamic>> deleteItem(String id) async {
    return await deleteRequest('/mdm/deleteItem/$id');
  }

  Future<Map<String, dynamic>> addMenu({
    required String dishName,
  }) async {
    return await postRequest('/mdm/addMenu', data: {
      'dishName': dishName,
    });
  }

  Future<Map<String, dynamic>> getAllMenus() async {
    return await getRequest('/mdm/getAllMenu');
  }

  Future<Map<String, dynamic>> updateMenu({
    required String id,
    String? dishName,
  }) async {
    return await putRequest('/mdm/updateMenu/$id', data: {
      if (dishName != null) 'dishName': dishName,
    });
  }

  Future<Map<String, dynamic>> deleteMenu(String id) async {
    return await deleteRequest('/mdm/deleteMenu/$id');
  }

  Future<Map<String, dynamic>> assignItemsToMenu({
    required String menuId,
    required List<String> itemIds,
  }) async {
    return await postRequest('/mdm/assignItemsToMenu', data: {
      'menuId': menuId,
      'itemIds': itemIds,
    });
  }

 Future<Map<String, dynamic>> createStock({
  required int itemId,
  required double previousStock,
  required double inwardMaterial,
  required double outwardMaterial,
  required double totalStock,
  required String classGroup,
}) async {
  return await postRequest('/mdm/createStock', data: {
    'ItemId': itemId,
    'previousStock': previousStock,
    'inwardMaterial': inwardMaterial,
    'outwardMaterial': outwardMaterial,
    'totalStock': totalStock,
    'classGroup': classGroup,
  });
}

  Future<Map<String, dynamic>> getAllStocks() async {
    return await getRequest('/mdm/getAllStocks');
  }

  Future<Map<String, dynamic>> updateStock({
    required String id,
    double? previousStock,
    double? inwardMaterial,
    double? outwardMaterial,
    double? totalStock,
    String? classGroup,
  }) async {
    return await putRequest('/mdm/updateStock/$id', data: {
      if (previousStock != null) 'previousStock': previousStock,
      if (inwardMaterial != null) 'inwardMaterial': inwardMaterial,
      if (outwardMaterial != null) 'outwardMaterial': outwardMaterial,
      if (totalStock != null) 'totalStock': totalStock,
      if (classGroup != null) 'classGroup': classGroup,
    });
  }

Future<Map<String, dynamic>> getAllInventoryReports() async {
  return await getRequest('/mdm/getAllReports');
}


  Future<Map<String, dynamic>> deleteStock(String id) async {
    return await deleteRequest('/mdm/deleteStock/$id');
  }

 Future<Map<String, dynamic>> updateStockInward({
  required String itemId,
  required String classGroup,
  required double inwardMaterial,
}) async {
  return await putRequest('/mdm/updateStockInward', data: {
    'ItemId': itemId, // Changed from 'itemId' to 'ItemId'
    'classGroup': classGroup,
    'inwardMaterial': inwardMaterial,
  });
}

  Future<Map<String, dynamic>> createReport({
    required String date,
    required String menuId,
    required int? totalStudent,
    required String className,
  }) async {
    final payload = {
      'date': date,
      'menuId': menuId,
      'totalStudent': totalStudent,
      'className': className,
    };
    if (kDebugMode) {
      debugPrint('createReport payload: ${jsonEncode(payload)}');
    }
    return await postRequest('/mdm/createReport', data: payload);
  }
  
  
  
    Future<Map<String, dynamic>> getAllReports() async {
    return await getRequest('/mdm/getAllReports');
  }

 Future<Map<String, dynamic>> getDailyReports({
  required String date,
}) async {
  return await getRequest(
    '/mdm/daily',
    queryParameters: {'date': date},
  );
}

  Future<Map<String, dynamic>> getMonthlyReports({
    required String month,
    required String year,
  }) async {
    return await getRequest('/mdm/monthly', queryParameters: {
      'month': month,
      'year': year,
    });
  }

  Future<Map<String, dynamic>> carryForwardStock() async {
    return await putRequest('/mdm/carryForwardStock', data: {});
  }

  
}



