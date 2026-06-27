import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../printer/data/repositories/printer_settings_repository.dart';
import '../../../printer/domain/entities/bill_template.dart';
import '../../../printer/services/bill_template_renderer.dart';
import '../../../printer/services/printer_service.dart';
import '../../data/repositories/billing_repository_impl.dart';
import '../../domain/entities/bill.dart';

class BillViewScreen extends StatefulWidget {
  final Bill bill;
  final bool isAdmin;
  const BillViewScreen({super.key, required this.bill, this.isAdmin = false});

  @override
  State<BillViewScreen> createState() => _BillViewScreenState();
}

class _BillViewScreenState extends State<BillViewScreen> {
  String _shopName = '';
  String _shopPhone = '';
  String? _logoPath;
  bool _logoExists = false;
  late final BillingRepositoryImpl _billingRepo;

  @override
  void initState() {
    super.initState();
    _billingRepo = BillingRepositoryImpl(DatabaseHelper.instance);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final logoPath = prefs.getString('logo_path');
      setState(() {
        _shopName = prefs.getString('shop_name') ?? 'My Shop';
        _shopPhone = prefs.getString('shop_phone') ?? '';
        _logoPath = logoPath;
        _logoExists = logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync();
      });
    }
  }

  Future<void> _onPrint() async {
    final config = await PrinterSettingsRepository.instance.loadConfig();
    final prefs = await SharedPreferences.getInstance();
    final shopAddress = prefs.getString('shop_address') ?? '';
    final shopGstin = prefs.getString('shop_gstin') ?? '';

    if (config.template.isPdf) {
      // ── A4 / WhatsApp PDF ──────────────────────────────────────────────
      final ok = await BillTemplateRenderer.sharePdf(
        bill: widget.bill,
        config: config,
        shopName: _shopName,
        shopAddress: shopAddress,
        shopPhone: _shopPhone,
        shopGstin: shopGstin.isNotEmpty ? shopGstin : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ PDF shared!' : '⚠️ Could not generate PDF'),
        backgroundColor: ok ? AppTheme.accent : AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ));
      return;
    }

    // ── Thermal print ──────────────────────────────────────────────────────
    if (!PrinterService.instance.isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('⚠️ Printer not connected'),
        backgroundColor: AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ));
      return;
    }

    final printed = await PrinterService.instance
        .printBillWithTemplate(widget.bill, config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(printed ? '✅ Printed successfully!' : '⚠️ Print failed — please try again'),
      backgroundColor: printed ? AppTheme.accent : AppTheme.warning,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
    ));
  }

  void _onShare() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                title: const Text('Direct WhatsApp Message'),
                subtitle: const Text('Send receipt text to a mobile number'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showWhatsAppPrompt();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: const Text('Share PDF Invoice'),
                subtitle: const Text('Standard share via WhatsApp, Email, etc.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _onSharePdf();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showWhatsAppPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final askNumber = prefs.getBool('ask_whatsapp_number') ?? true;

    if (!askNumber) {
      final text = _buildWhatsAppText();
      final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e'), backgroundColor: AppTheme.danger));
      }
      return;
    }

    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WhatsApp Number'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Enter 10-digit mobile number',
            prefixText: '+91 ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final number = ctrl.text.trim();
      final text = _buildWhatsAppText();
      final url = Uri.parse('https://wa.me/91$number?text=${Uri.encodeComponent(text)}');
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  String _buildWhatsAppText() {
    final b = widget.bill;
    final sb = StringBuffer();
    sb.writeln('*$_shopName*');
    if (_shopPhone.isNotEmpty) sb.writeln('Ph: $_shopPhone');
    sb.writeln('------------------------');
    sb.writeln('Bill No: #${b.billNumber}');
    sb.writeln('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(b.createdAt)}');
    sb.writeln('------------------------');
    for (var i = 0; i < b.items.length; i++) {
      final item = b.items[i];
      final qty = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);
      sb.writeln('${i+1}. ${item.productName} ($qty ${item.unit}) - Rs ${CurrencyFormatter.format(item.totalPrice)}');
    }
    sb.writeln('------------------------');
    if (b.discountAmount > 0) sb.writeln('Discount: -Rs ${CurrencyFormatter.format(b.discountAmount)}');
    sb.writeln('*Total: Rs ${CurrencyFormatter.format(b.totalAmount)}*');
    sb.writeln('------------------------');
    sb.writeln('Thank you for visiting!');
    return sb.toString();
  }

  Future<void> _onSharePdf() async {
    final config = await PrinterSettingsRepository.instance.loadConfig();
    final prefs = await SharedPreferences.getInstance();
    final shopAddress = prefs.getString('shop_address') ?? '';
    final shopGstin = prefs.getString('shop_gstin') ?? '';

    // Generate PDF and open native share sheet (WhatsApp, Email, etc.)
    final ok = await BillTemplateRenderer.sharePdf(
      bill: widget.bill,
      config: config,
      shopName: _shopName,
      shopAddress: shopAddress,
      shopPhone: _shopPhone,
      shopGstin: shopGstin.isNotEmpty ? shopGstin : null,
    );
    
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('⚠️ Could not generate PDF to share'),
        backgroundColor: AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ));
    }
  }

  Future<void> _onDelete() async {
    final bill = widget.bill;
    if (bill.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: Text('Are you sure you want to delete Bill #${bill.billNumber}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _billingRepo.deleteBill(bill.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bill #${bill.billNumber} deleted'),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt);
    final billTypeLabel = bill.billType == 'wholesale' ? 'Wholesale' : 'Retail';
    final subtotal = bill.items.fold(0.0, (s, i) => s + i.totalPrice);
    final hasTax = bill.gstTotal > 0;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Bill #${bill.billNumber}'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Bill',
              onPressed: _onDelete,
            ),
          IconButton(
            icon: const Text('🖨️', style: TextStyle(fontSize: 22)),
            tooltip: 'Print',
            onPressed: _onPrint,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  _buildReceiptCard(bill, dateStr, billTypeLabel, subtotal, hasTax),
                ],
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Bill bill, String dateStr, String billTypeLabel,
      double subtotal, bool hasTax) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Shop Header ──────────────────────────────────────────────────
          if (_logoExists) ...[
            CircleAvatar(
              backgroundImage: FileImage(File(_logoPath!)),
              radius: 36.r,
            ),
            SizedBox(height: 8.h),
          ],
          Text(
            _shopName,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          if (_shopPhone.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              'Ph: $_shopPhone',
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
          ],

          SizedBox(height: 12.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 12.h),

          // ── Bill Meta ────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _metaItem('Bill No', '#${bill.billNumber}')),
            Expanded(child: _metaItem('Type', billTypeLabel, align: TextAlign.center)),
            Expanded(child: _metaItem('Date', dateStr, align: TextAlign.right)),
          ]),

          if (bill.customerName != null && bill.customerName!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  style: AppTheme.body,
                  children: [
                    TextSpan(text: 'Customer: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.sp)),
                    TextSpan(
                      text: bill.customerName!,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],

          SizedBox(height: 12.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 8.h),

          // ── Items Table Header ───────────────────────────────────────────
          _tableHeader(),
          Divider(color: AppTheme.divider, height: 8),

          // ── Items ────────────────────────────────────────────────────────
          ...bill.items.map((item) => _itemRow(item)),

          SizedBox(height: 8.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 8.h),

          // ── Totals ───────────────────────────────────────────────────────
           _totalRow('Subtotal', subtotal),
           if (bill.discountAmount > 0) ...[
             SizedBox(height: 4.h),
             _totalRow('Discount', -bill.discountAmount, isNegative: true),
           ],
           if (bill.couponDiscountAmount > 0) ...[
             SizedBox(height: 4.h),
             _totalRow(
               bill.couponCode == null || bill.couponCode!.isEmpty
                   ? 'Coupon'
                   : 'Coupon (${bill.couponCode!})',
               -bill.couponDiscountAmount,
               isNegative: true,
             ),
           ],
           if (hasTax) ...[
            SizedBox(height: 4.h),
            _totalRow('Tax (GST)', bill.gstTotal),
          ],
          SizedBox(height: 8.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 6.h),
          _totalRow('Total', bill.totalAmount, isBold: true, isLarge: true),

          SizedBox(height: 12.h),
          Divider(color: AppTheme.divider, height: 1),
          SizedBox(height: 8.h),

          // ── Payment ──────────────────────────────────────────────────────
          _buildPaymentInfo(bill),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(Bill bill) {
    final hasSplit = bill.splitPaymentSummary != null && bill.splitPaymentSummary!.isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment', style: AppTheme.caption),
          SizedBox(height: 4.h),
          if (hasSplit)
            Text(
              bill.splitPaymentSummary!,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            )
          else
            Text(
              bill.paymentMode.toUpperCase(),
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
          if (bill.cashTendered != null) ...[
            SizedBox(height: 4.h),
            Text(
              'Amount Given: ${CurrencyFormatter.format(bill.cashTendered!)}',
              style: AppTheme.caption,
            ),
          ],
          if (bill.changeAmount != null) ...[
            SizedBox(height: 2.h),
            Text(
              'Change: ${CurrencyFormatter.format(bill.changeAmount!.abs())}',
              style: AppTheme.caption.copyWith(
                color: bill.changeAmount! >= 0
                    ? AppTheme.accent
                    : AppTheme.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaItem(String label, String value, {TextAlign align = TextAlign.left}) {
    return Column(
      crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end
          : align == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        SizedBox(height: 2.h),
        Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: 'Poppins'), textAlign: align),
      ],
    );
  }

  Widget _tableHeader() {
    return Row(
      children: [
        Expanded(flex: 4, child: Text('Item', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
        SizedBox(
          width: 50.w,
          child: Text('Qty', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.center),
        ),
        SizedBox(
          width: 60.w,
          child: Text('Price', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 64.w,
          child: Text('Total', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _itemRow(BillItem item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppTheme.textPrimary, fontFamily: 'Poppins')),
                if (item.productSku != null && item.productSku!.isNotEmpty)
                  Text('SKU: ${item.productSku}', style: AppTheme.caption),
                Text(item.unit, style: AppTheme.caption),
                if (item.discountAmount > 0)
                  Text(
                    item.itemDiscountType == 'percent'
                        ? '${item.itemDiscountValue.toStringAsFixed(item.itemDiscountValue % 1 == 0 ? 0 : 1)}% off • -${CurrencyFormatter.format(item.discountAmount)}'
                        : 'Discount • -${CurrencyFormatter.format(item.discountAmount)}',
                    style: AppTheme.caption.copyWith(color: AppTheme.accent),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 50.w,
            child: Text(
              item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(2),
              style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 60.w,
            child: Text(
              CurrencyFormatter.format(item.unitPrice),
              style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 64.w,
            child: Text(
              CurrencyFormatter.format(item.totalPrice),
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {bool isBold = false, bool isLarge = false, bool isNegative = false}) {
    final style = TextStyle(
      fontSize: isLarge ? 15.sp : 13.sp,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
      color: isNegative ? AppTheme.danger : (isBold ? AppTheme.primary : AppTheme.textPrimary),
      fontFamily: 'Poppins',
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          isNegative ? '- ${CurrencyFormatter.format(amount.abs())}' : CurrencyFormatter.format(amount),
          style: style,
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _onPrint,
              icon: const Text('🖨️'),
              label: const Text('Print', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                side: BorderSide(color: AppTheme.primary),
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _onShare,
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                side: BorderSide(color: AppTheme.accent),
                foregroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Text('✅'),
              label: const Text('New Bill', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
