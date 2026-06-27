import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/backend/backend_subscription_service.dart';
import '../../../../core/sync/JavaAuthService.dart';
import '../../../../core/sync/java_api_config_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/plan_time_helper.dart';
import '../../domain/tenant_roles.dart';
import '../../../owner/presentation/pages/owner_dashboard_screen.dart';
import '../../../shell/presentation/pages/main_shell.dart';
import '../../../subscription/presentation/pages/subscription_lock_screen.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../users/domain/entities/app_user.dart';
import 'login_screen.dart';

class LicenseActivationScreen extends StatefulWidget {
  final bool continueToDashboardAfterActivation;

  const LicenseActivationScreen({
    super.key,
    this.continueToDashboardAfterActivation = false,
  });

  @override
  State<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  static final RegExp _keyPattern = RegExp(r'^PM-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
  final _tenantCodeCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  BackendSubscriptionInfo? _verifiedInfo;

  @override
  void initState() {
    super.initState();
    _loadTenantCode();
  }

  Future<void> _loadTenantCode() async {
    try {
      final config = await JavaApiConfigService.instance.loadConfig(
        defaultBaseUrl: JavaAuthService.defaultBaseUrl,
      );
      if (mounted) {
        setState(() => _tenantCodeCtrl.text = config.tenantCode);
      }
    } catch (_) {
      // Keep tenant code field empty.
    }
  }

  @override
  void dispose() {
    _tenantCodeCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  bool get _looksValid => _keyPattern.hasMatch(_keyCtrl.text.trim().toUpperCase());

  Future<void> _verify() async {
    final tenantCode = _tenantCodeCtrl.text.trim();
    if (tenantCode.isEmpty) {
      setState(() => _error = 'Tenant code is required to activate this license');
      return;
    }
    if (!_looksValid) {
      setState(() => _error = 'Enter a valid key like PM-XXXX-XXXX-XXXX');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _verifiedInfo = null;
    });
    String? previousTenantCode;
    JavaApiConfig? loadedConfig;
    try {
      final config = await JavaApiConfigService.instance.loadConfig(
        defaultBaseUrl: JavaAuthService.defaultBaseUrl,
      );
      loadedConfig = config;
      previousTenantCode = config.tenantCode;
      if (config.tenantCode != tenantCode) {
        await JavaApiConfigService.instance.saveConfig(
          baseUrl: config.baseUrl,
          tenantCode: tenantCode,
          username: config.username,
          password: config.password,
        );
      }
      final result = await SubscriptionService.instance.activateWithKey(_keyCtrl.text.trim().toUpperCase());
      if (result.success) {
        final info = await BackendSubscriptionService.instance.fetchStatus(forceRefresh: true);
        setState(() => _verifiedInfo = info);
      } else {
        await _rollbackTenantCodeIfNeeded(
          previousTenantCode: previousTenantCode,
          currentTenantCode: tenantCode,
          config: config,
        );
        final tenantHint = ' Make sure this key belongs to tenant "$tenantCode".';
        setState(() => _error = '${result.message}$tenantHint');
      }
    } catch (e) {
      final config = loadedConfig ??
          await JavaApiConfigService.instance.loadConfig(
            defaultBaseUrl: JavaAuthService.defaultBaseUrl,
          );
      await _rollbackTenantCodeIfNeeded(
        previousTenantCode: previousTenantCode,
        currentTenantCode: tenantCode,
        config: config,
      );
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rollbackTenantCodeIfNeeded({
    required String? previousTenantCode,
    required String currentTenantCode,
    required JavaApiConfig config,
  }) async {
    // If no previous value exists or it matches the current value, there is nothing to rollback.
    if (previousTenantCode == null || previousTenantCode == currentTenantCode) return;
    await JavaApiConfigService.instance.saveConfig(
      tenantCode: previousTenantCode,
      username: config.username,
      password: config.password,
      baseUrl: config.baseUrl,
    );
  }

  Future<void> _continue() async {
    final info = _verifiedInfo;
    if (info == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLicenseActivated', true);
    final tenantId = await JavaAuthService.instance.getTenantId();
    final userBloc = context.read<UserBloc>();
    final current = userBloc.currentUser;
    final mapped = (current ?? AppUser(
      username: '',
      pin: '',
      role: UserRole.user,
      permissions: UserPermissions.defaultUser(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    )).copyWith(
      organizationId: current?.organizationId.isNotEmpty == true ? current!.organizationId : (tenantId ?? ''),
      organizationName: info.companyName,
      planName: info.planLabel,
      licenseKey: info.licenseKey ?? '',
      maxBranches: info.maxCompanies,
      currentBranches: current?.currentBranches ?? 1,
      planExpiresAt: info.expiresAt,
    );
    userBloc.currentUser = mapped;
    if (!mounted) return;
    if (widget.continueToDashboardAfterActivation) {
      final status = await SubscriptionService.instance.getStatus();
      if (!mounted) return;
      final role = TenantRoles.normalize(userBloc.currentUser?.tenantRole);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) {
            if (status.isLocked) return SubscriptionLockScreen(status: status);
            if (role == TenantRoles.owner) return const OwnerDashboardScreen();
            return const MainShell();
          },
        ),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D3250),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20.h),
              Container(
                width: 72.w,
                height: 72.h,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Icon(Icons.point_of_sale, color: Colors.white, size: 40.sp),
              ),
              SizedBox(height: 14.h),
              Text('NammaNanban', style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              SizedBox(height: 4.h),
              Text('BUSINESS EDITION', style: TextStyle(color: const Color(0xFFFFC857), fontSize: 11.sp, letterSpacing: 1.4, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              SizedBox(height: 28.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Activate your Organization', style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Enter the license key from your purchase email', style: TextStyle(color: Colors.white60, fontSize: 13.sp, fontFamily: 'Poppins')),
              ),
              SizedBox(height: 12.h),
              Semantics(
                label: 'Tenant Code',
                textField: true,
                child: TextField(
                  controller: _tenantCodeCtrl,
                  onChanged: (_) => setState(() => _error = null),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontFamily: 'Poppins',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tenant Code (required)',
                    prefixIcon: const Icon(Icons.business_rounded, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    hintStyle: TextStyle(color: Colors.white30, fontFamily: 'Poppins', fontSize: 13.sp),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.2),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _keyCtrl,
                onChanged: (_) => setState(() => _error = null),
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  color: const Color(0xFFFFC857),
                  fontSize: 15.sp,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: 'PM-XXXX-XXXX-XXXX',
                  prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFFFFC857)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  hintStyle: TextStyle(color: Colors.white30, fontFamily: 'monospace', fontSize: 13.sp),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: const BorderSide(color: Color(0xFFFFC857), width: 1.2),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Found in your welcome email', style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontFamily: 'Poppins')),
              ),
              if (_error != null) ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                  ),
                  child: Text(_error!, style: TextStyle(color: AppTheme.danger, fontSize: 12.sp, fontFamily: 'Poppins')),
                ),
              ],
              SizedBox(height: 14.h),
              if (_verifiedInfo != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.5)),
                  ),
                  child: Text(
                    '${_verifiedInfo!.planLabel} Plan · Verified ✓ — Up to ${_verifiedInfo!.maxCompanies} ${_verifiedInfo!.maxCompanies == 1 ? 'branch' : 'branches'} · ${_monthsLabel(_verifiedInfo!.daysLeft)}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.sp, fontFamily: 'Poppins'),
                  ),
                ),
              SizedBox(height: 18.h),
              ElevatedButton(
                onPressed: _isLoading ? null : (_verifiedInfo == null ? _verify : _continue),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50.h)),
                child: _isLoading
                    ? SizedBox(
                        width: 18.w,
                        height: 18.h,
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_verifiedInfo == null ? 'Activate' : 'Activate & Continue →'),
              ),
              SizedBox(height: 10.h),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact Support')),
                  );
                },
                child: const Text('Contact Support'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthsLabel(int daysLeft) {
    final months = remainingPlanMonths(_verifiedInfo?.expiresAt);
    if (months > 0) {
      return '$months ${monthUnit(months)}';
    }
    final fallbackMonths = ((daysLeft / 30).ceil()).clamp(0, 999).toInt();
    final normalized = fallbackMonths <= 0 ? 0 : fallbackMonths;
    return '$normalized ${monthUnit(normalized)}';
  }
}
