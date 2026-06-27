import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/dio.dart';

import '../network/api_logging_interceptor.dart';
import '../network/secure_dio_transport.dart';
import '../sync/JavaAuthService.dart';
import '../sync/data_access_mode_service.dart';
import '../sync/java_api_url.dart';

class BackendApiService {
  BackendApiService._();

  static final BackendApiService instance = BackendApiService._();

  Future<Map<String, String>> authHeaders() async {
    await JavaAuthService.instance.ensureAuthenticated();
    final token = await JavaAuthService.instance.getToken();
    final tenantId = await JavaAuthService.instance.getTenantId();
    var deviceId = await JavaAuthService.instance.getDeviceId();
    
    if (deviceId == null) {
      deviceId = 'device-${DateTime.now().millisecondsSinceEpoch}';
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_id', deviceId);
      } catch (_) {}
    }

    if (token == null || tenantId == null) {
      throw StateError('Backend authentication context is missing.');
    }
    return {
      'Authorization': 'Bearer $token',
      'X-Tenant-Id': tenantId,
      'X-Device-Id': deviceId,
    };
  }

  Future<Dio> dio() async {
    final baseUrl = await JavaAuthService.instance.getBaseUrl();
    final normalized = normalizeBaseUrlForDio(baseUrl);
    final dio = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        contentType: 'application/json',
      ),
    );
    attachSecureTransport(dio, normalized);
    attachApiLoggingInterceptor(dio);
    return dio;
  }

  Future<T> withAuthRetry<T>(
    Future<T> Function(Dio dio, Map<String, String> headers) action, {
    bool allowManagementCalls = false,
  }) async {
    final mode = await DataAccessModeService.instance.resolveMode();
    if (mode == DataAccessMode.offlineSqlite && !allowManagementCalls) {
      const modeLabel = 'offline SQLite mode';
      throw StateError(
        'API access is restricted in $modeLabel: business data operations must use local SQLite storage.',
      );
    }
    var headers = await authHeaders();
    var dioClient = await dio();
    try {
      return await action(dioClient, headers);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode != 401 && statusCode != 403) rethrow;
      await JavaAuthService.instance.ensureAuthenticated(forceRefresh: true);
      // After a forced re-auth the license type may have changed. If the data
      // access mode is now offline, retrying the API call would fail again with
      // 403 (the server rejects offline-licensed requests). Rethrow immediately
      // so callers surface a clear error rather than making a futile retry.
      final refreshedMode = await DataAccessModeService.instance.resolveMode();
      if (refreshedMode == DataAccessMode.offlineSqlite) rethrow;
      headers = await authHeaders();
      dioClient = await dio();
      return action(dioClient, headers);
    }
  }

  Future<String?> uploadImage(File file) async {
    return withAuthRetry((dio, headers) async {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final response = await dio.post(
        '/api/v1/upload',
        data: formData,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200 && response.data['url'] != null) {
        return response.data['url'] as String;
      }
      return null;
    });
  }
}
