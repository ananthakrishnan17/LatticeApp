import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../shared/widgets/section_header.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final users = [
      AppUser(
        name: 'System Admin',
        organization: 'NammaNanban',
        role: UserRole.superAdmin,
        lastLogin: DateTime.now().subtract(const Duration(minutes: 30)),
        status: UserStatus.active,
      ),
      AppUser(
        name: 'Meena',
        organization: 'Vetri Mart',
        role: UserRole.organizationAdmin,
        lastLogin: DateTime.now().subtract(const Duration(days: 1)),
        status: UserStatus.inactive,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(
              title: 'User Management',
              subtitle: 'Create users, edit profile access, reset passwords, and toggle status.',
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Create User'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text('${user.organization} • ${user.role.name}'),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(formatter.format(user.lastLogin)),
                      Text(user.status.name),
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
