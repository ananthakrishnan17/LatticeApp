enum OrganizationStatus { active, inactive }

class Organization {
  const Organization({
    required this.name,
    required this.contactPerson,
    required this.mobileNumber,
    required this.email,
    required this.address,
    required this.gstNumber,
    required this.licenseType,
    required this.status,
  });

  final String name;
  final String contactPerson;
  final String mobileNumber;
  final String email;
  final String address;
  final String gstNumber;
  final String licenseType;
  final OrganizationStatus status;
}
