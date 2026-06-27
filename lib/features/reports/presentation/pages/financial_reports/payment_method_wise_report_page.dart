import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class PaymentMethodWiseReportPage extends StatefulWidget {
  const PaymentMethodWiseReportPage({super.key});

  @override
  State<PaymentMethodWiseReportPage> createState() =>
      _PaymentMethodWiseReportPageState();
}

class _PaymentMethodWiseReportPageState
    extends State<PaymentMethodWiseReportPage> {
  final _repo = ReportRepository(DatabaseHelper.instance);
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null) return;
    setState(() {
      _from = DateTime(range.start.year, range.start.month, range.start.day);
      _to = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Method Wise Report')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _repo.getPaymentMethodWiseReport(from: _from, to: _to),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load payment report: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          final total = rows.fold<double>(
              0, (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.all(12.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_from.toString().substring(0, 10)} to ${_to.toString().substring(0, 10)}',
                        style: AppTheme.caption,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: const Text('Date Range'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final r = rows[index];
                    final mode = (r['payment_mode']?.toString() ?? '').toUpperCase();
                    final amount = (r['total'] as num?)?.toDouble() ?? 0;
                    return Card(
                      child: ListTile(
                        title: Text(mode),
                        trailing: Text(
                          CurrencyFormatter.format(amount),
                          style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
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
                    Text('Grand Total', style: AppTheme.heading3),
                    Text(
                      CurrencyFormatter.format(total),
                      style: AppTheme.price,
                    ),
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
