import 'dart:convert';

import 'package:dio/dio.dart' show Options;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;
import 'package:uuid/uuid.dart';

import '../../../../core/backend/backend_api_service.dart';
import '../../../../core/backend/backend_id_mapper.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/ledger/ledger_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/uom_conversion_helper.dart';
import '../../../../core/sync/data_access_mode_service.dart';
import '../../../cash_session/data/cash_session_repository.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/sale_type.dart';

abstract class BillingRepository {
  Future<Bill> saveBill({
    required List<CartItem> items, String billType, double discountAmount,
    String paymentMode, List<SplitPayment>? splitPayments,
    int? customerId, String? customerName,
    String? customerAddress, String? customerGstin,
    int? couponId, String? couponCode, double couponDiscountAmount,
    double? cashTendered, double? changeAmount,
    int? billedByUserId, String? billedByUsername,
  });
  Future<List<Bill>> getBillsByDate(DateTime date);
  Future<Bill> getBillById(int id);
  Future<List<Bill>> getAllBills({DateTime? fromDate, DateTime? toDate});
  Future<Map<String, double>> getDailySummary(DateTime date);
  Future<Map<String, double>> getMonthlySummary(int year, int month);
  Future<void> deleteBill(int id);
}

class BillingRepositoryImpl implements BillingRepository {
  final DatabaseHelper _dbHelper;
  static const _uuid = Uuid();
  late final CashSessionRepository _cashSessionRepository;
  BillingRepositoryImpl(this._dbHelper) {
    _cashSessionRepository = CashSessionRepository(_dbHelper);
  }

  Future<bool> _isOnlineMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.onlineApi;

  Future<String?> _lookupUuid(String namespace, int? id) async {
    if (id == null) return null;
    return BackendIdMapper.instance.lookupUuid(namespace: namespace, id: id);
  }

  Future<int> _registerUuid(String namespace, String? uuid) async {
    if (uuid == null || uuid.isEmpty) return 0;
    return BackendIdMapper.instance.register(namespace: namespace, uuid: uuid);
  }

  double _doubleValue(dynamic value, [double fallback = 0.0]) =>
      value is num ? value.toDouble() : fallback;

  Future<List<BillItem>> _mapOnlineBillItems(List<dynamic>? rawItems, int billId) async {
    if (rawItems == null) return const <BillItem>[];
    final items = <BillItem>[];
    for (final raw in rawItems.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final productUuid = row['product_id']?.toString();
      items.add(
        BillItem(
          billId: billId,
          productId: productUuid == null
              ? 0
              : await _registerUuid('products', productUuid),
          productName: (row['product_name'] ?? row['productName'] ?? '').toString(),
          productSku: row['product_sku']?.toString() ?? row['productSku']?.toString(),
          quantity: _doubleValue(row['quantity']),
          unit: (row['unit'] ?? 'piece').toString(),
          unitPrice: _doubleValue(row['unit_price'] ?? row['unitPrice']),
          purchasePrice: _doubleValue(row['purchase_price'] ?? row['purchasePrice']),
          discountAmount: _doubleValue(
            row['discount_amount'] ?? row['discountAmount'],
          ),
          itemDiscountType:
              (row['item_discount_type'] ?? row['itemDiscountType'] ?? 'none')
                  .toString(),
          itemDiscountValue: _doubleValue(
            row['item_discount_value'] ?? row['itemDiscountValue'],
          ),
          gstRate: _doubleValue(row['gst_rate'] ?? row['gstRate']),
          gstAmount: _doubleValue(row['gst_amount'] ?? row['gstAmount']),
          totalPrice: _doubleValue(row['total_price'] ?? row['totalPrice']),
        ),
      );
    }
    return items;
  }

  Future<Bill> _mapOnlineBill(Map<String, dynamic> row) async {
    final clientRecordId =
        (row['clientRecordId'] ?? row['client_record_id'] ?? row['serverId'])
            ?.toString();
    final billId = await _registerUuid('bills', clientRecordId);
    final createdAt = DateTime.tryParse(
          (row['createdAt'] ?? row['created_at'] ?? '').toString(),
        ) ??
        DateTime.now();
    return Bill(
      id: billId,
      billNumber: (row['billNumber'] ?? row['bill_number'] ?? '').toString(),
      billType: (row['billType'] ?? row['bill_type'] ?? 'retail').toString(),
      items: await _mapOnlineBillItems(
        (row['items'] as List?)?.cast<dynamic>(),
        billId,
      ),
      totalAmount: _doubleValue(row['totalAmount'] ?? row['total_amount']),
      totalProfit: _doubleValue(row['totalProfit'] ?? row['total_profit']),
      discountAmount: _doubleValue(row['discountAmount'] ?? row['discount_amount']),
      gstTotal: _doubleValue(row['gstTotal'] ?? row['gst_total']),
      cgstTotal: _doubleValue(row['cgstTotal'] ?? row['cgst_total']),
      sgstTotal: _doubleValue(row['sgstTotal'] ?? row['sgst_total']),
      igstTotal: _doubleValue(row['igstTotal'] ?? row['igst_total']),
      paymentMode: (row['paymentMode'] ?? row['payment_mode'] ?? 'cash').toString(),
      customerName: row['customerName']?.toString() ?? row['customer_name']?.toString(),
      customerAddress:
          row['customerAddress']?.toString() ?? row['customer_address']?.toString(),
      customerGstin:
          row['customerGstin']?.toString() ?? row['customer_gstin']?.toString(),
      couponCode: row['couponCode']?.toString() ?? row['coupon_code']?.toString(),
      couponDiscountAmount: _doubleValue(
        row['couponDiscountAmount'] ?? row['coupon_discount_amount'],
      ),
      cashTendered: row['cashTendered'] is num || row['cash_tendered'] is num
          ? _doubleValue(row['cashTendered'] ?? row['cash_tendered'])
          : null,
      changeAmount: row['changeAmount'] is num || row['change_amount'] is num
          ? _doubleValue(row['changeAmount'] ?? row['change_amount'])
          : null,
      splitPaymentSummary: row['splitPaymentSummary']?.toString() ??
          row['split_payment_summary']?.toString(),
      createdAt: createdAt,
    );
  }

