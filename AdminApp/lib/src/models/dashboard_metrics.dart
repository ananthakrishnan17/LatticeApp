class DashboardMetrics {
  const DashboardMetrics({
    required this.totalOrganizations,
    required this.totalActiveLicenses,
    required this.totalExpiredLicenses,
    required this.totalUsers,
    required this.totalBranches,
    required this.totalBillsGenerated,
    required this.monthlyRevenue,
    required this.recentOrganizations,
    required this.recentLicenses,
  });

  final int totalOrganizations;
  final int totalActiveLicenses;
  final int totalExpiredLicenses;
  final int totalUsers;
  final int totalBranches;
  final int totalBillsGenerated;
  final double monthlyRevenue;
  final List<String> recentOrganizations;
  final List<String> recentLicenses;
}
