import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';

import '../../../../core/backend/backend_subscription_service.dart';
import '../../../../core/backend/backend_user_service.dart';
import '../../../../core/sync/JavaAuthService.dart';
import '../../../../core/sync/data_access_mode_service.dart';
import '../../../../core/sync/java_api_config_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../owner/presentation/pages/owner_dashboard_screen.dart';
import '../../../shell/presentation/pages/main_shell.dart';
import '../../../subscription/presentation/pages/subscription_lock_screen.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../domain/tenant_roles.dart';
import '../../../users/domain/entities/app_user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _primary = Color(0xFF0073BB);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _bgColor = Color(0xFFF0F2F5);

  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _identifierFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  @override
  void dispose() {
    _identifierFocusNode.dispose();
    _passwordFocusNode.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final config = await JavaApiConfigService.instance.loadConfig(
      defaultBaseUrl: JavaAuthService.defaultBaseUrl,
    );
    if (!mounted) return;
    setState(() {
      // Backend settings persist this identifier in the existing `username` key.
      _identifierCtrl.text = config.username;
      _passwordCtrl.text = config.password;
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final existingConfig = await JavaApiConfigService.instance.loadConfig(
        defaultBaseUrl: JavaAuthService.defaultBaseUrl,
      );
      final identifier = _identifierCtrl.text.trim();
      await JavaApiConfigService.instance.saveConfig(
        tenantCode: existingConfig.tenantCode,
        username: identifier,
        password: _passwordCtrl.text,
      );
      await JavaAuthService.instance.logout();
      final deviceId = await JavaAuthService.instance.getOrCreateDeviceId();
      await JavaAuthService.instance.login(
        identifier,
        _passwordCtrl.text,
        deviceId,
      );
      final scopeRole = await JavaAuthService.instance.getScopeRole();
      final organizationId = await JavaAuthService.instance.getOrganizationId();
      final branchId = await JavaAuthService.instance.getBranchId();
      final mode = await DataAccessModeService.instance.resolveMode();
      final isOnlineLicense = mode == DataAccessMode.onlineApi;
      final resolvedRole = TenantRoles.normalize(scopeRole);
      AppUser mappedUser;
      if (isOnlineLicense) {
        final user = await BackendUserService.instance.getCurrentUser();
        await BackendSubscriptionService.instance.fetchStatus(forceRefresh: true);
        final sub = await BackendSubscriptionService.instance.getCachedStatus();
        mappedUser = user.copyWith(
          userId: user.userId.isNotEmpty ? user.userId : user.username,
          organizationId: (organizationId ?? user.organizationId),
          organizationName: (sub?.companyName.isNotEmpty == true)
              ? sub!.companyName
              : user.organizationName,
          branchId: (branchId ?? user.branchId),
          branchName: user.branchName,
          tenantRole: resolvedRole,
          licenseKey: sub?.licenseKey ?? user.licenseKey,
          planName: sub?.planLabel ?? user.planName,
          maxBranches: sub?.maxCompanies ?? user.maxBranches,
          currentBranches: user.currentBranches > 0 ? user.currentBranches : 1,
          planExpiresAt: sub?.expiresAt ?? user.planExpiresAt,
        );
      } else {
        final userRole = _mapTenantRoleToUserRole(resolvedRole);
        mappedUser = AppUser(
          username: identifier,
          pin: '',
          role: userRole,
          permissions: userRole == UserRole.admin
              ? UserPermissions.admin()
              : UserPermissions.defaultUser(),
          organizationId: organizationId ?? '',
          branchId: branchId ?? '',
          tenantRole: resolvedRole,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );
      }
      if (!mounted) return;
      context.read<UserBloc>().currentUser = mappedUser;
      if (!mounted) return;
      final status = await SubscriptionService.instance.getStatus();
      if (!mounted) return;
      _navigateToAuthorizedHome(
        resolvedRole: resolvedRole,
        status: status,
      );
    } on DioException catch (error) {
      final responseMessage = _extractErrorMessage(error.response?.data);
      if (!mounted) return;
      setState(() => _error = responseMessage ?? 'Login failed. Please verify your username/mobile number and password.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  UserRole _mapTenantRoleToUserRole(String tenantRole) {
    if (tenantRole == TenantRoles.owner || tenantRole == TenantRoles.branchAdmin) {
      return UserRole.admin;
    }
    return UserRole.user;
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      const keys = ['message', 'error', 'errorMessage', 'details'];
      for (final key in keys) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return null;
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            child: Column(
              children: [
                SizedBox(height: 48.h),
                _buildBranding(),
                SizedBox(height: 28.h),
                _buildFormCard(),
                SizedBox(height: 20.h),
                Text(
                  'Use your assigned login credentials.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'New to Namma Nanban? ',
                      style: TextStyle(
                        color: _textSecondary,
                        fontFamily: 'Poppins',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showInfoMessage(
                        'Please contact your administrator for account creation.',
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: Size(0, 24.h),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          color: _primary,
                          fontFamily: 'Poppins',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
          width: 72.w,
          height: 72.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            color: _primary,
          ),
          child: Icon(Icons.point_of_sale, color: Colors.white, size: 38.sp),
        ),
        SizedBox(height: 16.h),
        Text(
          'NAMMA NANBAN',
          style: TextStyle(
            color: _textPrimary,
            fontFamily: 'Poppins',
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          'Business management portal',
          style: TextStyle(
            color: _textSecondary,
            fontFamily: 'Poppins',
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          _field(
            controller: _identifierCtrl,
            focusNode: _identifierFocusNode,
            label: 'Username / Mobile Number',
            hint: 'Enter your username or mobile number',
            icon: Icons.person_outline,
            keyboardType: TextInputType.text,
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'Username or mobile number is required' : null,
          ),
          SizedBox(height: 20.h),
          _field(
            controller: _passwordCtrl,
            focusNode: _passwordFocusNode,
            label: 'Password / PIN',
            hint: 'Enter your backend password',
            icon: Icons.lock_outline,
            obscureText: true,
            validator: (value) => (value?.isEmpty ?? true) ? 'Password is required' : null,
          ),
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showInfoMessage(
                'Please contact your administrator to reset your password.',
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size(0, 22.h),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: _primary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  color: AppTheme.danger,
                  fontSize: 12.sp,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
          SizedBox(height: 20.h),
          _buildLoginButton(),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(child: Divider(color: _borderColor, thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              Expanded(child: Divider(color: _borderColor, thickness: 1)),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined, color: _primary, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  'Secure enterprise authentication',
                  style: TextStyle(
                    color: _textSecondary,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    final disabled = _isLoading;
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: disabled ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? const Color(0xFF9CA3AF) : _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'LOGIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  fontFamily: 'Poppins',
                ),
              ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: _textPrimary, fontFamily: 'Poppins', fontSize: 14.sp),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.w),
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _primary.withOpacity(0.8), size: 20.sp),
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: _textSecondary, fontFamily: 'Poppins'),
        hintStyle: TextStyle(color: _textSecondary.withOpacity(0.7), fontFamily: 'Poppins', fontSize: 13.sp),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppTheme.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppTheme.danger),
        ),
      ),
      cursorColor: _primary,
    );
  }

  void _navigateToAuthorizedHome({
    required String resolvedRole,
    required SubscriptionStatus status,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (status.isLocked) return SubscriptionLockScreen(status: status);
          if (resolvedRole == TenantRoles.owner) return const OwnerDashboardScreen();
          return const MainShell();
        },
      ),
    );
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
