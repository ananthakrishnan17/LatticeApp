import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/dashboard_metrics.dart';
import '../../shared/widgets/section_header.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const metrics = DashboardMetrics(
      totalOrganizations: 42,
      totalActiveLicenses: 38,
      totalExpiredLicenses: 4,
      totalUsers: 318,
      totalBranches: 96,
      totalBillsGenerated: 127420,
      monthlyRevenue: 1284200,
      recentOrganizations: ['Vetri Mart', 'Nila Stores', 'Urban Fresh'],
      recentLicenses: ['LIC-2026-0091', 'LIC-2026-0090', 'LIC-2026-0089'],
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'System Overview',
            subtitle: 'Centralized KPIs, growth trends, and latest onboarding activity.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(label: 'Organizations', value: metrics.totalOrganizations.toString()),
              _StatCard(label: 'Active Licenses', value: metrics.totalActiveLicenses.toString()),
              _StatCard(label: 'Expired Licenses', value: metrics.totalExpiredLicenses.toString()),
              _StatCard(label: 'Users', value: metrics.totalUsers.toString()),
              _StatCard(label: 'Branches', value: metrics.totalBranches.toString()),
              _StatCard(label: 'Bills Generated', value: metrics.totalBillsGenerated.toString()),
              _StatCard(label: 'Monthly Revenue', value: '₹${metrics.monthlyRevenue.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        spots: const [
                          FlSpot(1, 42),
                          FlSpot(2, 45),
                          FlSpot(3, 48),
                          FlSpot(4, 54),
                          FlSpot(5, 58),
                          FlSpot(6, 60),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RecentListCard(
                  title: 'Recently Created Organizations',
                  items: metrics.recentOrganizations,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RecentListCard(
                  title: 'Recently Activated Licenses',
                  items: metrics.recentLicenses,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentListCard extends StatelessWidget {
  const _RecentListCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(item),
              ),
          ],
        ),
      ),
    );
  }
}
