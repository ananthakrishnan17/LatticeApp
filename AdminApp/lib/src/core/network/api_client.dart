import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

  final Dio _dio;

  Dio get client => _dio;

  void setJwt(String token) {
    _dio.options.headers['Authorization'] = ['Bearer', token].join(' ');
  }
}
