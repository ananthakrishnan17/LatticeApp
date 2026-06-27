import 'dart:convert';

import 'package:dio/dio.dart' show Options;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/backend/backend_api_service.dart';
import '../../../../core/backend/backend_id_mapper.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/ledger/ledger_service.dart';
import '../../../../core/sync/data_access_mode_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/uom_conversion_helper.dart';
import '../../../cash_session/data/cash_session_repository.dart';
import '../../../billing/domain/entities/bill.dart';
import '../../../users/domain/entities/app_user.dart';

// ─── Sale Return Item ──────────────────────────────────────────────────────────
class SaleReturnItem {
  final int productId;
  final String productName;
  final String unit;
  double quantity;
  final double unitPrice;
  final double unitCost;

  // FIX: billing-ல save பண்ண இந்த 2 values இல்லாம stock சரியா restore ஆகாது
  final String saleType;           // 'retail' or 'wholesale'
  final double conversionQty;      // base units per sale unit (e.g. 12 bottles per box)
  final double wholesaleToRetailQty; // wholesale pack size (e.g. 1 box = 24 units)

  SaleReturnItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.unitCost = 0.0,
    this.saleType = 'retail',
    this.conversionQty = 1.0,
    this.wholesaleToRetailQty = 1.0,
  });

  double get totalPrice => quantity * unitPrice;

  // FIX: billing_repository_impl.dart-ல இருக்கற logic-ஐ mirror பண்றோம்
  // Billing-ல எவ்வளோ stock போச்சோ, return-ல அதே அளவு திரும்ப வரணும்
  double get baseQtyToRestore {
    if (saleType == 'wholesale' && wholesaleToRetailQty > 1.0) {
      return quantity * wholesaleToRetailQty;
    }
    return quantity * conversionQty;
  }
}

// ─── Sale Return Entity ────────────────────────────────────────────────────────
class SaleReturn {
  final int? id;
  final String returnNumber;
  final int? originalBillId;
  final String? originalBillNumber;
  final String returnType; // 'return' or 'exchange'
  final String? customerName;
  final List<SaleReturnItem> items;
  final double totalReturnAmount;
  final String refundMode;
  final String? reason;
  final DateTime createdAt;

  const SaleReturn({
    this.id,
    required this.returnNumber,
    this.originalBillId,
    this.originalBillNumber,
    required this.returnType,
    this.customerName,
    required this.items,
    required this.totalReturnAmount,
    this.refundMode = 'cash',
    this.reason,
    required this.createdAt,
  });
}

// ─── Repository ────────────────────────────────────────────────────────────────
class SaleReturnRepository {
  final DatabaseHelper _db;
  static const _uuid = Uuid();
  late final CashSessionRepository _cashSessionRepository;
  SaleReturnRepository(this._db) {
    _cashSessionRepository = CashSessionRepository(_db);
  }

  Future<bool> _isOnlineMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.onlineApi;

  Future<String?> _lookupUuid(String namespace, int? id) async {
    if (id == null || id <= 0) return null;
    return BackendIdMapper.instance.lookupUuid(namespace: namespace, id: id);
  }

  Future<int> _registerUuid(String namespace, String? uuid) async {
    if (uuid == null || uuid.isEmpty) return 0;
    return BackendIdMapper.instance.register(namespace: namespace, uuid: uuid);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  List<Map<String, dynamic>> _decodeMapList(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    }
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  String _generateOnlineReturnNumber(DateTime now) {
    final prefix =
        'RET-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return '$prefix-${now.microsecondsSinceEpoch}';
  }

  // FIX: _counter in-memory-ஆ இருந்தது — app restart ஆனா reset ஆகும்.
  // DB-லேர்ந்தே last counter படிக்கிறோம்
  Future<String> _generateReturnNumber() async {
    final db = await _db.database;
    final now = DateTime.now();
    final datePrefix =
        'RET-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // அந்த நாளுக்கு எத்தனை returns இருக்குன்னு count பண்ணு
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM sale_returns WHERE return_number LIKE ?",
      ['$datePrefix%'],
    );
    final row = result.isNotEmpty ? result.first : const <String, Object?>{};
    final count = (row['cnt'] as int?) ?? 0;
    // +1 பண்ணி next number குடு
    return '$datePrefix-${(count + 1).toString().padLeft(3, '0')}';
  }

