import 'dart:convert';

import '../../features/users/domain/entities/app_user.dart';
import '../sync/JavaAuthService.dart';

enum SessionGateFailure {
  unauthenticated,
  expired,
}

class SessionGateResult {
  final SessionGateFailure? failure;

  const SessionGateResult._(this.failure);

  const SessionGateResult.allowed() : this._(null);

  bool get isAllowed => failure == null;
}

class AppSessionGuard {
  AppSessionGuard._();

  static final AppSessionGuard instance = AppSessionGuard._();

  Future<SessionGateResult> checkProtectedAccess({
    required AppUser? currentUser,
    bool requireActivatedLicense = true,
  }) async {
    final token = await JavaAuthService.instance.getToken();
    if (token == null || token.trim().isEmpty || currentUser == null) {
      return const SessionGateResult._(SessionGateFailure.unauthenticated);
    }
    final exp = _readJwtExpiry(token.trim());
    if (exp != null && !exp.isAfter(DateTime.now().toUtc())) {
      return const SessionGateResult._(SessionGateFailure.expired);
    }

    return const SessionGateResult.allowed();
  }

  DateTime? _readJwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
