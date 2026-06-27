import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/auth/app_session_guard.dart';
import '../../../../core/backend/backend_api_service.dart';
import '../../../../core/backend/backend_user_service.dart';
import '../../../../core/sync/JavaAuthService.dart';
import '../../../../core/sync/java_api_config_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/plan_time_helper.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../auth/domain/tenant_roles.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../../users/domain/entities/users_page.dart';
import 'add_branch_screen.dart';
import 'branch_detail_screen.dart';
import 'manage_branches_screen.dart';
import 'role_assignment_screen.dart';
import 'master_catalog_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  late Future<_OwnerDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchDashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_enforceAccessGateSafely());
    });
  }

  Future<void> _enforceAccessGateSafely() async {
    try {
      await _enforceAccessGate();
    } catch (error, stackTrace) {
      debugPrint(
        '[OwnerDashboard] access gate failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> _enforceAccessGate() async {
    final gate = await AppSessionGuard.instance.checkProtectedAccess(
      currentUser: context.read<UserBloc>().currentUser,
      requireActivatedLicense: false,
    );
    if (!mounted || gate.isAllowed) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<_OwnerDashboardData> _fetchDashboard() async {
    final ownerConfigFuture = JavaApiConfigService.instance.loadConfig(role: TenantRoles.owner);
    final branchAdminConfigFuture = JavaApiConfigService.instance.loadConfig(role: TenantRoles.branchAdmin);
    final staffConfigFuture = JavaApiConfigService.instance.loadConfig(role: TenantRoles.staff);

    try {
      final dataFuture = BackendApiService.instance.withAuthRetry<_OwnerDashboardData>((dio, headers) async {
        final response = await dio.get<Map<String, dynamic>>(
          'owner/dashboard',
          options: Options(headers: headers),
        );
        return _OwnerDashboardData.fromMap(response.data ?? const <String, dynamic>{});
      });
      final usersFuture = BackendUserService.instance.fetchUsers();
      final result = await Future.wait<dynamic>([
        dataFuture,
        usersFuture,
        ownerConfigFuture,
        branchAdminConfigFuture,
        staffConfigFuture,
      ]);
      return (result[0] as _OwnerDashboardData).withDerived(
        users: result[1] as List<AppUser>,
        credentials: _DashboardCredentials(
          owner: _RoleCredentialData.fromConfig(result[2] as JavaApiConfig),
          branchAdmin: _RoleCredentialData.fromConfig(result[3] as JavaApiConfig),
          staff: _RoleCredentialData.fromConfig(result[4] as JavaApiConfig),
        ),
      );
    } catch (_) {
      final user = context.read<UserBloc>().currentUser;
      final credentials = await Future.wait<JavaApiConfig>([
        ownerConfigFuture,
        branchAdminConfigFuture,
        staffConfigFuture,
      ]);
      return _OwnerDashboardData(
        todayRevenue: 0,
        trendPercent: 0,
        totalProfit: 0,
        transactionCount: 0,
        activeStaffCount: 0,
        hasActiveStaffCount: false,
        branches: [
          _BranchCardData(
            branchId: user?.branchId.isNotEmpty == true ? user!.branchId : 'default-branch',
            branchName: user?.branchName.isNotEmpty == true ? user!.branchName : 'Main Branch',
            transactionCount: 0,
            activeStaffCount: 0,
            revenueAmount: 0,
            targetPercent: 0,
          ),
        ],
        credentials: _DashboardCredentials(
          owner: _RoleCredentialData.fromConfig(credentials[0]),
          branchAdmin: _RoleCredentialData.fromConfig(credentials[1]),
          staff: _RoleCredentialData.fromConfig(credentials[2]),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await JavaAuthService.instance.logout();
    if (!mounted) return;
    context.read<UserBloc>().currentUser = null;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserBloc>().currentUser;
    final orgName = (user?.organizationName.isNotEmpty == true) ? user!.organizationName : 'Organization';
    final initials = orgName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
    final usedBranches = user?.currentBranches ?? 1;
    final maxBranches = user?.maxBranches ?? 1;
    final planName = user?.planName.isNotEmpty == true ? user!.planName : 'Starter';
    final monthsRemaining = remainingPlanMonths(user?.planExpiresAt);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: FutureBuilder<_OwnerDashboardData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(orgName, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                            SizedBox(height: 2.h),
                            Text(
                              'Organization Dashboard · Owner View',
                              style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins'),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 20.r,
                        backgroundColor: AppTheme.primary.withOpacity(0.15),
                        child: Text(initials.isEmpty ? 'OR' : initials, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                      ),
                      IconButton(
                        tooltip: 'Logout',
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primary.withOpacity(0.95),
                          AppTheme.secondary,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_graph_rounded, color: Colors.white70, size: 18.sp),
                            SizedBox(width: 8.w),
                            Text('TODAY\'S REVENUE', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11.sp, letterSpacing: 1.2, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Text('₹${(data?.todayRevenue ?? 0).toStringAsFixed(2)}', style: TextStyle(color: Colors.white, fontSize: 36.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            '${(data?.trendPercent ?? 0) >= 0 ? '▲' : '▼'} ${(data?.trendPercent ?? 0).abs().toStringAsFixed(1)}% vs yesterday',
                            style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Expanded(
                        child: _metricTile(
                          title: 'Transactions',
                          value: '${data?.transactionCount ?? 0}',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _metricTile(
                          title: 'Net Profit',
                          value: '₹${(data?.totalProfit ?? 0).toStringAsFixed(0)}',
                          icon: Icons.trending_up_rounded,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _metricTile(
                          title: 'Active Staff',
                          value: '${data?.activeStaffCount ?? 0}',
                          icon: Icons.groups_2_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterCatalogScreen())),
                    borderRadius: BorderRadius.circular(16.r),
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(Icons.inventory_2_rounded, color: AppTheme.primary, size: 24.sp),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Manage Master Catalog', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                                Text('Add or update global products', style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins')),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  if (data != null) ...[
                    _GlobalAnalyticsSection(data: data),
                    SizedBox(height: 18.h),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Branches ($usedBranches / $maxBranches)',
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          if (usedBranches >= maxBranches) {
                            showModalBottomSheet<void>(
                              context: context,
                              builder: (ctx) => Padding(
                                padding: EdgeInsets.all(16.w),
                                child: Text(
                                  'Plan limit reached. Upgrade your plan to add more branches.',
                                  style: TextStyle(fontSize: 14.sp, fontFamily: 'Poppins'),
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBranchScreen()));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Branch'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  ...(data?.branches ?? const <_BranchCardData>[]).asMap().entries.map((entry) {
                    final colors = [
                      const Color(0xFF4E73DF),
                      const Color(0xFF1CC88A),
                      const Color(0xFFF6C23E),
                      const Color(0xFFE74A3B),
                    ];
                    final color = colors[entry.key % colors.length];
                    final branch = entry.value;
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BranchDetailScreen(branchId: branch.branchId, branchName: branch.branchName)),
                        );
                      },
                      borderRadius: BorderRadius.circular(14.r),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 5.w,
                              height: 80.h,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(branch.branchName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp, fontFamily: 'Poppins')),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${branch.transactionCount} transactions · ${branch.activeStaffCount} staff active',
                                    style: TextStyle(fontSize: 11.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins'),
                                  ),
                                  SizedBox(height: 8.h),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.r),
                                    child: LinearProgressIndicator(
                                      minHeight: 6.h,
                                      value: (branch.targetPercent / 100).clamp(0, 1),
                                      color: color,
                                      backgroundColor: color.withOpacity(0.2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${branch.revenueAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp, fontFamily: 'Poppins')),
                                SizedBox(height: 4.h),
                                Text('${branch.targetPercent.toStringAsFixed(0)}% of target', style: TextStyle(fontSize: 11.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  SizedBox(height: 8.h),
                  Text(
                    'Management',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _managementTile(
                          icon: Icons.store_rounded,
                          label: 'Branches',
                          color: AppTheme.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ManageBranchesScreen()),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _managementTile(
                          icon: Icons.group_rounded,
                          label: 'Users',
                          color: AppTheme.secondary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UsersPage()),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _managementTile(
                          icon: Icons.manage_accounts_rounded,
                          label: 'Roles',
                          color: const Color(0xFF8B5CF6),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RoleAssignmentScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'Role Credentials',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                  ),
                  SizedBox(height: 8.h),
                  _credentialCard('Owner Credentials', data?.credentials.owner),
                  SizedBox(height: 8.h),
                  _credentialCard('Branch Admin Credentials', data?.credentials.branchAdmin),
                  SizedBox(height: 8.h),
                  _credentialCard('Staff Credentials', data?.credentials.staff),
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC857).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.4)),
                    ),
                    child: Text(
                      '$planName · $monthsRemaining ${monthUnit(monthsRemaining)} remaining · $usedBranches/$maxBranches branches used',
                      style: TextStyle(fontSize: 12.sp, color: const Color(0xFF735500), fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _metricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(height: 12.h),
          Text(value, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppTheme.textPrimary)),
          SizedBox(height: 4.h),
          Text(title, style: TextStyle(fontSize: 11.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins')),
        ],
      ),
    );
  }

  Widget _managementTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26.sp),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credentialCard(String title, _RoleCredentialData? data) {
    final safeData = data ?? const _RoleCredentialData();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          SizedBox(height: 6.h),
          Text(
            'Username: ${safeData.username}',
            style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins'),
          ),
          SizedBox(height: 2.h),
          Text(
            'Saved Password / PIN: ${safeData.maskedPassword}',
            style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
}

class _GlobalAnalyticsSection extends StatelessWidget {
  final _OwnerDashboardData data;

  const _GlobalAnalyticsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Global Analytics',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        SizedBox(height: 16.h),
        // Outstanding Balances
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Expanded(
                child: _buildBalanceCard(
                  'Customer Dues',
                  data.outstandingCustomerDues,
                  const Color(0xFFF59E0B),
                  Icons.arrow_downward_rounded,
                  'To Receive',
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildBalanceCard(
                  'Supplier Payables',
                  data.outstandingSupplierPayables,
                  const Color(0xFFEF4444),
                  Icons.arrow_upward_rounded,
                  'To Pay',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        // Branch Comparison Chart
        if (data.branches.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              'Branch Revenue Comparison',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              height: 200.h,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < data.branches.length) {
                            final name = data.branches[value.toInt()].branchName;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                name.length > 6 ? '${name.substring(0, 6)}...' : name,
                                style: TextStyle(fontSize: 10.sp, color: AppTheme.textSecondary),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                            style: TextStyle(fontSize: 10.sp, color: AppTheme.textSecondary),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: data.branches.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.revenueAmount,
                          color: AppTheme.primary,
                          width: 16.w,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
        // Top Products
        if (data.topProducts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              'Top Selling Products (Global)',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          SizedBox(height: 12.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: data.topProducts.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final prod = data.topProducts[index];
              return Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text('${index + 1}', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prod.name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                          Text('${prod.quantity} sold', style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      '₹${prod.revenue.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 24.h),
        ],
      ],
    );
  }

  Widget _buildBalanceCard(String title, double amount, Color color, IconData icon, String subtitle) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14.sp, color: color),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: color, fontFamily: 'Poppins'),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.sp, color: AppTheme.textSecondary, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
}

class _OwnerDashboardData {
  final double todayRevenue;
  final double trendPercent;
  final double totalProfit;
  final int transactionCount;
  final int activeStaffCount;
  final bool hasActiveStaffCount;
  final List<_BranchCardData> branches;
  final _DashboardCredentials credentials;
  final List<_TopProductData> topProducts;
  final double outstandingCustomerDues;
  final double outstandingSupplierPayables;

  const _OwnerDashboardData({
    required this.todayRevenue,
    required this.trendPercent,
    required this.totalProfit,
    required this.transactionCount,
    required this.activeStaffCount,
    required this.hasActiveStaffCount,
    required this.branches,
    required this.credentials,
    this.topProducts = const [],
    this.outstandingCustomerDues = 0.0,
    this.outstandingSupplierPayables = 0.0,
  });

  factory _OwnerDashboardData.fromMap(Map<String, dynamic> map) {
    final branchesRaw = map['branches'];
    final rawCredentialsByRole = map['credentialsByRole'];
    final usersByRole = rawCredentialsByRole is Map
        ? Map<String, dynamic>.from(rawCredentialsByRole)
        : const <String, dynamic>{};
    return _OwnerDashboardData(
      todayRevenue: (map['todayRevenue'] as num?)?.toDouble() ?? 0,
      trendPercent: (map['trendPercent'] as num?)?.toDouble() ?? 0,
      totalProfit: (map['totalProfit'] as num?)?.toDouble() ??
          (map['profit'] as num?)?.toDouble() ??
          (map['netProfit'] as num?)?.toDouble() ??
          0,
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
      activeStaffCount: (map['activeStaffCount'] as num?)?.toInt() ?? 0,
      hasActiveStaffCount: map.containsKey('activeStaffCount'),
      branches: branchesRaw is List
          ? branchesRaw.whereType<Map>().map((e) => _BranchCardData.fromMap(Map<String, dynamic>.from(e))).toList()
          : const [],
      credentials: _DashboardCredentials(
        owner: _RoleCredentialData.fromMap(usersByRole[TenantRoles.owner] as Map?),
        branchAdmin: _RoleCredentialData.fromMap(usersByRole[TenantRoles.branchAdmin] as Map?),
        staff: _RoleCredentialData.fromMap(usersByRole[TenantRoles.staff] as Map?),
      ),
      topProducts: map['topProducts'] is List
          ? (map['topProducts'] as List).whereType<Map>().map((e) => _TopProductData.fromMap(Map<String, dynamic>.from(e))).toList()
          : const [],
      outstandingCustomerDues: (map['outstandingCustomerDues'] as num?)?.toDouble() ?? 0.0,
      outstandingSupplierPayables: (map['outstandingSupplierPayables'] as num?)?.toDouble() ?? 0.0,
    );
  }

  _OwnerDashboardData withDerived({
    required List<AppUser> users,
    required _DashboardCredentials credentials,
  }) {
    bool isStaffUser(AppUser user) {
      final normalizedTenantRole = TenantRoles.normalize(user.tenantRole);
      if (normalizedTenantRole == TenantRoles.owner || normalizedTenantRole == TenantRoles.branchAdmin) {
        return false;
      }
      return user.role != UserRole.admin;
    }

    final computedActiveStaffCount = users
        .where((u) => u.isActive && isStaffUser(u))
        .length;
    return _OwnerDashboardData(
      todayRevenue: todayRevenue,
      trendPercent: trendPercent,
      totalProfit: totalProfit,
      transactionCount: transactionCount,
      activeStaffCount: hasActiveStaffCount ? activeStaffCount : computedActiveStaffCount,
      hasActiveStaffCount: hasActiveStaffCount,
      branches: branches,
      credentials: this.credentials.merge(credentials),
      topProducts: topProducts,
      outstandingCustomerDues: outstandingCustomerDues,
      outstandingSupplierPayables: outstandingSupplierPayables,
    );
  }
}

class _DashboardCredentials {
  final _RoleCredentialData owner;
  final _RoleCredentialData branchAdmin;
  final _RoleCredentialData staff;

  const _DashboardCredentials({
    this.owner = const _RoleCredentialData(),
    this.branchAdmin = const _RoleCredentialData(),
    this.staff = const _RoleCredentialData(),
  });

  _DashboardCredentials merge(_DashboardCredentials fallback) {
    return _DashboardCredentials(
      owner: owner.hasValue ? owner : fallback.owner,
      branchAdmin: branchAdmin.hasValue ? branchAdmin : fallback.branchAdmin,
      staff: staff.hasValue ? staff : fallback.staff,
    );
  }
}

class _RoleCredentialData {
  final String username;
  final String password;

  const _RoleCredentialData({this.username = 'Not set', this.password = ''});

  bool get hasValue => username != 'Not set' && password.isNotEmpty;

  String get maskedPassword {
    if (password.isEmpty) return 'Not set';
    return '••••';
  }

  factory _RoleCredentialData.fromConfig(JavaApiConfig config) {
    return _RoleCredentialData(
      username: config.username.isEmpty ? 'Not set' : config.username,
      password: config.password,
    );
  }

  factory _RoleCredentialData.fromMap(Map? map) {
    if (map == null) return const _RoleCredentialData();
    final username = (map['username'] ?? '').toString().trim();
    return _RoleCredentialData(
      username: username.isEmpty ? 'Not set' : username,
      password: (map['password'] ?? '').toString(),
    );
  }
}

class _BranchCardData {
  final String branchId;
  final String branchName;
  final int transactionCount;
  final int activeStaffCount;
  final double targetPercent;
  final double revenueAmount;

  const _BranchCardData({
    required this.branchId,
    required this.branchName,
    required this.transactionCount,
    required this.activeStaffCount,
    required this.targetPercent,
    required this.revenueAmount,
  });

  factory _BranchCardData.fromMap(Map<String, dynamic> map) {
    return _BranchCardData(
      branchId: (map['branchId'] ?? map['id'] ?? '').toString(),
      branchName: (map['branchName'] ?? map['name'] ?? 'Branch').toString(),
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
      activeStaffCount: (map['activeStaffCount'] as num?)?.toInt() ?? 0,
      targetPercent: (map['targetPercent'] as num?)?.toDouble() ?? 0,
      revenueAmount: (map['revenueAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _TopProductData {
  final String name;
  final int quantity;
  final double revenue;

  const _TopProductData({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  factory _TopProductData.fromMap(Map<String, dynamic> map) {
    return _TopProductData(
      name: (map['name'] ?? map['productName'] ?? 'Unknown').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      revenue: (map['revenue'] ?? map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
