import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class CashInHandReportPage extends StatefulWidget {
  const CashInHandReportPage({super.key});

  @override
  State<CashInHandReportPage> createState() => _CashInHandReportPageState();
}

class _CashInHandReportPageState extends State<CashInHandReportPage> {
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
      appBar: AppBar(title: const Text('Cash In Hand Report')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _repo.getCashInHandReport(date: _date),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load cash in hand: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          final totalExpected = rows.fold<double>(
              0,
              (s, r) =>
                  s + ((r['expected_cash_in_hand'] as num?)?.toDouble() ?? 0));
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.all(12.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date: ${_date.toString().substring(0, 10)}',
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
                    ? const Center(child: Text('No cashier sessions found'))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final r = rows[index];
                          final opening =
                              (r['opening_amount'] as num?)?.toDouble() ?? 0;
                          final cashSales =
                              (r['total_cash_sales'] as num?)?.toDouble() ?? 0;
                          final cashRefunds =
                              (r['total_cash_refunds'] as num?)?.toDouble() ?? 0;
                          final expected =
                              (r['expected_cash_in_hand'] as num?)?.toDouble() ?? 0;
                          return Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 6.h),
                            child: Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['cashier_name']?.toString() ?? 'Unknown',
                                      style: AppTheme.heading3),
                                  SizedBox(height: 6.h),
                                  Text('Opening: ${CurrencyFormatter.format(opening)}'),
                                  Text('Cash Sales: ${CurrencyFormatter.format(cashSales)}'),
                                  Text(
                                      'Cash Refunds: ${CurrencyFormatter.format(cashRefunds)}'),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Expected Cash: ${CurrencyFormatter.format(expected)}',
                                    style: AppTheme.body.copyWith(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: const BoxDecoration(color: Colors.white),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Expected', style: AppTheme.heading3),
                    Text(CurrencyFormatter.format(totalExpected), style: AppTheme.price),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
