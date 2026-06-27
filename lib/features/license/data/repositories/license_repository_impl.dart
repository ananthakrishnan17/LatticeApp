import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/license.dart';
import '../../domain/repositories/license_repository.dart';
import '../models/license_model.dart';

class LicenseRepositoryImpl implements LicenseRepository {
  static const _kMobileNumber = 'license_mobile_number';
  static const _kLicenseType = 'license_type';
  static const _kLicenseId = 'license_id_v2';
  static const _kExpiresAt = 'license_expires_at_v2';
  static const _kIsActive = 'license_is_active';
  static const _kNonExpiringFallbackDays = 36500;

  @override
  Future<License> activateLicense({
    required String mobileNumber,
    required LicenseType licenseType,
    required String deviceId,
  }) async {
    throw Exception('License activation is now managed by the Java/Postgres backend.');
  }

  @override
  Future<License?> verifyLicense(String mobileNumber) async {
    return getCachedLicense();
  }

  /// Returns the cached license, reading from SharedPreferences first.
  ///
  /// SharedPreferences is the primary store so that license type can be
  /// resolved without opening SQLite (which is disabled in online mode).
  @override
  Future<License?> getCachedLicense() async {
    final fromPrefs = await _getCachedFromPrefs();
    if (fromPrefs != null) return fromPrefs;
    // Fallback: read from SQLite only when not in online mode.
    if (DatabaseHelper.isOnlineModeBlocked) return null;
    return _getCachedFromSqlite();
  }

  Future<License?> _getCachedFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kLicenseId);
    if (id == null) return null;
    final expiresStr = prefs.getString(_kExpiresAt);
    if (expiresStr == null) return null;
    final expiresAt = DateTime.tryParse(expiresStr);
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) return null;
    return LicenseModel(
      id: id,
      mobileNumber: prefs.getString(_kMobileNumber) ?? '',
      licenseType: LicenseType.fromString(prefs.getString(_kLicenseType)),
      activatedAt: DateTime.now(),
      expiresAt: expiresAt,
      isActive: prefs.getBool(_kIsActive) ?? true,
      createdAt: DateTime.now(),
    );
  }

  Future<License?> _getCachedFromSqlite() async {
    try {
      final db = await DatabaseHelper.instance.rawDatabase;
      final rows = await db.query('license_cache', limit: 1);
      if (rows.isEmpty) return null;
      final model = LicenseModel.fromLocalMap(rows.first);
      return model.isExpired ? null : model;
    } catch (e) {
      debugPrint('[LicenseRepository] Local DB cache read failed: $e');
      return null;
    }
  }

  @override
  Future<void> cacheLicense(License license) async {
    // Always persist to SharedPreferences (works in both online and offline mode).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLicenseId, license.id);
    await prefs.setString(_kMobileNumber, license.mobileNumber);
    await prefs.setString(_kLicenseType, license.licenseType.value);
    await prefs.setString(_kExpiresAt, license.expiresAt.toIso8601String());
    await prefs.setBool(_kIsActive, license.isActive);

    // Only write to SQLite when not in online mode.
    if (!DatabaseHelper.isOnlineModeBlocked) {
      try {
        final db = await DatabaseHelper.instance.rawDatabase;
        final model = LicenseModel.fromEntity(license);
        await db.delete('license_cache');
        await db.insert('license_cache', model.toLocalMap());
      } catch (e) {
        debugPrint('[LicenseRepository] Failed to write license to local DB: $e');
      }
    }
  }

  Future<void> cacheBackendLicenseSnapshot({
    required String licenseId,
    required LicenseType licenseType,
    String mobileNumber = '',
    String? deviceId,
    DateTime? activatedAt,
    DateTime? expiresAt,
    bool isActive = true,
    DateTime? createdAt,
  }) async {
    final now = DateTime.now().toUtc();
    await cacheLicense(
      LicenseModel(
        id: licenseId,
        mobileNumber: mobileNumber,
        licenseType: licenseType,
        deviceId: deviceId,
        activatedAt: activatedAt ?? now,
        expiresAt: expiresAt ?? now.add(const Duration(days: _kNonExpiringFallbackDays)),
        isActive: isActive,
        createdAt: createdAt ?? now,
      ),
    );
  }

  @override
  Future<void> clearCache() async {
    if (!DatabaseHelper.isOnlineModeBlocked) {
      try {
        final db = await DatabaseHelper.instance.rawDatabase;
        await db.delete('license_cache');
      } catch (e) {
        debugPrint('[LicenseRepository] Failed to clear local license cache: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _kLicenseId,
      _kMobileNumber,
      _kLicenseType,
      _kExpiresAt,
      _kIsActive,
    ]) {
      await prefs.remove(k);
    }
  }
}
