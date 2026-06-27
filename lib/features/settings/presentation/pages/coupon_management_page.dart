import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/data/repositories/coupon_repository.dart';
import '../../../billing/domain/entities/bill.dart';

class CouponManagementPage extends StatefulWidget {
  const CouponManagementPage({super.key});

  @override
  State<CouponManagementPage> createState() => _CouponManagementPageState();
}

class _CouponManagementPageState extends State<CouponManagementPage> {
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _maxUsageController = TextEditingController();
  final _repository = CouponRepository(DatabaseHelper.instance);

  CouponType _couponType = CouponType.flat;
  DateTime? _expiryDate;
  bool _isSaving = false;
  late Future<List<Coupon>> _couponsFuture;

  @override
  void initState() {
    super.initState();
    _couponsFuture = _repository.getCoupons();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    _maxUsageController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _couponsFuture = _repository.getCoupons();
    });
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _expiryDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _createCoupon() async {
    final code = _codeController.text.trim().toUpperCase();
    final value = double.tryParse(_valueController.text.trim()) ?? 0;
    final maxUsageRaw = _maxUsageController.text.trim();
    final maxUsage = maxUsageRaw.isEmpty ? null : int.tryParse(maxUsageRaw);

    if (code.isEmpty || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a coupon code and valid discount value.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      await _repository.createCoupon(
        Coupon(
          code: code,
          discountType: _couponType,
          discountValue: value,
          maxUsage: maxUsage,
          expiryDate: _expiryDate,
          createdAt: now,
          updatedAt: now,
        ),
      );
      _codeController.clear();
      _valueController.clear();
      _maxUsageController.clear();
      setState(() => _expiryDate = null);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coupon created successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coupon Management')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreateCard(),
            SizedBox(height: 16.h),
            Text('Saved Coupons', style: AppTheme.heading3),
            SizedBox(height: 8.h),
            FutureBuilder<List<Coupon>>(
              future: _couponsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final coupons = snapshot.data ?? const <Coupon>[];
                if (coupons.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Text('No coupons created yet.', style: AppTheme.caption),
                  );
                }
                return Column(
                  children: coupons
                      .map((coupon) => _couponCard(coupon))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Coupon', style: AppTheme.heading3),
          SizedBox(height: 12.h),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Coupon Code',
              hintText: 'SUMMER10',
            ),
          ),
          SizedBox(height: 12.h),
          DropdownButtonFormField<CouponType>(
            value: _couponType,
            items: CouponType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type == CouponType.flat ? 'Flat amount' : 'Percentage'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _couponType = value);
              }
            },
            decoration: const InputDecoration(labelText: 'Discount Type'),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _couponType == CouponType.flat
                  ? 'Discount Amount'
                  : 'Discount %',
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _maxUsageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Max Usage (optional)',
            ),
          ),
          SizedBox(height: 12.h),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expiry Date'),
            subtitle: Text(
              _expiryDate == null
                  ? 'No expiry'
                  : DateFormat('dd MMM yyyy').format(_expiryDate!),
              style: AppTheme.caption,
            ),
            trailing: TextButton(
              onPressed: _pickExpiryDate,
              child: const Text('Select'),
            ),
          ),
          if (_expiryDate != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expiryDate = null),
                child: const Text('Clear expiry'),
              ),
            ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _createCoupon,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Coupon'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _couponCard(Coupon coupon) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coupon.code, style: AppTheme.heading3),
                SizedBox(height: 4.h),
                Text(
                  coupon.discountType == CouponType.flat
                      ? 'Flat ₹${coupon.discountValue.toStringAsFixed(2)}'
                      : '${coupon.discountValue.toStringAsFixed(0)}% off',
                  style: AppTheme.caption,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Used ${coupon.usedCount}${coupon.maxUsage != null ? ' / ${coupon.maxUsage}' : ''}'
                  '${coupon.expiryDate != null ? ' • Expires ${DateFormat("dd MMM yyyy").format(coupon.expiryDate!)}' : ''}',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: coupon.isActive,
            onChanged: (value) async {
              await _repository.updateCouponStatus(id: coupon.id!, isActive: value);
              await _reload();
            },
          ),
        ],
      ),
    );
  }
}
