import 'package:flutter/material.dart';

import '../../shared/widgets/section_header.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const reports = [
      'License Expiry Report',
      'Organization Report',
      'User Activity Report',
      'Billing Usage Report',
      'Branch Usage Report',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Reports',
          subtitle: 'Generate and export administrative reports in Excel, PDF, and CSV.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: ListView.separated(
              itemCount: reports.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final report = reports[index];
                return ListTile(
                  title: Text(report),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(onPressed: () {}, child: const Text('Excel')),
                      OutlinedButton(onPressed: () {}, child: const Text('PDF')),
                      OutlinedButton(onPressed: () {}, child: const Text('CSV')),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