  Future<SaleReturn> saveSaleReturn({
    required List<SaleReturnItem> items,
    required String returnType,
    int? originalBillId,
    String? originalBillNumber,
    String? customerName,
    String refundMode = 'cash',
    String? reason,
    String? refundedByUsername,
  }) async {
    if (await _isOnlineMode()) {
      return _saveSaleReturnOnline(
        items: items,
        returnType: returnType,
        originalBillId: originalBillId,
        originalBillNumber: originalBillNumber,
        customerName: customerName,
        refundMode: refundMode,
        reason: reason,
        refundedByUsername: refundedByUsername,
      );
    }
    final db = await _db.database;
    final now = DateTime.now();

    // FIX: DB-based return number (crash-safe)
    final returnNumber = await _generateReturnNumber();
    final total = items.fold(0.0, (s, i) => s + i.totalPrice.abs());
    final returnCost =
        items.fold(0.0, (s, i) => s + (i.quantity * i.unitCost).abs());

    // IMPORTANT: resolve licenseId BEFORE the transaction to prevent sqflite
    // deadlock — resolveLicenseId opens the main DB connection, which conflicts
    // with the exclusive lock held by db.transaction().
    final licenseId = await LedgerService.resolveLicenseId(_db);

    final ret = await db.transaction((txn) async {
      final retId = await txn.insert('sale_returns', {
        'return_number': returnNumber,
        'original_bill_id': originalBillId,
        'original_bill_number': originalBillNumber,
        'return_type': returnType,
        'customer_name': customerName,
        'total_return_amount': total,
        'refund_mode': refundMode,
        'reason': reason,
        'created_at': now.toIso8601String(),
      });

      for (final item in items) {
        await txn.insert('sale_return_items', {
          'return_id': retId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity.abs(),
          'unit': item.unit,
          'unit_price': item.unitPrice.abs(),
          'total_price': item.totalPrice.abs(),
          // FIX: conversion info-ஐயும் save பண்றோம் — audit trail-க்கு useful
          'sale_type': item.saleType,
          'conversion_qty': item.conversionQty,
          'wholesale_to_retail_qty': item.wholesaleToRetailQty,
          'base_qty_restored': item.baseQtyToRestore,
        });

        // Restore stock in the smallest base unit (g for Kg, ml for L).
        // baseQtyToRestore is in user-facing units; multiply by baseFactor
        // so the DB column (which stores in base units since v20) is updated
        // by the same amount that was deducted at sale time.
        final restoreBase = item.baseQtyToRestore.abs() *
            UomConversionHelper.baseFactor(item.unit);
        final productRows = await txn.query(
          'products',
          columns: ['item_type'],
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        final itemType = productRows.isNotEmpty
            ? productRows.first['item_type'] as String? ?? 'physical'
            : 'physical';
        if (itemType != 'service') {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity + ?, updated_at = ? WHERE id = ?',
            [restoreBase, now.toIso8601String(), item.productId],
          );
        }
      }

      // ── Double-entry ledger ─────────────────────────────────────────────
      // Sale-return journal:
      //   DR Income    returnAmount  (revenue reversal)
      //   CR Asset     returnAmount  (refund issued)
      //
      // ATOMICITY: inside the same transaction so a ledger failure rolls back
      // the entire return (return record + items + stock restoration).
      await LedgerService.instance.recordSaleReturn(
        txn: txn,
        returnAmount: total.abs(),
        returnCost: returnCost.abs(),
        licenseId: licenseId,
        tags: {
          'return_number': returnNumber,
          'original_bill_number': originalBillNumber,
          'customer_name': customerName,
          'refund_mode': refundMode,
          'reason': reason,
        },
      );

      return SaleReturn(
        id: retId,
        returnNumber: returnNumber,
        originalBillId: originalBillId,
        originalBillNumber: originalBillNumber,
        returnType: returnType,
        customerName: customerName,
        items: items,
        totalReturnAmount: total,
        refundMode: refundMode,
        reason: reason,
        createdAt: now,
      );
    });

    if (refundMode == 'cash' &&
        refundedByUsername != null &&
        refundedByUsername.trim().isNotEmpty) {
      await _cashSessionRepository.addCashRefund(
        cashierUsername: refundedByUsername.trim(),
        amount: total,
      );
    }
    return ret;
  }

