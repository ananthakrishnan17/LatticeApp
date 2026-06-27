import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/backend/backend_user_service.dart';
import '../../../../core/backend/owner_management_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../users/domain/entities/app_user.dart';

class RoleAssignmentScreen extends StatefulWidget {
  const RoleAssignmentScreen({super.key});

  @override
  State<RoleAssignmentScreen> createState() => _RoleAssignmentScreenState();
}

class _RoleAssignmentScreenState extends State<RoleAssignmentScreen> {
  late Future<_PageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PageData> _load() async {
    final results = await Future.wait<dynamic>([
      BackendUserService.instance.fetchUsers(),
      OwnerManagementService.instance.fetchBranches(),
      OwnerManagementService.instance.fetchRoles(),
    ]);
    return _PageData(
      users: results[0] as List<AppUser>,
      branches: results[1] as List<BranchDto>,
      roles: results[2] as List<RoleDto>,
    );
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Assignment'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<_PageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 40.sp)),
                  SizedBox(height: 12.h),
                  Text('Failed to load data', style: TextStyle(fontSize: 14.sp, fontFamily: 'Poppins')),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          if (data.users.isEmpty) {
            return Center(
              child: Text('No users found.', style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary)),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: data.users.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) => _userAssignTile(data.users[i], data),
          );
        },
      ),
    );
  }

  Widget _userAssignTile(AppUser user, _PageData data) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User header
          Row(
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
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      'Current: ${user.tenantRole.isNotEmpty ? user.tenantRole : user.role.label}'
                      '${user.branchName.isNotEmpty ? ' · ${user.branchName}' : ''}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAssignSheet(user, data),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Reassign'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignSheet(AppUser user, _PageData data) {
    String? selectedBranchId = user.branchId.isNotEmpty ? user.branchId : null;
    String? selectedRoleCode;

    // Map tenantRole to roleCode
    final tnRole = user.tenantRole.toLowerCase();
    if (tnRole == 'owner' || tnRole == 'admin') {
      selectedRoleCode = 'owner';
    } else if (tnRole == 'branchadmin' || tnRole == 'branch_admin') {
      selectedRoleCode = 'branch_admin';
    } else if (tnRole == 'staff') {
      selectedRoleCode = 'staff';
    }

    String? saveError;
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sCtx, setSt) => Container(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Reassign ${user.username}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 16.h),
              // Branch selector
              Text(
                'Branch',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
              ),
              SizedBox(height: 8.h),
              if (data.branches.isEmpty)
                Text(
                  'No branches available',
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins'),
                )
              else
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: data.branches.map((b) {
                    final sel = selectedBranchId == b.id;
                    return GestureDetector(
                      onTap: () => setSt(() => selectedBranchId = b.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: sel ? AppTheme.primary : AppTheme.divider,
                          ),
                        ),
                        child: Text(
                          b.name,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppTheme.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              SizedBox(height: 16.h),
              // Role selector
              Text(
                'Role',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: data.roles.map((r) {
                  final sel = selectedRoleCode == r.code;
                  return GestureDetector(
                    onTap: () => setSt(() => selectedRoleCode = r.code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.secondary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: sel ? AppTheme.secondary : AppTheme.divider,
                        ),
                      ),
                      child: Text(
                        '${r.emoji} ${r.displayName}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppTheme.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (saveError != null) ...[
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                  ),
                  child: Text(
                    saveError!,
                    style: TextStyle(color: AppTheme.danger, fontSize: 12.sp, fontFamily: 'Poppins'),
                  ),
                ),
              ],
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (selectedBranchId == null || selectedRoleCode == null) {
                            setSt(() => saveError = 'Please select both a branch and a role');
                            return;
                          }
                          setSt(() {
                            saving = true;
                            saveError = null;
                          });
                          final result = await OwnerManagementService.instance.assignUserToBranchRole(
                            username: user.username,
                            branchId: selectedBranchId!,
                            roleCode: selectedRoleCode!,
                          );
                          if (!mounted) return;
                          if (result.success) {
                            Navigator.pop(sCtx);
                            _refresh();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${user.username} reassigned successfully'),
                                  backgroundColor: AppTheme.accent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            setSt(() {
                              saving = false;
                              saveError = result.error ?? 'Failed to assign user';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: saving
                      ? SizedBox(
                          width: 22.w,
                          height: 22.h,
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Assign Role',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageData {
  final List<AppUser> users;
  final List<BranchDto> branches;
  final List<RoleDto> roles;
  const _PageData({required this.users, required this.branches, required this.roles});
}
