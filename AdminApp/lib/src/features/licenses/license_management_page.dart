import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/license.dart';
import '../../shared/widgets/section_header.dart';

class LicenseManagementPage extends StatelessWidget {
  const LicenseManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM yyyy');
    final licenses = [
      LicenseModel(
        licenseKey: 'LIC-2026-0091',
        licenseType: 'Enterprise',
        startDate: DateTime(2026, 1, 1),
        expiryDate: DateTime(2026, 12, 31),
        branchLimit: 50,
        userLimit: 200,
        billingLimit: 500000,
        status: LicenseStatus.active,
      ),
      LicenseModel(
        licenseKey: 'LIC-2025-0045',
        licenseType: 'Trial',
        startDate: DateTime(2025, 10, 1),
        expiryDate: DateTime(2025, 12, 31),
        branchLimit: 3,
        userLimit: 10,
        billingLimit: 3000,
        status: LicenseStatus.expired,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(
              title: 'License Management',
              subtitle: 'Create, renew, upgrade, or suspend licenses by organization.',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: () {}, child: const Text('Create License')),
                OutlinedButton(onPressed: () {}, child: const Text('Renew')),
                OutlinedButton(onPressed: () {}, child: const Text('Upgrade')),
                FilledButton(onPressed: () {}, child: const Text('Suspend')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('License Key')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Start Date')),
                  DataColumn(label: Text('Expiry Date')),
                  DataColumn(label: Text('Branch Limit')),
                  DataColumn(label: Text('User Limit')),
                  DataColumn(label: Text('Billing Limit')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final license in licenses)
                    DataRow(cells: [
                      DataCell(Text(license.licenseKey)),
                      DataCell(Text(license.licenseType)),
                      DataCell(Text(format.format(license.startDate))),
                      DataCell(Text(format.format(license.expiryDate))),
                      DataCell(Text(license.branchLimit.toString())),
                      DataCell(Text(license.userLimit.toString())),
                      DataCell(Text(license.billingLimit.toString())),
                      DataCell(Text(license.status.name)),
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
