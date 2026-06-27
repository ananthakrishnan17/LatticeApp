import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../network/api_logging_interceptor.dart';
import '../network/secure_dio_transport.dart';
import '../../features/license/data/repositories/license_repository_impl.dart';
import '../../features/license/domain/entities/license.dart';
import 'data_access_mode_service.dart';
import 'java_api_url.dart';
import 'java_api_config_service.dart';

class JavaAuthService {
  JavaAuthService._();

  static final JavaAuthService instance = JavaAuthService._();
  static const _loginPath = 'auth/login';
  final LicenseRepositoryImpl _licenseRepository = LicenseRepositoryImpl();
  static const String defaultBaseUrl =
      String.fromEnvironment(
        'JAVA_API_BASE_URL',
        defaultValue: 'http://18.60.200.156',
      );

  static const _kJwtToken = 'java_api_jwt_token';
  static const _kLoginFailCount = 'java_api_login_fail_count';
  static const _kLoginFailTimestamp = 'java_api_login_fail_timestamp';
  static const _kMaxFailedAttempts = 5;
  static const _kLockoutWindow = Duration(minutes: 5);
  static const _kTenantId = 'java_api_tenant_id';
  static const _kDeviceId = 'java_api_device_id';
  static const _kRole = 'java_api_user_role';
  static const _kOrganizationId = 'java_api_organization_id';
  static const _kBranchId = 'java_api_branch_id';
  static const _kScopeRole = 'java_api_scope_role';
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  Future<String> login(
    String phoneNumber,
    String password,
    String deviceId, {
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final failedCount = prefs.getInt(_kLoginFailCount) ?? 0;
    final lastFailedAtMs = prefs.getInt(_kLoginFailTimestamp) ?? 0;
    if (failedCount >= _kMaxFailedAttempts && lastFailedAtMs > 0) {
      final lockedUntil = DateTime.fromMillisecondsSinceEpoch(lastFailedAtMs)
          .add(_kLockoutWindow);
      if (DateTime.now().isBefore(lockedUntil)) {
        final remainingDuration = lockedUntil.difference(DateTime.now());
        if (remainingDuration.inSeconds <= 0) {
          await prefs.setInt(_kLoginFailCount, 0);
          await prefs.remove(_kLoginFailTimestamp);
        } else {
          final remainingMessage = remainingDuration.inSeconds < 60
              ? 'less than 1 minute'
              : '${(remainingDuration.inSeconds / 60).ceil().clamp(1, _kLockoutWindow.inMinutes)} minute(s)';
          throw StateError(
            'Too many failed login attempts. Try again in $remainingMessage.',
          );
        }
      }
      await prefs.setInt(_kLoginFailCount, 0);
      await prefs.remove(_kLoginFailTimestamp);
    }

    final dio = _dioForBaseUrl(baseUrl ?? await getBaseUrl());
    try {
      final parsedBaseUrl = Uri.tryParse(dio.options.baseUrl);
      final loginUrl =
          parsedBaseUrl?.resolve(_loginPath).toString() ??
          'Failed to parse base URL: ${dio.options.baseUrl}';
      developer.log(
        'Login request URL: $loginUrl',
        name: 'JavaAuthService',
      );
      final response = await dio.post<Map<String, dynamic>>(
        _loginPath,
        data: {
          'phoneNumber': phoneNumber,
          'password': password,
          'deviceId': deviceId,
        },
      );

      final data = response.data ?? <String, dynamic>{};
      final token = (data['accessToken'] ?? '').toString();
      final tenantId = (data['tenantId'] ?? '').toString();
      final responseDeviceId = (data['deviceId'] ?? deviceId).toString();
      final organizationId = (data['organizationId'] ?? '').toString();
      final branchId = (data['branchId'] ?? '').toString();
      final scopeRole = (data['scopeRole'] ?? '').toString();
      final licenseId = data['licenseId']?.toString();
      final licenseType = LicenseType.fromString(data['licenseType']?.toString());
      final licenseActive = data['licenseActive'] != false;
      final licenseActivatedAt = _tryParseDateTime(data['licenseActivatedAt']?.toString());
      final licenseExpiresAt = _tryParseDateTime(data['licenseExpiresAt']?.toString());

      if (token.isEmpty) {
        throw StateError('JWT token missing in /auth/login response');
      }
      if (tenantId.isEmpty) {
        throw StateError('tenantId missing in /auth/login response');
      }

      await _secureStorage.write(key: _kJwtToken, value: token);
      await prefs.setInt(_kLoginFailCount, 0);
      await prefs.remove(_kLoginFailTimestamp);
      await prefs.setString(_kTenantId, tenantId);
      await prefs.setString(_kDeviceId, responseDeviceId);

      final role = data['role']?.toString();
      if (role != null && role.isNotEmpty) {
        await prefs.setString(_kRole, role);
      }
      if (organizationId.isNotEmpty) {
        await prefs.setString(_kOrganizationId, organizationId);
      }
      if (branchId.isNotEmpty) {
        await prefs.setString(_kBranchId, branchId);
      }
      if (scopeRole.isNotEmpty) {
        await prefs.setString(_kScopeRole, scopeRole);
      }
      if (licenseId != null && licenseId.isNotEmpty) {
        await _licenseRepository.cacheBackendLicenseSnapshot(
          licenseId: licenseId,
          licenseType: licenseType,
          deviceId: responseDeviceId,
          activatedAt: licenseActivatedAt,
          expiresAt: licenseExpiresAt,
          isActive: licenseActive,
        );
      }

      // Refresh the in-memory mode cache so subsequent resolveMode() calls
      // pick up the license type that was just stored in SharedPreferences.
      DataAccessModeService.instance.clearCache();
      if (licenseType == LicenseType.online) {
        DatabaseHelper.setOnlineMode();
      } else {
        DatabaseHelper.resetOnlineMode();
      }

      return token;
    } on DioException {
      await _recordLoginFailure(prefs);
      rethrow;
    } on StateError {
      await _recordLoginFailure(prefs);
      rethrow;
    }
  }

  Future<bool> hasConfiguredConnection() async {
    final config = await JavaApiConfigService.instance.loadConfig(
      defaultBaseUrl: defaultBaseUrl,
    );
    return config.isComplete;
  }

  Future<String> getBaseUrl() async {
    final config = await JavaApiConfigService.instance.loadConfig(
      defaultBaseUrl: defaultBaseUrl,
    );
    return config.baseUrl;
  }

  Future<void> ensureAuthenticated({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        // Verify the cached token's device_id claim matches the value stored in
        // SharedPreferences. A mismatch means the token is from a different
        // session and would be rejected by the server with a 403. Detecting
        // the inconsistency here triggers a fresh login, avoiding an
        // unnecessary 403 on the first API call.
        final storedDeviceId = await getDeviceId();
        final tokenDeviceId = _extractDeviceIdFromToken(token);
        // If either value is absent we cannot verify — trust the cached token.
        // If both are present and match, the token is consistent — return early.
        // Only fall through to re-login when both are present but differ.
        if (tokenDeviceId == null ||
            storedDeviceId == null ||
            tokenDeviceId == storedDeviceId) {
          return;
        }
        // Device ID mismatch detected — fall through to re-login.
      }
    }

    final config = await JavaApiConfigService.instance.loadConfig(
      defaultBaseUrl: defaultBaseUrl,
    );
    if (!config.isComplete) {
      throw StateError(
        'Java backend settings are incomplete. Configure base URL, username/mobile number, and password first.',
      );
    }

    final deviceId = await _resolveDeviceId();
    await login(
      config.username,
      config.password,
      deviceId,
      baseUrl: config.baseUrl,
    );
  }

