import 'dart:developer' as developer;

// Matches package:logging Level.WARNING.
const _warningLogLevel = 900;

/// Normalizes a configured backend base URL for Dio request joining.
///
/// Ensures non-empty values end with `/` so relative paths like `auth/login`
/// or `sync/pull` consistently resolve under the configured base URL, whether
/// the deployment is at server root (ROOT.war) or under a context path.
String normalizeBaseUrlForDio(String baseUrl) {
  final trimmed = baseUrl.trim();
  if (trimmed.isEmpty) return trimmed;
  final withScheme =
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null) return withScheme.endsWith('/') ? withScheme : '$withScheme/';
  final hostLowerCase = uri.host.toLowerCase();
  final isLocal =
      hostLowerCase == 'localhost' || hostLowerCase == '127.0.0.1';
  if (uri.scheme == 'http' && !isLocal) {
    developer.log(
      'Using insecure HTTP base URL: $uri',
      name: 'JavaApiUrl',
      level: _warningLogLevel,
    );
  }
  final normalized = uri.toString();
  return normalized.endsWith('/') ? normalized : '$normalized/';
}
