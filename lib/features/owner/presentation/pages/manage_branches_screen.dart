import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/backend/owner_management_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'add_branch_screen.dart';
import 'branch_detail_screen.dart';

class ManageBranchesScreen extends StatefulWidget {
  const ManageBranchesScreen({super.key});

  @override
  State<ManageBranchesScreen> createState() => _ManageBranchesScreenState();
}

class _ManageBranchesScreenState extends State<ManageBranchesScreen> {
  late Future<List<BranchDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = OwnerManagementService.instance.fetchBranches();
  }

  void _refresh() {
    setState(() {
      _future = OwnerManagementService.instance.fetchBranches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Branches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<BranchDto>(
            context,
            MaterialPageRoute(builder: (_) => const AddBranchScreen()),
          );
          if (result != null) {
            _refresh();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Branch "${result.name}" created!'),
                  backgroundColor: AppTheme.accent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Branch', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<BranchDto>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 40.sp)),
                    SizedBox(height: 12.h),
                    Text(
                      'Could not load branches',
                      style: TextStyle(fontSize: 14.sp, fontFamily: 'Poppins'),
                    ),
                    SizedBox(height: 8.h),
                    TextButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final branches = snapshot.data ?? [];
          if (branches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🏢', style: TextStyle(fontSize: 48.sp)),
                  SizedBox(height: 12.h),
                  Text(
                    'No branches yet',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Tap + to create your first branch',
                    style: TextStyle(fontSize: 13.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: branches.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) => _branchTile(branches[i]),
          );
        },
      ),
    );
  }

  Widget _branchTile(BranchDto branch) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BranchDetailScreen(branchId: branch.id, branchName: branch.name),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: branch.isDefault ? AppTheme.primary.withOpacity(0.4) : AppTheme.divider,
            width: branch.isDefault ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.store_rounded, color: AppTheme.primary, size: 22.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        branch.name,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (branch.isDefault) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Tap to view staff',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20.sp),
          ],
        ),
      ),
    );
  }
}
