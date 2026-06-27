import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/license/data/repositories/license_repository_impl.dart';
import '../../features/license/domain/entities/license.dart';
import 'backend_api_service.dart';

class BackendSubscriptionInfo {
  const BackendSubscriptionInfo({
    required this.companyName,
    required this.licenseId,
    required this.licenseKey,
    required this.licenseType,
    required this.planCode,
    required this.maxUsers,
    required this.maxCompanies,
    required this.active,
    required this.expired,
    required this.daysLeft,
    this.activatedAt,
    this.expiresAt,
  });

  final String companyName;
  final String? licenseId;
  final String? licenseKey;
  final LicenseType licenseType;
  final String planCode;
  final int maxUsers;
  final int maxCompanies;
  final bool active;
  final bool expired;
  final int daysLeft;
  final DateTime? activatedAt;
  final DateTime? expiresAt;

  String get planLabel => planCode == 'standard' ? 'Standard' : 'Basic';
}

class BackendActivationResult {
  const BackendActivationResult({
    this.info,
    this.errorMessage,
    this.statusCode,
  });

  final BackendSubscriptionInfo? info;
  final String? errorMessage;
  final int? statusCode;
}

class BackendSubscriptionService {
  BackendSubscriptionService._();

  static final BackendSubscriptionService instance = BackendSubscriptionService._();
  final LicenseRepositoryImpl _licenseRepository = LicenseRepositoryImpl();
  static const _defaultMaxUsers = 2;
  static const _defaultMaxCompanies = 1;

  static const _kCompanyName = 'backend_company_name';
  static const _kLicenseKey = 'backend_license_key';
  static const _kLicenseId = 'backend_license_id';
  static const _kLicenseType = 'backend_license_type';
  static const _kPlanCode = 'backend_plan_code';
  static const _kMaxUsers = 'backend_max_users';
  static const _kMaxCompanies = 'backend_max_companies';
  static const _kActive = 'backend_license_active';
  static const _kExpired = 'backend_license_expired';
  static const _kDaysLeft = 'backend_license_days_left';
  static const _kActivatedAt = 'backend_activated_at';
  static const _kExpiresAt = 'backend_expires_at';

