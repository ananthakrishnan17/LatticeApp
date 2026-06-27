import 'package:flutter/material.dart';

import '../../shared/widgets/section_header.dart';

class OrganizationMappingPage extends StatelessWidget {
  const OrganizationMappingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Organization Mapping',
          subtitle: 'Single-screen relationship view for license, users, and branches.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: ListView(
              children: const [
                ListTile(
                  leading: Icon(Icons.apartment_rounded),
                  title: Text('Vetri Mart'),
                  subtitle: Text('License: LIC-2026-0091 • Users: 56 • Branches: 18'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.apartment_rounded),
                  title: Text('Nila Stores'),
                  subtitle: Text('License: LIC-2026-0090 • Users: 21 • Branches: 6'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
