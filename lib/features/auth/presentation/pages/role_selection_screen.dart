import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/tenant_roles.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D3250),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WELCOME BACK',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "Who's logging in?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Choose your role to continue',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.sp,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 24.h),
              _roleCard(
                context,
                emoji: '👑',
                role: TenantRoles.owner,
                description: 'Full access — all branches, reports & settings',
                highlighted: true,
              ),
              SizedBox(height: 12.h),
              _roleCard(
                context,
                emoji: '🛡️',
                role: TenantRoles.branchAdmin,
                description: 'Manage one branch — staff, inventory, reports',
              ),
              SizedBox(height: 12.h),
              _roleCard(
                context,
                emoji: '💼',
                role: TenantRoles.staff,
                description: 'Sales, checkout & daily operations only',
              ),
              SizedBox(height: 20.h),
              Center(
                child: Text(
                  'Roles are assigned by your organization owner.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12.sp,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required String emoji,
    required String role,
    required String description,
    bool highlighted = false,
  }) {
    final borderColor = highlighted ? const Color(0xFFFFC857) : Colors.white.withOpacity(0.18);
    final bgColor = highlighted ? const Color(0xFFFFC857).withOpacity(0.10) : Colors.white.withOpacity(0.06);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.h,
              decoration: BoxDecoration(
                color: highlighted ? const Color(0xFFFFC857).withOpacity(0.18) : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: TextStyle(fontSize: 20.sp)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role == TenantRoles.branchAdmin ? 'Branch Admin' : role,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12.sp,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16.sp),
          ],
        ),
      ),
    );
  }
}
