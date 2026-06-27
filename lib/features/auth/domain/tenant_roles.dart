class TenantRoles {
  static const String owner = 'Owner';
  static const String branchAdmin = 'BranchAdmin';
  static const String staff = 'Staff';

  static const List<String> all = [owner, branchAdmin, staff];

  static String normalize(String? value) {
    final role = (value ?? '').trim().toLowerCase();
    if (role == 'owner') return owner;
    if (role == 'branchadmin' || role == 'branch_admin' || role == 'branch-admin') return branchAdmin;
    if (role == 'staff') return staff;
    return staff;
  }
}