  Future<List<Bill>> _fetchOnlineBills() async {
    final body = await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
      dio,
      headers,
    ) async {
      final response = await dio.get<Map<String, dynamic>>(
        'bills',
        queryParameters: {'limit': 500},
        options: Options(headers: headers),
      );
      return response.data ?? <String, dynamic>{};
    });
    final bills = <Bill>[];
    for (final raw in ((body['bills'] as List?) ?? const <dynamic>[]).whereType<Map>()) {
      bills.add(await _mapOnlineBill(Map<String, dynamic>.from(raw)));
    }
    return bills;
  }

  String _genOnlineBillNumber() {
    final nowUtc = DateTime.now().toUtc();
    return 'B${nowUtc.microsecondsSinceEpoch}';
  }

  String _dailyPrefix(DateTime now) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<String> _nextOfflineBillNumber(DatabaseExecutor txn) async {
    final prefix = _dailyPrefix(DateTime.now());
    final rows = await txn.query(
      'bills',
      columns: ['bill_number'],
      where: 'bill_number LIKE ?',
      whereArgs: ['B$prefix-%'],
      orderBy: 'bill_number DESC',
      limit: 1,
    );
    var nextSeq = 1;
    if (rows.isNotEmpty) {
      final last = (rows.first['bill_number'] as String?) ?? '';
      final parts = last.split('-');
      if (parts.length == 2) {
        final parsed = int.tryParse(parts[1]);
        if (parsed != null && parsed >= 1) {
          nextSeq = parsed + 1;
        }
      }
    }
    return 'B$prefix-${nextSeq.toString().padLeft(4, '0')}';
  }

  bool _resolveIsInterState(String? customerGstin, String? shopGstin) {
    final customerStateCode = _extractStateCode(customerGstin);
    final shopStateCode = _extractStateCode(shopGstin);
    if (customerStateCode == null || shopStateCode == null) return false;
    return customerStateCode != shopStateCode;
  }

  String? _extractStateCode(String? gstin) {
    // Indian GSTIN standard: first 2 digits represent state code.
    final normalized = (gstin ?? '').replaceAll(RegExp(r'\s+'), '');
    if (normalized.length < 2) return null;
    final stateCode = normalized.substring(0, 2);
    if (!RegExp(r'^\d{2}$').hasMatch(stateCode)) return null;
    return stateCode;
  }

  @override
  Future<Bill> saveBill({
    required List<CartItem> items, String billType = 'retail',
    double discountAmount = 0.0, String paymentMode = 'cash',
    List<SplitPayment>? splitPayments,
    int? customerId, String? customerName, String? customerAddress, String? customerGstin,
    int? couponId, String? couponCode, double couponDiscountAmount = 0.0,
    double? cashTendered, double? changeAmount,
    int? billedByUserId, String? billedByUsername,
    bool isInterState = false,  // FIX BUG#2: pass true for inter-state (IGST) transactions
  }) async {
    debugPrint('[saveBill] started — items: ${items.length}, billType: $billType');

    final prefs = await SharedPreferences.getInstance();
    final inferredInterState = _resolveIsInterState(
      customerGstin,
      prefs.getString('shop_gstin'),
    );
    final effectiveInterState = isInterState || inferredInterState;

    if (await _isOnlineMode()) {
      final now = DateTime.now();
      final bt = billType == 'wholesale' ? BillType.wholesale : BillType.retail;
      final bool isSplit = splitPayments != null && splitPayments.isNotEmpty;
      String effectivePaymentMode = paymentMode;
      String? splitSummary;
      if (isSplit) {
        effectivePaymentMode = 'split';
        splitSummary = splitPayments.map((s) {
          final label = PaymentMode.values
              .firstWhere((m) => m.name == s.mode, orElse: () => PaymentMode.cash)
              .label;
          return '$label ${CurrencyFormatter.format(s.amount)}';
        }).join(' + ');
      }

      final totalAmount = (items.fold(0.0, (s, i) => s + i.totalFor(bt)) -
              discountAmount -
              couponDiscountAmount)
          .clamp(0.0, double.infinity);
      final totalProfit = items.fold(0.0, (s, i) => s + i.profitFor(bt));
      final gstTotal = items.fold(0.0, (s, i) => s + i.gstAmountFor(bt));
      final cgstAmount = effectiveInterState ? 0.0 : gstTotal / 2;
      final sgstAmount = effectiveInterState ? 0.0 : gstTotal / 2;
      final igstAmount = effectiveInterState ? gstTotal : 0.0;
      final billNum = _genOnlineBillNumber();
      final clientRecordId = _uuid.v4();
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'bills/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'billNumber': billNum,
            'billType': billType,
            'customerName': customerName,
            'customerAddress': customerAddress,
            'customerGstin': customerGstin,
            'totalAmount': totalAmount,
            'totalProfit': totalProfit,
            'discountAmount': discountAmount,
            'gstTotal': gstTotal,
            'cgstTotal': cgstAmount,
            'sgstTotal': sgstAmount,
            'igstTotal': igstAmount,
            'paymentMode': effectivePaymentMode,
            'couponCode': couponCode,
            'couponDiscountAmount': couponDiscountAmount,
            'cashTendered': cashTendered,
            'changeAmount': changeAmount,
            'splitPaymentSummary': splitSummary,
            'items': await Future.wait(items.map((item) async => {
                  'productId': await _lookupUuid('products', item.productId),
                  'productName': item.productName,
                  'productSku': item.productSku,
                  'unit': item.unit,
                  'quantity': item.quantity,
                  'unitPrice': item.effectivePrice(bt),
                  'purchasePrice': item.purchasePrice,
                  'totalPrice': item.totalFor(bt),
                  'gstRate': item.gstRate,
                  'conversionQty': item.conversionQty,
                  'saleType': item.saleType.value,
                  'discountAmount': item.itemDiscountAmountFor(bt),
                  'itemDiscountType': item.itemDiscountType.value,
                  'itemDiscountValue': item.itemDiscountValue,
                })),
            'createdAt': now.toUtc().toIso8601String(),
            'updatedAt': now.toUtc().toIso8601String(),
            'version': 1,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      final billId = await _registerUuid('bills', clientRecordId);
      if (effectivePaymentMode == 'cash' &&
          billedByUsername != null &&
          billedByUsername.trim().isNotEmpty) {
        await _cashSessionRepository.addCashCollection(
          cashierUsername: billedByUsername.trim(),
          amount: totalAmount,
        );
      }
      return Bill(
        id: billId,
        billNumber: billNum,
        billType: billType,
        items: items
            .map((item) => BillItem(
                  billId: billId,
                  productId: item.productId,
                  productName: item.productName,
                  productSku: item.productSku,
                  quantity: item.quantity,
                  unit: item.unit,
                  unitPrice: item.effectivePrice(bt),
                  purchasePrice: item.purchasePrice,
                  discountAmount: item.itemDiscountAmountFor(bt),
                  itemDiscountType: item.itemDiscountType.value,
                  itemDiscountValue: item.itemDiscountValue,
                  gstRate: item.gstRate,
                  gstAmount: item.gstAmountFor(bt),
                  totalPrice: item.totalFor(bt),
                ))
            .toList(),
        totalAmount: totalAmount,
        totalProfit: totalProfit,
        discountAmount: discountAmount,
        gstTotal: gstTotal,
        cgstTotal: cgstAmount,
        sgstTotal: sgstAmount,
        igstTotal: igstAmount,
        paymentMode: effectivePaymentMode,
        customerName: customerName,
        customerAddress: customerAddress,
        customerGstin: customerGstin,
        couponCode: couponCode,
        couponDiscountAmount: couponDiscountAmount,
        cashTendered: cashTendered,
        changeAmount: changeAmount,
        splitPaymentSummary: splitSummary,
        createdAt: now,
      );
    }

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final bt = billType == 'wholesale' ? BillType.wholesale : BillType.retail;

    // If split payments provided, override paymentMode and build summary string
    final bool isSplit = splitPayments != null && splitPayments.isNotEmpty;
    String effectivePaymentMode = paymentMode;
    String? splitSummary;
    if (isSplit) {
      effectivePaymentMode = 'split';
      splitSummary = splitPayments.map((s) {
        final label = PaymentMode.values
            .firstWhere((m) => m.name == s.mode, orElse: () => PaymentMode.cash)
            .label;
        return '$label ${CurrencyFormatter.format(s.amount)}';
      }).join(' + ');
    }

    // FIX BUG#4: clamp so totalAmount can never go negative
    double totalAmount = (items.fold(0.0, (s, i) => s + i.totalFor(bt)) - discountAmount - couponDiscountAmount)
        .clamp(0.0, double.infinity);
    double totalProfit = items.fold(0.0, (s, i) => s + i.profitFor(bt));
    double gstTotal = items.fold(0.0, (s, i) => s + i.gstAmountFor(bt));

    // FIX BUG#2: split GST correctly based on transaction type
    final double cgstAmount = effectiveInterState ? 0.0 : gstTotal / 2;
    final double sgstAmount = effectiveInterState ? 0.0 : gstTotal / 2;
    final double igstAmount = effectiveInterState ? gstTotal : 0.0;

    // Assigned inside txn to keep sequence allocation and insert atomic.
    late final String billNum;

    // ── IMPORTANT: resolve licenseId BEFORE the transaction ─────────────────
    // LedgerService.resolveLicenseId queries the main DB connection. If called
    // inside db.transaction(), sqflite deadlocks because the transaction holds
    // an exclusive lock on the same connection. Pre-fetch it here.
    final String licenseId = await LedgerService.resolveLicenseId(_dbHelper);
    debugPrint('[saveBill] licenseId resolved: $licenseId');

    // ── ATOMIC TRANSACTION ────────────────────────────────────────────────
    // All four steps below run inside a single SQLite transaction so that a
    // failure in any one of them automatically rolls back the whole operation:
    //   Step 1 — Insert bill row (+ split-payment rows)
    //   Step 2 — Insert bill_item rows
    //   Step 3 — Deduct stock for every item sold
    //   Step 4 — Write JSON snapshot + double-entry ledger entries
    // No try/catch is used here intentionally — any exception propagates up,
    // causing sqflite to roll back the transaction before it is committed.
    int? ledgerTxId;
    final bill = await db.transaction((txn) async {
      billNum = await _nextOfflineBillNumber(txn);
      // ── Step 1: Insert bill ────────────────────────────────────────────
      // snapshot_json is written in Step 4, after all items have been built,
      // so the snapshot contains the final resolved item list and totals.
      final billId = await txn.insert('bills', {
        'bill_number': billNum, 'bill_type': billType,  // FIX BUG#1
        'customer_id': customerId, 'customer_name': customerName,
        'customer_address': customerAddress, 'customer_gstin': customerGstin,
        'total_amount': totalAmount, 'total_profit': totalProfit,
        'discount_amount': discountAmount, 'gst_total': gstTotal,
        'coupon_id': couponId, 'coupon_code': couponCode,
        'coupon_discount_amount': couponDiscountAmount,
        'cgst_total': cgstAmount, 'sgst_total': sgstAmount, 'igst_total': igstAmount,  // FIX BUG#2
        'cash_tendered': cashTendered, 'change_amount': changeAmount,
        'payment_mode': effectivePaymentMode,
        'split_payment_summary': splitSummary,
        'billed_by_user_id': billedByUserId,
        'billed_by_username': billedByUsername,
        'created_at': nowStr,
      });
      debugPrint('[saveBill] bill inserted: id=$billId, number=$billNum');

      // Store individual split entries
      if (isSplit) {
        for (final split in splitPayments) {
          await txn.insert('bill_payment_splits', {
            'bill_id': billId,
            'payment_mode': split.mode,
            'amount': split.amount,
          });
        }
      }

      final billItems = <BillItem>[];
      // ── Step 2: Insert bill items + deduct stock (Step 3) ─────────────
      for (final cartItem in items) {
        final effectivePrice = cartItem.effectivePrice(bt);
        final itemDiscountAmount = cartItem.itemDiscountAmountFor(bt);
        final gstAmt = cartItem.gstAmountFor(bt);
        final itemTotal = cartItem.totalFor(bt);
        final itemSaleType = cartItem.saleType.value;
        final itemId = await txn.insert('bill_items', {
          'bill_id': billId, 'product_id': cartItem.productId,
          'product_name': cartItem.productName, 'quantity': cartItem.quantity,
          'product_sku': cartItem.productSku,
          'unit': cartItem.unit, 'unit_price': effectivePrice,
          'purchase_price': cartItem.purchasePrice,
          'discount_amount': itemDiscountAmount,
          'item_discount_type': cartItem.itemDiscountType.value,
          'item_discount_value': cartItem.itemDiscountValue,
          'gst_rate': cartItem.gstRate, 'gst_amount': gstAmt, 'total_price': itemTotal,
          'sale_uom_id': cartItem.saleUomId,
          'conversion_qty': cartItem.conversionQty,
          'sale_type': itemSaleType,
        });
        debugPrint('[saveBill] item inserted: id=$itemId, product=${cartItem.productName}');

        // ── Step 3: Deduct stock ───────────────────────────────────────────
        // Wholesale items deduct wholesaleToRetailQty per unit (base UOM).
        final double baseQtyToDeduct;
        if (cartItem.saleType == SaleType.wholesale && cartItem.wholesaleToRetailQty > 1.0) {
          baseQtyToDeduct = cartItem.quantity * cartItem.wholesaleToRetailQty;
        } else {
          baseQtyToDeduct = cartItem.quantity * cartItem.conversionQty;
        }

        // Load product type and unit to choose deduction path.
        final productTypeRows = await txn.query(
          'products',
          columns: ['item_type', 'attributes', 'unit'],
          where: 'id = ?',
          whereArgs: [cartItem.productId],
        );
        final itemType = productTypeRows.isNotEmpty
            ? productTypeRows.first['item_type'] as String? ?? 'physical'
            : 'physical';
        final isServiceItem = itemType == 'service';
        final isCompositeRecipe = itemType == 'composite_recipe';

        if (isServiceItem) {
          debugPrint(
            '[saveBill] service item=${cartItem.productId} — skipping stock deduction',
          );
        } else if (isCompositeRecipe) {
          // ── BOM/Recipe: deduct raw material stocks ──────────────────────
          // The `quantity` stored per BOM ingredient is the amount of that raw
          // material required to produce ONE unit of the finished product
          // (in user-facing units, e.g. 100 g = quantity:100, unit:'g').
          // DB stores stock in the smallest base unit (g / ml), so we must
          // multiply each ingredient quantity by its baseFactor before the
          // DB comparison and update.
          // When selling N units, each ingredient must have at least:
          //   ingredient.quantity * N * ingBaseFactor  base units available.
          final attrStr = productTypeRows.first['attributes'] as String? ?? '{}';
          final attrs = jsonDecode(attrStr) as Map<String, dynamic>? ?? {};
          final bom = (attrs['bom'] as List<dynamic>?) ?? [];

          // 1. Pre-flight availability check — abort before any deduction.
          for (final ing in bom) {
            final ingMap = ing as Map<String, dynamic>;
            final ingId = ingMap['product_id'] as int?;
            final ingQtyPerUnit = (ingMap['quantity'] as num?)?.toDouble() ?? 0;
            if (ingId == null || ingQtyPerUnit <= 0) continue;
            final ingRows = await txn.query('products',
                columns: ['name', 'stock_quantity', 'unit'],
                where: 'id = ?', whereArgs: [ingId]);
            if (ingRows.isNotEmpty) {
              final ingUnit = ingRows.first['unit'] as String? ?? 'piece';
              final ingFactor = UomConversionHelper.baseFactor(ingUnit);
              // Required quantity in DB base units
              final totalIngQtyBase = ingQtyPerUnit * baseQtyToDeduct * ingFactor;
              final ingStock = (ingRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
              if (ingStock < totalIngQtyBase) {
                final ingName = ingRows.first['name'] as String? ?? 'Ingredient';
                // Show user-facing quantities in the error message
                final ingStockUser = ingStock / ingFactor;
                final totalIngQtyUser = ingQtyPerUnit * baseQtyToDeduct;
                throw Exception(
                  'Insufficient raw material "$ingName" for ${cartItem.productName}. '
                  'Required: ${totalIngQtyUser.toStringAsFixed(2)} $ingUnit, '
                  'Available: ${ingStockUser.toStringAsFixed(2)} $ingUnit.',
                );
              }
            }
          }

          // 2. Deduct from each raw material (in base units).
          for (final ing in bom) {
            final ingMap = ing as Map<String, dynamic>;
            final ingId = ingMap['product_id'] as int?;
            final ingQtyPerUnit = (ingMap['quantity'] as num?)?.toDouble() ?? 0;
            if (ingId == null || ingQtyPerUnit <= 0) continue;
            final ingRows = await txn.query('products',
                columns: ['unit'],
                where: 'id = ?', whereArgs: [ingId]);
            final ingUnit = ingRows.isNotEmpty
                ? ingRows.first['unit'] as String? ?? 'piece'
                : 'piece';
            final ingFactor = UomConversionHelper.baseFactor(ingUnit);
            final totalIngQtyBase = ingQtyPerUnit * baseQtyToDeduct * ingFactor;
            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity - ?, updated_at = ? WHERE id = ?',
              [totalIngQtyBase, nowStr, ingId],
            );
          }
          debugPrint('[saveBill] BOM ingredients deducted for recipe product=${cartItem.productId}');

          // 3. Recompute derived stock for the recipe product.
          //    derived = floor( min over all ingredients of
          //                (remaining_stock_base / (qty_per_unit * ingFactor)) )
          //    Note: This mirrors the logic in ProductRepositoryImpl._enrichWithDerivedStock but
          //    must run inside this transaction (against `txn`) so it reads the freshly-deducted
          //    ingredient stocks rather than stale pre-sale values.
          double derivedStock = double.infinity;
          for (final ing in bom) {
            final ingMap = ing as Map<String, dynamic>;
            final ingId = ingMap['product_id'] as int?;
            final ingQtyPerUnit = (ingMap['quantity'] as num?)?.toDouble() ?? 0;
            if (ingId == null || ingQtyPerUnit <= 0) continue;
            final ingRows = await txn.query('products',
                columns: ['stock_quantity', 'unit'],
                where: 'id = ?', whereArgs: [ingId]);
            if (ingRows.isNotEmpty) {
              final ingUnit = ingRows.first['unit'] as String? ?? 'piece';
              final ingFactor = UomConversionHelper.baseFactor(ingUnit);
              final ingStockBase = (ingRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
              // Convert stock to user units and divide by per-unit requirement
              final ingStockUser = ingStockBase / ingFactor;
              final canMake = ingStockUser / ingQtyPerUnit;
              if (canMake < derivedStock) derivedStock = canMake;
            }
          }
          if (derivedStock == double.infinity || bom.isEmpty) derivedStock = 0;
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = ?, updated_at = ? WHERE id = ?',
            [derivedStock.floorToDouble(), nowStr, cartItem.productId],
          );
          debugPrint('[saveBill] derived stock updated for recipe=${cartItem.productId}: ${derivedStock.floorToDouble()}');
        } else {
          // ── Regular product: FEFO batch deduction ────────────────────────
          // baseQtyToDeduct is in the product's user-facing unit (e.g., 2 Kg).
          // DB stores stock and batch quantities in the smallest base unit
          // (e.g., grams), so we multiply by productFactor before all DB ops.
          final productUnit = productTypeRows.isNotEmpty
              ? productTypeRows.first['unit'] as String? ?? 'piece'
              : 'piece';
          final productFactor = UomConversionHelper.baseFactor(productUnit);
          final actualBaseQtyToDeduct = baseQtyToDeduct * productFactor;

          // 1. Fetch all batches with remaining stock, sorted by earliest expiry
          //    (nulls last — batches without expiry are treated as non-perishable
          //    and are used after all dated batches).
          // 2. Reject expired batches (expiry_date < today).
          // 3. If the product has batch records and total available is less than
          //    required, abort the transaction with an informative error.
          // 4. Deduct from each batch in FEFO order until qty is fully covered.
          // 5. Always update the aggregate products.stock_quantity for backward
          //    compatibility with reports and stock display.
          final todayDate = DateTime(now.year, now.month, now.day); // midnight today
          final batchRows = await txn.rawQuery('''
            SELECT id, qty_remaining, expiry_date
            FROM batches
            WHERE product_id = ? AND qty_remaining > 0
            ORDER BY
              CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END,
              expiry_date ASC
          ''', [cartItem.productId]);

          if (batchRows.isNotEmpty) {
            // Parse expiry_date ('YYYY-MM-DD') to DateTime for reliable comparison.
            DateTime? parseExpiry(String? raw) {
              if (raw == null) return null;
              try { return DateTime.parse(raw); } catch (_) { return null; }
            }

            // Separate expired from sellable batches
            final sellable = batchRows.where((b) {
              final exp = parseExpiry(b['expiry_date'] as String?);
              // Allow null expiry (non-perishable). Block if expiry is in the past.
              return exp == null || !exp.isBefore(todayDate);
            }).toList();

            final expired = batchRows.where((b) {
              final exp = parseExpiry(b['expiry_date'] as String?);
              return exp != null && exp.isBefore(todayDate);
            }).toList();

            if (expired.isNotEmpty && sellable.isEmpty) {
              // All remaining stock is from expired batches — block the sale.
              throw Exception(
                '${cartItem.productName}: all remaining stock is expired. '
                'Please remove expired batches before selling.',
              );
            }

            // Total available stock across non-expired batches (in base units)
            final availableQty = sellable.fold(
              0.0, (s, b) => s + (b['qty_remaining'] as num).toDouble());

            if (availableQty < actualBaseQtyToDeduct) {
              // Report shortage in user-facing units for readability
              final availableUser = availableQty / productFactor;
              throw Exception(
                'Insufficient stock for ${cartItem.productName}. '
                'Available: ${availableUser.toStringAsFixed(2)} $productUnit, '
                'Required: ${baseQtyToDeduct.toStringAsFixed(2)} $productUnit.',
              );
            }

            // Drain batches in FEFO order (quantities in base units)
            double remaining = actualBaseQtyToDeduct;
            for (final batch in sellable) {
              if (remaining <= 0) break;
              final batchId = batch['id'] as int;
              final batchQty = (batch['qty_remaining'] as num).toDouble();
              final deduct = remaining < batchQty ? remaining : batchQty;
              await txn.rawUpdate(
                'UPDATE batches SET qty_remaining = qty_remaining - ?, updated_at = ? WHERE id = ?',
                [deduct, nowStr, batchId],
              );
              remaining -= deduct;
            }
            debugPrint('[saveBill] FEFO deducted batches for product=${cartItem.productId}, qty=$actualBaseQtyToDeduct');
          }

          // Always update the aggregate product stock (in base units)
          await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity - ?, updated_at = ? WHERE id = ?',
              [actualBaseQtyToDeduct, nowStr, cartItem.productId]);
          debugPrint('[saveBill] stock deducted: product=${cartItem.productId}, qty=$actualBaseQtyToDeduct');
        }

        billItems.add(BillItem(id: itemId, billId: billId, productId: cartItem.productId,
            productName: cartItem.productName, quantity: cartItem.quantity, unit: cartItem.unit,
            productSku: cartItem.productSku,
            unitPrice: effectivePrice, purchasePrice: cartItem.purchasePrice,
            discountAmount: itemDiscountAmount,
            itemDiscountType: cartItem.itemDiscountType.value,
            itemDiscountValue: cartItem.itemDiscountValue,
            gstRate: cartItem.gstRate, gstAmount: gstAmt, totalPrice: itemTotal));
      }
      debugPrint('[saveBill] items inserted: count=${billItems.length}');

      // ── Step 4: Snapshot + double-entry ledger ────────────────────────
      // Persist an immutable JSON copy of the bill so receipt rendering never
      // needs to re-join bill_items.  Written here (after step 3) so the
      // snapshot reflects the final, fully-resolved item list and totals.
      final snapshotMap = {
        'bill_number': billNum,
        'bill_type': billType,
        'total_amount': totalAmount,
        'total_profit': totalProfit,
        'discount_amount': discountAmount,
        'coupon_code': couponCode,
        'coupon_discount_amount': couponDiscountAmount,
        'gst_total': gstTotal,
        'cgst_total': cgstAmount,
        'sgst_total': sgstAmount,
        'igst_total': igstAmount,
        'cash_tendered': cashTendered,
        'change_amount': changeAmount,
        'payment_mode': effectivePaymentMode,
        'split_payment_summary': splitSummary,
        'customer_name': customerName,
        'customer_address': customerAddress,
        'customer_gstin': customerGstin,
        'created_at': nowStr,
        'items': billItems.map((i) => {
          'product_id': i.productId,
          'product_name': i.productName,
          'product_sku': i.productSku,
          'quantity': i.quantity,
          'unit': i.unit,
          'unit_price': i.unitPrice,
          'purchase_price': i.purchasePrice,
          'discount_amount': i.discountAmount,
          'item_discount_type': i.itemDiscountType,
          'item_discount_value': i.itemDiscountValue,
          'gst_rate': i.gstRate,
          'gst_amount': i.gstAmount,
          'total_price': i.totalPrice,
        }).toList(),
      };
      await txn.rawUpdate(
        'UPDATE bills SET snapshot_json = ? WHERE id = ?',
        [jsonEncode(snapshotMap), billId],
      );
      debugPrint('[saveBill] snapshot saved for bill id=$billId');

      // ── Double-entry ledger ─────────────────────────────────────────────
      // Sale journal (single recordTransaction call — no duplicate writes):
      //   DR Asset (cash/bank)     totalAmount
      //   CR Income (sales)        totalAmount
      //   DR COGS                  totalCOGS  (per item: purchasePrice × baseQty)
      //   CR Inventory             totalCOGS
      //
      // licenseId is resolved BEFORE the transaction to avoid sqflite deadlock.
      // A failure here rolls back all prior steps (bill, items, stock, snapshot).
      final ledger = LedgerService.instance;

      final ledgerEntries = <LedgerEntryInput>[];

      for (final cartItem in items) {
        final double qtyInUserUnits;
        if (cartItem.saleType == SaleType.wholesale && cartItem.wholesaleToRetailQty > 1.0) {
          qtyInUserUnits = cartItem.quantity * cartItem.wholesaleToRetailQty;
        } else {
          qtyInUserUnits = cartItem.quantity * cartItem.conversionQty;
        }
        // ledger quantityChange uses base units to match what was deducted from stock
        final productFactor = UomConversionHelper.baseFactor(cartItem.unit);
        final qtyInBaseUnits = qtyInUserUnits * productFactor;
        final cogs = cartItem.purchasePrice * qtyInUserUnits;
        if (cogs > 0) {
          ledgerEntries.add(LedgerEntryInput(
            accountType: 'cogs', direction: 'debit', amount: cogs,
            quantityChange: -qtyInBaseUnits,
          ));
          ledgerEntries.add(LedgerEntryInput(
            accountType: 'inventory', direction: 'credit', amount: cogs,
            quantityChange: -qtyInBaseUnits,
          ));
        }
      }

      // DR Asset = totalAmount (cash/bank received)
      // CR Income = totalAmount
      ledgerEntries.addAll([
        LedgerEntryInput(accountType: 'asset', direction: 'debit', amount: totalAmount),
        LedgerEntryInput(accountType: 'income', direction: 'credit', amount: totalAmount),
      ]);

      await ledger.recordTransaction(
        executor: txn,
        type: 'sale',
        totalAmount: totalAmount,
        tags: {
          'bill_number': billNum,
          'bill_id': billId,
          'customer_name': customerName,
          'payment_mode': effectivePaymentMode,
          'discount_amount': discountAmount,
          'coupon_code': couponCode,
          'coupon_discount_amount': couponDiscountAmount,
        },
        licenseId: licenseId,
        createdAt: nowStr,
        entries: ledgerEntries,
      ).then((id) => ledgerTxId = id);
      debugPrint('[saveBill] ledger written: ${ledgerEntries.length} entries');

      if (couponId != null) {
        final updatedRows = await txn.rawUpdate(
          '''
            UPDATE coupons
            SET used_count = used_count + 1, updated_at = ?
            WHERE id = ?
              AND is_active = 1
              AND (max_usage IS NULL OR used_count < max_usage)
          ''',
          [nowStr, couponId],
        );
        if (updatedRows == 0) {
          throw Exception('Coupon usage limit reached.');
        }
      }

      return Bill(id: billId, billNumber: billNum, billType: billType,  // FIX BUG#1
          items: billItems, totalAmount: totalAmount, totalProfit: totalProfit,
          discountAmount: discountAmount, gstTotal: gstTotal, cgstTotal: cgstAmount,
          sgstTotal: sgstAmount, igstTotal: igstAmount,  // FIX BUG#2
          paymentMode: effectivePaymentMode,
          splitPaymentSummary: splitSummary,
          customerId: customerId,
          couponId: couponId, couponCode: couponCode,
          couponDiscountAmount: couponDiscountAmount,
          cashTendered: cashTendered, changeAmount: changeAmount,
          customerName: customerName, customerAddress: customerAddress,
          customerGstin: customerGstin, createdAt: now);
    });
    debugPrint('[saveBill] transaction complete: bill #${bill.billNumber}, id=${bill.id}');

    final normalizedBilledBy = billedByUsername?.trim();
    if (normalizedBilledBy != null && normalizedBilledBy.isNotEmpty) {
      var cashCollected = 0.0;
      if (isSplit) {
        for (final split in splitPayments ?? const <SplitPayment>[]) {
          if (split.mode == 'cash') {
            cashCollected += split.amount;
          }
        }
      } else if (effectivePaymentMode == 'cash') {
        cashCollected = totalAmount;
      }

      if (cashCollected > 0) {
        try {
          await _cashSessionRepository.addCashCollection(
            cashierUsername: normalizedBilledBy,
            amount: cashCollected,
          );
        } catch (e) {
          // Non-fatal: bill is already committed. Log and continue so the
          // receipt screen is always shown even when no cashier session is open.
          debugPrint('[saveBill] cash session update skipped (non-fatal): $e');
        }
      }
    }

    debugPrint('[saveBill] completed: bill #${bill.billNumber}');
    return bill;
  }

  @override
  Future<List<Bill>> getBillsByDate(DateTime date) async {
    if (await _isOnlineMode()) {
      final dateStr = date.toIso8601String().substring(0, 10);
      final bills = await _fetchOnlineBills();
      return bills
          .where((bill) => bill.createdAt.toIso8601String().startsWith(dateStr))
          .toList();
    }
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('bills', where: "created_at LIKE ?", whereArgs: ['$dateStr%'], orderBy: 'created_at DESC');
    return rows.map((r) => Bill(
      id: r['id'] as int, billNumber: r['bill_number'] as String,
      billType: r['bill_type'] as String? ?? 'retail', items: [],
      totalAmount: (r['total_amount'] as num).toDouble(),
      totalProfit: (r['total_profit'] as num).toDouble(),
      customerName: r['customer_name'] as String?,
      couponCode: r['coupon_code'] as String?,
      couponDiscountAmount:
          (r['coupon_discount_amount'] as num?)?.toDouble() ?? 0.0,
      cashTendered: (r['cash_tendered'] as num?)?.toDouble(),
      changeAmount: (r['change_amount'] as num?)?.toDouble(),
      paymentMode: r['payment_mode'] as String? ?? 'cash',
      createdAt: DateTime.parse(r['created_at'] as String),
    )).toList();
  }

  @override
  Future<Bill> getBillById(int id) async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineBills();
      for (final bill in bills) {
        if (bill.id == id) return bill;
      }
      throw Exception('Bill #$id not found');
    }
    final db = await _dbHelper.database;
    final rows = await db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw Exception('Bill #$id not found');
    final map = rows.first;
    final itemRows = await db.query('bill_items', where: 'bill_id = ?', whereArgs: [id]);
    final items = itemRows.map((r) => BillItem(
      id: r['id'] as int?,
      billId: id,
      productId: r['product_id'] as int? ?? 0,
      productName: r['product_name'] as String? ?? '',
      productSku: r['product_sku'] as String?,
      quantity: (r['quantity'] as num).toDouble(),
      unit: r['unit'] as String? ?? '',
      unitPrice: (r['unit_price'] as num).toDouble(),
      purchasePrice: (r['purchase_price'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (r['discount_amount'] as num?)?.toDouble() ?? 0.0,
      itemDiscountType: r['item_discount_type'] as String? ?? 'none',
      itemDiscountValue: (r['item_discount_value'] as num?)?.toDouble() ?? 0.0,
      gstRate: (r['gst_rate'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (r['gst_amount'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (r['total_price'] as num).toDouble(),
    )).toList();
    return Bill(
      id: map['id'] as int?,
      billNumber: map['bill_number'] as String,
      billType: map['bill_type'] as String? ?? 'retail',
      items: items,
      totalAmount: (map['total_amount'] as num).toDouble(),
      totalProfit: (map['total_profit'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      couponId: map['coupon_id'] as int?,
      couponCode: map['coupon_code'] as String?,
      couponDiscountAmount:
          (map['coupon_discount_amount'] as num?)?.toDouble() ?? 0.0,
      gstTotal: (map['gst_total'] as num?)?.toDouble() ?? 0.0,
      cgstTotal: (map['cgst_total'] as num?)?.toDouble() ?? 0.0,
      sgstTotal: (map['sgst_total'] as num?)?.toDouble() ?? 0.0,
      igstTotal: (map['igst_total'] as num?)?.toDouble() ?? 0.0,
      cashTendered: (map['cash_tendered'] as num?)?.toDouble(),
      changeAmount: (map['change_amount'] as num?)?.toDouble(),
      paymentMode: map['payment_mode'] as String? ?? 'cash',
      splitPaymentSummary: map['split_payment_summary'] as String?,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      customerAddress: map['customer_address'] as String?,
      customerGstin: map['customer_gstin'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  Future<List<Bill>> getAllBills({DateTime? fromDate, DateTime? toDate}) async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineBills();
      return bills.where((bill) {
        if (fromDate != null && bill.createdAt.isBefore(fromDate)) return false;
        if (toDate != null && bill.createdAt.isAfter(toDate)) return false;
        return true;
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs;
    if (fromDate != null && toDate != null) {
      where = 'created_at BETWEEN ? AND ?';
      whereArgs = [fromDate.toIso8601String(), toDate.toIso8601String()];
    } else if (fromDate != null) {
      where = 'created_at >= ?';
      whereArgs = [fromDate.toIso8601String()];
    } else if (toDate != null) {
      where = 'created_at <= ?';
      whereArgs = [toDate.toIso8601String()];
    }
    final rows = await db.query(
      'bills',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => Bill(
      id: r['id'] as int,
      billNumber: r['bill_number'] as String,
      billType: r['bill_type'] as String? ?? 'retail',
      items: [],
      totalAmount: (r['total_amount'] as num).toDouble(),
      totalProfit: (r['total_profit'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (r['discount_amount'] as num?)?.toDouble() ?? 0.0,
      couponId: r['coupon_id'] as int?,
      couponCode: r['coupon_code'] as String?,
      couponDiscountAmount:
          (r['coupon_discount_amount'] as num?)?.toDouble() ?? 0.0,
      gstTotal: (r['gst_total'] as num?)?.toDouble() ?? 0.0,
      cgstTotal: (r['cgst_total'] as num?)?.toDouble() ?? 0.0,
      sgstTotal: (r['sgst_total'] as num?)?.toDouble() ?? 0.0,
      igstTotal: (r['igst_total'] as num?)?.toDouble() ?? 0.0,
      cashTendered: (r['cash_tendered'] as num?)?.toDouble(),
      changeAmount: (r['change_amount'] as num?)?.toDouble(),
      paymentMode: r['payment_mode'] as String? ?? 'cash',
      splitPaymentSummary: r['split_payment_summary'] as String?,
      customerName: r['customer_name'] as String?,
      customerAddress: r['customer_address'] as String?,
      customerGstin: r['customer_gstin'] as String?,
      createdAt: DateTime.parse(r['created_at'] as String),
    )).toList();
  }

  @override
  Future<Map<String, double>> getDailySummary(DateTime date) async {
    if (await _isOnlineMode()) {
      final bills = await getBillsByDate(date);
      return {
        'sales': bills.fold<double>(0.0, (sum, bill) => sum + bill.totalAmount),
        'profit': bills.fold<double>(0.0, (sum, bill) => sum + bill.totalProfit),
        'billCount': bills.length.toDouble(),
      };
    }
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
        "SELECT COALESCE(SUM(total_amount),0) as sales, COALESCE(SUM(total_profit),0) as profit, COUNT(*) as bill_count FROM bills WHERE created_at LIKE ? AND (status IS NULL OR status != 'cancelled')",
        ['$dateStr%']);
    final row = result.isNotEmpty ? result.first : const <String, Object?>{};
    return {
      'sales': (row['sales'] as num?)?.toDouble() ?? 0.0,
      'profit': (row['profit'] as num?)?.toDouble() ?? 0.0,
      'billCount': (row['bill_count'] as num?)?.toDouble() ?? 0.0,
    };
  }

  @override
  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    if (await _isOnlineMode()) {
      final from = DateTime(year, month, 1);
      final to = DateTime(year, month + 1, 1).subtract(const Duration(seconds: 1));
      final bills = await getAllBills(fromDate: from, toDate: to);
      return {
        'sales': bills.fold<double>(0.0, (sum, bill) => sum + bill.totalAmount),
        'profit': bills.fold<double>(0.0, (sum, bill) => sum + bill.totalProfit),
        'billCount': bills.length.toDouble(),
      };
    }
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2,'0')}';
    final result = await db.rawQuery(
        "SELECT COALESCE(SUM(total_amount),0) as sales, COALESCE(SUM(total_profit),0) as profit, COUNT(*) as bill_count FROM bills WHERE created_at LIKE ? AND (status IS NULL OR status != 'cancelled')",
        ['$prefix%']);
    final row = result.isNotEmpty ? result.first : const <String, Object?>{};
    return {
      'sales': (row['sales'] as num?)?.toDouble() ?? 0.0,
      'profit': (row['profit'] as num?)?.toDouble() ?? 0.0,
      'billCount': (row['bill_count'] as num?)?.toDouble() ?? 0.0,
    };
  }

  @override
  Future<void> deleteBill(int id) async {
    if (await _isOnlineMode()) {
      throw StateError('Bill deletion is unavailable in online API mode.');
    }
    final db = await _dbHelper.database;
    final now = DateTime.now();
    await db.transaction((txn) async {
      // Query bill items joined with products to get the correct stock quantities
      final billItemRows = await txn.rawQuery('''
        SELECT bi.product_id, bi.quantity, bi.sale_type, bi.conversion_qty,
               COALESCE(p.wholesale_to_retail_qty, 1.0) as wholesale_to_retail_qty
        FROM bill_items bi
        LEFT JOIN products p ON bi.product_id = p.id
        WHERE bi.bill_id = ?
      ''', [id]);
      for (final row in billItemRows) {
        final productId = row['product_id'] as int?;
        if (productId == null) continue;
        final quantity = (row['quantity'] as num).toDouble();
        final saleType = row['sale_type'] as String? ?? 'retail';
        final conversionQty = (row['conversion_qty'] as num?)?.toDouble() ?? 1.0;
        final wholesaleToRetailQty =
            (row['wholesale_to_retail_qty'] as num?)?.toDouble() ?? 1.0;
        // Mirror the deduction logic used in saveBill
        final double baseQtyToRestore;
        if (saleType == 'wholesale' && wholesaleToRetailQty > 1.0) {
          baseQtyToRestore = quantity * wholesaleToRetailQty;
        } else {
          baseQtyToRestore = quantity * conversionQty;
        }
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity + ?, updated_at = ? WHERE id = ?',
          [baseQtyToRestore, now.toIso8601String(), productId],
        );
      }
      await txn.delete('bill_items', where: 'bill_id = ?', whereArgs: [id]);
      await txn.delete('bill_payment_splits', where: 'bill_id = ?', whereArgs: [id]);
      await txn.delete('bills', where: 'id = ?', whereArgs: [id]);
    });
  }
}
