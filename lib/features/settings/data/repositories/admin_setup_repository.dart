import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/admin_setup.dart';

class AdminSetupRepository {
  static final AdminSetupRepository instance = AdminSetupRepository._();
  AdminSetupRepository._();

  static const _kShopGstin = 'shop_gstin';
  static const _kBusinessType = 'business_type';
  static const _kTaxSlabs = 'tax_slabs_config';
  static const _kPaymentMethods = 'payment_methods_config';

  Future<AdminSetupConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultConfig = AdminSetupConfig.defaults();

    final businessType = _normalizeBusinessType(
      prefs.getString(_kBusinessType),
    );
    final gst = prefs.getString(_kShopGstin) ?? '';

    List<TaxSlabConfig> slabs = defaultConfig.taxSlabs;
    final slabsRaw = prefs.getString(_kTaxSlabs);
    if (slabsRaw != null && slabsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(slabsRaw) as List<dynamic>;
        slabs = decoded
            .map((e) => TaxSlabConfig.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }

    for (final rate in AdminSetupConfig.allowedTaxRates) {
      if (!slabs.any((s) => s.rate == rate.toDouble())) {
        slabs.add(TaxSlabConfig(rate: rate.toDouble(), isInclusive: true));
      }
    }
    slabs.sort((a, b) => a.rate.compareTo(b.rate));

    Map<String, bool> methods = defaultConfig.paymentMethods;
    final methodsRaw = prefs.getString(_kPaymentMethods);
    if (methodsRaw != null && methodsRaw.isNotEmpty) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(methodsRaw));
        methods = {
          for (final key in AdminSetupConfig.allowedPaymentMethods)
            key: decoded[key] == true,
        };
      } catch (_) {}
    }

    return AdminSetupConfig(
      gstNumber: gst,
      businessType: businessType,
      taxSlabs: slabs,
      paymentMethods: methods,
    );
  }

  Future<void> save(AdminSetupConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kShopGstin, config.gstNumber.trim());
    await prefs.setString(
      _kBusinessType,
      _normalizeBusinessType(config.businessType),
    );
    await prefs.setString(
      _kTaxSlabs,
      jsonEncode(config.taxSlabs.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(_kPaymentMethods, jsonEncode(config.paymentMethods));
  }

  Future<List<TaxSlabConfig>> getEnabledTaxSlabs() async {
    final cfg = await load();
    final enabled = cfg.taxSlabs.where((s) => s.isEnabled).toList();
    enabled.sort((a, b) => a.rate.compareTo(b.rate));
    return enabled;
  }

  Future<List<String>> getEnabledPaymentMethods() async {
    final cfg = await load();
    final enabled = cfg.paymentMethods.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (enabled.isEmpty) return ['cash'];
    return enabled;
  }

  String _normalizeBusinessType(String? businessType) {
    final normalized = (businessType ?? '').trim().toLowerCase();
    if (normalized == 'restaurant') {
      return 'service';
    }
    if (AdminSetupConfig.allowedBusinessTypes.contains(normalized)) {
      return normalized;
    }
    return 'reselling';
  }
}
