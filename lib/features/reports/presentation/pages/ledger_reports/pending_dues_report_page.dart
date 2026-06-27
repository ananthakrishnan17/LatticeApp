import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import 'customer_credit_statement_page.dart';

class PendingDuesReportPage extends StatelessWidget {
  const PendingDuesReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ReportRepository(DatabaseHelper.instance);
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Dues & Credit Customers')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getPendingDuesCustomers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load pending dues: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          return rows.isEmpty
              ? const Center(child: Text('No pending dues'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final r = rows[index];
                    final due = (r['total_outstanding_amount'] as num?)?.toDouble() ?? 0;
                    return Card(
                      margin:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      child: ListTile(
                        title: Text(
                          r['customer_name']?.toString() ?? 'Unknown',
                          style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Last Txn: ${r['last_transaction_date']?.toString() ?? '-'}',
                          style: AppTheme.caption,
                        ),
                        trailing: Text(
                          CurrencyFormatter.format(due),
                          style: AppTheme.body
                              .copyWith(color: AppTheme.danger, fontWeight: FontWeight.w700),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerCreditStatementPage(
                              customerId: r['id'],
                              customerName:
                                  r['customer_name']?.toString() ?? 'Customer',
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}
