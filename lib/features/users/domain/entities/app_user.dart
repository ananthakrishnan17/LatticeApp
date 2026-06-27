import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/backend/backend_user_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/JavaAuthService.dart';
import '../../../../core/sync/java_api_config_service.dart';

// ─── User Roles ────────────────────────────────────────────────────────────────
enum UserRole { admin, user }

extension UserRoleExt on UserRole {
  String get value => name;
  String get label => name == 'admin' ? 'Admin' : 'User';
  String get emoji => name == 'admin' ? '👑' : '👤';
}

// ─── User Permissions ─────────────────────────────────────────────────────────
class UserPermissions extends Equatable {
  final bool canBill;
  final bool canViewReports;
  final bool canManageProducts;
  final bool canManageMasters;
  final bool canViewExpenses;
  final bool canManagePurchase;
  final bool canViewDashboard;

  const UserPermissions({
    this.canBill = true,
    this.canViewReports = false,
    this.canManageProducts = false,
    this.canManageMasters = false,
    this.canViewExpenses = false,
    this.canManagePurchase = false,
    this.canViewDashboard = true,
  });

  factory UserPermissions.admin() => const UserPermissions(
        canBill: true,
        canViewReports: true,
        canManageProducts: true,
        canManageMasters: true,
        canViewExpenses: true,
        canManagePurchase: true,
        canViewDashboard: true,
      );

  factory UserPermissions.defaultUser() => const UserPermissions(
        canBill: true,
        canViewDashboard: true,
      );

  factory UserPermissions.fromMap(Map<String, dynamic> m) => UserPermissions(
        canBill: _boolValue(m['can_bill'], defaultValue: true),
        canViewReports: _boolValue(m['can_view_reports']),
        canManageProducts: _boolValue(m['can_manage_products']),
        canManageMasters: _boolValue(m['can_manage_masters']),
        canViewExpenses: _boolValue(m['can_view_expenses']),
        canManagePurchase: _boolValue(m['can_manage_purchase']),
        canViewDashboard: _boolValue(m['can_view_dashboard'], defaultValue: true),
      );

  Map<String, int> toMap() => {
        'can_bill': canBill ? 1 : 0,
        'can_view_reports': canViewReports ? 1 : 0,
        'can_manage_products': canManageProducts ? 1 : 0,
        'can_manage_masters': canManageMasters ? 1 : 0,
        'can_view_expenses': canViewExpenses ? 1 : 0,
        'can_manage_purchase': canManagePurchase ? 1 : 0,
        'can_view_dashboard': canViewDashboard ? 1 : 0,
      };

  UserPermissions copyWith({
    bool? canBill,
    bool? canViewReports,
    bool? canManageProducts,
    bool? canManageMasters,
    bool? canViewExpenses,
    bool? canManagePurchase,
    bool? canViewDashboard,
  }) =>
      UserPermissions(
        canBill: canBill ?? this.canBill,
        canViewReports: canViewReports ?? this.canViewReports,
        canManageProducts: canManageProducts ?? this.canManageProducts,
        canManageMasters: canManageMasters ?? this.canManageMasters,
        canViewExpenses: canViewExpenses ?? this.canViewExpenses,
        canManagePurchase: canManagePurchase ?? this.canManagePurchase,
        canViewDashboard: canViewDashboard ?? this.canViewDashboard,
      );

  @override
  List<Object?> get props => [
        canBill,
        canViewReports,
        canManageProducts,
        canManageMasters,
        canViewExpenses,
        canManagePurchase,
        canViewDashboard,
      ];
}

