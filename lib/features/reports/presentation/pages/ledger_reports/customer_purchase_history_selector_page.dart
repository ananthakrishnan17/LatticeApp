import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/repositories/report_repository.dart';
import 'customer_purchase_history_page.dart';

class CustomerPurchaseHistorySelectorPage extends StatelessWidget {
  const CustomerPurchaseHistorySelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ReportRepository(DatabaseHelper.instance);
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Purchase History')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getAllCustomerBalances(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load customers: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          return rows.isEmpty
              ? const Center(child: Text('No customers found'))
              : ListView.separated(
                  padding: EdgeInsets.all(12.w),
                  itemBuilder: (context, index) {
                    final r = rows[index];
                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        side: BorderSide(color: AppTheme.divider),
                      ),
                      title: Text(r['name']?.toString() ?? 'Unknown'),
                      subtitle: Text(r['phone']?.toString() ?? '-',
                          style: AppTheme.caption),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerPurchaseHistoryPage(
                            customerId: r['id'],
                            customerName: r['name']?.toString() ?? 'Customer',
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemCount: rows.length,
                );
        },
      ),
    );
  }
}
