class UsageAnalytics {
  const UsageAnalytics({
    required this.companyName,
    required this.licenseType,
    required this.licenseStatus,
    required this.branchesUsed,
    required this.branchLimit,
    required this.activeUsers,
    required this.userLimit,
    required this.totalBillsGenerated,
    required this.billsGeneratedThisMonth,
    required this.databaseSizeUsed,
    required this.lastActivityDate,
  });

  final String companyName;
  final String licenseType;
  final String licenseStatus;
  final int branchesUsed;
  final int branchLimit;
  final int activeUsers;
  final int userLimit;
  final int totalBillsGenerated;
  final int billsGeneratedThisMonth;
  final String databaseSizeUsed;
  final DateTime lastActivityDate;
}
