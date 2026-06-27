import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/usage_analytics.dart';
import '../../shared/widgets/section_header.dart';

class UsageAnalyticsPage extends StatelessWidget {
  const UsageAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM yyyy, hh:mm a');
    final data = [
      UsageAnalytics(
        companyName: 'Vetri Mart',
        licenseType: 'Enterprise',
        licenseStatus: 'Active',
        branchesUsed: 18,
        branchLimit: 50,
        activeUsers: 56,
        userLimit: 200,
        totalBillsGenerated: 72100,
        billsGeneratedThisMonth: 6400,
        databaseSizeUsed: '2.1 GB',
        lastActivityDate: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
      UsageAnalytics(
        companyName: 'Nila Stores',
        licenseType: 'Professional',
        licenseStatus: 'Active',
        branchesUsed: 6,
        branchLimit: 15,
        activeUsers: 21,
        userLimit: 60,
        totalBillsGenerated: 20980,
        billsGeneratedThisMonth: 1801,
        databaseSizeUsed: '860 MB',
        lastActivityDate: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Usage Analytics',
          subtitle: 'Track limits, utilization, billing volume, storage, and activity in real time.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Company Name')),
                  DataColumn(label: Text('License Type')),
                  DataColumn(label: Text('License Status')),
                  DataColumn(label: Text('Branches Used / Limit')),
                  DataColumn(label: Text('Active Users / Limit')),
                  DataColumn(label: Text('Total Bills')),
                  DataColumn(label: Text('Bills This Month')),
                  DataColumn(label: Text('DB Size Used')),
                  DataColumn(label: Text('Last Activity')),
                ],
                rows: [
                  for (final org in data)
                    DataRow(cells: [
                      DataCell(Text(org.companyName)),
                      DataCell(Text(org.licenseType)),
                      DataCell(Text(org.licenseStatus)),
                      DataCell(Text('${org.branchesUsed} / ${org.branchLimit}')),
                      DataCell(Text('${org.activeUsers} / ${org.userLimit}')),
                      DataCell(Text(org.totalBillsGenerated.toString())),
                      DataCell(Text(org.billsGeneratedThisMonth.toString())),
                      DataCell(Text(org.databaseSizeUsed)),
                      DataCell(Text(format.format(org.lastActivityDate))),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
