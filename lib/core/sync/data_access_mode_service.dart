import 'package:shared_preferences/shared_preferences.dart';

enum DataAccessMode {
  offlineSqlite,
  onlineApi,
}

/// Resolves the data-access mode (online API vs offline SQLite) based on the
/// license type stored in SharedPreferences after login.
///
/// The mode is cached in-memory after the first resolution so that every
/// repository call does not re-read SharedPreferences. Call [clearCache] after
/// login or logout so the next [resolveMode] picks up a fresh value.
class DataAccessModeService {
  DataAccessModeService._();

  static final DataAccessModeService instance = DataAccessModeService._();

  /// SharedPreferences key written by [LicenseRepositoryImpl.cacheLicense].
  static const _kLicenseType = 'license_type';

  DataAccessMode? _cached;

  /// Clears the in-memory mode cache so the next [resolveMode] call reads
  /// the current license type from SharedPreferences.
  void clearCache() => _cached = null;

  /// Returns the data-access mode for the active license.
  ///
  /// Reads the license type directly from SharedPreferences (no SQLite
  /// dependency). The result is cached in-memory until [clearCache] is called.
  Future<DataAccessMode> resolveMode() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    _cached = _toMode(prefs.getString(_kLicenseType));
    return _cached!;
  }

  Future<bool> isOnlineApiMode() async =>
      (await resolveMode()) == DataAccessMode.onlineApi;

  DataAccessMode _toMode(String? licenseType) {
    final normalized = (licenseType ?? '').trim().toLowerCase();
    return normalized == 'online'
        ? DataAccessMode.onlineApi
        : DataAccessMode.offlineSqlite;
  }
}
