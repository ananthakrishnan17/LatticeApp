import 'package:shared_preferences/shared_preferences.dart';

class JavaApiConfig {
  const JavaApiConfig({
    required this.baseUrl,
    required this.tenantCode,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String tenantCode;
  final String username;
  final String password;

  bool get isComplete =>
      baseUrl.isNotEmpty &&
      username.isNotEmpty &&
      password.isNotEmpty;
}

class JavaApiConfigService {
  JavaApiConfigService._();

  static final JavaApiConfigService instance = JavaApiConfigService._();

  static const _kBaseUrl = 'java_api_base_url';
  static const _kTenantCode = 'java_api_tenant_code';
  static const _kUsername = 'java_api_username';
  static const _kPassword = 'java_api_password';
  static const _kRoleUsernamePrefix = 'java_api_username_';
  static const _kRolePasswordPrefix = 'java_api_password_';

  Future<JavaApiConfig> loadConfig({String? defaultBaseUrl, String? role}) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedRole = _normalizeRoleKey(role);
    final roleUsername = normalizedRole == null
        ? null
        : prefs.getString('$_kRoleUsernamePrefix$normalizedRole');
    final rolePassword = normalizedRole == null
        ? null
        : prefs.getString('$_kRolePasswordPrefix$normalizedRole');
    return JavaApiConfig(
      baseUrl: _normalizeBaseUrl(
        prefs.getString(_kBaseUrl) ?? defaultBaseUrl ?? '',
      ),
      tenantCode: (prefs.getString(_kTenantCode) ?? '').trim(),
      // Fallback to shared credentials when role-scoped values are not saved yet.
      username: (roleUsername ?? prefs.getString(_kUsername) ?? '').trim(),
      password: rolePassword ?? prefs.getString(_kPassword) ?? '',
    );
  }

  Future<void> saveConfig({
    String? baseUrl,
    String tenantCode = '',
    required String username,
    required String password,
    String? role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedRole = _normalizeRoleKey(role);
    if (baseUrl != null) {
      await prefs.setString(_kBaseUrl, _normalizeBaseUrl(baseUrl));
    }
    await prefs.setString(_kTenantCode, tenantCode.trim());
    await prefs.setString(_kUsername, username.trim());
    await prefs.setString(_kPassword, password);
    if (normalizedRole != null) {
      await prefs.setString('$_kRoleUsernamePrefix$normalizedRole', username.trim());
      await prefs.setString('$_kRolePasswordPrefix$normalizedRole', password);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBaseUrl);
    await prefs.remove(_kTenantCode);
    await prefs.remove(_kUsername);
    await prefs.remove(_kPassword);
  }

  Future<void> clearRoleCredentials(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedRole = _normalizeRoleKey(role);
    if (normalizedRole == null) return;
    await prefs.remove('$_kRoleUsernamePrefix$normalizedRole');
    await prefs.remove('$_kRolePasswordPrefix$normalizedRole');
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  String? _normalizeRoleKey(String? role) {
    final value = (role ?? '').trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == 'owner') return 'owner';
    if (const {'branchadmin', 'branch_admin', 'branch-admin'}.contains(value)) {
      return 'branch_admin';
    }
    if (value == 'staff') return 'staff';
    return null;
  }
}
