import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';

class CustomerPurchaseHistoryPage extends StatefulWidget {
  final Object customerId;
  final String customerName;
  const CustomerPurchaseHistoryPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerPurchaseHistoryPage> createState() =>
      _CustomerPurchaseHistoryPageState();
}

class _CustomerPurchaseHistoryPageState extends State<CustomerPurchaseHistoryPage> {
  final _repo = ReportRepository(DatabaseHelper.instance);
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
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
      appBar: AppBar(title: Text('${widget.customerName} Purchase History')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _repo.getCustomerPurchaseHistory(
          customerId: widget.customerId,
          from: _from,
          to: _to,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load purchase history: ${snapshot.error}'));
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
                child: rows.isEmpty
                    ? const Center(child: Text('No bills found'))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final r = rows[index];
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
                                          'Bill #${r['bill_number']}',
                                          style: AppTheme.body.copyWith(
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(
                                            (r['total_amount'] as num?)?.toDouble() ?? 0),
                                        style: AppTheme.body.copyWith(
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text('Date: ${r['created_at']}',
                                      style: AppTheme.caption),
                                  Text(
                                      'Payment: ${(r['payment_mode']?.toString() ?? '').toUpperCase()}',
                                      style: AppTheme.caption),
                                  SizedBox(height: 4.h),
                                  Text(
                                    r['items_summary']?.toString() ?? '-',
                                    style: AppTheme.caption,
                                  ),
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
