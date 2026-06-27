class TaxSlabConfig {
  final double rate;
  final bool isInclusive;
  final bool isEnabled;

  const TaxSlabConfig({
    required this.rate,
    required this.isInclusive,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'rate': rate,
        'is_inclusive': isInclusive,
        'is_enabled': isEnabled,
      };

  factory TaxSlabConfig.fromJson(Map<String, dynamic> json) => TaxSlabConfig(
        rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
        isInclusive: json['is_inclusive'] as bool? ?? true,
        isEnabled: json['is_enabled'] as bool? ?? true,
      );
}

class AdminSetupConfig {
  final String gstNumber;
  final String businessType;
  final List<TaxSlabConfig> taxSlabs;
  final Map<String, bool> paymentMethods;

  const AdminSetupConfig({
    required this.gstNumber,
    required this.businessType,
    required this.taxSlabs,
    required this.paymentMethods,
  });

  static const List<double> allowedTaxRates = [0, 5, 12, 18, 28];
  static const List<String> allowedBusinessTypes = [
    'reselling',
    'manufacturing',
    'service',
  ];
  static const List<String> allowedPaymentMethods = [
    'cash',
    'card',
    'upi',
    'credit',
  ];

  factory AdminSetupConfig.defaults() => AdminSetupConfig(
        gstNumber: '',
        businessType: 'reselling',
        taxSlabs: allowedTaxRates
            .map((e) => TaxSlabConfig(rate: e.toDouble(), isInclusive: true))
            .toList(),
        paymentMethods: {
          'cash': true,
          'card': true,
          'upi': true,
          'credit': true,
        },
      );
}
