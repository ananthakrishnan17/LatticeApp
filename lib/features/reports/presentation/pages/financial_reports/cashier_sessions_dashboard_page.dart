import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class CashierSessionsDashboardPage extends StatefulWidget {
  const CashierSessionsDashboardPage({super.key});

  @override
  State<CashierSessionsDashboardPage> createState() =>
      _CashierSessionsDashboardPageState();
}

class _CashierSessionsDashboardPageState
    extends State<CashierSessionsDashboardPage> {
  final _repo = ReportRepository(DatabaseHelper.instance);
  DateTime _date = DateTime.now();

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: _date,
    );
    if (d == null) return;
    setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cashier Sessions Dashboard')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _repo.getAllCashierSessionsForDate(_date),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load cashier sessions: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.all(12.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Day: ${_date.toString().substring(0, 10)}',
                        style: AppTheme.caption,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Change'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('No sessions found for selected day'))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final r = rows[index];
                          final status = (r['status']?.toString() ?? 'OPEN').toUpperCase();
                          final isOpen = status == 'OPEN';
                          return Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 6.h),
                            child: Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r['cashier_name']?.toString() ?? 'Unknown',
                                          style: AppTheme.heading3,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8.w, vertical: 3.h),
                                        decoration: BoxDecoration(
                                          color: (isOpen
                                                  ? AppTheme.warning
                                                  : AppTheme.accent)
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(999.r),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: isOpen
                                                ? AppTheme.warning
                                                : AppTheme.accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                      'Opening: ${CurrencyFormatter.format((r['opening_amount'] as num?)?.toDouble() ?? 0)}'),
                                  Text(
                                      'Cash Sales: ${CurrencyFormatter.format((r['cash_sales'] as num?)?.toDouble() ?? 0)}'),
                                  Text(
                                      'Cash Refunds: ${CurrencyFormatter.format((r['cash_refunds'] as num?)?.toDouble() ?? 0)}'),
                                  Text(
                                      'Expected Closing: ${CurrencyFormatter.format((r['expected_closing'] as num?)?.toDouble() ?? 0)}'),
                                  Text(
                                      'Actual Closing: ${CurrencyFormatter.format((r['actual_closing'] as num?)?.toDouble() ?? 0)}'),
                                  Text(
                                      'Difference: ${CurrencyFormatter.format((r['difference'] as num?)?.toDouble() ?? 0)}'),
                                ],
                              ),
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
