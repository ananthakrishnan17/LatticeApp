import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/admin_setup_repository.dart';
import '../../domain/entities/admin_setup.dart';

class GstBusinessSetupPage extends StatefulWidget {
  const GstBusinessSetupPage({super.key});

  @override
  State<GstBusinessSetupPage> createState() => _GstBusinessSetupPageState();
}

class _GstBusinessSetupPageState extends State<GstBusinessSetupPage> {
  final _gstController = TextEditingController();
  String _businessType = 'reselling';
  List<TaxSlabConfig> _slabs = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await AdminSetupRepository.instance.load();
    if (!mounted) return;
    setState(() {
      _gstController.text = cfg.gstNumber;
      _businessType = cfg.businessType;
      _slabs = List<TaxSlabConfig>.from(cfg.taxSlabs);
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final current = await AdminSetupRepository.instance.load();
    final cfg = AdminSetupConfig(
      gstNumber: _gstController.text.trim(),
      businessType: _businessType,
      taxSlabs: _slabs,
      paymentMethods: current.paymentMethods,
    );
    await AdminSetupRepository.instance.save(cfg);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GST & business setup saved'),
        backgroundColor: AppTheme.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST & Business Setup')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                TextField(
                  controller: _gstController,
                  decoration: const InputDecoration(
                    labelText: 'GST Number',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<String>(
                  value: _businessType,
                  decoration: const InputDecoration(
                    labelText: 'Business Type',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'reselling', child: Text('Reselling')),
                    DropdownMenuItem(
                        value: 'manufacturing', child: Text('Manufacturing')),
                    DropdownMenuItem(
                        value: 'service', child: Text('Service')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _businessType = v);
                  },
                ),
                SizedBox(height: 20.h),
                Text('Tax Slabs', style: AppTheme.heading3),
                SizedBox(height: 8.h),
                ..._slabs.map((slab) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: slab.isEnabled,
                          onChanged: (v) => setState(() {
                            final i = _slabs.indexOf(slab);
                            _slabs[i] = TaxSlabConfig(
                              rate: slab.rate,
                              isInclusive: slab.isInclusive,
                              isEnabled: v == true,
                            );
                          }),
                        ),
                        Expanded(
                          child: Text('${slab.rate.toStringAsFixed(0)}% GST',
                              style: AppTheme.body),
                        ),
                        Text(slab.isInclusive ? 'Inclusive' : 'Exclusive',
                            style: AppTheme.caption),
                        SizedBox(width: 8.w),
                        Switch(
                          value: slab.isInclusive,
                          onChanged: (v) => setState(() {
                            final i = _slabs.indexOf(slab);
                            _slabs[i] = TaxSlabConfig(
                              rate: slab.rate,
                              isInclusive: v,
                              isEnabled: slab.isEnabled,
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: 10.h),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
    );
  }
}
