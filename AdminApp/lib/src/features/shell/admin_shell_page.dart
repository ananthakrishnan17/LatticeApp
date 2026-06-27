import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/admin_app.dart';
import '../analytics/usage_analytics_page.dart';
import '../dashboard/dashboard_page.dart';
import '../licenses/license_management_page.dart';
import '../mappings/organization_mapping_page.dart';
import '../organizations/organization_management_page.dart';
import '../reports/reports_page.dart';
import '../users/user_management_page.dart';

final selectedNavIndexProvider = StateProvider<int>((_) => 0);

class AdminShellPage extends ConsumerWidget {
  const AdminShellPage({super.key});

  static final List<_NavItem> _items = [
    _NavItem('Dashboard', Icons.dashboard_rounded, const DashboardPage()),
    _NavItem('Organizations', Icons.apartment_rounded, const OrganizationManagementPage()),
    _NavItem('Users', Icons.group_rounded, const UserManagementPage()),
    _NavItem('Licenses', Icons.verified_rounded, const LicenseManagementPage()),
    _NavItem('Mappings', Icons.hub_rounded, const OrganizationMappingPage()),
    _NavItem('Analytics', Icons.bar_chart_rounded, const UsageAnalyticsPage()),
    _NavItem('Reports', Icons.description_rounded, const ReportsPage()),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final screen = _items[selectedIndex].screen;
    final isCompact = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(_items[selectedIndex].label),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6_rounded),
            onPressed: () {
              final current = ref.read(themeModeProvider);
              final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              ref.read(themeModeProvider.notifier).state = next;
            },
          ),
        ],
      ),
      drawer: isCompact
          ? Drawer(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    selected: selectedIndex == index,
                    onTap: () {
                      ref.read(selectedNavIndexProvider.notifier).state = index;
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isCompact)
            NavigationRail(
              selectedIndex: selectedIndex,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) => ref.read(selectedNavIndexProvider.notifier).state = index,
              destinations: [
                for (final item in _items)
                  NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label)),
              ],
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: screen,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.screen);

  final String label;
  final IconData icon;
  final Widget screen;
}