  Future<String?> getToken() async {
    final secureToken = await _secureStorage.read(key: _kJwtToken);
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_kJwtToken);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.write(key: _kJwtToken, value: legacyToken);
      await prefs.remove(_kJwtToken);
      return legacyToken;
    }
    return null;
  }

  Future<String?> getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTenantId);
  }

  Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDeviceId);
  }

  Future<String?> getScopeRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kScopeRole) ?? prefs.getString(_kRole);
  }

  Future<String?> getOrganizationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kOrganizationId);
  }

  Future<String?> getBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBranchId);
  }

  Future<String> getOrCreateDeviceId() async {
    final existing = await getDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = 'device-${DateTime.now().microsecondsSinceEpoch}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceId, generated);
    return generated;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _kJwtToken);
    await prefs.remove(_kJwtToken);
    await prefs.remove(_kTenantId);
    await prefs.remove(_kDeviceId);
    await prefs.remove(_kRole);
    await prefs.remove(_kOrganizationId);
    await prefs.remove(_kBranchId);
    await prefs.remove(_kScopeRole);
    DataAccessModeService.instance.clearCache();
    DatabaseHelper.resetOnlineMode();
  }

  Dio _dioForBaseUrl(String baseUrl) {
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

  Future<String> _resolveDeviceId() async {
    // Use SharedPreferences only — SQLite may not be available in online mode.
    return getOrCreateDeviceId();
  }

  DateTime? _tryParseDateTime(String? value) =>
      value == null || value.isEmpty ? null : DateTime.tryParse(value);

  Future<void> _recordLoginFailure(SharedPreferences prefs) async {
    final updatedFails = (prefs.getInt(_kLoginFailCount) ?? 0) + 1;
    await prefs.setInt(_kLoginFailCount, updatedFails);
    await prefs.setInt(
      _kLoginFailTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Decodes the JWT payload and returns the `device_id` claim, or `null` if
  /// the token is malformed or the claim is absent.
  String? _extractDeviceIdFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      final deviceId = payload['device_id'];
      return deviceId is String ? deviceId : null;
    } catch (_) {
      return null;
    }
  }

}
