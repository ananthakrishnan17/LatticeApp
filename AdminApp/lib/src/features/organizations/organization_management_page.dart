import 'package:flutter/material.dart';

import '../../models/organization.dart';
import '../../shared/widgets/section_header.dart';

class OrganizationManagementPage extends StatelessWidget {
  const OrganizationManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    const organizations = [
      Organization(
        name: 'Vetri Mart',
        contactPerson: 'Arun',
        mobileNumber: '9876543210',
        email: 'admin@vetrimart.com',
        address: 'Chennai',
        gstNumber: '33AAAAA1111A1Z1',
        licenseType: 'Enterprise',
        status: OrganizationStatus.active,
      ),
      Organization(
        name: 'Nila Stores',
        contactPerson: 'Keerthi',
        mobileNumber: '9000000001',
        email: 'owner@nilastores.com',
        address: 'Madurai',
        gstNumber: '33BBBBB2222B1Z2',
        licenseType: 'Professional',
        status: OrganizationStatus.inactive,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(
              title: 'Organization Management',
              subtitle: 'Create, update, deactivate, and review organization details.',
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Create Organization'),
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
                  DataColumn(label: Text('Organization Name')),
                  DataColumn(label: Text('Contact Person')),
                  DataColumn(label: Text('Mobile')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('GST Number')),
                  DataColumn(label: Text('License Type')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final org in organizations)
                    DataRow(cells: [
                      DataCell(Text(org.name)),
                      DataCell(Text(org.contactPerson)),
                      DataCell(Text(org.mobileNumber)),
                      DataCell(Text(org.email)),
                      DataCell(Text(org.gstNumber)),
                      DataCell(Text(org.licenseType)),
                      DataCell(Text(org.status.name)),
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
