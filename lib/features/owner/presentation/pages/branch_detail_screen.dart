import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/backend/backend_user_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../users/domain/entities/app_user.dart';

class BranchDetailScreen extends StatefulWidget {
  final String branchId;
  final String branchName;

  const BranchDetailScreen({super.key, required this.branchId, this.branchName = 'Branch'});

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  late Future<List<AppUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchBranchUsers();
  }

  Future<List<AppUser>> _fetchBranchUsers() async {
    final all = await BackendUserService.instance.fetchUsers();
    return all.where((u) => u.branchId == widget.branchId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.branchName)),
      body: FutureBuilder<List<AppUser>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Text(
                  'Staff (${users.length})',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              if (users.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60.h),
                    child: Column(
                      children: [
                        Text('👥', style: TextStyle(fontSize: 48.sp)),
                        SizedBox(height: 12.h),
                        Text(
                          'No staff in this branch',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.textSecondary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8.h),
                    itemBuilder: (_, i) => _userTile(users[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _userTile(AppUser user) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: user.isAdmin
                ? AppTheme.primary.withOpacity(0.12)
                : AppTheme.secondary.withOpacity(0.1),
            child: Text(
              user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
                color: user.isAdmin ? AppTheme.primary : AppTheme.secondary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  '${user.role.emoji} ${user.tenantRole.isNotEmpty ? user.tenantRole : user.role.label}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: user.isActive
                  ? AppTheme.accent.withOpacity(0.1)
                  : AppTheme.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              user.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11.sp,
                color: user.isActive ? AppTheme.accent : AppTheme.danger,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
