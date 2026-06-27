import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/admin_setup_repository.dart';
import '../../domain/entities/admin_setup.dart';

class PaymentMethodsSetupPage extends StatefulWidget {
  const PaymentMethodsSetupPage({super.key});

  @override
  State<PaymentMethodsSetupPage> createState() => _PaymentMethodsSetupPageState();
}

class _PaymentMethodsSetupPageState extends State<PaymentMethodsSetupPage> {
  Map<String, bool> _methods = {
    for (final e in AdminSetupConfig.allowedPaymentMethods) e: true,
  };
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await AdminSetupRepository.instance.load();
    if (!mounted) return;
    setState(() {
      _methods = {...cfg.paymentMethods};
      _loading = false;
    });
  }

  Future<void> _save() async {
    final enabledCount = _methods.values.where((v) => v).length;
    if (enabledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable at least one payment method'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final current = await AdminSetupRepository.instance.load();
    final cfg = AdminSetupConfig(
      gstNumber: current.gstNumber,
      businessType: current.businessType,
      taxSlabs: current.taxSlabs,
      paymentMethods: _methods,
    );
    await AdminSetupRepository.instance.save(cfg);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment methods updated'),
        backgroundColor: AppTheme.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = {
      'cash': 'Cash',
      'card': 'Card',
      'upi': 'UPI',
      'credit': 'Credit',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                ...AdminSetupConfig.allowedPaymentMethods.map((method) {
                  return SwitchListTile(
                    value: _methods[method] == true,
                    title: Text(labels[method] ?? method, style: AppTheme.body),
                    onChanged: (value) =>
                        setState(() => _methods[method] = value),
                  );
                }),
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
    );
  }
}
