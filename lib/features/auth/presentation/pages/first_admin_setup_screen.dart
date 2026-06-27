import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/backend/backend_user_service.dart';
import '../../../../core/network/api_logging_interceptor.dart';
import '../../../../core/sync/JavaAuthService.dart';
import '../../../../core/sync/java_api_config_service.dart';
import '../../../../core/sync/java_api_url.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shell/presentation/pages/main_shell.dart';
import '../../../users/domain/entities/app_user.dart';

class FirstAdminSetupScreen extends StatefulWidget {
  const FirstAdminSetupScreen({super.key});

  @override
  State<FirstAdminSetupScreen> createState() => _FirstAdminSetupScreenState();
}

class _FirstAdminSetupScreenState extends State<FirstAdminSetupScreen> {
  final _usernameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _isSaving = false;
  String? _error;
  String? _tenantCode;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await JavaApiConfigService.instance.loadConfig(
      defaultBaseUrl: JavaAuthService.defaultBaseUrl,
    );
    if (mounted) {
      setState(() => _tenantCode = config.tenantCode.isEmpty ? null : config.tenantCode);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    setState(() => _error = null);
    final username = _usernameCtrl.text.trim();
    final pin = _pinCtrl.text;
    if (username.isEmpty) {
      setState(() => _error = 'Username is required');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    if (pin != _confirmPinCtrl.text) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    final config = await JavaApiConfigService.instance.loadConfig(
      defaultBaseUrl: JavaAuthService.defaultBaseUrl,
    );
    if (config.tenantCode.isEmpty) {
      setState(() => _error = 'Go back to login and fill in Tenant Code first.');
      return;
    }
    if (config.baseUrl.isEmpty) {
      setState(() => _error = 'Backend URL is missing in app configuration. Contact support.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final deviceId = await JavaAuthService.instance.getOrCreateDeviceId();
      final dio = Dio(
        BaseOptions(
          baseUrl: normalizeBaseUrlForDio(config.baseUrl),
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          contentType: 'application/json',
        ),
      );
      attachApiLoggingInterceptor(dio);
      await dio.post<void>(
        'auth/bootstrap',
        data: {
          'tenantCode': config.tenantCode,
          'username': username,
          'password': pin,
          'deviceId': deviceId,
        },
      );
      await JavaApiConfigService.instance.saveConfig(
        baseUrl: config.baseUrl,
        tenantCode: config.tenantCode,
        username: username,
        password: pin,
      );
      await JavaAuthService.instance.login(
        username,
        pin,
        deviceId,
      );
      final verified = await BackendUserService.instance.getCurrentUser();
      if (!mounted) return;
      context.read<UserBloc>().currentUser = verified;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainShell(),
        ),
      );
    } on DioException catch (error) {
      setState(() => _error = error.response?.data is Map
          ? (error.response?.data['message']?.toString() ?? error.message)
          : error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = _tenantCode ?? 'your tenant';
    return Scaffold(
      backgroundColor: const Color(0xFF2D3250),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(height: 48.h),
            Container(
              width: 72.w,
              height: 72.h,
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20.r)),
              child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 38.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              'Create First Admin',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins'),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6.h),
            Text(
              'Bootstrap the first backend user for $tenant.',
              style: TextStyle(fontSize: 13.sp, color: Colors.white60, fontFamily: 'Poppins', height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 36.h),
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Username'),
                SizedBox(height: 6.h),
                _field(_usernameCtrl, 'e.g. Admin', Icons.person_outline),
                SizedBox(height: 14.h),
                _label('PIN (4 digits)'),
                SizedBox(height: 6.h),
                _field(_pinCtrl, '••••', Icons.lock_outline, obscure: true, maxLength: 4),
                SizedBox(height: 14.h),
                _label('Confirm PIN'),
                SizedBox(height: 6.h),
                _field(_confirmPinCtrl, '••••', Icons.lock_outline, obscure: true, maxLength: 4),
                if (_error != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                    ),
                    child: Text(_error!, style: TextStyle(color: AppTheme.danger, fontSize: 12.sp, fontFamily: 'Poppins')),
                  ),
                ],
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: _isSaving ? null : _createAdmin,
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50.h)),
                  child: _isSaving
                      ? SizedBox(width: 20.w, height: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Admin Account'),
                ),
              ]),
            ),
            SizedBox(height: 32.h),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.white70, fontFamily: 'Poppins'),
      );

  Widget _field(TextEditingController controller, String hint, IconData icon, {bool obscure = false, int? maxLength}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLength: maxLength,
      keyboardType: maxLength == 4 ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        prefixIcon: Icon(icon, color: Colors.white54, size: 20.sp),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        hintStyle: TextStyle(color: Colors.white30, fontFamily: 'Poppins', fontSize: 13.sp),
      ),
    );
  }
}
