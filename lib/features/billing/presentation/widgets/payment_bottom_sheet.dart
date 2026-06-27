import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../masters/domain/entities/masters.dart';
import '../../../settings/data/repositories/admin_setup_repository.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../data/repositories/coupon_repository.dart';
import '../../domain/entities/bill.dart';
import '../bloc/billing_bloc.dart';
import 'customer_picker_sheet.dart';

class PaymentBottomSheet extends StatefulWidget {
  final CartState cart;
  const PaymentBottomSheet({super.key, required this.cart});

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _SplitEntry {
  String mode;
  final TextEditingController controller;
  _SplitEntry({required this.mode, String amount = ''})
      : controller = TextEditingController(text: amount);
  double get amount =>
      _PaymentBottomSheetState.parseAmount(controller.text) ?? 0.0;
  void dispose() => controller.dispose();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  static double? parseAmount(String value) {
    var normalized = value.trim().replaceAll(RegExp(r'[^0-9,.]'), '');
    if (normalized.isEmpty) return null;
    if (normalized.contains(',') && normalized.contains('.')) {
      final lastComma = normalized.lastIndexOf(',');
      final lastDot = normalized.lastIndexOf('.');
      if (lastComma > lastDot) {
        normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (normalized.contains(',')) {
      final firstComma = normalized.indexOf(',');
      final lastComma = normalized.lastIndexOf(',');
      if (firstComma != lastComma) {
        normalized = normalized.replaceAll(',', '');
      } else {
        final fractionalLength = normalized.length - firstComma - 1;
        if (fractionalLength <= 2) {
          normalized = normalized.replaceAll(',', '.');
        } else {
          normalized = normalized.replaceAll(',', '');
        }
      }
    }
    return double.tryParse(normalized);
  }

  late String _selectedMode;
  bool _isSplitMode = false;
  List<String> _enabledMethods = ['cash', 'upi', 'card', 'credit'];
  final List<_SplitEntry> _splitEntries = [];
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _amountGivenController = TextEditingController();
  final CouponRepository _couponRepository =
      CouponRepository(DatabaseHelper.instance);

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.cart.paymentMode;
    _discountController.text = widget.cart.discountAmount > 0
        ? widget.cart.discountAmount.toStringAsFixed(2)
        : '';
    _couponController.text = widget.cart.appliedCoupon?.code ?? '';
    _amountGivenController.text = widget.cart.cashTendered != null
        ? widget.cart.cashTendered!.toStringAsFixed(2)
        : '';
    if (widget.cart.splitPayments.isNotEmpty) {
      _isSplitMode = true;
      for (final sp in widget.cart.splitPayments) {
        _splitEntries.add(_SplitEntry(
          mode: sp.mode,
          amount: sp.amount % 1 == 0
              ? sp.amount.toInt().toString()
              : sp.amount.toStringAsFixed(2),
        ));
      }
    }
    _loadEnabledMethods();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureDefaultCashTendered(widget.cart);
    });
  }

  Future<void> _loadEnabledMethods() async {
    final enabled = await AdminSetupRepository.instance.getEnabledPaymentMethods();
    if (!mounted) return;
    setState(() {
      _enabledMethods = enabled;
      if (_enabledMethods.isEmpty) {
        _enabledMethods = ['cash'];
      }
      if (!_enabledMethods.contains(_selectedMode)) {
        _selectedMode = _enabledMethods.first;
      }
      if (_splitEntries.isEmpty) {
        _splitEntries.add(_SplitEntry(mode: _enabledMethods.first));
        if (_enabledMethods.length > 1) {
          _splitEntries.add(_SplitEntry(mode: _enabledMethods[1]));
        }
      }
      for (var i = 0; i < _splitEntries.length; i++) {
        if (!_enabledMethods.contains(_splitEntries[i].mode)) {
          _splitEntries[i].mode = _enabledMethods.first;
        }
      }
    });
  }

  @override
  void dispose() {
    _discountController.dispose();
    _couponController.dispose();
    _amountGivenController.dispose();
    for (final e in _splitEntries) {
      e.dispose();
    }
    super.dispose();
  }

  double get _splitTotal =>
      _splitEntries.fold(0.0, (s, e) => s + e.amount);

