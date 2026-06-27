import '../../../core/backend/backend_subscription_service.dart';
import '../../../core/sync/data_access_mode_service.dart';
import '../../license/data/repositories/license_repository_impl.dart';

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  static const _offlineMaxUsers = 2;
  static const _offlineMaxCompanies = 1;
  static const _expiryWarningDays = 2;

  BackendSubscriptionInfo? _statusCache;
  Future<BackendSubscriptionInfo?>? _inFlightStatusFetch;
  final LicenseRepositoryImpl _licenseRepository = LicenseRepositoryImpl();

  Future<bool> _isOfflineSqliteMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.offlineSqlite;

  Future<BackendSubscriptionInfo?> _loadStatus({bool forceRefresh = false}) async {
    if (!forceRefresh && _statusCache != null) return _statusCache;
    if (!forceRefresh && _inFlightStatusFetch != null) return _inFlightStatusFetch!;
    final request = BackendSubscriptionService.instance.fetchStatus(forceRefresh: forceRefresh);
    _inFlightStatusFetch = request;
    final result = await request;
    _statusCache = result;
    _inFlightStatusFetch = null;
    return result;
  }

  Future<SubscriptionStatus> getStatus() async {
    if (await _isOfflineSqliteMode()) {
      final license = await _licenseRepository.getCachedLicense();
      if (license == null) return SubscriptionStatus.notActivated;
      if (license.isExpired) return SubscriptionStatus.expired;
      if (!license.isActive) return SubscriptionStatus.notActivated;
      if (license.daysLeft <= _expiryWarningDays) {
        return SubscriptionStatus.expiringSoon;
      }
      return SubscriptionStatus.active;
    }
    final cached = await _loadStatus();
    if (cached == null) return SubscriptionStatus.notActivated;
    if (!cached.active && cached.expired) return SubscriptionStatus.expired;
    if (!cached.active) return SubscriptionStatus.notActivated;
    if (cached.daysLeft <= _expiryWarningDays) {
      return SubscriptionStatus.expiringSoon;
    }
    return SubscriptionStatus.active;
  }

  Future<int> getDaysLeft() async {
    if (await _isOfflineSqliteMode()) {
      return (await _licenseRepository.getCachedLicense())?.daysLeft ?? 0;
    }
    return (await _loadStatus())?.daysLeft ?? 0;
  }

  Future<String?> getPlanName() async {
    if (await _isOfflineSqliteMode()) {
      return 'Offline';
    }
    return (await _loadStatus())?.planLabel;
  }

  Future<bool> reVerifyOnline() async {
    if (await _isOfflineSqliteMode()) {
      return (await getStatus()) == SubscriptionStatus.active;
    }
    final info = await _loadStatus(forceRefresh: true);
    return info?.active == true;
  }

  Future<ActivateResult> activateWithKey(String licenseKey) async {
    final result = await BackendSubscriptionService.instance.activate(licenseKey);
    final info = result.info;
    if (info != null && info.active) {
      return ActivateResult(
        success: true,
        message: 'License activated! ${info.planLabel} plan — ${info.daysLeft} days remaining.',
        plan: info.planLabel,
        daysLeft: info.daysLeft,
      );
    }
    return ActivateResult(
      success: false,
      message: result.errorMessage ?? 'Unable to activate subscription. Please try again.',
    );
  }

  Future<void> clearSubscription() async {
    _statusCache = null;
    _inFlightStatusFetch = null;
    await BackendSubscriptionService.instance.clearCache();
  }

  Future<int> getMaxAllowedUsers() async {
    if (await _isOfflineSqliteMode()) return _offlineMaxUsers;
    return BackendSubscriptionService.instance.getMaxUsers();
  }

  Future<int> getMaxAllowedCompanies() async {
    if (await _isOfflineSqliteMode()) return _offlineMaxCompanies;
    return BackendSubscriptionService.instance.getMaxCompanies();
  }
}

class ActivateResult {
  final bool success;
  final String message;
  final String? plan;
  final int? daysLeft;
  const ActivateResult({required this.success, required this.message, this.plan, this.daysLeft});
}

enum SubscriptionStatus { notActivated, active, expiringSoon, expired }

extension SubscriptionStatusExt on SubscriptionStatus {
  bool get isLocked => this == SubscriptionStatus.expired || this == SubscriptionStatus.notActivated;
  bool get needsReminder => this == SubscriptionStatus.expiringSoon;
}
