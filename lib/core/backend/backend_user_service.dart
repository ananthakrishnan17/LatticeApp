import 'package:dio/dio.dart';

import '../../features/users/domain/entities/app_user.dart';
import 'backend_api_service.dart';

class BackendUserService {
  BackendUserService._();

  static final BackendUserService instance = BackendUserService._();

  Future<List<AppUser>> fetchUsers() async {
    final rows = await BackendApiService.instance.withAuthRetry<List<dynamic>>((dio, headers) async {
      final response = await dio.get<List<dynamic>>(
        'users',
        options: Options(headers: headers),
      );
      return response.data ?? const <dynamic>[];
    }, allowManagementCalls: true);
    return rows
        .whereType<Map>()
        .map((row) => _mapUser(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<AppUser> getCurrentUser() async {
    final row = await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((dio, headers) async {
      final response = await dio.get<Map<String, dynamic>>(
        'users/me',
        options: Options(headers: headers),
      );
      return response.data ?? <String, dynamic>{};
    }, allowManagementCalls: true);
    return _mapUser(row);
  }

  Future<({bool success, String? error})> createUser(AppUser user) async {
    try {
      await BackendApiService.instance.withAuthRetry<void>((dio, headers) async {
        await dio.post<void>(
          'users',
          data: {
            'username': user.username,
            'pin': user.pin,
            'role': _toBackendRole(user.role),
            'isActive': user.isActive,
            'canBill': user.permissions.canBill,
            'canViewReports': user.permissions.canViewReports,
            'canManageProducts': user.permissions.canManageProducts,
            'canManageMasters': user.permissions.canManageMasters,
            'canViewExpenses': user.permissions.canViewExpenses,
            'canManagePurchase': user.permissions.canManagePurchase,
            'canViewDashboard': user.permissions.canViewDashboard,
          },
          options: Options(headers: headers),
        );
      }, allowManagementCalls: true);
      return (success: true, error: null);
    } on DioException catch (error) {
      return (success: false, error: _message(error, 'Failed to create user.'));
    }
  }

  Future<bool> updateUser(AppUser user) async {
    try {
      await BackendApiService.instance.withAuthRetry<void>((dio, headers) async {
        await dio.put<void>(
          'users/${Uri.encodeComponent(user.username)}',
          data: {
            'role': _toBackendRole(user.role),
            'isActive': user.isActive,
            'canBill': user.permissions.canBill,
            'canViewReports': user.permissions.canViewReports,
            'canManageProducts': user.permissions.canManageProducts,
            'canManageMasters': user.permissions.canManageMasters,
            'canViewExpenses': user.permissions.canViewExpenses,
            'canManagePurchase': user.permissions.canManagePurchase,
            'canViewDashboard': user.permissions.canViewDashboard,
          },
          options: Options(headers: headers),
        );
      }, allowManagementCalls: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteUser(String username) async {
    try {
      await BackendApiService.instance.withAuthRetry<void>((dio, headers) async {
        await dio.delete<void>(
          'users/${Uri.encodeComponent(username)}',
          options: Options(headers: headers),
        );
      }, allowManagementCalls: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeUserPin(String username, String newPin) async {
    try {
      await BackendApiService.instance.withAuthRetry<void>((dio, headers) async {
        await dio.put<void>(
          'users/${Uri.encodeComponent(username)}/pin',
          data: {'pin': newPin},
          options: Options(headers: headers),
        );
      }, allowManagementCalls: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  AppUser _mapUser(Map<String, dynamic> row) {
    final normalizedRole = (row['role'] ?? 'user').toString().toLowerCase();
    final role = normalizedRole == 'admin' ||
            normalizedRole == 'branchadmin' ||
            normalizedRole == 'branch_admin'
        ? UserRole.admin
        : UserRole.user;
    return AppUser(
      id: null,
      userId: (row['userId'] ?? row['user_id'] ?? '').toString(),
      organizationId: (row['organizationId'] ?? row['organization_id'] ?? '').toString(),
      organizationName: (row['organizationName'] ?? row['organization_name'] ?? '').toString(),
      branchId: (row['branchId'] ?? row['branch_id'] ?? '').toString(),
      branchName: (row['branchName'] ?? row['branch_name'] ?? '').toString(),
      tenantRole: (row['scopeRole'] ?? row['scope_role'] ?? row['tenantRole'] ?? row['tenant_role'] ?? '').toString(),
      licenseKey: (row['licenseKey'] ?? row['license_key'] ?? '').toString(),
      planName: (row['planName'] ?? row['plan_name'] ?? '').toString(),
      maxBranches: ((row['maxBranches'] ?? row['max_branches']) as num?)?.toInt() ?? 1,
      currentBranches: ((row['currentBranches'] ?? row['current_branches']) as num?)?.toInt() ?? 1,
      planExpiresAt: DateTime.tryParse((row['planExpiresAt'] ?? row['plan_expires_at'] ?? '').toString()),
      username: (row['username'] ?? '').toString(),
      pin: '',
      role: role,
      permissions: role == UserRole.admin
          ? UserPermissions.admin()
          : UserPermissions(
              canBill: row['canBill'] == true,
              canViewReports: row['canViewReports'] == true,
              canManageProducts: row['canManageProducts'] == true,
              canManageMasters: row['canManageMasters'] == true,
              canViewExpenses: row['canViewExpenses'] == true,
              canManagePurchase: row['canManagePurchase'] == true,
              canViewDashboard: row['canViewDashboard'] != false,
            ),
      isActive: row['isActive'] != false,
      createdAt: DateTime.tryParse((row['createdAt'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((row['updatedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  String _message(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return error.message ?? fallback;
  }

  String _toBackendRole(UserRole role) {
    if (role == UserRole.admin) return 'branchadmin';
    return role.value;
  }
}
