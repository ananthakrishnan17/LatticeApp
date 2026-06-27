import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../billing/presentation/pages/all_bills_page.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../users/domain/entities/app_user.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

const String _unnamedProduct = 'Unnamed Product';

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(LoadSalesData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: Colors.white,
          onRefresh: () async => context.read<SalesBloc>().add(LoadSalesData()),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 16.h),
                _buildTodaySummary(),
                SizedBox(height: 16.h),
                _buildTodaySettlement(),
                SizedBox(height: 16.h),
                _buildViewAllBillsButton(),
                SizedBox(height: 16.h),
                _buildMonthlyChart(),
                SizedBox(height: 16.h),
                _buildQuickStats(),
                SizedBox(height: 16.h),
                _buildLowStockAlert(),
                SizedBox(height: 86.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = context.read<UserBloc>().currentUser;
    final orgName = user?.organizationName.isNotEmpty == true ? user!.organizationName : 'Organization';
    final username = user?.username.isNotEmpty == true ? user!.username : 'User';
    final greeting = _getGreeting();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $username 👋',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    orgName,
                    style: AppTheme.heading1,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Text(
                DateFormat('EEE, d MMM').format(DateTime.now()),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        Divider(color: AppTheme.divider, height: 1),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 🌅';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  Widget _buildTodaySummary() {
    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        if (state is SalesError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                state.message,
                style: AppTheme.body.copyWith(color: AppTheme.danger),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (state is! SalesLoaded) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final cards = [
          _summaryCard(
            label: "Today's Sales",
            value: CurrencyFormatter.format(state.todaySales),
            icon: '💰',
            valueColor: AppTheme.primary,
            sub: '${state.todayBillCount} bills',
          ),
          _summaryCard(
            label: "Today's Profit",
            value: CurrencyFormatter.format(state.todayProfit),
            icon: '📈',
            valueColor: AppTheme.success,
            sub: '${state.profitMargin.toStringAsFixed(1)}% margin',
          ),
          _summaryCard(
            label: 'Monthly Sales',
            value: CurrencyFormatter.format(state.monthlySales),
            icon: '📅',
            valueColor: AppTheme.textPrimary,
            valueSize: 22.sp,
            sub: '${state.monthlyBillCount} bills',
          ),
          _summaryCard(
            label: 'Monthly Profit',
            value: CurrencyFormatter.format(state.monthlyProfit),
            icon: '🎯',
            valueColor: AppTheme.warning,
            valueSize: 22.sp,
            sub: 'After expenses',
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Summary", style: AppTheme.heading3),
            SizedBox(height: 12.h),
            LayoutBuilder(
              builder: (context, constraints) {
                final responsive = ResponsiveHelper.fromConstraints(constraints);
                final columns = responsive.gridCount(mobile: 2, tablet: 2, desktop: 4);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: responsive.value(mobile: 1.08, tablet: 1.12, desktop: 1.22),
                  ),
                  itemCount: cards.length,
                  itemBuilder: (_, index) => cards[index],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewAllBillsButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllBillsPage())),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: Center(
                child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 21.sp),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View All Bills',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Browse & manage billing history',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: Colors.white.withOpacity(0.2),
              ),
              child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySettlement() {
    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        if (state is! SalesLoaded) return const SizedBox();

        final modes = ['cash', 'upi', 'card', 'credit', 'other'];
        final labels = {
          'cash': 'Cash',
          'upi': 'UPI',
          'card': 'Card',
          'credit': 'Credit',
          'other': 'Other',
        };
        final icons = {
          'cash': '💵',
          'upi': '📱',
          'card': '💳',
          'credit': '📒',
          'other': '🔁',
        };
        final values = {
          for (final mode in modes) mode: (state.todaySettlementByMode[mode] ?? 0.0),
        };
        final total = values.values.fold<double>(0, (sum, value) => sum + value);

        return _lightCard(
          padding: EdgeInsets.all(18.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Settlement", style: AppTheme.heading3),
              SizedBox(height: 6.h),
              Text(
                CurrencyFormatter.format(total),
                style: TextStyle(
                  fontSize: 30.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 12.h),
              const Divider(),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: modes.map((mode) {
                  final amount = CurrencyFormatter.format(values[mode] ?? 0.0);
                  return _paymentChip(
                    icon: icons[mode]!,
                    label: labels[mode]!,
                    amount: amount,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required String icon,
    required Color valueColor,
    double? valueSize,
    String? sub,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: TextStyle(fontSize: 20.sp)),
                const Spacer(),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: valueSize ?? 22.sp,
                fontWeight: FontWeight.w700,
                color: valueColor,
                fontFamily: 'Poppins',
              ),
            ),
            if (sub != null) ...[
              SizedBox(height: 4.h),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppTheme.textSecondary,
                  fontFamily: 'Poppins',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChart() {
    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        if (state is! SalesLoaded || state.weeklyData.isEmpty) return const SizedBox();

        final weeklySales = state.weeklyData
            .map((item) => (item['sales'] as num?)?.toDouble() ?? 0.0)
            .toList();
        final maxValue = weeklySales.fold<double>(0.0, (previous, next) => max(previous, next));
        final maxY = maxValue <= 0 ? 10.0 : maxValue * 1.3;
        final maxIndex = maxValue > 0 ? weeklySales.indexOf(maxValue) : -1;

        return _lightCard(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Last 7 Days Sales', style: AppTheme.heading3),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6.r),
                      color: AppTheme.primary.withOpacity(0.08),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              SizedBox(
                height: 190.h,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    minY: 0,
                    alignment: BarChartAlignment.spaceAround,
                    barGroups: state.weeklyData.asMap().entries.map((entry) {
                      final value = weeklySales[entry.key];
                      final isHighest = entry.key == maxIndex;
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: value,
                            width: 14.w,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(6.r)),
                            color: isHighest ? AppTheme.primary : AppTheme.primary.withOpacity(0.5),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY,
                              color: AppTheme.surface,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppTheme.divider,
                        strokeWidth: 1,
                        dashArray: [4, 3],
                      ),
                    ),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26.h,
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();
                            if (index < 0 || index >= state.weeklyData.length) return const SizedBox();
                            final salesValue = (state.weeklyData[index]['sales'] ?? 0).toStringAsFixed(0);
                            return Padding(
                              padding: EdgeInsets.only(bottom: 3.h),
                              child: Text(
                                salesValue,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24.h,
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();
                            final date = DateTime.now().subtract(Duration(days: 6 - index));
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            final dayName = days[date.weekday - 1];
                            return Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is! ProductsLoaded) return const SizedBox();
        final total = state.products.length;
        final lowStock = state.lowStockProducts.where((p) => !p.isOutOfStock).length;
        final outOfStock = state.lowStockProducts.where((p) => p.isOutOfStock).length;

        return _lightCard(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text('Inventory Overview', style: AppTheme.heading3),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _inventoryBox(
                      label: 'Total Products',
                      value: '$total',
                      valueColor: AppTheme.textPrimary,
                      borderColor: AppTheme.primary,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _inventoryBox(
                      label: 'Low Stock',
                      value: '$lowStock',
                      valueColor: AppTheme.warning,
                      borderColor: AppTheme.warning,
                      tintColor: const Color(0xFFFFF3CD),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _inventoryBox(
                      label: 'Out of Stock',
                      value: '$outOfStock',
                      valueColor: AppTheme.danger,
                      borderColor: AppTheme.danger,
                      tintColor: const Color(0xFFFFEBEB),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLowStockAlert() {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is! ProductsLoaded || state.lowStockProducts.isEmpty) return const SizedBox();
        final alerts = state.lowStockProducts.take(5).toList();

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFFB26200).withOpacity(0.3)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 16.sp)),
                    SizedBox(width: 8.w),
                    Text('Stock Alerts', style: AppTheme.heading3),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppTheme.warning,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '${alerts.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                ...alerts.asMap().entries.map((entry) {
                  final product = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: entry.key == alerts.length - 1 ? 0 : 10.h),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name.isNotEmpty ? product.name : _unnamedProduct,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'Poppins',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: product.isOutOfStock
                                    ? const Color(0xFFFFEBEB)
                                    : const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: product.isOutOfStock
                                      ? AppTheme.danger.withOpacity(0.4)
                                      : AppTheme.warning.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                product.isOutOfStock
                                    ? 'OUT OF STOCK'
                                    : '${product.stockQuantity} ${product.unit} left',
                                style: TextStyle(
                                  color: product.isOutOfStock ? AppTheme.danger : AppTheme.warning,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (entry.key != alerts.length - 1) ...[
                          SizedBox(height: 10.h),
                          Divider(color: AppTheme.warning.withOpacity(0.2), height: 1),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _paymentChip({
    required String icon,
    required String label,
    required String amount,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: 14.sp)),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            amount,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryBox({
    required String label,
    required String value,
    required Color valueColor,
    required Color borderColor,
    Color? tintColor,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: tintColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _lightCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding ?? EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: child,
    );
  }
}