  Future<SaleReturn> _saveSaleReturnOnline({
    required List<SaleReturnItem> items,
    required String returnType,
    int? originalBillId,
    String? originalBillNumber,
    String? customerName,
    String refundMode = 'cash',
    String? reason,
    String? refundedByUsername,
  }) async {
    final now = DateTime.now();
    final nowUtc = now.toUtc().toIso8601String();
    final returnNumber = _generateOnlineReturnNumber(now);
    final total = items.fold(0.0, (sum, item) => sum + item.totalPrice.abs());
    final returnCost =
        items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitCost).abs());
    final saleReturnClientRecordId = _uuid.v4();
    final ledgerClientRecordId = _uuid.v4();

    await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
      dio,
      headers,
    ) async {
      await dio.post<Map<String, dynamic>>(
        'transactions/upsert',
        data: {
          'clientRecordId': ledgerClientRecordId,
          'type': 'sale_return',
          'totalAmount': total,
          'tags': {
            'return_number': returnNumber,
            'original_bill_number': originalBillNumber,
            'customer_name': customerName,
            'refund_mode': refundMode,
            'reason': reason,
            'return_cost': returnCost,
          },
          'createdAt': nowUtc,
          'updatedAt': nowUtc,
        },
        options: Options(headers: headers),
      );
      final response = await dio.post<Map<String, dynamic>>(
        'sale-returns/upsert',
        data: {
          'clientRecordId': saleReturnClientRecordId,
          'returnNumber': returnNumber,
          'originalBillNumber': originalBillNumber,
          'returnType': returnType,
          'customerName': customerName,
          'totalReturnAmount': total,
          'refundMode': refundMode,
          'reason': reason,
          'createdAt': nowUtc,
          'updatedAt': nowUtc,
          'items': await Future.wait(
            items.map((item) async => {
                  'productId': await _lookupUuid('products', item.productId),
                  'productName': item.productName,
                  'quantity': item.quantity.abs(),
                  'unit': item.unit,
                  'unitPrice': item.unitPrice.abs(),
                  'totalPrice': item.totalPrice.abs(),
                }),
          ),
        },
        options: Options(headers: headers),
      );
      return response.data ?? <String, dynamic>{};
    });

    final returnId = await _registerUuid('sale_returns', saleReturnClientRecordId);
    await _registerUuid('transactions', ledgerClientRecordId);

    if (refundMode == 'cash' &&
        refundedByUsername != null &&
        refundedByUsername.trim().isNotEmpty) {
      await _cashSessionRepository.addCashRefund(
        cashierUsername: refundedByUsername.trim(),
        amount: total,
      );
    }

    return SaleReturn(
      id: returnId,
      returnNumber: returnNumber,
      originalBillId: originalBillId,
      originalBillNumber: originalBillNumber,
      returnType: returnType,
      customerName: customerName,
      items: items,
      totalReturnAmount: total,
      refundMode: refundMode,
      reason: reason,
      createdAt: now,
    );
  }

  // Original bill-ல இருந்து item details (conversion info உட்பட) fetch பண்ணு
  // "Fetch from Bill" button-க்கு இதை use பண்ணலாம்
  Future<List<Map<String, dynamic>>> getBillItems(String billNumber) async {
    if (await _isOnlineMode()) {
      final body = await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.get<Map<String, dynamic>>(
          'bills',
          queryParameters: {'billNumber': billNumber, 'limit': 1},
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      final bills =
          ((body['bills'] as List?) ?? const <dynamic>[]).whereType<Map>().toList();
      if (bills.isEmpty) return const <Map<String, dynamic>>[];
      final items = _decodeMapList(Map<String, dynamic>.from(bills.first)['items']);
      return Future.wait(items.map((item) async {
        final productUuid =
            (item['product_id'] ?? item['productId'])?.toString();
        return {
          'product_id': productUuid == null || productUuid.isEmpty
              ? 0
              : await _registerUuid('products', productUuid),
          'product_name': item['product_name'] ?? item['productName'] ?? '',
          'quantity': _toDouble(item['quantity']),
          'unit': item['unit'] ?? 'piece',
          'unit_price': _toDouble(item['unit_price'] ?? item['unitPrice']),
          'purchase_price':
              _toDouble(item['purchase_price'] ?? item['purchasePrice']),
          'sale_type': item['sale_type'] ?? item['saleType'] ?? 'retail',
          'conversion_qty': _toDouble(
            item['conversion_qty'] ?? item['conversionQty'] ?? 1.0,
          ),
          'wholesale_to_retail_qty': _toDouble(
            item['wholesale_to_retail_qty'] ??
                item['wholesaleToRetailQty'] ??
                1.0,
          ),
        };
      }));
    }
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT bi.product_id, bi.product_name, bi.quantity, bi.unit,
             bi.unit_price, COALESCE(bi.purchase_price, 0) as purchase_price, bi.sale_type,
             COALESCE(bi.conversion_qty, 1.0) as conversion_qty,
             COALESCE(p.wholesale_to_retail_qty, 1.0) as wholesale_to_retail_qty
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      LEFT JOIN products p ON p.id = bi.product_id
      WHERE b.bill_number = ?
    ''', [billNumber]);
  }

  Future<List<Map<String, dynamic>>> getRecentReturns({int limit = 30}) async {
    if (await _isOnlineMode()) {
      final body = await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.get<Map<String, dynamic>>(
          'sale-returns',
          queryParameters: {'limit': limit},
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      return ((body['saleReturns'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((raw) {
            final row = Map<String, dynamic>.from(raw);
            return <String, dynamic>{
              'return_number':
                  (row['returnNumber'] ?? row['return_number'] ?? '').toString(),
              'original_bill_number':
                  row['originalBillNumber'] ?? row['original_bill_number'],
              'customer_name': row['customerName'] ?? row['customer_name'],
              'return_type':
                  (row['returnType'] ?? row['return_type'] ?? 'return').toString(),
              'reason': row['reason'],
              'total_return_amount':
                  _toDouble(row['totalReturnAmount'] ?? row['total_return_amount']),
              'created_at':
                  (row['createdAt'] ?? row['created_at'] ?? '').toString(),
            };
          })
          .toList();
    }
    final db = await _db.database;
    return await db.query(
      'sale_returns',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
}

// ─── Sale Return Page ──────────────────────────────────────────────────────────
class SaleReturnPage extends StatefulWidget {
  const SaleReturnPage({super.key});
  @override
  State<SaleReturnPage> createState() => _SaleReturnPageState();
}

class _SaleReturnPageState extends State<SaleReturnPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late final SaleReturnRepository _repo;

  String _returnType = 'return';
  String? _originalBillNumber;
  String? _customerName;
  String _refundMode = 'cash';
  final List<SaleReturnItem> _items = [];
  final _billNumCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isFetchingBill = false;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _repo = SaleReturnRepository(DatabaseHelper.instance);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await _repo.getRecentReturns();
    setState(() => _history = h);
  }

  double get _total => _items.fold(0.0, (s, i) => s + i.totalPrice);

  @override
  void dispose() {
    _tabs.dispose();
    _billNumCtrl.dispose();
    _customerCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Return / Exchange'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'New Return'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildNewReturn(), _buildHistory()],
      ),
    );
  }

  Widget _buildNewReturn() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Return Type
                _label('Return Type'),
                Row(children: [
                  Expanded(child: _typeBtn('return', 'Return', '↩️')),
                  SizedBox(width: 10.w),
                  Expanded(child: _typeBtn('exchange', 'Exchange', '🔄')),
                ]),
                SizedBox(height: 14.h),

                // Bill Number + Fetch button
                _label('Original Bill Number (optional)'),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _billNumCtrl,
                      onChanged: (v) => setState(
                          () => _originalBillNumber = v.isEmpty ? null : v),
                      decoration: const InputDecoration(
                        hintText: 'e.g. 20241201-143022001',
                        prefixIcon: Icon(Icons.receipt),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // FIX: Bill number enter பண்ணா items auto-fetch பண்ண button
                  TextButton(
                    onPressed: _isFetchingBill ? null : _fetchBillItems,
                    child: _isFetchingBill
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Text('Fetch'),
                  ),
                ]),
                SizedBox(height: 10.h),

                _label('Customer Name (optional)'),
                TextField(
                  controller: _customerCtrl,
                  onChanged: (v) =>
                      setState(() => _customerName = v.isEmpty ? null : v),
                  decoration: const InputDecoration(
                    hintText: 'Customer name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 14.h),

                // Items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _label('Items to Return'),
                    TextButton.icon(
                      onPressed: _addReturnItemSheet,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                if (_items.isEmpty)
                  Container(
                    height: 80.h,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Center(
                      child: Text('Add items being returned',
                          style: AppTheme.caption),
                    ),
                  )
                else
                  ..._items.asMap().entries.map((e) => Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.value.productName,
                                    style: AppTheme.heading3),
                                Text(
                                  '${e.value.quantity} ${e.value.unit} × ${CurrencyFormatter.format(e.value.unitPrice)}',
                                  style: AppTheme.caption,
                                ),
                                // FIX: conversion info user-க்கு காட்டு — transparency
                                if (e.value.baseQtyToRestore !=
                                    e.value.quantity)
                                  Text(
                                    'Stock restore: ${e.value.baseQtyToRestore.toStringAsFixed(2)} base units',
                                    style: AppTheme.caption.copyWith(
                                        color: AppTheme.primary,
                                        fontSize: 10.sp),
                                  ),
                                Text(
                                  CurrencyFormatter.format(e.value.totalPrice),
                                  style: AppTheme.price
                                      .copyWith(fontSize: 13.sp),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.danger),
                            onPressed: () =>
                                setState(() => _items.removeAt(e.key)),
                          ),
                        ]),
                      )),
                SizedBox(height: 14.h),

                // Refund Mode
                _label('Refund Mode'),
                Row(
                  children: ['cash', 'upi', 'card'].map((m) {
                    final sel = _refundMode == m;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _refundMode = m),
                        child: Container(
                          margin: EdgeInsets.only(right: 6.w),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.primary.withOpacity(0.1)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                                color:
                                    sel ? AppTheme.primary : AppTheme.divider),
                          ),
                          child: Text(
                            m.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: sel
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 10.h),
                TextField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                ),
                SizedBox(height: 80.h),
              ],
            ),
          ),
        ),
        if (_items.isNotEmpty)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.divider))),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Refund Amount', style: AppTheme.heading3),
                  Text(CurrencyFormatter.format(_total),
                      style: AppTheme.price),
                ],
              ),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveReturn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _returnType == 'exchange'
                      ? AppTheme.warning
                      : AppTheme.danger,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        '${_returnType == 'exchange' ? '🔄 Exchange' : '↩️ Return'} — ${CurrencyFormatter.format(_total)}'),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📋', style: TextStyle(fontSize: 48.sp)),
            SizedBox(height: 12.h),
            Text('No returns yet', style: AppTheme.heading3),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(14.w),
      itemCount: _history.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (_, i) {
        final r = _history[i];
        return Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(r['return_number'] as String,
                        style: AppTheme.heading3)),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: (r['return_type'] == 'exchange'
                            ? AppTheme.warning
                            : AppTheme.danger)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    (r['return_type'] as String).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: r['return_type'] == 'exchange'
                          ? AppTheme.warning
                          : AppTheme.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
              SizedBox(height: 4.h),
              Text(
                DateFormat('dd MMM yyyy, h:mm a').format(
                    DateTime.parse(r['created_at'] as String)),
                style: AppTheme.caption,
              ),
              if (r['customer_name'] != null)
                Text('👤 ${r['customer_name']}', style: AppTheme.caption),
              if (r['original_bill_number'] != null)
                Text('🧾 Bill: ${r['original_bill_number']}',
                    style: AppTheme.caption),
              if (r['reason'] != null)
                Text('Reason: ${r['reason']}', style: AppTheme.caption),
              SizedBox(height: 6.h),
              Text(
                CurrencyFormatter.format(
                    (r['total_return_amount'] as num).toDouble()),
                style: AppTheme.price
                    .copyWith(fontSize: 16.sp, color: AppTheme.danger),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _typeBtn(String type, String label, String emoji) {
    final sel = _returnType == type;
    final color =
        type == 'exchange' ? AppTheme.warning : AppTheme.danger;
    return GestureDetector(
      onTap: () => setState(() => _returnType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
              color: sel ? color : AppTheme.divider,
              width: sel ? 1.5 : 1),
        ),
        child: Column(children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              color: sel ? color : AppTheme.textSecondary,
              fontFamily: 'Poppins',
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Text(t,
            style: AppTheme.heading3.copyWith(color: AppTheme.primary)),
      );

  // FIX: Bill number இருந்தா DB-லேர்ந்தே items fetch பண்ணி auto-fill பண்றோம்
  // இதுனால user manually item add பண்ண வேண்டாம், conversion info-உம் correct-ஆ வரும்
  Future<void> _fetchBillItems() async {
    final billNum = _billNumCtrl.text.trim();
    if (billNum.isEmpty) return;

    setState(() => _isFetchingBill = true);
    try {
      final rows = await _repo.getBillItems(billNum);
      if (!mounted) return;
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill not found')),
        );
        return;
      }
      setState(() {
        _items.clear();
        for (final row in rows) {
          _items.add(SaleReturnItem(
            productId: row['product_id'] as int,
            productName: row['product_name'] as String,
            unit: row['unit'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            unitPrice: (row['unit_price'] as num).toDouble(),
            unitCost: (row['purchase_price'] as num?)?.toDouble() ?? 0.0,
            saleType: row['sale_type'] as String? ?? 'retail',
            conversionQty:
                (row['conversion_qty'] as num?)?.toDouble() ?? 1.0,
            wholesaleToRetailQty:
                (row['wholesale_to_retail_qty'] as num?)?.toDouble() ?? 1.0,
          ));
        }
        _originalBillNumber = billNum;
      });
    } finally {
      if (mounted) {
        setState(() => _isFetchingBill = false);
      }
    }
  }

  void _addReturnItemSheet() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 20.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Return Item', style: AppTheme.heading2),
            SizedBox(height: 16.h),
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Product Name *'),
            ),
            SizedBox(height: 10.h),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Quantity'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Unit Price (₹)'),
                ),
              ),
            ]),
            SizedBox(height: 10.h),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Unit Cost (₹)',
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text);
                final unitPrice = double.tryParse(priceCtrl.text);
                final unitCost = double.tryParse(costCtrl.text);
                if (nameCtrl.text.trim().isEmpty ||
                    qty == null ||
                    unitPrice == null ||
                    unitCost == null ||
                    qty <= 0 ||
                    unitPrice <= 0 ||
                    unitCost <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Enter valid positive quantity, price and cost'),
                  ));
                  return;
                }
                // Manual add: conversion info தெரியாததால் 1.0 default
                // Bill-லேர்ந்து fetch பண்ணா correct values வரும்
                setState(() => _items.add(SaleReturnItem(
                      productId: 0,
                      productName: nameCtrl.text.trim(),
                      unit: 'piece',
                      quantity: qty,
                      unitPrice: unitPrice,
                      unitCost: unitCost,
                    )));
                Navigator.pop(context);
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      qtyCtrl.dispose();
      priceCtrl.dispose();
      costCtrl.dispose();
    });
  }

  Future<void> _saveReturn() async {
    if (_items.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _repo.saveSaleReturn(
        items: _items,
        returnType: _returnType,
        originalBillNumber: _originalBillNumber,
        customerName: _customerName,
        refundMode: _refundMode,
        reason: _reasonCtrl.text.isEmpty ? null : _reasonCtrl.text,
        refundedByUsername: context.read<UserBloc>().currentUser?.username,
      );
      await _loadHistory();
      setState(() {
        _isSaving = false;
        _items.clear();
        _billNumCtrl.clear();
        _customerCtrl.clear();
        _reasonCtrl.clear();
        _originalBillNumber = null;
        _customerName = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${_returnType == 'exchange' ? 'Exchange' : 'Return'} saved! Stock restored correctly.'),
          backgroundColor: AppTheme.accent,
        ));
        _tabs.animateTo(1);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }
}