bool _boolValue(Object? value, {bool defaultValue = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return defaultValue;
}

// ─── App User Entity ───────────────────────────────────────────────────────────
class AppUser extends Equatable {
  final int? id;
  final String userId;
  final String organizationId;
  final String organizationName;
  final String branchId;
  final String branchName;
  final String tenantRole;
  final String licenseKey;
  final String planName;
  final int maxBranches;
  final int currentBranches;
  final DateTime? planExpiresAt;
  final String username;
  final String pin;
  final UserRole role;
  final UserPermissions permissions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    this.id,
    this.userId = '',
    this.organizationId = '',
    this.organizationName = '',
    this.branchId = '',
    this.branchName = '',
    this.tenantRole = 'Staff',
    this.licenseKey = '',
    this.planName = '',
    this.maxBranches = 1,
    this.currentBranches = 1,
    this.planExpiresAt,
    required this.username,
    required this.pin,
    required this.role,
    required this.permissions,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromMap(Map<String, dynamic> m) {
    final roleStr = (m['role']?.toString().toLowerCase() ?? '');
    final tenantRoleStr = (m['tenantRole']?.toString().toLowerCase() ?? 
                           m['tenant_role']?.toString().toLowerCase() ?? 
                           m['scopeRole']?.toString().toLowerCase() ?? 
                           m['scope_role']?.toString().toLowerCase() ?? '');
    final role = (roleStr == 'admin' || roleStr == 'owner' || 
                  tenantRoleStr == 'admin' || tenantRoleStr == 'owner') 
                 ? UserRole.admin : UserRole.user;
    return AppUser(
      id: m['id'] as int?,
      userId: (m['userId'] ?? m['user_id'] ?? '').toString(),
      organizationId: (m['organizationId'] ?? m['organization_id'] ?? '').toString(),
      organizationName: (m['organizationName'] ?? m['organization_name'] ?? '').toString(),
      branchId: (m['branchId'] ?? m['branch_id'] ?? '').toString(),
      branchName: (m['branchName'] ?? m['branch_name'] ?? '').toString(),
      tenantRole: (m['tenantRole'] ?? m['tenant_role'] ?? m['scopeRole'] ?? m['scope_role'] ?? 'Staff').toString(),
      licenseKey: (m['licenseKey'] ?? m['license_key'] ?? '').toString(),
      planName: (m['planName'] ?? m['plan_name'] ?? '').toString(),
      maxBranches: ((m['maxBranches'] ?? m['max_branches']) as num?)?.toInt() ?? 1,
      currentBranches: ((m['currentBranches'] ?? m['current_branches']) as num?)?.toInt() ?? 1,
      planExpiresAt: DateTime.tryParse((m['planExpiresAt'] ?? m['plan_expires_at'] ?? '').toString()),
      username: m['username'] as String,
      pin: (m['pin'] ?? '').toString(),
      role: role,
      permissions: role == UserRole.admin
          ? UserPermissions.admin()
          : UserPermissions.fromMap(m),
      isActive: _boolValue(m['is_active'], defaultValue: true),
      createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((m['updated_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'organization_id': organizationId,
        'organization_name': organizationName,
        'branch_id': branchId,
        'branch_name': branchName,
        'tenant_role': tenantRole,
        'license_key': licenseKey,
        'plan_name': planName,
        'max_branches': maxBranches,
        'current_branches': currentBranches,
        if (planExpiresAt != null) 'plan_expires_at': planExpiresAt!.toIso8601String(),
        'username': username,
        'pin': pin,
        'role': role.value,
        ...permissions.toMap(),
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  AppUser copyWith({
    String? userId,
    String? organizationId,
    String? organizationName,
    String? branchId,
    String? branchName,
    String? tenantRole,
    String? licenseKey,
    String? planName,
    int? maxBranches,
    int? currentBranches,
    DateTime? planExpiresAt,
    String? username,
    String? pin,
    UserRole? role,
    UserPermissions? permissions,
    bool? isActive,
  }) =>
      AppUser(
        id: id,
        userId: userId ?? this.userId,
        organizationId: organizationId ?? this.organizationId,
        organizationName: organizationName ?? this.organizationName,
        branchId: branchId ?? this.branchId,
        branchName: branchName ?? this.branchName,
        tenantRole: tenantRole ?? this.tenantRole,
        licenseKey: licenseKey ?? this.licenseKey,
        planName: planName ?? this.planName,
        maxBranches: maxBranches ?? this.maxBranches,
        currentBranches: currentBranches ?? this.currentBranches,
        planExpiresAt: planExpiresAt ?? this.planExpiresAt,
        username: username ?? this.username,
        pin: pin ?? this.pin,
        role: role ?? this.role,
        permissions: permissions ?? this.permissions,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        organizationId,
        organizationName,
        branchId,
        branchName,
        tenantRole,
        licenseKey,
        planName,
        maxBranches,
        currentBranches,
        planExpiresAt,
        username,
        role,
        isActive,
      ];
}

// ─── User Repository ───────────────────────────────────────────────────────────
class UserRepository {
  final DatabaseHelper _db;
  UserRepository(this._db);

  Future<List<AppUser>> getAllUsers() => BackendUserService.instance.fetchUsers();

  Future<AppUser?> verifyPin(String username, String pin) async {
    final config = await JavaApiConfigService.instance.loadConfig(
      defaultBaseUrl: JavaAuthService.defaultBaseUrl,
    );
    if (!config.isComplete) return null;
    final deviceId = await JavaAuthService.instance.getOrCreateDeviceId();
    await JavaAuthService.instance.login(
      username,
      pin,
      deviceId,
      baseUrl: config.baseUrl,
    );
    return BackendUserService.instance.getCurrentUser();
  }

  Future<bool> hasAnyAdmin() async {
    final users = await getAllUsers();
    return users.any((user) => user.isAdmin && user.isActive);
  }

  Future<int> createUser(AppUser user) async {
    final result = await BackendUserService.instance.createUser(user);
    if (!result.success) {
      throw StateError(result.error ?? 'Failed to create user');
    }
    return 1;
  }

  Future<bool> updateUser(AppUser user) => BackendUserService.instance.updateUser(user);

  Future<bool> toggleActive(String username, bool isActive) async {
    final users = await getAllUsers();
    final user = users.firstWhere((item) => item.username == username);
    return updateUser(user.copyWith(isActive: isActive));
  }

  Future<bool> deleteUser(String username) => BackendUserService.instance.deleteUser(username);

  Future<bool> changePin(String username, String newPin) =>
      BackendUserService.instance.changeUserPin(username, newPin);

  Future<AppUser> getCurrentUser() => BackendUserService.instance.getCurrentUser();
}

// ─── Events ────────────────────────────────────────────────────────────────────
abstract class UserEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadUsers extends UserEvent {}

class LoadCloudUsers extends UserEvent {}

class CreateUser extends UserEvent {
  final AppUser user;
  CreateUser(this.user);
  @override
  List<Object?> get props => [user.username];
}

class UpdateUser extends UserEvent {
  final AppUser user;
  UpdateUser(this.user);
  @override
  List<Object?> get props => [user.username, user.isActive];
}

class DeleteUserEvent extends UserEvent {
  final String username;
  DeleteUserEvent(this.username);
  @override
  List<Object?> get props => [username];
}

class ToggleUserActive extends UserEvent {
  final String username;
  final bool isActive;
  ToggleUserActive(this.username, this.isActive);
  @override
  List<Object?> get props => [username, isActive];
}

class LoginUser extends UserEvent {
  final String username;
  final String pin;
  LoginUser(this.username, this.pin);
  @override
  List<Object?> get props => [username];
}

class LogoutUser extends UserEvent {}

// ─── States ────────────────────────────────────────────────────────────────────
abstract class UserState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserListLoaded extends UserState {
  final List<AppUser> users;
  UserListLoaded(this.users);
  @override
  List<Object?> get props => [users];
}

class UserLoggedIn extends UserState {
  final AppUser user;
  UserLoggedIn(this.user);
  @override
  List<Object?> get props => [user];
}

class UserLoginFailed extends UserState {
  final String message;
  UserLoginFailed(this.message);
  @override
  List<Object?> get props => [message];
}

class UserLoggedOut extends UserState {}

class UserError extends UserState {
  final String message;
  UserError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────────────────
class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _repo;
  AppUser? currentUser;

  UserBloc(this._repo) : super(UserInitial()) {
    on<LoadUsers>(_onLoad);
    on<LoadCloudUsers>(_onLoad);
    on<CreateUser>(_onCreate);
    on<UpdateUser>(_onUpdate);
    on<DeleteUserEvent>(_onDelete);
    on<ToggleUserActive>(_onToggle);
    on<LoginUser>(_onLogin);
    on<LogoutUser>(_onLogout);
  }

  Future<void> _onLoad(UserEvent e, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final users = await _repo.getAllUsers();
      emit(UserListLoaded(users));
    } catch (err) {
      emit(UserError(err.toString()));
    }
  }

  Future<void> _onCreate(CreateUser e, Emitter<UserState> emit) async {
    try {
      await _repo.createUser(e.user);
      add(LoadUsers());
    } catch (err) {
      emit(UserError(err.toString()));
    }
  }

  Future<void> _onUpdate(UpdateUser e, Emitter<UserState> emit) async {
    try {
      await _repo.updateUser(e.user);
      add(LoadUsers());
    } catch (err) {
      emit(UserError(err.toString()));
    }
  }

  Future<void> _onDelete(DeleteUserEvent e, Emitter<UserState> emit) async {
    try {
      await _repo.deleteUser(e.username);
      add(LoadUsers());
    } catch (err) {
      emit(UserError(err.toString()));
    }
  }

  Future<void> _onToggle(ToggleUserActive e, Emitter<UserState> emit) async {
    try {
      await _repo.toggleActive(e.username, e.isActive);
      add(LoadUsers());
    } catch (err) {
      emit(UserError(err.toString()));
    }
  }

  Future<void> _onLogin(LoginUser e, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final user = await _repo.verifyPin(e.username, e.pin);
      if (user == null) {
        emit(UserLoginFailed('Wrong credentials. Try again.'));
      } else {
        currentUser = user;
        emit(UserLoggedIn(user));
      }
    } catch (err) {
      emit(UserError(err.toString()));
    }
  }

  Future<void> _onLogout(LogoutUser e, Emitter<UserState> emit) async {
    currentUser = null;
    emit(UserLoggedOut());
  }
}

extension UserBlocExt on UserBloc {
  UserRepository get repo => _repo;
}