  bool _isSplitBalanced(double totalAmount) =>
      (_splitTotal - totalAmount).abs() <= 0.01;

  Future<void> _selectCustomer(CartState cart) async {
    final customer = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerPickerSheet(selectedCustomer: cart.selectedCustomer),
    );
    if (!mounted) return;
    if (customer is Customer) {
      context.read<BillingBloc>().add(SetCustomer(customer));
    } else if (customer == 'walk_in') {
      context.read<BillingBloc>().add(SetCustomer(null));
    }
  }

  Future<void> _applyCoupon(CartState cart) async {
    try {
      final coupon = await _couponRepository.validateCoupon(
        code: _couponController.text,
        amount: (cart.subtotal - cart.discountAmount)
            .clamp(0.0, double.infinity),
      );
      if (!mounted) return;
      context.read<BillingBloc>().add(ApplyCoupon(coupon));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coupon ${coupon.code} applied.'),
          backgroundColor: AppTheme.accent,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      context.read<BillingBloc>().add(ClearCoupon());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  bool _hasEnoughCash(CartState cart) {
    if (_isSplitMode || _selectedMode != PaymentMode.cash.name) return true;
    final tendered = parseAmount(_amountGivenController.text);
    return tendered != null && tendered >= cart.totalAmount;
  }

  void _ensureDefaultCashTendered(CartState cart) {
    if (_isSplitMode || _selectedMode != PaymentMode.cash.name) return;
    final currentText = _amountGivenController.text.trim();
    final parsed = double.tryParse(currentText);
    if (parsed != null && parsed > 0) return;

    final suggested = cart.totalAmount.toStringAsFixed(2);
    _amountGivenController.value = TextEditingValue(
      text: suggested,
      selection: TextSelection.collapsed(offset: suggested.length),
    );
    context.read<BillingBloc>().add(SetCashTendered(cart.totalAmount));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BillingBloc, CartState>(
      listenWhen: (previous, current) {
        final saveCompleted = previous.isSaving == true && current.isSaving == false;
        return saveCompleted &&
            (current.lastSavedBill != null || current.errorMessage != null);
      },
      listener: (context, state) {
        if (state.lastSavedBill != null) {
          Navigator.of(context).pop(state.lastSavedBill);
          return;
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage!.replaceFirst('Exception: ', ''),
              ),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      },
      builder: (context, state) {
        final cart = state as CartState;
        final isSaving = cart.isSaving;
        final selectedCustomerName =
            cart.selectedCustomer?.name ?? cart.customerName ?? 'Walk-in customer';
        final changeAmount = cart.changeAmount;
        final hasCashChange =
            !_isSplitMode && _selectedMode == PaymentMode.cash.name;
        if (hasCashChange &&
            (cart.cashTendered == null || cart.cashTendered! <= 0)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureDefaultCashTendered(cart);
          });
        }

        return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            padding: EdgeInsets.only(
              left: 20.w,
              right: 20.w,
              top: 20.h,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text('Confirm Payment', style: AppTheme.heading2),
                SizedBox(height: 4.h),
                Text(
                  cart.billType == BillType.retail
                      ? '🛒 Retail Bill'
                      : '📦 Wholesale Bill',
                  style:
                      AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                ),
                SizedBox(height: 20.h),
                Text('Customer', style: AppTheme.caption),
                SizedBox(height: 6.h),
                InkWell(
                  onTap: () => _selectCustomer(cart),
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.divider),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            color: AppTheme.primary),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(selectedCustomerName, style: AppTheme.body),
                              Text(
                                cart.selectedCustomer?.phone ??
                                    'Tap to search customers',
                                style: AppTheme.caption,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context
                              .read<BillingBloc>()
                              .add(SetCustomer(null)),
                          child: const Text('Walk-in'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text('Bill Discount', style: AppTheme.caption),
                SizedBox(height: 6.h),
                TextField(
                  controller: _discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final d = double.tryParse(v) ?? 0.0;
                    context.read<BillingBloc>().add(ApplyDiscount(d));
                  },
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 10.h),
                    isDense: true,
                  ),
                ),
                SizedBox(height: 16.h),
                Text('Coupon Code', style: AppTheme.caption),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Enter coupon code',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r)),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 10.h),
                          isDense: true,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ElevatedButton(
                      onPressed: () => _applyCoupon(cart),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(64.w, 40.h),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
                if (cart.appliedCoupon != null) ...[
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Applied ${cart.appliedCoupon!.code} • -${CurrencyFormatter.format(cart.couponDiscountAmount)}',
                          style:
                              AppTheme.caption.copyWith(color: AppTheme.accent),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _couponController.clear();
                          context.read<BillingBloc>().add(ClearCoupon());
                        },
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _isSplitMode = false);
                          context.read<BillingBloc>().add(SetPaymentMode(_selectedMode));
                          _ensureDefaultCashTendered(cart);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            color: !_isSplitMode
                                ? AppTheme.primary
                                : AppTheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10.r),
                              bottomLeft: Radius.circular(10.r),
                            ),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: Center(
                            child: Text(
                              'Single Payment',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: !_isSplitMode
                                    ? Colors.white
                                    : AppTheme.primary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.read<BillingBloc>().add(SetCashTendered(null));
                          context.read<BillingBloc>().add(SetPaymentMode('split'));
                          setState(() => _isSplitMode = true);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            color: _isSplitMode
                                ? AppTheme.primary
                                : AppTheme.surface,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10.r),
                              bottomRight: Radius.circular(10.r),
                            ),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: Center(
                            child: Text(
                              'Split Payment',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: _isSplitMode
                                    ? Colors.white
                                    : AppTheme.primary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (!_isSplitMode) ...[
                  Text('Payment Mode', style: AppTheme.caption),
                  SizedBox(height: 8.h),
                  Row(
                    children: _enabledMethods.map((method) {
                      final mode = PaymentMode.values.firstWhere(
                        (m) => m.name == method,
                        orElse: () => PaymentMode.cash,
                      );
                      final isSelected = _selectedMode == mode.name;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedMode = mode.name);
                            context
                                .read<BillingBloc>()
                                .add(SetPaymentMode(mode.name));
                            if (mode.name != PaymentMode.cash.name) {
                              _amountGivenController.clear();
                            } else {
                              _ensureDefaultCashTendered(cart);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(right: 6.w),
                            padding: EdgeInsets.symmetric(
                                vertical: 10.h, horizontal: 4.w),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withOpacity(0.12)
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.divider,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(mode.icon,
                                    style: TextStyle(fontSize: 18.sp)),
                                SizedBox(height: 3.h),
                                Text(
                                  mode.label,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (hasCashChange) ...[
                    SizedBox(height: 12.h),
                    Text('Amount Given', style: AppTheme.caption),
                    SizedBox(height: 6.h),
                    TextField(
                      controller: _amountGivenController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        final amount = parseAmount(value);
                        context.read<BillingBloc>().add(SetCashTendered(amount));
                      },
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      changeAmount == null
                          ? 'Enter amount received from customer'
                          : changeAmount >= 0
                              ? 'Change: ${CurrencyFormatter.format(changeAmount)}'
                              : 'Pending: ${CurrencyFormatter.format(changeAmount.abs())}',
                      style: AppTheme.caption.copyWith(
                        color: changeAmount != null && changeAmount >= 0
                            ? AppTheme.accent
                            : AppTheme.danger,
                      ),
                    ),
                  ],
                ] else ...[
                  ...List.generate(_splitEntries.length, (i) {
                    final entry = _splitEntries[i];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.divider),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: entry.mode,
                                isDense: true,
                                items: _enabledMethods.map((method) {
                                  final m = PaymentMode.values.firstWhere(
                                    (x) => x.name == method,
                                    orElse: () => PaymentMode.cash,
                                  );
                                  return DropdownMenuItem(
                                    value: m.name,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(m.icon,
                                            style: TextStyle(fontSize: 14.sp)),
                                        SizedBox(width: 4.w),
                                        Text(m.label,
                                            style: TextStyle(
                                                fontSize: 12.sp,
                                                fontFamily: 'Poppins')),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => entry.mode = v);
                                  }
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: entry.controller,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r)),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 10.h),
                                isDense: true,
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          if (_splitEntries.length > 1)
                            GestureDetector(
                              onTap: () {
                                final removedEntry = _splitEntries[i];
                                setState(() {
                                  _splitEntries.removeAt(i);
                                });
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  removedEntry.dispose();
                                });
                              },
                              child: Icon(Icons.delete_outline,
                                  color: AppTheme.danger, size: 22.sp),
                            )
                          else
                            SizedBox(width: 22.sp),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                         _splitEntries.add(_SplitEntry(mode: _enabledMethods.first));
                       });
                     },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Payment Method'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary),
                  ),
                  SizedBox(height: 4.h),
                  Builder(builder: (context) {
                    final remaining =
                        cart.totalAmount - _splitTotal;
                    final isBalanced = remaining.abs() <= 0.01;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isBalanced
                              ? '✅ Balanced'
                              : remaining > 0
                                  ? 'Remaining: ${CurrencyFormatter.format(remaining)}'
                                  : 'Excess: ${CurrencyFormatter.format(-remaining)}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: isBalanced
                                ? AppTheme.accent
                                : AppTheme.danger,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          'Total: ${CurrencyFormatter.format(cart.totalAmount)}',
                          style: AppTheme.caption,
                        ),
                      ],
                    );
                  }),
                ],
                SizedBox(height: 20.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      _summaryRow('Subtotal',
                          CurrencyFormatter.format(cart.subtotal)),
                      if (cart.gstTotal > 0) ...[
                        SizedBox(height: 4.h),
                        _summaryRow(
                            'GST', CurrencyFormatter.format(cart.gstTotal)),
                      ],
                      if (cart.discountAmount > 0) ...[
                        SizedBox(height: 4.h),
                        _summaryRow(
                          'Bill Discount',
                          '-${CurrencyFormatter.format(cart.discountAmount)}',
                          valueColor: AppTheme.accent,
                        ),
                      ],
                      if (cart.couponDiscountAmount > 0) ...[
                        SizedBox(height: 4.h),
                        _summaryRow(
                          'Coupon (${cart.appliedCoupon?.code ?? ''})',
                          '-${CurrencyFormatter.format(cart.couponDiscountAmount)}',
                          valueColor: AppTheme.accent,
                        ),
                      ],
                      if (hasCashChange && cart.cashTendered != null) ...[
                        SizedBox(height: 4.h),
                        _summaryRow('Amount Given',
                            CurrencyFormatter.format(cart.cashTendered!)),
                        if (changeAmount != null) ...[
                          SizedBox(height: 4.h),
                          _summaryRow(
                            changeAmount >= 0 ? 'Change' : 'Pending',
                            CurrencyFormatter.format(changeAmount.abs()),
                            valueColor: changeAmount >= 0
                                ? AppTheme.accent
                                : AppTheme.danger,
                          ),
                        ],
                      ],
                      Divider(height: 14.h, color: AppTheme.divider),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Payable', style: AppTheme.heading3),
                          Text(
                            CurrencyFormatter.format(cart.totalAmount),
                            style: AppTheme.price,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: isSaving ||
                            (_isSplitMode &&
                                !_isSplitBalanced(cart.totalAmount)) ||
                            !_hasEnoughCash(cart)
                        ? null
                        : () {
                            debugPrint(
                                '[PaymentBottomSheet] Confirm Payment pressed');
                            if (_isSplitMode) {
                              context
                                  .read<BillingBloc>()
                                  .add(SetCashTendered(null));
                              final splits = _splitEntries
                                  .map((e) => SplitPayment(
                                      mode: e.mode, amount: e.amount))
                                  .toList();
                              context
                                  .read<BillingBloc>()
                                  .add(SetSplitPayments(splits));
                            } else {
                              context
                                  .read<BillingBloc>()
                                  .add(SetSplitPayments(const []));
                            }
                            final user = context.read<UserBloc>().currentUser;
                            context.read<BillingBloc>().add(
                              SaveBill(
                                billedByUserId: user?.id,
                                billedByUsername: user?.username,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r)),
                    ),
                    child: Text(
                            !_hasEnoughCash(cart)
                                ? 'Enter enough cash'
                                : 'Confirm & Pay ${CurrencyFormatter.format(cart.totalAmount)}',
                            style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins'),
                          ),
                  ),
                ),
                ],
              ),
            ),
          );
      },
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTheme.body.copyWith(color: AppTheme.textSecondary)),
        Text(value,
            style: AppTheme.body.copyWith(color: valueColor)),
      ],
    );
  }
}
