import 'package:flutter/material.dart';

import '../../features/users/domain/entities/app_user.dart';

class RoleVisibility extends StatelessWidget {
  final List<String> roles;
  final AppUser? user;
  final Widget child;
  final Widget? fallback;

  const RoleVisibility({
    super.key,
    required this.roles,
    required this.user,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final currentRole = (user?.tenantRole ?? '').trim().toLowerCase();
    final canShow = roles.any((role) => role.trim().toLowerCase() == currentRole);
    if (canShow) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