  Future<BackendSubscriptionInfo?> fetchStatus({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedStatus();
      if (cached != null) return cached;
    }
    try {
      final body = await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((dio, headers) async {
        final response = await dio.get<Map<String, dynamic>>(
          'subscription/status',
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      final info = _map(body);
      await _cache(info);
      return info;
    } catch (_) {
      return getCachedStatus();
    }
  }

  Future<BackendActivationResult> activate(String licenseKey) async {
    try {
      final body = await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((dio, headers) async {
        final response = await dio.post<Map<String, dynamic>>(
          'subscription/activate',
          data: {'licenseKey': licenseKey},
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      final info = _map(body);
      await _cache(info);
      return BackendActivationResult(info: info);
    } on DioException catch (e) {
      return BackendActivationResult(
        errorMessage: _extractDioErrorMessage(e) ?? 'Activation failed. Please verify your license key and try again.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return BackendActivationResult(
        errorMessage: 'Unable to activate subscription. Please try again.',
      );
    }
  }

  Future<BackendSubscriptionInfo?> getCachedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString(_kCompanyName);
    final planCode = prefs.getString(_kPlanCode);
    final licenseType = LicenseType.fromString(prefs.getString(_kLicenseType));
    final maxUsers = prefs.getInt(_kMaxUsers);
    final maxCompanies = prefs.getInt(_kMaxCompanies);
    final active = prefs.getBool(_kActive);
    final expired = prefs.getBool(_kExpired);
    final daysLeft = prefs.getInt(_kDaysLeft);
    if (companyName == null || planCode == null || maxUsers == null || maxCompanies == null || active == null || expired == null || daysLeft == null) {
      return null;
    }
    return BackendSubscriptionInfo(
      companyName: companyName,
      licenseId: prefs.getString(_kLicenseId),
      licenseKey: prefs.getString(_kLicenseKey),
      licenseType: licenseType,
      planCode: planCode,
      maxUsers: maxUsers,
      maxCompanies: maxCompanies,
      active: active,
      expired: expired,
      daysLeft: daysLeft,
      activatedAt: _parse(prefs.getString(_kActivatedAt)),
      expiresAt: _parse(prefs.getString(_kExpiresAt)),
    );
  }

  Future<int> getMaxUsers() async {
    return (await getCachedStatus())?.maxUsers ?? _defaultMaxUsers;
  }

  Future<int> getMaxCompanies() async {
    return (await getCachedStatus())?.maxCompanies ?? _defaultMaxCompanies;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kCompanyName,
      _kLicenseId,
      _kLicenseKey,
      _kPlanCode,
      _kMaxUsers,
      _kMaxCompanies,
      _kActive,
      _kExpired,
      _kDaysLeft,
      _kActivatedAt,
      _kExpiresAt,
    ]) {
      await prefs.remove(key);
    }
  }

  BackendSubscriptionInfo _map(Map<String, dynamic> body) {
    return BackendSubscriptionInfo(
      companyName: (body['companyName'] ?? '').toString(),
      licenseId: body['licenseId']?.toString(),
      licenseKey: body['licenseKey']?.toString(),
      licenseType: LicenseType.fromString(body['licenseType']?.toString()),
      planCode: (body['planCode'] ?? 'basic').toString(),
      maxUsers: body['maxUsers'] is num ? (body['maxUsers'] as num).toInt() : _defaultMaxUsers,
      maxCompanies: body['maxCompanies'] is num ? (body['maxCompanies'] as num).toInt() : _defaultMaxCompanies,
      active: body['active'] == true,
      expired: body['expired'] == true,
      daysLeft: body['daysLeft'] is num ? (body['daysLeft'] as num).toInt() : 0,
      activatedAt: _parse(body['activatedAt']?.toString()),
      expiresAt: _parse(body['expiresAt']?.toString()),
    );
  }

  Future<void> _cache(BackendSubscriptionInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCompanyName, info.companyName);
    if (info.licenseId != null) {
      await prefs.setString(_kLicenseId, info.licenseId!);
    }
    if (info.licenseKey != null) {
      await prefs.setString(_kLicenseKey, info.licenseKey!);
    }
    await prefs.setString(_kLicenseType, info.licenseType.value);
    await prefs.setString(_kPlanCode, info.planCode);
    await prefs.setInt(_kMaxUsers, info.maxUsers);
    await prefs.setInt(_kMaxCompanies, info.maxCompanies);
    await prefs.setBool(_kActive, info.active);
    await prefs.setBool(_kExpired, info.expired);
    await prefs.setInt(_kDaysLeft, info.daysLeft);
    if (info.activatedAt != null) {
      await prefs.setString(_kActivatedAt, info.activatedAt!.toIso8601String());
    }
    if (info.expiresAt != null) {
      await prefs.setString(_kExpiresAt, info.expiresAt!.toIso8601String());
    }
    final snapshotLicenseId = info.licenseId ?? info.licenseKey;
    if (snapshotLicenseId != null && snapshotLicenseId.isNotEmpty) {
      await _licenseRepository.cacheBackendLicenseSnapshot(
        licenseId: snapshotLicenseId,
        licenseType: info.licenseType,
        activatedAt: info.activatedAt,
        expiresAt: info.expiresAt,
        isActive: info.active,
      );
    }
  }

  DateTime? _parse(String? value) => value == null ? null : DateTime.tryParse(value);

  String? _extractDioErrorMessage(DioException e) {
    final responseBody = e.response?.data;
    if (responseBody is Map<String, dynamic>) {
      return responseBody['message']?.toString() ?? responseBody['error']?.toString() ?? e.message;
    }
    if (responseBody is String) {
      final trimmed = responseBody.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return e.message;
  }
}
