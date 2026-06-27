import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const _requestStartKey = '__api_request_start';

class ApiLoggingInterceptor extends Interceptor {
  static final ApiLoggingInterceptor instance = ApiLoggingInterceptor._();

  ApiLoggingInterceptor._();

  bool get _enabled => kDebugMode || kProfileMode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_enabled) {
      final start = DateTime.now();
      options.extra[_requestStartKey] = start;
      debugPrint(
        '[API][REQUEST] ${options.method.toUpperCase()} ${options.uri}\n'
        'startTime=${start.toIso8601String()}\n'
        'query=${_safeJson(options.queryParameters)}\n'
        'headers=${_safeJson(_maskSensitive(options.headers))}\n'
        'body=${_safeJson(_maskSensitive(options.data))}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_enabled) {
      final options = response.requestOptions;
      final start = options.extra[_requestStartKey] as DateTime?;
      final durationMs = start == null
          ? null
          : DateTime.now().difference(start).inMilliseconds;
      debugPrint(
        '[API][SUCCESS] ${options.method.toUpperCase()} ${options.uri}\n'
        'status=${response.statusCode ?? '-'}\n'
        'durationMs=${durationMs ?? '-'}\n'
        'response=${_safeJson(_maskSensitive(response.data))}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_enabled) {
      final options = err.requestOptions;
      final start = options.extra[_requestStartKey] as DateTime?;
      final durationMs = start == null
          ? null
          : DateTime.now().difference(start).inMilliseconds;
      debugPrint(
        '[API][FAILED] ${options.method.toUpperCase()} ${options.uri}\n'
        'status=${err.response?.statusCode ?? '-'}\n'
        'durationMs=${durationMs ?? '-'}\n'
        'message=${err.message ?? '-'}\n'
        'response=${_safeJson(_maskSensitive(err.response?.data))}',
      );
      if (err.stackTrace != null) {
        debugPrint('[API][STACKTRACE] ${err.stackTrace}');
      } else {
        debugPrint('[API][STACKTRACE] unavailable');
      }
    }
    handler.next(err);
  }
}

void attachApiLoggingInterceptor(Dio dio) {
  if (dio.interceptors.any((i) => i is ApiLoggingInterceptor)) {
    return;
  }
  dio.interceptors.add(ApiLoggingInterceptor.instance);
}

dynamic _maskSensitive(dynamic value) {
  if (value is Map) {
    return value.map((key, item) {
      final keyString = key.toString();
      if (_isSensitiveKey(keyString)) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, _maskSensitive(item));
    });
  }
  if (value is List) {
    return value.map(_maskSensitive).toList();
  }
  return value;
}

bool _isSensitiveKey(String key) {
  final normalized = key
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m.group(1) ?? ''}_${m.group(2) ?? ''}',
      )
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (normalized.isEmpty) return false;
  final segments = normalized.split('_').where((s) => s.isNotEmpty).toSet();
  return segments.contains('authorization') ||
      segments.contains('token') ||
      segments.contains('password') ||
      segments.contains('secret') ||
      segments.contains('pin') ||
      segments.contains('jwt') ||
      (segments.contains('api') && segments.contains('key'));
}

String _safeJson(dynamic value) {
  if (value == null) return 'null';
  try {
    if (value is String) return value;
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
}
