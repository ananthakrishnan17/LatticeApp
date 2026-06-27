import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/auth/app_session_guard.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/data_access_mode_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../billing/presentation/pages/billing_screen.dart';
import '../../../cash_session/data/cash_session_repository.dart';
import '../../../cash_session/presentation/widgets/opening_amount_dialog.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../sales/presentation/pages/dashboard_screen.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../subscription/presentation/pages/subscription_lock_screen.dart';
import '../../../users/domain/entities/app_user.dart';


class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final CashSessionRepository _cashSessionRepository;

  @override
  void initState() {
    super.initState();
    _cashSessionRepository = CashSessionRepository(DatabaseHelper.instance);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupChecksSafely());
    });
  }

  Future<void> _runStartupChecksSafely() async {
    try {
      await _runStartupChecks();
    } catch (error, stackTrace) {
      debugPrint('[MainShell] startup gate failed: $error\n$stackTrace');
    }
  }

  Future<void> _runStartupChecks() async {
    final allowed = await _enforceAccessGate();
    if (!allowed) return;
    await _ensureCashierOpeningShift();
  }

  Future<bool> _enforceAccessGate() async {
    final gate = await AppSessionGuard.instance.checkProtectedAccess(
      currentUser: context.read<UserBloc>().currentUser,
      requireActivatedLicense: false,
    );
    if (!mounted) return false;
    if (gate.isAllowed) return true;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    return false;
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const BillingScreen();
      case 2: return const ProductsPage();
      case 3: return const ReportsPage();
      case 4: return const SettingsPage();
      default: return const DashboardScreen();
    }
  }

  // Check if current user can access this tab
  bool _canAccess(int index, AppUser? user) {
    if (user == null || user.isAdmin) return true; // admin always OK
    switch (index) {
      case 0: return user.permissions.canViewDashboard;
      case 1: return user.permissions.canBill;
      case 2: return user.permissions.canManageProducts;
      case 3: return user.permissions.canViewReports;
      case 4: return true; // keep basic settings (PIN/logout) available to all users
      default: return false;
    }
  }

  Future<void> _onTabTapped(int index, AppUser? user) async {
    // Subscription check for billing tab
    if (index == 1) {
      final status = await SubscriptionService.instance.getStatus();
      if (status.isLocked && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionLockScreen(status: status)));
        return;
      }
      if (user != null && !user.isAdmin) {
        final isOffline = (await DataAccessModeService.instance.resolveMode()) ==
            DataAccessMode.offlineSqlite;
        if (isOffline) {
          final active = await _cashSessionRepository.getActiveSession(user.username);
          if (active == null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Open shift is required before billing.'),
              backgroundColor: AppTheme.warning,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ));
            return;
          }
        }
      }
    }
    // Permission check
    if (!_canAccess(index, user)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('You don\'t have permission to access this.'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ));
      return;
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _ensureCashierOpeningShift() async {
    final user = context.read<UserBloc>().currentUser;
    if (user == null || user.isAdmin || !mounted) return;

    // Cash sessions are only supported in offline (SQLite) mode.
    final isOffline = (await DataAccessModeService.instance.resolveMode()) ==
        DataAccessMode.offlineSqlite;
    if (!isOffline) return;

    final session = await _cashSessionRepository.getActiveSession(user.username);
    if (session != null) return;
    if (!mounted) return;

    final opening = await showOpeningAmountDialog(context);
    if (opening == null) return;
    try {
      await _cashSessionRepository.openSession(
        cashierUsername: user.username,
        cashierUserId: user.id,
        openingAmount: opening.amount,
        openingDenominationCounts: opening.denominations,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userBloc = context.read<UserBloc>();
    final currentUser = userBloc.currentUser;

    final navItems = <(IconData, String)>[
      (Icons.dashboard_rounded, 'Dashboard'),
      (Icons.point_of_sale_rounded, 'Billing'),
      (Icons.inventory_2_rounded, 'Products'),
      (Icons.receipt_long_rounded, 'Reports'),
      (Icons.settings_rounded, 'Settings'),
    ];
    final visibleNavIndices = navItems.asMap().keys.where((index) => _canAccess(index, currentUser)).toList();
    if (visibleNavIndices.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                'No modules are enabled for this account.\nContact your account administrator to grant access.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    final activeIndex = visibleNavIndices.contains(_currentIndex)
        ? _currentIndex
        : visibleNavIndices.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = ResponsiveHelper.fromConstraints(constraints);
        final isTabletLayout = !responsive.isMobile;

        return Scaffold(
          body: SafeArea(
            child: isTabletLayout
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: visibleNavIndices.indexOf(activeIndex),
                        onDestinationSelected: (index) => _onTabTapped(visibleNavIndices[index], currentUser),
                        labelType: NavigationRailLabelType.all,
                      backgroundColor: Colors.white,
                        leading: Padding(
                          padding: EdgeInsets.only(top: responsive.spacing(8)),
                          child: Icon(Icons.storefront_rounded, color: AppTheme.primary, size: responsive.font(22)),
                        ),
                        destinations: visibleNavIndices.map((i) {
                          final item = navItems[i];
                          return NavigationRailDestination(
                            icon: Icon(item.$1),
                            selectedIcon: Icon(item.$1, color: AppTheme.primary),
                            label: Text(item.$2),
                          );
                        }).toList(),
                      ),
                      VerticalDivider(width: responsive.spacing(1), color: AppTheme.divider),
                      Expanded(
                        child: IndexedStack(index: activeIndex, children: List.generate(navItems.length, _buildPage)),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: IndexedStack(index: activeIndex, children: List.generate(navItems.length, _buildPage)),
                      ),
                      _buildMobileBottomNav(navItems, visibleNavIndices, currentUser, activeIndex),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildMobileBottomNav(
    List<(IconData, String)> navItems,
    List<int> visibleNavIndices,
    AppUser? currentUser,
    int activeIndex,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60.h,
          child: Row(
            children: visibleNavIndices.map((i) {
              final item = navItems[i];
              final isSelected = activeIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTapped(i, currentUser),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.$1,
                        color: isSelected ? AppTheme.primary : const Color(0xFF9CA3AF),
                        size: 22.sp,
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: isSelected ? AppTheme.primary : const Color(0xFF9CA3AF),
                          fontSize: 10.sp,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
