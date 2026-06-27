enum UserRole { superAdmin, organizationAdmin, manager, staff }
enum UserStatus { active, inactive }

class AppUser {
  const AppUser({
    required this.name,
    required this.organization,
    required this.role,
    required this.lastLogin,
    required this.status,
  });

  final String name;
  final String organization;
  final UserRole role;
  final DateTime lastLogin;
  final UserStatus status;
}
