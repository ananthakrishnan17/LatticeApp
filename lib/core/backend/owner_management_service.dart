import 'dart:convert';

import 'package:dio/dio.dart';

import 'backend_api_service.dart';

// ── DTOs ──────────────────────────────────────────────────────────────────────

class BranchDto {
  final String id;
  final String name;
  final bool isDefault;

  const BranchDto({required this.id, required this.name, required this.isDefault});

  factory BranchDto.fromMap(Map<String, dynamic> map) => BranchDto(
        id: (map['id'] ?? map['server_id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        isDefault: map['isDefault'] == true || map['is_default'] == true,
      );
}

class RoleDto {
  final String code;
  final String displayName;
  final String scope;

  const RoleDto({required this.code, required this.displayName, required this.scope});

  factory RoleDto.fromMap(Map<String, dynamic> map) => RoleDto(
        code: (map['code'] ?? map['role_code'] ?? '').toString(),
        displayName: (map['displayName'] ?? map['display_name'] ?? '').toString(),
        scope: (map['scope'] ?? '').toString(),
      );

  String get emoji {
    switch (code.toLowerCase()) {
      case 'owner':
        return '👑';
      case 'branch_admin':
        return '🏢';
      default:
        return '👤';
    }
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class OwnerManagementService {
  OwnerManagementService._();

  static final OwnerManagementService instance = OwnerManagementService._();

  Future<List<BranchDto>> fetchBranches() async {
    final rows = await BackendApiService.instance.withAuthRetry<List<dynamic>>((dio, headers) async {
      final response = await dio.get<List<dynamic>>(
        'owner/branches',
        options: Options(headers: headers),
      );
      return response.data ?? const <dynamic>[];
    }, allowManagementCalls: true);
    return rows.whereType<Map>().map((r) => BranchDto.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<({bool success, String? error, BranchDto? branch})> createBranch(String name) async {
    try {
      final data = await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((dio, headers) async {
        final response = await dio.post<Map<String, dynamic>>(
          'owner/branches',
          data: {'name': name},
          options: Options(headers: headers),
        );
        return response.data ?? const <String, dynamic>{};
      }, allowManagementCalls: true);
      return (success: true, error: null, branch: BranchDto.fromMap(data));
    } on DioException catch (e) {
      return (success: false, error: _message(e, 'Failed to create branch'), branch: null);
    }
  }

  Future<List<RoleDto>> fetchRoles() async {
    final rows = await BackendApiService.instance.withAuthRetry<List<dynamic>>((dio, headers) async {
      final response = await dio.get<List<dynamic>>(
        'owner/roles',
        options: Options(headers: headers),
      );
      return response.data ?? const <dynamic>[];
    }, allowManagementCalls: true);
    return rows.whereType<Map>().map((r) => RoleDto.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<({bool success, String? error})> assignUserToBranchRole({
    required String username,
    required String branchId,
    required String roleCode,
  }) async {
    try {
      await BackendApiService.instance.withAuthRetry<void>((dio, headers) async {
        await dio.post<void>(
          'owner/users/${Uri.encodeComponent(username)}/assign',
          data: {'branchId': branchId, 'roleCode': roleCode},
          options: Options(headers: headers),
        );
      }, allowManagementCalls: true);
      return (success: true, error: null);
    } on DioException catch (e) {
      return (success: false, error: _message(e, 'Failed to assign user'));
    }
  }

  String _message(DioException error, String fallback) {
    final raw = error.response?.data;
    Map<String, dynamic>? body;
    if (raw is Map<String, dynamic>) {
      body = raw;
    } else if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    if (body != null) {
      final msg = body['message'];
      if (msg != null && msg.toString().isNotEmpty) return msg.toString();
    }
    return error.message ?? fallback;
  }
}
