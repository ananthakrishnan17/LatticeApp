import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class CustomerCreditStatementPage extends StatelessWidget {
  final Object customerId;
  final String customerName;
  const CustomerCreditStatementPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    final repo = ReportRepository(DatabaseHelper.instance);
    return Scaffold(
      appBar: AppBar(title: Text('$customerName Statement')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: repo.getCustomerLedger(customerId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load statement: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final entries = (data['entries'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>();
          final closing = (data['closing_balance'] as num?)?.toDouble() ?? 0;
          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(14.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Closing Balance', style: AppTheme.heading3),
                    Text(
                      CurrencyFormatter.format(closing),
                      style: AppTheme.body.copyWith(
                        color: closing > 0 ? AppTheme.danger : AppTheme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('No credit transactions'))
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          final debit = (e['debit'] as num?)?.toDouble() ?? 0;
                          final credit = (e['credit'] as num?)?.toDouble() ?? 0;
                          final balance = (e['balance'] as num?)?.toDouble() ?? 0;
                          return ListTile(
                            title: Text(e['description']?.toString() ?? '-'),
                            subtitle: Text(e['date']?.toString() ?? '-'),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Dr ${CurrencyFormatter.format(debit)}'),
                                Text('Cr ${CurrencyFormatter.format(credit)}'),
                                Text(
                                  'Bal ${CurrencyFormatter.format(balance)}',
                                  style: AppTheme.caption,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
