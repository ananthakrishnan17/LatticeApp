import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/database/database_helper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/report_repository.dart';
import 'customer_purchase_history_page.dart';

class TopCustomersReportPage extends StatefulWidget {
  const TopCustomersReportPage({super.key});

  @override
  State<TopCustomersReportPage> createState() => _TopCustomersReportPageState();
}

class _TopCustomersReportPageState extends State<TopCustomersReportPage> {
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
      appBar: AppBar(title: const Text('Top Customers by Revenue')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _repo.getTopCustomersByRevenue(from: _from, to: _to),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load top customers: ${snapshot.error}'));
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
                    ? const Center(child: Text('No customer sales found'))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final r = rows[index];
                          final id = r['customer_id'];
                          final total = (r['total_spent'] as num?)?.toDouble() ?? 0;
                          final billCount = (r['bill_count'] as num?)?.toInt() ?? 0;
                          return Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 6.h),
                            child: ListTile(
                              title: Text(
                                r['customer_name']?.toString() ?? 'Unknown',
                                style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('$billCount bills'),
                              trailing: Text(
                                CurrencyFormatter.format(total),
                                style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                              ),
                              onTap: id == null
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CustomerPurchaseHistoryPage(
                                            customerId: id,
                                            customerName:
                                                r['customer_name']?.toString() ?? 'Customer',
                                          ),
                                        ),
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
