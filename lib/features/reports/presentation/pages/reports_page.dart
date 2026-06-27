import 'package:flutter/material.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/theme/app_theme.dart';
import 'bill_reports/bill_reports_menu.dart';
import 'financial_reports/financial_reports_menu.dart';
import 'ledger_reports/ledger_dashboard_page.dart';
import 'ledger_reports/ledger_reports_menu.dart';
import 'product_reports/product_reports_menu.dart';
import 'purchase_reports/purchase_report_page.dart';
import 'stock_reports/product_stock_sales_report_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _HubCard(
        emoji: '📒',
        title: 'Ledger Dashboard',
        subtitle: 'Profit, stock & transactions',
        color: AppTheme.primary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerDashboardPage())),
      ),
      _HubCard(
        emoji: '📋',
        title: 'Bill Reports',
        subtitle: '7 Reports',
        color: AppTheme.primary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillReportsMenu())),
      ),
      _HubCard(
        emoji: '📦',
        title: 'Product Reports',
        subtitle: '5 Reports',
        color: AppTheme.accent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductReportsMenu())),
      ),
      _HubCard(
        emoji: '💰',
        title: 'Financial Reports',
        subtitle: '9 Reports',
        color: AppTheme.secondary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialReportsMenu())),
      ),
      _HubCard(
        emoji: '👥',
        title: 'Ledger Reports',
        subtitle: '8 Reports',
        color: AppTheme.warning,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerReportsMenu())),
      ),
      _HubCard(
        emoji: '📥',
        title: 'Purchase Report',
        subtitle: 'Purchase entries',
        color: AppTheme.secondary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseReportPage())),
      ),
      _HubCard(
        emoji: '📊',
        title: 'Stock & Sales',
        subtitle: 'Product reconciliation',
        color: AppTheme.danger,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductStockSalesReportPage())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        automaticallyImplyLeading: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final responsive = ResponsiveHelper.fromConstraints(constraints);
          final columns = responsive.gridCount(mobile: 2, tablet: 3, desktop: 4);
          final spacing = responsive.spacing(14);
          final maxContentWidth = responsive.value<double>(
            mobile: constraints.maxWidth,
            tablet: ResponsiveBreakpoints.maxContentWidthTablet,
            desktop: ResponsiveBreakpoints.maxContentWidthDesktop,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.all(responsive.spacing(16)),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report Categories', style: AppTheme.heading2),
                    SizedBox(height: responsive.spacing(4)),
                    Text('Choose a category to view detailed reports', style: AppTheme.caption),
                    SizedBox(height: responsive.spacing(20)),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: responsive.value(mobile: 1.06, tablet: 1.12, desktop: 1.18),
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) => cards[index],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(responsive.spacing(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(responsive.spacing(16)),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FractionallySizedBox(
              widthFactor: 0.32,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(responsive.spacing(12))),
                  child: Center(child: Text(emoji, style: TextStyle(fontSize: responsive.font(22)))),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: responsive.font(14),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: responsive.spacing(2)),
                Text(subtitle, style: AppTheme.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
