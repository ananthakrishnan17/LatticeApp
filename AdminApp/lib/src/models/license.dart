enum LicenseStatus { active, expired, suspended, trial }

class LicenseModel {
  const LicenseModel({
    required this.licenseKey,
    required this.licenseType,
    required this.startDate,
    required this.expiryDate,
    required this.branchLimit,
    required this.userLimit,
    required this.billingLimit,
    required this.status,
  });

  final String licenseKey;
  final String licenseType;
  final DateTime startDate;
  final DateTime expiryDate;
  final int branchLimit;
  final int userLimit;
  final int billingLimit;
  final LicenseStatus status;
}
