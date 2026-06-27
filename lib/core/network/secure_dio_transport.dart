import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

void attachSecureTransport(Dio dio, String normalizedBaseUrl) {
  final uri = Uri.tryParse(normalizedBaseUrl);
  if (uri == null) return;
  final host = uri.host.toLowerCase();
  final isLocal = host == 'localhost' || host == '127.0.0.1';
  if (isLocal || uri.scheme != 'https') return;

  // JAVA_API_CERT_SHA256 format: comma-separated lowercase SHA-256 cert hashes.
  final configuredPins = const String.fromEnvironment(
    'JAVA_API_CERT_SHA256',
    defaultValue: '',
  ).trim().toLowerCase();
  if (configuredPins.isEmpty) return;
  final allowedPins = configuredPins
      .split(',')
      .map((pin) => pin.trim())
      .where((pin) => pin.isNotEmpty)
      .toSet();
  if (allowedPins.isEmpty) return;

  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;

  adapter.createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, _, __) {
      final now = DateTime.now();
      if (now.isBefore(cert.startValidity) || now.isAfter(cert.endValidity)) {
        return false;
      }
      final digest = sha256.convert(cert.der).toString().toLowerCase();
      return allowedPins.contains(digest);
    };
    return client;
  };
}
