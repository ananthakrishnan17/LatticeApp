import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = 'http://18.60.200.156/';
  
  try {
    print('Logging in...');
    final loginRes = await dio.post('auth/login', data: {
      'username': 'Admin',
      'password': '111',
      'deviceId': 'test-device'
    });
    
    final data = loginRes.data;
    final token = data['accessToken'];
    final tenantId = data['tenantId'];
    
    print('Logged in. Token: $token');
    
    final headers = {
      'Authorization': 'Bearer $token',
      'X-Tenant-Id': tenantId,
      'X-Device-Id': 'test-device',
      'content-type': 'application/json',
    };
    
    // First try GET /users to see if we can fetch users
    print('\nFetching users...');
    try {
      final getRes = await dio.get('users', options: Options(headers: headers));
      print('GET /users response: ${getRes.statusCode}');
      print('Body: ${getRes.data}');
    } catch (e) {
      if (e is DioException) {
        print('GET /users failed: ${e.response?.statusCode}');
        print('Body: ${e.response?.data}');
      } else {
        print('GET error: $e');
      }
    }
    
    // Now try POST /users
    print('\nCreating user...');
    try {
      final postRes = await dio.post('users', 
        data: {
          "username": "testuser",
          "pin": "1234",
          "role": "branchadmin",
          "isActive": true,
          "canBill": true,
          "canViewReports": true,
          "canManageProducts": true,
          "canManageMasters": true,
          "canViewExpenses": true,
          "canManagePurchase": true,
          "canViewDashboard": true
        },
        options: Options(headers: headers)
      );
      print('POST /users response: ${postRes.statusCode}');
      print('Body: ${postRes.data}');
    } catch (e) {
      if (e is DioException) {
        print('POST /users failed: ${e.response?.statusCode}');
        print('Body: ${e.response?.data}');
      } else {
        print('POST error: $e');
      }
    }
    
    // Try POST /auth/register just in case
    print('\nTrying /auth/register...');
    try {
      final postRes = await dio.post('auth/register', 
        data: {
          "username": "testuser2",
          "pin": "1234",
          "role": "branchadmin"
        },
        options: Options(headers: headers)
      );
      print('POST /auth/register response: ${postRes.statusCode}');
      print('Body: ${postRes.data}');
    } catch (e) {
      if (e is DioException) {
        print('POST /auth/register failed: ${e.response?.statusCode}');
        print('Body: ${e.response?.data}');
      } else {
        print('POST error: $e');
      }
    }
    
  } catch (e) {
    if (e is DioException) {
      print('Error: ${e.response?.statusCode}');
      print('Body: ${e.response?.data}');
    } else {
      print('Error: $e');
    }
  }
}
