import 'dart:convert';

import 'package:dio/dio.dart' show Options;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:uuid/uuid.dart';

import '../../../../core/backend/backend_api_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/data_access_mode_service.dart';
import '../../../../core/utils/uom_conversion_helper.dart';
import '../../../billing/domain/entities/bill.dart';

class ReportRepository {
  final DatabaseHelper _db;
  static const _uuid = Uuid();
  ReportRepository(this._db);

  Future<bool> _isOnlineMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.onlineApi;

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Map<String, dynamic> _decodeMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return const <String, dynamic>{};
  }

  bool _matchesDate(Map<String, dynamic> row, String dateStr, List<String> keys) {
    for (final key in keys) {
      final raw = row[key];
      if (raw != null && raw.toString().startsWith(dateStr)) {
        return true;
      }
    }
    return false;
  }

  double _cashFromSplitSummary(String? summary) {
    if (summary == null || summary.trim().isEmpty) return 0.0;
    var total = 0.0;
    for (final segment in summary.split(' + ')) {
      final trimmed = segment.trim();
      final matches = RegExp(r'([0-9][0-9,]*\.?[0-9]*)').allMatches(trimmed).toList();
      if (matches.isEmpty) continue;
      final amountMatch = matches.last;
      final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      if (trimmed.toLowerCase().contains('cash')) {
        total += amount;
      }
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> _fetchOnlineRows(
    String path, {
    Map<String, dynamic>? queryParameters,
    String listKey = 'rows',
  }) async {
    final body = await BackendApiService.instance.withAuthRetry<dynamic>((
      dio,
      headers,
    ) async {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response.data;
    });
    final rows = body is List
        ? body
        : body is Map
            ? ((body[listKey] as List?) ??
                (body['data'] as List?) ??
                const <dynamic>[])
            : const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Normalizes a dynamic entity identifier into a trimmed string form so
  /// UUID, integer, and string IDs can be compared consistently.
  String? _entityId(dynamic value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  /// Compares two entity identifiers after normalization, returning false
  /// when either side is null or blank.
  bool _sameEntityId(dynamic left, dynamic right) {
    final lhs = _entityId(left);
    final rhs = _entityId(right);
    return lhs != null && rhs != null && lhs == rhs;
  }

  bool _isCancelledStatus(dynamic status) {
    final normalized = status?.toString().toLowerCase().trim();
    return normalized == 'cancelled' || normalized == 'canceled';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool _isWithinRange(DateTime? value, DateTime from, DateTime to) {
    if (value == null) return false;
    return !value.isBefore(from) && !value.isAfter(to);
  }

  String _paymentMode(Map<String, dynamic> row) {
    return (row['paymentMode'] ?? row['payment_mode'] ?? 'other')
        .toString()
        .toLowerCase();
  }

  List<Map<String, dynamic>> _splitPayments(Map<String, dynamic> bill) {
    final raw = bill['paymentSplits'] ?? bill['payment_splits'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ── Modified Bills ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getModifiedBills(
      {DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();
    try {
      return db.rawQuery('''
        SELECT
          h.id,
          h.bill_id,
          h.bill_number,
          h.customer_name,
          h.updated_total_amount as total_amount,
          h.previous_total_amount,
          h.updated_total_amount,
          h.modification_note,
          h.modified_at as created_at
        FROM bill_modification_history h
        WHERE h.modified_at BETWEEN ? AND ?
        ORDER BY h.modified_at DESC
      ''', [f.toIso8601String(), t.toIso8601String()]);
    } catch (_) {
      return db.rawQuery(
        "SELECT * FROM bills WHERE is_modified=1 AND created_at BETWEEN ? AND ? ORDER BY created_at DESC",
        [f.toIso8601String(), t.toIso8601String()],
      );
    }
  }

  // ── Cancelled Bills ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCancelledBills(
      {DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();
    return db.rawQuery(
      "SELECT * FROM bills WHERE status='cancelled' AND created_at BETWEEN ? AND ? ORDER BY created_at DESC",
      [f.toIso8601String(), t.toIso8601String()],
    );
  }

  // ── Fast/Slow/Non-Moving Products ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getProductMovementReport(int days) async {
    final db = await _db.database;
    final since =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return db.rawQuery('''
      SELECT p.id as product_id, p.name as product_name,
        COALESCE(SUM(bi.quantity), 0) as total_qty_sold,
        COALESCE(SUM(bi.total_price), 0) as total_revenue,
        CASE
          WHEN COALESCE(SUM(bi.quantity), 0) > 10 THEN 'fast'
          WHEN COALESCE(SUM(bi.quantity), 0) > 0 THEN 'slow'
          ELSE 'non-moving'
        END as movement_type
      FROM products p
      LEFT JOIN bill_items bi ON bi.product_id = p.id
        AND bi.bill_id IN (SELECT id FROM bills WHERE created_at >= ?)
      WHERE p.is_active = 1
      GROUP BY p.id, p.name
      ORDER BY total_qty_sold DESC
    ''', [since]);
  }

  // ── Sales by Bill ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSalesByBill(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT b.*,
        CASE
          WHEN EXISTS (SELECT 1 FROM bill_modification_history h WHERE h.bill_id = b.id)
            OR COALESCE(b.is_modified, 0) = 1
          THEN 1 ELSE 0
        END as is_modified,
        COALESCE(
          (SELECT h.modification_note
           FROM bill_modification_history h
           WHERE h.bill_id = b.id
           ORDER BY h.modified_at DESC
           LIMIT 1),
          b.modification_note
        ) as modification_note,
        GROUP_CONCAT(bi.product_name || ' x' || bi.quantity, ', ') as items_summary,
        COUNT(bi.id) as item_count
      FROM bills b
      LEFT JOIN bill_items bi ON bi.bill_id = b.id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY b.id
      ORDER BY b.created_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Sales by Item ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSalesByItem(
      {required DateTime from, required DateTime to}) async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineRows(
        'bills',
        queryParameters: {'limit': 1000},
        listKey: 'bills',
      );
      final totals = <String, Map<String, dynamic>>{};
      for (final bill in bills) {
        if (_isCancelledStatus(bill['status'])) continue;
        final createdAt = _parseDate(bill['createdAt'] ?? bill['created_at']);
        if (!_isWithinRange(createdAt, from, to)) continue;
        final billKey = (bill['id'] ?? bill['billNumber'] ?? bill['bill_number'])?.toString() ?? '';
        final items = ((bill['items'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        for (final item in items) {
          final name =
              (item['productName'] ?? item['product_name'] ?? 'Unknown').toString();
          final qty = _toDouble(item['quantity']);
          final unitPrice = _toDouble(item['unitPrice'] ?? item['unit_price']);
          final purchasePrice = _toDouble(item['purchasePrice'] ?? item['purchase_price']);
          final totalPrice = _toDouble(item['totalPrice'] ?? item['total_price']);
          final profit = (unitPrice - purchasePrice) * qty;
          if (!totals.containsKey(name)) {
            totals[name] = {
              'product_name': name,
              'total_qty': 0.0,
              'total_revenue': 0.0,
              'total_profit': 0.0,
              '_bill_keys': <String>{},
            };
          }
          totals[name]!['total_qty'] =
              (totals[name]!['total_qty'] as double) + qty;
          totals[name]!['total_revenue'] =
              (totals[name]!['total_revenue'] as double) + totalPrice;
          totals[name]!['total_profit'] =
              (totals[name]!['total_profit'] as double) + profit;
          (totals[name]!['_bill_keys'] as Set<String>).add(billKey);
        }
      }
      final result = totals.values.map((e) {
        final billKeys = e['_bill_keys'] as Set<String>;
        return <String, dynamic>{
          'product_name': e['product_name'],
          'total_qty': e['total_qty'],
          'total_revenue': e['total_revenue'],
          'total_profit': e['total_profit'],
          'bill_count': billKeys.length,
        };
      }).toList();
      result.sort((a, b) =>
          (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
      return result;
    }
    final db = await _db.database;
    return db.rawQuery('''
      SELECT bi.product_name,
        SUM(bi.quantity) as total_qty,
        SUM(bi.total_price) as total_revenue,
        SUM((bi.unit_price - bi.purchase_price) * bi.quantity) as total_profit,
        COUNT(DISTINCT bi.bill_id) as bill_count
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY bi.product_name
      ORDER BY total_revenue DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Day-wise Profit ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDaywiseProfitReport(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    final bills = await db.rawQuery('''
      SELECT DATE(created_at) as day,
        SUM(total_amount) as total_sales,
        SUM(total_profit) as total_profit,
        COUNT(*) as bill_count
      FROM bills
      WHERE created_at BETWEEN ? AND ? AND (status IS NULL OR status != 'cancelled')
      GROUP BY DATE(created_at)
      ORDER BY day ASC
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final expenses = await db.rawQuery('''
      SELECT date as day, SUM(amount) as total_expenses
      FROM expenses
      WHERE date BETWEEN ? AND ?
      GROUP BY date
    ''', [from.toIso8601String().substring(0, 10), to.toIso8601String().substring(0, 10)]);

    final expMap = {for (final e in expenses) e['day'] as String: (e['total_expenses'] as num).toDouble()};
    return bills.map((b) {
      final day = b['day'] as String;
      final exp = expMap[day] ?? 0.0;
      return {...b, 'total_expenses': exp, 'net_profit': (b['total_profit'] as num).toDouble() - exp};
    }).toList();
  }

  // ── Total Bill Count (all-time, non-cancelled) ──────────────────────────────
  Future<int> getTotalBillCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM bills WHERE status IS NULL OR status != 'cancelled'");
    return (result.isNotEmpty ? (result.first['cnt'] as int? ?? 0) : 0);
  }

  // ── GST Report ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getGstReport(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT
        b.id as bill_id,
        b.bill_number,
        b.bill_type,
        b.customer_name,
        b.customer_gstin,
        b.created_at,
        b.total_amount,
        b.discount_amount,
        b.gst_total,
        b.cgst_total,
        b.sgst_total,
        CASE
          WHEN EXISTS (SELECT 1 FROM bill_modification_history h WHERE h.bill_id = b.id)
            OR COALESCE(b.is_modified, 0) = 1
          THEN 1 ELSE 0
        END as is_modified,
        COALESCE(
          (SELECT h.modification_note
           FROM bill_modification_history h
           WHERE h.bill_id = b.id
           ORDER BY h.modified_at DESC
           LIMIT 1),
          b.modification_note
        ) as modification_note,
        b.payment_mode,
        bi.product_name,
        bi.quantity,
        bi.unit,
        bi.unit_price,
        bi.gst_rate,
        bi.gst_amount,
        bi.total_price
      FROM bills b
      JOIN bill_items bi ON bi.bill_id = b.id
      WHERE b.created_at BETWEEN ? AND ?
        AND (b.status IS NULL OR b.status != 'cancelled')
      ORDER BY b.created_at DESC, b.id, bi.id
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Bill-wise Report ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBillwiseReport(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT b.*,
        CASE
          WHEN EXISTS (SELECT 1 FROM bill_modification_history h WHERE h.bill_id = b.id)
            OR COALESCE(b.is_modified, 0) = 1
          THEN 1 ELSE 0
        END as is_modified,
        COALESCE(
          (SELECT h.modification_note
           FROM bill_modification_history h
           WHERE h.bill_id = b.id
           ORDER BY h.modified_at DESC
           LIMIT 1),
          b.modification_note
        ) as modification_note,
        GROUP_CONCAT(bi.product_name || ' x' || bi.quantity, ', ') as items_summary,
        COUNT(bi.id) as item_count
      FROM bills b
      LEFT JOIN bill_items bi ON bi.bill_id = b.id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY b.id
      ORDER BY b.created_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Get Bill By ID ──────────────────────────────────────────────────────────
  Future<Bill> getBillById(int id) async {
    final db = await _db.database;
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
      gstTotal: (map['gst_total'] as num?)?.toDouble() ?? 0.0,
      cgstTotal: (map['cgst_total'] as num?)?.toDouble() ?? 0.0,
      sgstTotal: (map['sgst_total'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['payment_mode'] as String? ?? 'cash',
      splitPaymentSummary: map['split_payment_summary'] as String?,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      customerAddress: map['customer_address'] as String?,
      customerGstin: map['customer_gstin'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // ── Hourly Sales ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getHourlySalesReport(DateTime date) async {
    final db = await _db.database;
    final day = date.toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT strftime('%H', created_at) as hour,
        SUM(total_amount) as total_sales,
        COUNT(*) as bill_count
      FROM bills
      WHERE DATE(created_at) = ? AND (status IS NULL OR status != 'cancelled')
      GROUP BY strftime('%H', created_at)
      ORDER BY hour ASC
    ''', [day]);
  }

  // ── Item-wise Report ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getItemwiseReport(
      {required DateTime from, required DateTime to}) async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineRows(
        'bills',
        queryParameters: {'limit': 1000},
        listKey: 'bills',
      );
      final rows = <Map<String, dynamic>>[];
      for (final bill in bills) {
        if (_isCancelledStatus(bill['status'])) continue;
        final createdAt = _parseDate(bill['createdAt'] ?? bill['created_at']);
        if (!_isWithinRange(createdAt, from, to)) continue;
        final billNumber =
            (bill['billNumber'] ?? bill['bill_number'] ?? '-').toString();
        final createdAtStr =
            (bill['createdAt'] ?? bill['created_at'])?.toString() ?? '';
        final items = ((bill['items'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        for (final item in items) {
          final unitPrice =
              _toDouble(item['unitPrice'] ?? item['unit_price']);
          final purchasePrice =
              _toDouble(item['purchasePrice'] ?? item['purchase_price']);
          final qty = _toDouble(item['quantity']);
          rows.add({
            'product_name':
                (item['productName'] ?? item['product_name'] ?? 'Unknown')
                    .toString(),
            'quantity': qty,
            'unit_price': unitPrice,
            'purchase_price': purchasePrice,
            'total_price': _toDouble(item['totalPrice'] ?? item['total_price']),
            'bill_number': billNumber,
            'created_at': createdAtStr,
            'profit': (unitPrice - purchasePrice) * qty,
          });
        }
      }
      rows.sort((a, b) =>
          (b['created_at']?.toString() ?? '')
              .compareTo(a['created_at']?.toString() ?? ''));
      return rows;
    }
    final db = await _db.database;
    return db.rawQuery('''
      SELECT bi.product_name, bi.quantity, bi.unit_price, bi.purchase_price,
        bi.total_price, b.bill_number, b.created_at,
        (bi.unit_price - bi.purchase_price) * bi.quantity as profit
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      ORDER BY b.created_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Cashier-wise Sales ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCashierWiseSales(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT COALESCE(u.username, 'Unknown') as cashier_name,
        COUNT(b.id) as bill_count,
        SUM(b.total_amount) as total_sales,
        SUM(b.total_profit) as total_profit
      FROM bills b
      LEFT JOIN app_users u ON u.id = b.billed_by_user_id
      WHERE b.created_at BETWEEN ? AND ? AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY b.billed_by_user_id
      ORDER BY total_sales DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Payment Method Wise ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPaymentMethodWiseReport(
      {required DateTime from, required DateTime to}) async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineRows(
        'bills',
        queryParameters: {'limit': 1000},
        listKey: 'bills',
      );
      final totals = <String, double>{
        'cash': 0,
        'upi': 0,
        'card': 0,
        'credit': 0,
        'other': 0,
      };
      for (final bill in bills) {
        if (_isCancelledStatus(bill['status'])) continue;
        final createdAt = _parseDate(bill['createdAt'] ?? bill['created_at']);
        if (!_isWithinRange(createdAt, from, to)) continue;
        final amount = _toDouble(bill['totalAmount'] ?? bill['total_amount']);
        final mode = _paymentMode(bill);
        if (mode == 'split') {
          final splits = _splitPayments(bill);
          if (splits.isNotEmpty) {
            for (final split in splits) {
              final splitMode =
                  (split['paymentMode'] ?? split['payment_mode'] ?? 'other')
                      .toString()
                      .toLowerCase();
              final key = totals.containsKey(splitMode) ? splitMode : 'other';
              totals[key] = totals[key]! + _toDouble(split['amount']);
            }
          } else {
            final splitCash = _cashFromSplitSummary(
              (bill['splitPaymentSummary'] ?? bill['split_payment_summary'])
                  ?.toString(),
            );
            totals['cash'] = totals['cash']! + splitCash;
            final remaining = amount - splitCash;
            if (remaining > 0) {
              totals['other'] = totals['other']! + remaining;
            }
          }
          continue;
        }
        final key = totals.containsKey(mode) ? mode : 'other';
        totals[key] = totals[key]! + amount;
      }
      return totals.entries
          .map((e) => {'payment_mode': e.key, 'total': e.value})
          .toList();
    }
    final db = await _db.database;
    final nonSplit = await db.rawQuery('''
      SELECT LOWER(payment_mode) as payment_mode, COALESCE(SUM(total_amount), 0) as total
      FROM bills
      WHERE created_at BETWEEN ? AND ?
        AND (status IS NULL OR status != 'cancelled')
        AND LOWER(payment_mode) != 'split'
      GROUP BY LOWER(payment_mode)
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final split = await db.rawQuery('''
      SELECT LOWER(bps.payment_mode) as payment_mode, COALESCE(SUM(bps.amount), 0) as total
      FROM bill_payment_splits bps
      JOIN bills b ON b.id = bps.bill_id
      WHERE b.created_at BETWEEN ? AND ?
        AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY LOWER(bps.payment_mode)
    ''', [from.toIso8601String(), to.toIso8601String()]);

    // Canonical payment modes currently supported by billing flow.
    final totals = <String, double>{
      'cash': 0,
      'upi': 0,
      'card': 0,
      'credit': 0,
      'other': 0,
    };
    for (final row in [...nonSplit, ...split]) {
      final mode = (row['payment_mode'] as String? ?? '').toLowerCase();
      final key = totals.containsKey(mode) ? mode : 'other';
      totals[key] = (totals[key] ?? 0) + ((row['total'] as num?)?.toDouble() ?? 0);
    }

    return totals.entries
        .map((e) => {'payment_mode': e.key, 'total': e.value})
        .toList();
  }

  // ── Cash in Hand ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCashInHandReport({
    required DateTime date,
    String? cashierUsername,
  }) async {
    if (await _isOnlineMode()) {
      final dateStr = date.toIso8601String().substring(0, 10);
      final bills = await _fetchOnlineRows(
        'bills',
        queryParameters: {'limit': 1000},
        listKey: 'bills',
      );
      final grouped = <String, Map<String, dynamic>>{};
      for (final bill in bills) {
        if (_isCancelledStatus(bill['status'])) continue;
        final createdAt = (bill['createdAt'] ?? bill['created_at'] ?? '').toString();
        if (!createdAt.startsWith(dateStr)) continue;
        final cashier = (bill['billedBy'] ??
                    bill['billed_by'] ??
                    bill['cashierUsername'] ??
                    bill['cashier_username'] ??
                    'Unknown')
                .toString();
        if (cashierUsername != null && cashier != cashierUsername) continue;
        final mode = _paymentMode(bill);
        var cashAmount = 0.0;
        if (mode == 'cash') {
          cashAmount = _toDouble(bill['totalAmount'] ?? bill['total_amount']);
        } else if (mode == 'split') {
          cashAmount = _cashFromSplitSummary(
            (bill['splitPaymentSummary'] ?? bill['split_payment_summary'])
                ?.toString(),
          );
        }
        final row = grouped.putIfAbsent(cashier, () {
          return {
            'cashier_name': cashier,
            'opening_amount': 0.0,
            'total_cash_sales': 0.0,
            'total_cash_refunds': 0.0,
            'expected_cash_in_hand': 0.0,
            'status': 'OPEN',
          };
        });
        row['total_cash_sales'] =
            (row['total_cash_sales'] as double) + cashAmount;
        row['expected_cash_in_hand'] =
            (row['opening_amount'] as double) +
                (row['total_cash_sales'] as double) -
                (row['total_cash_refunds'] as double);
      }
      final rows = grouped.values.toList()
        ..sort((a, b) => (a['cashier_name'] as String)
            .compareTo(b['cashier_name'] as String));
      return rows;
    }
    final db = await _db.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final where = cashierUsername != null
        ? 'DATE(opened_at) = ? AND cashier_username = ?'
        : 'DATE(opened_at) = ?';
    final args = cashierUsername != null ? [dateStr, cashierUsername] : [dateStr];
    final sessions = await db.query('cashier_sessions',
        where: where, whereArgs: args, orderBy: 'opened_at DESC');

    if (sessions.isEmpty) return [];

    if (cashierUsername != null) {
      return sessions.map((s) {
        final opening = (s['opening_amount'] as num?)?.toDouble() ?? 0;
        final cashSales = (s['total_cash_collected'] as num?)?.toDouble() ?? 0;
        final cashRefunds = (s['total_cash_refunded'] as num?)?.toDouble() ?? 0;
        return {
          'cashier_name': s['cashier_username'],
          'opening_amount': opening,
          'total_cash_sales': cashSales,
          'total_cash_refunds': cashRefunds,
          'expected_cash_in_hand': opening + cashSales - cashRefunds,
          'status': s['status'],
        };
      }).toList();
    }

    final grouped = <String, Map<String, dynamic>>{};
    for (final s in sessions) {
      final user = s['cashier_username'] as String? ?? 'Unknown';
      grouped.putIfAbsent(user, () => {
            'cashier_name': user,
            'opening_amount': 0.0,
            'total_cash_sales': 0.0,
            'total_cash_refunds': 0.0,
            'expected_cash_in_hand': 0.0,
            'status': 'MIXED',
          });
      grouped[user]!['opening_amount'] =
          (grouped[user]!['opening_amount'] as double) +
              ((s['opening_amount'] as num?)?.toDouble() ?? 0);
      grouped[user]!['total_cash_sales'] =
          (grouped[user]!['total_cash_sales'] as double) +
              ((s['total_cash_collected'] as num?)?.toDouble() ?? 0);
      grouped[user]!['total_cash_refunds'] =
          (grouped[user]!['total_cash_refunds'] as double) +
              ((s['total_cash_refunded'] as num?)?.toDouble() ?? 0);
      grouped[user]!['expected_cash_in_hand'] =
          (grouped[user]!['opening_amount'] as double) +
              (grouped[user]!['total_cash_sales'] as double) -
              (grouped[user]!['total_cash_refunds'] as double);
      final status = s['status']?.toString().toUpperCase() ?? 'OPEN';
      if (status == 'OPEN') grouped[user]!['status'] = 'OPEN';
    }
    return grouped.values.toList()
      ..sort((a, b) => (a['cashier_name'] as String)
          .compareTo(b['cashier_name'] as String));
  }

  // ── Top Customers by Revenue ────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTopCustomersByRevenue({
    required DateTime from,
    required DateTime to,
  }) async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineRows(
        'bills',
        queryParameters: {'limit': 1000},
        listKey: 'bills',
      );
      final grouped = <String, Map<String, dynamic>>{};
      for (final bill in bills) {
        if (_isCancelledStatus(bill['status'])) continue;
        final createdAt = _parseDate(bill['createdAt'] ?? bill['created_at']);
        if (!_isWithinRange(createdAt, from, to)) continue;
        final customerId =
            bill['customerId'] ?? bill['customer_id'];
        if (_entityId(customerId) == null) continue;
        final customerName =
            (bill['customerName'] ?? bill['customer_name'] ?? 'Customer')
                .toString();
        final key = _entityId(customerId)!;
        final row = grouped.putIfAbsent(key, () {
          return {
            'customer_id': customerId,
            'customer_name': customerName,
            'bill_count': 0,
            'total_spent': 0.0,
          };
        });
        row['bill_count'] = (row['bill_count'] as int) + 1;
        row['total_spent'] = (row['total_spent'] as double) +
            _toDouble(bill['totalAmount'] ?? bill['total_amount']);
      }
      final rows = grouped.values.toList()
        ..sort((a, b) =>
            (b['total_spent'] as double).compareTo(a['total_spent'] as double));
      return rows;
    }
    final db = await _db.database;
    return db.rawQuery('''
      SELECT
        b.customer_id,
        COALESCE(b.customer_name, c.name, 'Walk-in') as customer_name,
        COUNT(b.id) as bill_count,
        COALESCE(SUM(b.total_amount), 0) as total_spent
      FROM bills b
      LEFT JOIN customers c ON c.id = b.customer_id
      WHERE b.created_at BETWEEN ? AND ?
        AND (b.status IS NULL OR b.status != 'cancelled')
        AND b.customer_id IS NOT NULL
      GROUP BY b.customer_id, customer_name
      ORDER BY total_spent DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // ── Customer Purchase History ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCustomerPurchaseHistory({
    required Object customerId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineRows(
        'bills',
        queryParameters: {'limit': 1000},
        listKey: 'bills',
      );
      final rows = <Map<String, dynamic>>[];
      for (final bill in bills) {
        if (_isCancelledStatus(bill['status'])) continue;
        final id = bill['customerId'] ?? bill['customer_id'];
        if (!_sameEntityId(id, customerId)) continue;
        final createdAt = _parseDate(bill['createdAt'] ?? bill['created_at']);
        if (!_isWithinRange(createdAt, from, to)) continue;
        final items = ((bill['items'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList();
        final itemSummary = items
            .map((item) =>
                '${item['productName'] ?? item['product_name'] ?? '-'} x${item['quantity'] ?? '?'}')
            .join(', ');
        rows.add({
          'id': _toInt(bill['id']),
          'bill_number': bill['billNumber'] ?? bill['bill_number'] ?? '-',
          'created_at': bill['createdAt'] ?? bill['created_at'],
          'payment_mode': bill['paymentMode'] ?? bill['payment_mode'],
          'total_amount': _toDouble(bill['totalAmount'] ?? bill['total_amount']),
          'items_summary': itemSummary,
        });
      }
      rows.sort((a, b) =>
          (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? ''));
      return rows;
    }
    final db = await _db.database;
    return db.rawQuery('''
      SELECT
        b.id,
        b.bill_number,
        b.created_at,
        b.payment_mode,
        b.total_amount,
        GROUP_CONCAT(bi.product_name || ' x' || bi.quantity, ', ') as items_summary
      FROM bills b
      LEFT JOIN bill_items bi ON bi.bill_id = b.id
      WHERE b.customer_id = ?
        AND b.created_at BETWEEN ? AND ?
        AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY b.id
      ORDER BY b.created_at DESC
    ''', [customerId, from.toIso8601String(), to.toIso8601String()]);
  }

  // ── All Cashier Sessions Dashboard ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllCashierSessionsForDate(
      DateTime date) async {
    if (await _isOnlineMode()) {
      final rows = await getCashInHandReport(date: date);
      return rows
          .map((row) => <String, dynamic>{
                'cashier_name': row['cashier_name'],
                'opening_amount': row['opening_amount'],
                'closing_amount': null,
                'cash_sales': row['total_cash_sales'],
                'cash_refunds': row['total_cash_refunds'],
                'expected_closing': row['expected_cash_in_hand'],
                'actual_closing': null,
                'difference': null,
                'status': row['status'] ?? 'OPEN',
                'opened_at': date.toIso8601String(),
                'closed_at': null,
              })
          .toList();
    }
    final db = await _db.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT
        cashier_username as cashier_name,
        opening_amount,
        closing_amount,
        total_cash_collected as cash_sales,
        total_cash_refunded as cash_refunds,
        expected_closing,
        closing_amount as actual_closing,
        difference,
        status,
        opened_at,
        closed_at
      FROM cashier_sessions
      WHERE DATE(opened_at) = ?
      ORDER BY opened_at DESC
    ''', [dateStr]);
  }

  // ── Pending Dues / Credit Customers ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingDuesCustomers() async {
    if (await _isOnlineMode()) {
      try {
        final customers = await _fetchOnlineRows(
          'customers',
          queryParameters: {'limit': 1000},
          listKey: 'customers',
        );
        final rows = customers
            .map((row) => <String, dynamic>{
                  'id': row['serverId'] ??
                      row['server_id'] ??
                      row['clientRecordId'] ??
                      row['client_record_id'] ??
                      row['id'],
                  'customer_name': row['name'] ?? row['customerName'] ?? 'Customer',
                  'phone': row['phone'],
                  'total_outstanding_amount':
                      _toDouble(row['outstandingBalance'] ?? row['outstanding_balance']),
                  'last_transaction_date':
                      row['lastTransactionDate'] ?? row['last_transaction_date'],
                })
            .where((row) =>
                (_toDouble(row['total_outstanding_amount']) > 0.0))
            .toList();
        rows.sort((a, b) => _toDouble(b['total_outstanding_amount'])
            .compareTo(_toDouble(a['total_outstanding_amount'])));
        return rows;
      } catch (error, stackTrace) {
        debugPrint(
          '[ReportRepository] getPendingDuesCustomers online mode failed: $error\n$stackTrace',
        );
        rethrow;
      }
    }
    final db = await _db.database;
    return db.rawQuery('''
      SELECT
        c.id,
        c.name as customer_name,
        c.phone,
        c.outstanding_balance as total_outstanding_amount,
        MAX(b.created_at) as last_transaction_date
      FROM customers c
      LEFT JOIN bills b ON b.customer_id = c.id
      WHERE c.is_active = 1
        AND COALESCE(c.outstanding_balance, 0) > 0
      GROUP BY c.id, c.name, c.phone, c.outstanding_balance
      ORDER BY c.outstanding_balance DESC
    ''');
  }

  // ── Category-wise Stock ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCategoryStockReport() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT c.id as category_id, c.name as category_name, c.icon,
        COUNT(p.id) as product_count,
        SUM(
          CASE
            WHEN LOWER(COALESCE(p.unit, '')) IN ('kg', 'kilogram', 'l', 'litre', 'liter')
              THEN p.stock_quantity / 1000.0
            ELSE p.stock_quantity
          END
        ) as total_stock_qty,
        SUM(
          (CASE
            WHEN LOWER(COALESCE(p.unit, '')) IN ('kg', 'kilogram', 'l', 'litre', 'liter')
              THEN p.stock_quantity / 1000.0
            ELSE p.stock_quantity
          END) * p.selling_price
        ) as total_stock_value
      FROM categories c
      LEFT JOIN products p ON p.category_id = c.id AND p.is_active = 1
      GROUP BY c.id, c.name, c.icon
      ORDER BY total_stock_value DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getProductsByCategory(int categoryId) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT id, name,
        CASE
          WHEN LOWER(COALESCE(unit, '')) IN ('kg', 'kilogram', 'l', 'litre', 'liter')
            THEN stock_quantity / 1000.0
          ELSE stock_quantity
        END as stock_quantity,
        selling_price,
        (CASE
          WHEN LOWER(COALESCE(unit, '')) IN ('kg', 'kilogram', 'l', 'litre', 'liter')
            THEN stock_quantity / 1000.0
          ELSE stock_quantity
        END) * selling_price as stock_value
      FROM products
      WHERE category_id = ? AND is_active = 1
      ORDER BY name ASC
    ''', [categoryId]);
  }

  // ── Product Stock History ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getProductStockHistory(int productId,
      {DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();
    final sales = await db.rawQuery('''
      SELECT b.created_at, 'sale' as type, bi.quantity * -1 as qty_change,
        bi.total_price as amount, b.bill_number as reference
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      WHERE bi.product_id = ? AND b.created_at BETWEEN ? AND ?
    ''', [productId, f.toIso8601String(), t.toIso8601String()]);

    final purchases = await db.rawQuery('''
      SELECT p.created_at, 'purchase' as type, pi.quantity as qty_change,
        pi.total_cost as amount, p.purchase_number as reference
      FROM purchase_items pi
      JOIN purchases p ON p.id = pi.purchase_id
      WHERE pi.product_id = ? AND p.created_at BETWEEN ? AND ?
    ''', [productId, f.toIso8601String(), t.toIso8601String()]);

    final adjustments = await db.rawQuery('''
      SELECT created_at,
        CASE adjustment_type WHEN 'add' THEN 'adjustment_in' ELSE 'adjustment_out' END as type,
        CASE adjustment_type WHEN 'add' THEN quantity ELSE quantity * -1 END as qty_change,
        0.0 as amount, reason as reference
      FROM stock_adjustments
      WHERE product_id = ? AND created_at BETWEEN ? AND ?
    ''', [productId, f.toIso8601String(), t.toIso8601String()]);

    final all = [...sales, ...purchases, ...adjustments];
    all.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return all;
  }

  // ── Supplier Statement ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSupplierStatement(int supplierId) async {
    final db = await _db.database;
    final suppliers = await db.query('suppliers', where: 'id = ?', whereArgs: [supplierId]);
    final purchases = await db.query('purchases',
        where: 'supplier_id = ?', whereArgs: [supplierId], orderBy: 'created_at DESC');
    return {'supplier': suppliers.isNotEmpty ? suppliers.first : {}, 'purchases': purchases};
  }

  Future<List<Map<String, dynamic>>> getAllSupplierBalances() async {
    final db = await _db.database;
    return db.rawQuery(
        "SELECT id, name, phone, outstanding_balance FROM suppliers WHERE is_active=1 ORDER BY name ASC");
  }

  // ── Customer Statement ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getCustomerStatement(Object customerId) async {
    if (await _isOnlineMode()) {
      final customers = await _fetchOnlineRows(
        'customers',
        queryParameters: {'limit': 1000},
        listKey: 'customers',
      );
      final bills = await _fetchOnlineRows(
        'bills',
        queryParameters: {'limit': 1000},
        listKey: 'bills',
      );
      final customer = customers.cast<Map<String, dynamic>>().firstWhere(
            (row) => _sameEntityId(
              row['serverId'] ??
                  row['server_id'] ??
                  row['clientRecordId'] ??
                  row['client_record_id'] ??
                  row['id'],
              customerId,
            ),
            orElse: () => <String, dynamic>{},
          );
      final customerBills = bills.where((bill) {
        if (_isCancelledStatus(bill['status'])) return false;
        return _sameEntityId(bill['customerId'] ?? bill['customer_id'], customerId);
      }).map((bill) {
        return <String, dynamic>{
          'id': bill['serverId'] ?? bill['server_id'] ?? bill['id'],
          'bill_number': bill['billNumber'] ?? bill['bill_number'] ?? '-',
          'created_at': bill['createdAt'] ?? bill['created_at'],
          'payment_mode': bill['paymentMode'] ?? bill['payment_mode'],
          'total_amount': _toDouble(bill['totalAmount'] ?? bill['total_amount']),
        };
      }).toList();
      return {
        'customer': {
          'id': customer['serverId'] ??
              customer['server_id'] ??
              customer['clientRecordId'] ??
              customer['client_record_id'] ??
              customer['id'],
          'name': customer['name'] ?? customer['customerName'],
          'phone': customer['phone'],
          'outstanding_balance':
              _toDouble(customer['outstandingBalance'] ?? customer['outstanding_balance']),
        },
        'bills': customerBills,
      };
    }
    final db = await _db.database;
    final customers = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
    final bills = await db.query('bills',
        where: 'customer_id = ? AND (status IS NULL OR status != ?)',
        whereArgs: [customerId, 'cancelled'],
        orderBy: 'created_at DESC');
    return {'customer': customers.isNotEmpty ? customers.first : {}, 'bills': bills};
  }

  Future<List<Map<String, dynamic>>> getAllCustomerBalances() async {
    if (await _isOnlineMode()) {
      try {
        final customers = await _fetchOnlineRows(
          'customers',
          queryParameters: {'limit': 1000},
          listKey: 'customers',
        );
        final rows = customers
            .map((row) => <String, dynamic>{
                  'id': row['serverId'] ??
                      row['server_id'] ??
                      row['clientRecordId'] ??
                      row['client_record_id'] ??
                      row['id'],
                  'name': row['name'] ?? row['customerName'] ?? 'Customer',
                  'phone': row['phone'],
                  'outstanding_balance':
                      _toDouble(row['outstandingBalance'] ?? row['outstanding_balance']),
                })
            .toList();
        rows.sort((a, b) =>
            (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
        return rows;
      } catch (error, stackTrace) {
        debugPrint(
          '[ReportRepository] getAllCustomerBalances online mode failed: $error\n$stackTrace',
        );
        rethrow;
      }
    }
    final db = await _db.database;
    return db.rawQuery(
        "SELECT id, name, phone, outstanding_balance FROM customers WHERE is_active=1 ORDER BY name ASC");
  }

  // ── CRM Points ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCRMPointsBalances() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT customer_id, customer_name, SUM(points) as total_points
      FROM crm_points_ledger
      GROUP BY customer_id, customer_name
      ORDER BY total_points DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getCRMStatement(int customerId) async {
    final db = await _db.database;
    return db.rawQuery(
        "SELECT * FROM crm_points_ledger WHERE customer_id=? ORDER BY created_at DESC",
        [customerId]);
  }

  // ── Cash Book ───────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCashBook(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    final cashSales = await db.rawQuery('''
      SELECT created_at as date, 'in' as flow_type,
        'Cash Sale - Bill #' || bill_number as description, total_amount as amount
      FROM bills
      WHERE (payment_mode = 'cash' OR payment_mode = 'Cash')
        AND created_at BETWEEN ? AND ?
        AND (status IS NULL OR status != 'cancelled')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final splitCash = await db.rawQuery('''
      SELECT b.created_at as date, 'in' as flow_type,
        'Cash Split - Bill #' || b.bill_number as description, bps.amount as amount
      FROM bill_payment_splits bps
      JOIN bills b ON b.id = bps.bill_id
      WHERE (bps.payment_mode = 'cash' OR bps.payment_mode = 'Cash')
        AND b.created_at BETWEEN ? AND ?
        AND (b.payment_mode != 'cash' AND b.payment_mode != 'Cash')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final expenses = await db.rawQuery('''
      SELECT date, 'out' as flow_type,
        COALESCE(description, category) as description, amount
      FROM expenses
      WHERE date BETWEEN ? AND ?
    ''', [from.toIso8601String().substring(0, 10), to.toIso8601String().substring(0, 10)]);

    final all = [...cashSales, ...splitCash, ...expenses];
    all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return all;
  }

  // ── Bank Book ───────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBankBook(
      {required DateTime from, required DateTime to, String? mode}) async {
    final db = await _db.database;
    final modeFilter = mode != null
        ? "AND (LOWER(payment_mode) = LOWER(?))"
        : "AND LOWER(payment_mode) IN ('upi','card','bank','online')";
    final args = mode != null
        ? [from.toIso8601String(), to.toIso8601String(), mode]
        : [from.toIso8601String(), to.toIso8601String()];

    final digitalSales = await db.rawQuery('''
      SELECT created_at as date, 'in' as flow_type,
        payment_mode || ' Sale - Bill #' || bill_number as description, total_amount as amount
      FROM bills
      WHERE created_at BETWEEN ? AND ?
        AND (status IS NULL OR status != 'cancelled')
        $modeFilter
    ''', args);

    final splitDigital = await db.rawQuery('''
      SELECT b.created_at as date, 'in' as flow_type,
        bps.payment_mode || ' Split - Bill #' || b.bill_number as description, bps.amount as amount
      FROM bill_payment_splits bps
      JOIN bills b ON b.id = bps.bill_id
      WHERE b.created_at BETWEEN ? AND ?
        AND LOWER(bps.payment_mode) IN ('upi','card','bank','online')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final all = [...digitalSales, ...splitDigital];
    all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return all;
  }

  // ── Day Book ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDayBook(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    final bills = await db.rawQuery('''
      SELECT created_at as date, 'sale' as tx_type,
        'Sale - Bill #' || bill_number as description,
        total_amount as amount, payment_mode
      FROM bills
      WHERE created_at BETWEEN ? AND ? AND (status IS NULL OR status != 'cancelled')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final purchases = await db.rawQuery('''
      SELECT created_at as date, 'purchase' as tx_type,
        'Purchase - ' || COALESCE(supplier_name, purchase_number) as description,
        total_amount as amount, payment_mode
      FROM purchases
      WHERE created_at BETWEEN ? AND ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final expenses = await db.rawQuery('''
      SELECT date, 'expense' as tx_type,
        COALESCE(description, category) as description,
        amount, 'cash' as payment_mode
      FROM expenses
      WHERE date BETWEEN ? AND ?
    ''', [from.toIso8601String().substring(0, 10), to.toIso8601String().substring(0, 10)]);

    final returns = await db.rawQuery('''
      SELECT created_at as date, 'return' as tx_type,
        'Return - ' || COALESCE(original_bill_number, return_number) as description,
        total_return_amount as amount, refund_mode as payment_mode
      FROM sale_returns
      WHERE created_at BETWEEN ? AND ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final all = [...bills, ...purchases, ...expenses, ...returns];
    all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return all;
  }

  // ── Profit & Loss ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfitAndLoss(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;
    final incomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as income
      FROM ledger_entries
      WHERE created_at BETWEEN ? AND ?
        AND account_type = 'income'
        AND direction = 'credit'
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final cogsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as cogs
      FROM ledger_entries
      WHERE created_at BETWEEN ? AND ?
        AND account_type = 'cogs'
        AND direction = 'debit'
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final expensesResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as expenses
      FROM expenses
      WHERE date BETWEEN ? AND ?
    ''', [from.toIso8601String().substring(0, 10), to.toIso8601String().substring(0, 10)]);

    final returnsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as return_deductions
      FROM ledger_entries
      WHERE created_at BETWEEN ? AND ?
        AND account_type = 'income'
        AND direction = 'debit'
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final income = incomeResult.isNotEmpty ? (incomeResult.first['income'] as num).toDouble() : 0.0;
    final cogs = cogsResult.isNotEmpty ? (cogsResult.first['cogs'] as num).toDouble() : 0.0;
    final expenses = expensesResult.isNotEmpty ? (expensesResult.first['expenses'] as num).toDouble() : 0.0;
    final returnDeductions = returnsResult.isNotEmpty ? (returnsResult.first['return_deductions'] as num).toDouble() : 0.0;
    final netSales = income - returnDeductions;
    final grossProfit = netSales - cogs;
    final netProfit = grossProfit - expenses;

    return {
      'income': income,
      'return_deductions': returnDeductions,
      'net_sales': netSales,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'expenses': expenses,
      'net_profit': netProfit,
      'profit_margin': netSales > 0 ? (netProfit / netSales) * 100 : 0.0,
    };
  }

  // ── Wholesale / Retail Stock Report ─────────────────────────────────────────
  /// Returns stock report with wholesale+retail breakdown for products
  /// that have wholesaleToRetailQty > 1
  Future<List<Map<String, dynamic>>> getWholesaleRetailStockReport() async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT 
        p.id, p.name, p.stock_quantity,
        p.wholesale_unit, p.retail_unit, p.wholesale_to_retail_qty,
        p.wholesale_price, p.retail_price,
        COALESCE(SUM(CASE WHEN IFNULL(bi.sale_type, 'retail') = 'wholesale' THEN bi.quantity ELSE 0 END), 0) as total_wholesale_sold,
        COALESCE(SUM(CASE WHEN IFNULL(bi.sale_type, 'retail') = 'retail' THEN bi.quantity ELSE 0 END), 0) as total_retail_sold,
        COALESCE(pur.total_purchased_bags, 0) as total_purchased_bags
      FROM products p
      LEFT JOIN bill_items bi ON bi.product_id = p.id
      LEFT JOIN bills b ON b.id = bi.bill_id AND (b.status IS NULL OR b.status != 'cancelled')
      LEFT JOIN (
        SELECT pi.product_id, SUM(pi.quantity) as total_purchased_bags
        FROM purchase_items pi
        GROUP BY pi.product_id
      ) pur ON pur.product_id = p.id
      WHERE p.wholesale_to_retail_qty > 1.0 AND p.is_active = 1
      GROUP BY p.id, p.name
      ORDER BY p.name ASC
    ''');
  }

  // ── Purchase Report ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPurchaseReport({
    DateTime? from,
    DateTime? to,
    int? supplierId,
    int? productId,
    int? categoryId,
  }) async {
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();
    final fStr = f.toIso8601String().substring(0, 10);
    final tStr = t.toIso8601String().substring(0, 10);

    if (await _isOnlineMode()) {
      // Fetch enough rows to cover any date range; product/category id filters
      // are not applied in online mode because the backend uses UUID keys that
      // cannot be trivially mapped to local SQLite ids here.
      final purchases = await _fetchOnlineRows(
        'purchases',
        queryParameters: {'limit': 5000},
        listKey: 'purchases',
      );
      final rows = <Map<String, dynamic>>[];
      for (final purchase in purchases) {
        final purchaseDateRaw =
            (purchase['purchaseDate'] ?? purchase['purchase_date'] ?? '')
                .toString();
        final purchaseDateStr =
            purchaseDateRaw.substring(0, purchaseDateRaw.length.clamp(0, 10));
        if (purchaseDateStr.compareTo(fStr) < 0 ||
            purchaseDateStr.compareTo(tStr) > 0) continue;
        final purchaseSupplierName =
            (purchase['supplierName'] ?? purchase['supplier_name'])
                    ?.toString() ??
                'N/A';
        // Supplier id filter — apply by name when set in online mode.
        if (supplierId != null) {
          // supplierId is a local SQLite id; supplier filtering is unavailable
          // in online mode (no stable mapping). Skip the filter gracefully.
        }
        final paymentMode =
            (purchase['paymentMode'] ?? purchase['payment_mode'] ?? 'cash')
                .toString();
        final purchaseNumber =
            (purchase['purchaseNumber'] ?? purchase['purchase_number'] ?? '')
                .toString();
        final items = ((purchase['items'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        for (final item in items) {
          final itemProductName =
              (item['productName'] ?? item['product_name'] ?? 'Unknown')
                  .toString();
          rows.add({
            'item_id': null,
            'product_id': null,
            'product_name': itemProductName,
            'quantity': _toDouble(item['quantity']),
            'unit': (item['unit'] ?? '').toString(),
            'unit_cost': _toDouble(item['unitCost'] ?? item['unit_cost']),
            'total_cost': _toDouble(item['totalCost'] ?? item['total_cost']),
            'purchase_number': purchaseNumber,
            'purchase_date': purchaseDateRaw,
            'supplier_name': purchaseSupplierName,
            'payment_mode': paymentMode,
            'category_name': 'N/A',
          });
        }
      }
      rows.sort((a, b) => (b['purchase_date']?.toString() ?? '')
          .compareTo(a['purchase_date']?.toString() ?? ''));
      return rows;
    }

    final db = await _db.database;

    // Use substr so that full ISO timestamps (e.g. "2026-06-13T11:00:00")
    // compare correctly against the date-only bounds.
    String where = "substr(p.purchase_date, 1, 10) BETWEEN ? AND ?";
    final args = <dynamic>[fStr, tStr];

    if (supplierId != null) {
      where += " AND p.supplier_id = ?";
      args.add(supplierId);
    }
    if (productId != null) {
      where += " AND pi.product_id = ?";
      args.add(productId);
    }
    if (categoryId != null) {
      where += " AND pr.category_id = ?";
      args.add(categoryId);
    }

    return db.rawQuery('''
      SELECT 
        pi.id as item_id,
        pi.product_id,
        pi.product_name,
        pi.quantity,
        pi.unit,
        pi.unit_cost,
        pi.total_cost,
        p.purchase_number,
        p.purchase_date,
        COALESCE(p.supplier_name, 'N/A') as supplier_name,
        p.payment_mode,
        COALESCE(c.name, 'Uncategorized') as category_name
      FROM purchase_items pi
      JOIN purchases p ON p.id = pi.purchase_id
      LEFT JOIN products pr ON pr.id = pi.product_id
      LEFT JOIN categories c ON c.id = pr.category_id
      WHERE $where
      ORDER BY p.purchase_date DESC, p.id DESC
    ''', args);
  }

  // ── Product Stock & Sales Report ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getProductStockSalesReport({
    DateTime? from,
    DateTime? to,
    int? productId,
    int? categoryId,
  }) async {
    if (await _isOnlineMode()) {
      final fStr = from?.toIso8601String().substring(0, 10) ?? '';
      final tStr = to?.toIso8601String().substring(0, 10) ?? '';
      
      final queryParams = <String, dynamic>{};
      if (fStr.isNotEmpty) queryParams['from'] = fStr;
      if (tStr.isNotEmpty) queryParams['to'] = tStr;
      if (productId != null) queryParams['productId'] = productId.toString();
      if (categoryId != null) queryParams['categoryId'] = categoryId.toString();

      final results = await _fetchOnlineRows(
        'reports/inventory-dashboard',
        queryParameters: queryParams,
        listKey: 'reports',
      );

      final rows = <Map<String, dynamic>>[];
      for (final item in results) {
        rows.add({
          'id': item['id'],
          'name': item['name'],
          'unit': item['unit'],
          'wholesale_unit': item['wholesale_unit'] ?? item['wholesaleUnit'],
          'retail_unit': item['retail_unit'] ?? item['retailUnit'],
          'wholesale_to_retail_qty': _toDouble(item['wholesale_to_retail_qty'] ?? item['wholesaleToRetailQty']),
          'selling_price': _toDouble(item['selling_price'] ?? item['sellingPrice']),
          'retail_price': _toDouble(item['retail_price'] ?? item['retailPrice']),
          'wholesale_price': _toDouble(item['wholesale_price'] ?? item['wholesalePrice']),
          'current_stock': _toDouble(item['current_stock'] ?? item['currentStock']),
          'total_purchased_qty': _toDouble(item['total_purchased_qty'] ?? item['totalPurchasedQty']),
          'total_purchase_value': _toDouble(item['total_purchase_value'] ?? item['totalPurchaseValue']),
          'total_wholesale_sold_qty': _toDouble(item['total_wholesale_sold_qty'] ?? item['totalWholesaleSoldQty']),
          'total_wholesale_sold_value': _toDouble(item['total_wholesale_sold_value'] ?? item['totalWholesaleSoldValue']),
          'total_retail_sold_qty': _toDouble(item['total_retail_sold_qty'] ?? item['totalRetailSoldQty']),
          'total_retail_sold_value': _toDouble(item['total_retail_sold_value'] ?? item['totalRetailSoldValue']),
          'total_sold_base_qty': _toDouble(item['total_sold_base_qty'] ?? item['totalSoldBaseQty']),
          'category_name': item['category_name'] ?? item['categoryName'] ?? 'Uncategorized',
        });
      }
      return rows;
    }
    final db = await _db.database;
    final f = from ?? DateTime(2020);
    final t = to ?? DateTime.now();
    final fStr = f.toIso8601String().substring(0, 10);
    final tStr = t.toIso8601String().substring(0, 10);

    String outerWhere = "p.is_active = 1";
    final args = <dynamic>[fStr, tStr, fStr, tStr, fStr, tStr];

    if (productId != null) {
      outerWhere += " AND p.id = ?";
      args.add(productId);
    }
    if (categoryId != null) {
      outerWhere += " AND p.category_id = ?";
      args.add(categoryId);
    }

    return db.rawQuery('''
      SELECT
        p.id,
        p.name,
        COALESCE(p.unit, 'pcs') as unit,
        CASE
          WHEN COALESCE(p.wholesale_to_retail_qty, 1.0) > 1.0
            THEN COALESCE(NULLIF(TRIM(p.wholesale_unit), ''), COALESCE(p.unit, 'pcs'))
          ELSE COALESCE(p.unit, 'pcs')
        END as wholesale_unit,
        CASE
          WHEN COALESCE(p.wholesale_to_retail_qty, 1.0) > 1.0
            THEN COALESCE(NULLIF(TRIM(p.retail_unit), ''), COALESCE(p.unit, 'pcs'))
          ELSE COALESCE(p.unit, 'pcs')
        END as retail_unit,
        COALESCE(p.wholesale_to_retail_qty, 1.0) as wholesale_to_retail_qty,
        p.selling_price,
        COALESCE(p.retail_price, p.selling_price) as retail_price,
        p.wholesale_price,
        CASE
          WHEN LOWER(COALESCE(p.unit, '')) IN ('kg', 'kilogram', 'l', 'litre', 'liter')
            THEN p.stock_quantity / 1000.0
          ELSE p.stock_quantity
        END as current_stock,

        COALESCE(pur.total_purchased_qty, 0) as total_purchased_qty,
        COALESCE(pur.total_purchase_value, 0) as total_purchase_value,

        COALESCE(wsales.total_wholesale_qty, 0) as total_wholesale_sold_qty,
        COALESCE(wsales.total_wholesale_value, 0) as total_wholesale_sold_value,

        COALESCE(rsales.total_retail_qty, 0) as total_retail_sold_qty,
        COALESCE(rsales.total_retail_value, 0) as total_retail_sold_value,

        COALESCE(
          (COALESCE(wsales.total_wholesale_qty,0) * COALESCE(p.wholesale_to_retail_qty,1.0))
          + COALESCE(rsales.total_retail_qty, 0),
          0
        ) as total_sold_base_qty,

        COALESCE(c.name, 'Uncategorized') as category_name

      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id

      LEFT JOIN (
        SELECT pi.product_id,
          SUM(pi.quantity) as total_purchased_qty,
          SUM(pi.total_cost) as total_purchase_value
        FROM purchase_items pi
        JOIN purchases pu ON pu.id = pi.purchase_id
        WHERE pu.purchase_date BETWEEN ? AND ?
        GROUP BY pi.product_id
      ) pur ON pur.product_id = p.id

      LEFT JOIN (
        SELECT bi.product_id,
          SUM(bi.quantity) as total_wholesale_qty,
          SUM(bi.total_price) as total_wholesale_value
        FROM bill_items bi
        JOIN bills b ON b.id = bi.bill_id
        WHERE DATE(b.created_at) BETWEEN ? AND ?
          AND COALESCE(bi.sale_type, 'retail') = 'wholesale'
          AND (b.status IS NULL OR b.status != 'cancelled')
        GROUP BY bi.product_id
      ) wsales ON wsales.product_id = p.id

      LEFT JOIN (
        SELECT bi.product_id,
          SUM(bi.quantity) as total_retail_qty,
          SUM(bi.total_price) as total_retail_value
        FROM bill_items bi
        JOIN bills b ON b.id = bi.bill_id
        WHERE DATE(b.created_at) BETWEEN ? AND ?
          AND COALESCE(bi.sale_type, 'retail') != 'wholesale'
          AND (b.status IS NULL OR b.status != 'cancelled')
        GROUP BY bi.product_id
      ) rsales ON rsales.product_id = p.id

      WHERE $outerWhere
      ORDER BY p.name ASC
    ''', args);
  }

  // ── Filter Dropdown Helpers ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllSuppliers() async {
    if (await _isOnlineMode()) return const <Map<String, dynamic>>[];
    final db = await _db.database;
    return db.query('suppliers', where: 'is_active = 1', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    if (await _isOnlineMode()) return const <Map<String, dynamic>>[];
    final db = await _db.database;
    return db.query('categories', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getAllProductsForFilter() async {
    if (await _isOnlineMode()) return const <Map<String, dynamic>>[];
    final db = await _db.database;
    return db.query('products',
        where: 'is_active = 1',
        columns: ['id', 'name'],
        orderBy: 'name ASC');
  }

  // ── Theoretical Yield Report ─────────────────────────────────────────────────
  /// Returns composite_recipe products with their theoretical yield based on
  /// current ingredient stock. Each row contains name, unit, max_yield,
  /// limiting_ingredient, bom_cost, and selling_price.
  Future<List<Map<String, dynamic>>> getTheoreticalYieldReport() async {
    if (await _isOnlineMode()) {
      return const <Map<String, dynamic>>[];
    }
    final db = await _db.database;
    // Fetch all composite_recipe products (v12+; graceful fallback for older DBs)
    List<Map<String, dynamic>> recipes;
    try {
      recipes = await db.rawQuery(
          "SELECT id, name, unit, selling_price, attributes FROM products "
          "WHERE item_type = 'composite_recipe' AND is_active = 1");
    } catch (_) {
      return []; // item_type column not yet added
    }
    if (recipes.isEmpty) return [];

    // Fetch current stock for all products
    final stockRows = await db.rawQuery(
        "SELECT id, stock_quantity, unit FROM products WHERE is_active = 1");
    final stockMap = <int, double>{
      for (final r in stockRows)
        (r['id'] as int): UomConversionHelper.toUser(
            (r['stock_quantity'] as num).toDouble(),
            r['unit'] as String? ?? 'piece')
    };

    final results = <Map<String, dynamic>>[];
    for (final recipe in recipes) {
      final attributesStr = recipe['attributes'] as String? ?? '{}';
      late final List<dynamic> bomRaw;
      try {
        final decoded = jsonDecode(attributesStr) as Map<String, dynamic>?;
        bomRaw = decoded?['bom'] as List<dynamic>? ?? [];
      } catch (_) {
        bomRaw = [];
      }
      if (bomRaw.isEmpty) continue;

      double maxYield = double.infinity;
      String? limitingIngredient;
      double bomCost = 0;

      for (final ingRaw in bomRaw) {
        final ing = ingRaw as Map<String, dynamic>;
        final productId = ing['product_id'] as int?;
        final qty = (ing['quantity'] as num?)?.toDouble() ?? 0;
        final unitCost = (ing['unit_cost'] as num?)?.toDouble() ?? 0;
        bomCost += qty * unitCost;
        if (productId == null || qty <= 0) continue;
        final avail = stockMap[productId] ?? 0;
        final possible = avail / qty;
        if (possible < maxYield) {
          maxYield = possible;
          limitingIngredient = ing['product_name'] as String?;
        }
      }

      if (maxYield == double.infinity) maxYield = 0;

      results.add({
        'id': recipe['id'],
        'name': recipe['name'],
        'unit': recipe['unit'],
        'selling_price': recipe['selling_price'],
        'bom_cost': bomCost,
        'max_yield': maxYield.floorToDouble(),
        'limiting_ingredient': maxYield == 0 ? limitingIngredient : null,
      });
    }
    return results;
  }

  // ── Phase 4: Ledger-based Profit & Loss ─────────────────────────────────────
  /// Aggregates P&L from ledger_entries (double-entry sub-ledger introduced in
  /// Phase 1). Falls back to the legacy query when no ledger rows exist.
  Future<Map<String, dynamic>> getProfitAndLossFromLedger(
      {required DateTime from, required DateTime to}) async {
    final db = await _db.database;

    // Check if ledger_entries table exists and has data in range
    int ledgerCount = 0;
    try {
      final check = await db.rawQuery(
          "SELECT COUNT(*) as cnt FROM ledger_entries WHERE created_at BETWEEN ? AND ?",
          [from.toIso8601String(), to.toIso8601String()]);
      ledgerCount = check.isNotEmpty ? (check.first['cnt'] as int? ?? 0) : 0;
    } catch (_) {}

    if (ledgerCount == 0) {
      // Fall back to legacy bills/expenses query
      return getProfitAndLoss(from: from, to: to);
    }

    // Aggregate by account_type + direction from ledger_entries.
    final rows = await db.rawQuery('''
      SELECT le.account_type, le.direction, SUM(le.amount) as total
      FROM ledger_entries le
      JOIN erp_transactions et ON et.id = le.transaction_id
      WHERE le.created_at BETWEEN ? AND ?
      GROUP BY le.account_type, le.direction
    ''', [from.toIso8601String(), to.toIso8601String()]);

    double income = 0;
    double returnDeductions = 0;
    double cogs = 0;
    double expenses = 0;
    double waste = 0;
    for (final r in rows) {
      final type = r['account_type'] as String? ?? '';
      final direction = r['direction'] as String? ?? '';
      final amount = (r['total'] as num?)?.toDouble() ?? 0;
      if (type == 'income' && direction == 'credit') income += amount;
      if (type == 'income' && direction == 'debit') returnDeductions += amount;
      if (type == 'cogs' && direction == 'debit') cogs += amount;
      if (type == 'expense' && direction == 'debit') expenses += amount;
      if (type == 'waste' && direction == 'debit') waste += amount;
    }

    final netSales = income - returnDeductions;
    final grossProfit = netSales - cogs;
    final netProfit = grossProfit - expenses - waste;

    return {
      'income': income,
      'return_deductions': returnDeductions,
      'net_sales': netSales,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'expenses': expenses,
      'waste': waste,
      'net_profit': netProfit,
      'profit_margin': netSales > 0 ? (netProfit / netSales) * 100 : 0.0,
      'source': 'ledger',
    };
  }

  // ── Ledger Balances (account-wise totals) ────────────────────────────────────
  /// Returns current balance for each account_type, aggregated from
  /// [ledger_entries]. Debit entries are positive, credit entries negative
  /// for asset/expense/cogs/inventory/waste accounts. For income/liability
  /// the balance is the net credit amount.
  ///
  /// In online-API mode the ledger_entries table is not populated; instead
  /// the figures are derived directly from bills (income, cogs, asset) and
  /// expense transactions fetched from the backend.
  Future<Map<String, double>> getLedgerBalances({
    DateTime? from,
    DateTime? to,
  }) async {
    final f = from ?? DateTime(2000);
    final t = to ?? DateTime.now();

    if (await _isOnlineMode()) {
      try {
        // ── Income & COGS from bills ──────────────────────────────────────
        final bills = await _fetchOnlineRows(
          'bills',
          queryParameters: {'limit': 1000},
          listKey: 'bills',
        );
        var income = 0.0, cogs = 0.0;
        for (final bill in bills) {
          if (_isCancelledStatus(bill['status'])) continue;
          final createdAt = _parseDate(bill['createdAt'] ?? bill['created_at']);
          if (!_isWithinRange(createdAt, f, t)) continue;
          income += _toDouble(bill['totalAmount'] ?? bill['total_amount']);
          final items = ((bill['items'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          for (final item in items) {
            cogs += _toDouble(item['purchasePrice'] ?? item['purchase_price']) *
                _toDouble(item['quantity']);
          }
        }
        // ── Expenses from transactions API ────────────────────────────────
        var expense = 0.0;
        try {
          final txns = await _fetchOnlineRows(
            'transactions',
            queryParameters: {'types': 'expense', 'limit': 500},
            listKey: 'transactions',
          );
          for (final txn in txns) {
            final createdAt =
                _parseDate(txn['createdAt'] ?? txn['created_at']);
            if (!_isWithinRange(createdAt, f, t)) continue;
            expense +=
                _toDouble(txn['totalAmount'] ?? txn['total_amount']);
          }
        } catch (e, st) {
          debugPrint('[ReportRepository] getLedgerBalances expense fetch failed: $e\n$st');
        }
        return {
          'income': income,
          'cogs': cogs,
          'expense': expense,
          'inventory': 0.0,
          // In online mode asset = income (cash/bank received equals billed revenue;
          // receivables are tracked separately via customer outstanding balances).
          'asset': income,
          'liability': 0.0,
          'waste': 0.0,
        };
      } catch (e, st) {
        debugPrint('[ReportRepository] getLedgerBalances online mode failed: $e\n$st');
        return {
          'income': 0.0, 'cogs': 0.0, 'expense': 0.0, 'inventory': 0.0,
          'asset': 0.0, 'liability': 0.0, 'waste': 0.0,
        };
      }
    }

    final db = await _db.database;
    try {
      final rows = await db.rawQuery('''
        SELECT account_type,
               direction,
               COALESCE(SUM(amount), 0) as total
        FROM ledger_entries
        WHERE created_at BETWEEN ? AND ?
        GROUP BY account_type, direction
      ''', [f.toIso8601String(), t.toIso8601String()]);

      final map = <String, double>{
        'income': 0.0, 'cogs': 0.0, 'expense': 0.0,
        'inventory': 0.0, 'asset': 0.0, 'liability': 0.0, 'waste': 0.0,
      };
      for (final r in rows) {
        final type = r['account_type'] as String;
        final dir = r['direction'] as String? ?? 'debit';
        final amt = (r['total'] as num).toDouble();
        final current = map[type] ?? 0.0;
        // Credit income/liability = positive balance; debit = negative balance
        if (type == 'income' || type == 'liability') {
          map[type] = current + (dir == 'credit' ? amt : -amt);
        } else {
          map[type] = current + (dir == 'debit' ? amt : -amt);
        }
      }
      return map;
    } catch (_) {
      return {'income': 0.0, 'cogs': 0.0, 'expense': 0.0, 'inventory': 0.0,
              'asset': 0.0, 'liability': 0.0, 'waste': 0.0};
    }
  }

  // ── Trial Balance ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTrialBalance({
    required DateTime from,
    required DateTime to,
  }) async {
    final balances = await getLedgerBalances(from: from, to: to);
    final totalDebits = (balances['asset'] ?? 0) + (balances['cogs'] ?? 0) +
        (balances['expense'] ?? 0) + (balances['inventory'] ?? 0) +
        (balances['waste'] ?? 0);
    final totalCredits = (balances['income'] ?? 0) + (balances['liability'] ?? 0);
    return {
      ...balances,
      'total_debits': totalDebits,
      'total_credits': totalCredits,
      'is_balanced': (totalDebits - totalCredits).abs() < 0.01,
    };
  }

  // ── Customer Dr/Cr Ledger ────────────────────────────────────────────────────
  /// Returns a chronological Dr/Cr statement for a customer with running balance.
  /// Sources: bills (Dr), payments recorded in bill_payment_splits (Cr).
  Future<Map<String, dynamic>> getCustomerLedger(Object customerId) async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineRows(
        'bills',
        queryParameters: {'limit': 1000},
        listKey: 'bills',
      );
      List<Map<String, dynamic>> returns = const <Map<String, dynamic>>[];
      try {
        returns = await _fetchOnlineRows(
          'sale-returns',
          queryParameters: {'limit': 1000},
          listKey: 'saleReturns',
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[ReportRepository] getCustomerLedger sale-returns fetch failed: $error\n$stackTrace',
        );
        returns = const <Map<String, dynamic>>[];
      }

      final entries = <Map<String, dynamic>>[];
      for (final bill in bills) {
        if (_isCancelledStatus(bill['status'])) continue;
        final id = bill['customerId'] ?? bill['customer_id'];
        if (!_sameEntityId(id, customerId)) continue;
        entries.add({
          'date': bill['createdAt'] ?? bill['created_at'],
          'description':
              'Invoice #${bill['billNumber'] ?? bill['bill_number'] ?? '-'}',
          'debit': _toDouble(bill['totalAmount'] ?? bill['total_amount']),
          'credit': 0.0,
        });
      }
      for (final row in returns) {
        final id = row['customerId'] ?? row['customer_id'];
        if (!_sameEntityId(id, customerId)) continue;
        entries.add({
          'date': row['createdAt'] ?? row['created_at'],
          'description':
              'Return #${row['returnNumber'] ?? row['return_number'] ?? '-'}',
          'debit': 0.0,
          'credit':
              _toDouble(row['totalReturnAmount'] ?? row['total_return_amount']),
        });
      }
      entries.sort((a, b) =>
          (a['date']?.toString() ?? '').compareTo(b['date']?.toString() ?? ''));

      var balance = 0.0;
      final running = entries.map((row) {
        final debit = _toDouble(row['debit']);
        final credit = _toDouble(row['credit']);
        balance += debit - credit;
        return {
          'date': row['date'],
          'description': row['description'],
          'debit': debit,
          'credit': credit,
          'balance': balance,
        };
      }).toList();

      return {
        'customer': {'id': customerId},
        'opening_balance': 0.0,
        'entries': running,
        'closing_balance': balance,
      };
    }
    final db = await _db.database;
    final customerRows = await db.query('customers',
        where: 'id = ?', whereArgs: [customerId]);
    if (customerRows.isEmpty) return {'customer': {}, 'entries': [], 'closing_balance': 0.0};

    final customer = customerRows.first;
    final double openingBalance =
        (customer['outstanding_balance'] as num?)?.toDouble() ?? 0;

    // Bills (debit — customer owes)
    final bills = await db.rawQuery('''
      SELECT created_at as date,
             'Invoice #' || bill_number as description,
             total_amount as debit, 0.0 as credit
      FROM bills
      WHERE customer_id = ? AND (status IS NULL OR status != 'cancelled')
      ORDER BY created_at ASC
    ''', [customerId]);

    // Returns (credit — customer is owed)
    final returns = await db.rawQuery('''
      SELECT sr.created_at as date,
             'Return #' || sr.return_number as description,
             0.0 as debit, sr.total_return_amount as credit
      FROM sale_returns sr
      JOIN bills b ON b.id = sr.original_bill_id
      WHERE b.customer_id = ?
      ORDER BY sr.created_at ASC
    ''', [customerId]);

    final all = [...bills, ...returns];
    all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    // Compute running balance
    double balance = openingBalance;
    final entries = all.map((r) {
      final debit = (r['debit'] as num?)?.toDouble() ?? 0;
      final credit = (r['credit'] as num?)?.toDouble() ?? 0;
      balance += debit - credit;
      return {
        'date': r['date'],
        'description': r['description'],
        'debit': debit,
        'credit': credit,
        'balance': balance,
      };
    }).toList();

    return {
      'customer': customer,
      'opening_balance': openingBalance,
      'entries': entries,
      'closing_balance': balance,
    };
  }

  // ── Supplier Dr/Cr Ledger ────────────────────────────────────────────────────
  /// Returns a chronological Dr/Cr statement for a supplier with running balance.
  Future<Map<String, dynamic>> getSupplierLedger(int supplierId) async {
    final db = await _db.database;
    final supplierRows = await db.query('suppliers',
        where: 'id = ?', whereArgs: [supplierId]);
    if (supplierRows.isEmpty) return {'supplier': {}, 'entries': [], 'closing_balance': 0.0};

    final supplier = supplierRows.first;
    final double openingBalance =
        (supplier['outstanding_balance'] as num?)?.toDouble() ?? 0;

    // Purchases (credit — we owe supplier)
    final purchases = await db.rawQuery('''
      SELECT created_at as date,
             'Purchase #' || purchase_number as description,
             0.0 as debit, total_amount as credit
      FROM purchases
      WHERE supplier_id = ?
      ORDER BY created_at ASC
    ''', [supplierId]);

    double balance = openingBalance;
    final entries = (purchases as List<Map<String, dynamic>>).map((r) {
      final credit = (r['credit'] as num?)?.toDouble() ?? 0;
      balance += credit;
      return {
        'date': r['date'],
        'description': r['description'],
        'debit': 0.0,
        'credit': credit,
        'balance': balance,
      };
    }).toList();

    return {
      'supplier': supplier,
      'opening_balance': openingBalance,
      'entries': entries,
      'closing_balance': balance,
    };
  }

  // ── GSTR-1 Report ────────────────────────────────────────────────────────────
  /// Returns structured GSTR-1 data: B2B invoices, B2C invoices, HSN summary.
  Future<Map<String, dynamic>> getGstr1Report({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;

    // B2B — bills with customer GSTIN
    final b2b = await db.rawQuery('''
      SELECT b.bill_number, b.created_at, b.customer_name, b.customer_gstin,
             b.total_amount, b.gst_total, b.cgst_total, b.sgst_total, b.igst_total,
             b.total_amount - b.gst_total as taxable_value
      FROM bills b
      WHERE b.created_at BETWEEN ? AND ?
        AND b.customer_gstin IS NOT NULL
        AND (b.status IS NULL OR b.status != 'cancelled')
      ORDER BY b.created_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);

    // B2C — bills without GSTIN
    final b2cResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(b.total_amount - b.gst_total), 0) as taxable_value,
        COALESCE(SUM(b.cgst_total), 0) as cgst,
        COALESCE(SUM(b.sgst_total), 0) as sgst,
        COALESCE(SUM(b.igst_total), 0) as igst,
        COUNT(*) as invoice_count
      FROM bills b
      WHERE b.created_at BETWEEN ? AND ?
        AND (b.customer_gstin IS NULL OR b.customer_gstin = '')
        AND (b.status IS NULL OR b.status != 'cancelled')
    ''', [from.toIso8601String(), to.toIso8601String()]);

    // HSN-wise summary
    final hsn = await db.rawQuery('''
      SELECT COALESCE(p.hsn_code, 'N/A') as hsn_code,
             COALESCE(p.unit, 'Pcs') as unit,
             SUM(bi.quantity) as total_qty,
             SUM(bi.total_price - bi.gst_amount) as taxable_value,
             SUM(bi.gst_amount) as total_gst,
             bi.gst_rate
      FROM bill_items bi
      JOIN bills b ON b.id = bi.bill_id
      LEFT JOIN products p ON p.id = bi.product_id
      WHERE b.created_at BETWEEN ? AND ?
        AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY p.hsn_code, bi.gst_rate
      ORDER BY taxable_value DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);

    return {
      'period_from': from.toIso8601String().substring(0, 10),
      'period_to': to.toIso8601String().substring(0, 10),
      'b2b': b2b,
      'b2c': b2cResult.isNotEmpty ? b2cResult.first : {},
      'hsn_summary': hsn,
    };
  }

  // ── Day Close Summary ────────────────────────────────────────────────────────
  /// Computes all the numbers needed to close a business day.
  Future<Map<String, dynamic>> getDayCloseSummary(DateTime date) async {
    if (await _isOnlineMode()) {
      final dateStr = date.toIso8601String().substring(0, 10);
      final bills = await _fetchOnlineRows('bills', queryParameters: {'limit': 500}, listKey: 'bills');
      final expenses = await _fetchOnlineRows(
        'transactions',
        queryParameters: {'types': 'expense', 'limit': 500},
        listKey: 'transactions',
      );
      final returns = await _fetchOnlineRows(
        'sale-returns',
        queryParameters: {'limit': 500},
        listKey: 'saleReturns',
      );
      final purchases = await _fetchOnlineRows(
        'purchases',
        queryParameters: {'limit': 500},
        listKey: 'purchases',
      );

      var totalSales = 0.0;
      var billCount = 0;
      var cashSales = 0.0;
      var digitalSales = 0.0;
      for (final bill in bills) {
        if (!_matchesDate(bill, dateStr, ['createdAt', 'created_at'])) continue;
        final paymentMode =
            (bill['paymentMode'] ?? bill['payment_mode'] ?? 'cash').toString().toLowerCase();
        final amount = _toDouble(bill['totalAmount'] ?? bill['total_amount']);
        totalSales += amount;
        billCount += 1;
        if (paymentMode == 'cash') {
          cashSales += amount;
        } else if (paymentMode == 'split') {
          final splitCash = _cashFromSplitSummary(
            (bill['splitPaymentSummary'] ?? bill['split_payment_summary'])?.toString(),
          );
          cashSales += splitCash;
          digitalSales += (amount - splitCash);
        } else {
          digitalSales += amount;
        }
      }

      final totalExpenses = expenses.fold<double>(0.0, (sum, row) {
        final tags = _decodeMap(row['tagsJson'] ?? row['tags_json']);
        final rawDate = tags['date'] ?? row['createdAt'] ?? row['created_at'];
        return rawDate != null && rawDate.toString().startsWith(dateStr)
            ? sum + _toDouble(row['totalAmount'] ?? row['total_amount'])
            : sum;
      });
      final totalReturns = returns.fold<double>(0.0, (sum, row) {
        return _matchesDate(row, dateStr, ['createdAt', 'created_at'])
            ? sum + _toDouble(row['totalReturnAmount'] ?? row['total_return_amount'])
            : sum;
      });
      final totalPurchases = purchases.fold<double>(0.0, (sum, row) {
        final rawDate =
            row['purchaseDate'] ?? row['purchase_date'] ?? row['createdAt'] ?? row['created_at'];
        return rawDate != null && rawDate.toString().startsWith(dateStr)
            ? sum + _toDouble(row['totalAmount'] ?? row['total_amount'])
            : sum;
      });

      return {
        'date': dateStr,
        'total_sales': totalSales,
        'bill_count': billCount,
        'cash_sales': cashSales,
        'digital_sales': digitalSales,
        'total_expenses': totalExpenses,
        'total_returns': totalReturns,
        'total_purchases': totalPurchases,
        'net_cash': cashSales - totalExpenses,
      };
    }
    final db = await _db.database;
    final dateStr = date.toIso8601String().substring(0, 10);

    final salesResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total_amount), 0) as total_sales,
        COUNT(*) as bill_count,
        COALESCE(SUM(CASE WHEN LOWER(payment_mode) IN ('cash') THEN total_amount ELSE 0 END), 0) as cash_sales,
        COALESCE(SUM(CASE WHEN LOWER(payment_mode) NOT IN ('cash','split') THEN total_amount ELSE 0 END), 0) as digital_sales
      FROM bills
      WHERE DATE(created_at) = ? AND (status IS NULL OR status != 'cancelled')
    ''', [dateStr]);

    final splitCash = await db.rawQuery('''
      SELECT COALESCE(SUM(bps.amount), 0) as split_cash
      FROM bill_payment_splits bps
      JOIN bills b ON b.id = bps.bill_id
      WHERE DATE(b.created_at) = ? AND LOWER(bps.payment_mode) = 'cash'
    ''', [dateStr]);

    final expensesResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total_expenses
      FROM expenses WHERE DATE(date) = ?
    ''', [dateStr]);

    final returnsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_return_amount), 0) as total_returns
      FROM sale_returns WHERE DATE(created_at) = ?
    ''', [dateStr]);

    final purchasesResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total_purchases
      FROM purchases WHERE DATE(created_at) = ?
    ''', [dateStr]);

    final s = salesResult.isNotEmpty ? salesResult.first : <String, dynamic>{};
    final totalSales = (s['total_sales'] as num?)?.toDouble() ?? 0.0;
    final billCount = (s['bill_count'] as int?) ?? 0;
    final cashSales = (s['cash_sales'] as num?)?.toDouble() ?? 0.0 +
        (splitCash.isNotEmpty ? ((splitCash.first['split_cash'] as num?)?.toDouble() ?? 0) : 0.0);
    final digitalSales = (s['digital_sales'] as num?)?.toDouble() ?? 0.0;
    final expenses = expensesResult.isNotEmpty ? (expensesResult.first['total_expenses'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final returns = returnsResult.isNotEmpty ? (returnsResult.first['total_returns'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final purchases = purchasesResult.isNotEmpty ? (purchasesResult.first['total_purchases'] as num?)?.toDouble() ?? 0.0 : 0.0;

    return {
      'date': dateStr,
      'total_sales': totalSales,
      'bill_count': billCount,
      'cash_sales': cashSales,
      'digital_sales': digitalSales,
      'total_expenses': expenses,
      'total_returns': returns,
      'total_purchases': purchases,
      'net_cash': cashSales - expenses,
    };
  }

  // ── Day Close CRUD ───────────────────────────────────────────────────────────
  Future<bool> isDayClosed(DateTime date) async {
    if (await _isOnlineMode()) {
      final dateStr = date.toIso8601String().substring(0, 10);
      final rows = await _fetchOnlineRows(
        'day-close',
        queryParameters: {'limit': 60},
        listKey: 'dayCloseRecords',
      );
      return rows.any(
        (row) => (row['closeDate'] ?? row['close_date'])?.toString() == dateStr,
      );
    }
    final db = await _db.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query('day_close',
        where: 'close_date = ?', whereArgs: [dateStr]);
    return rows.isNotEmpty;
  }

  Future<void> saveCloseDay({
    required DateTime date,
    required double cashOpening,
    required double cashClosing,
    required Map<String, dynamic> summary,
    String? notes,
    String? closedBy,
  }) async {
    if (await _isOnlineMode()) {
      final dateStr = date.toIso8601String().substring(0, 10);
      final cashVariance = cashClosing -
          (cashOpening + (summary['cash_sales'] as num).toDouble() -
              (summary['total_expenses'] as num).toDouble());
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'day-close/upsert',
          data: {
            'clientRecordId': _uuid.v5(Uuid.NAMESPACE_URL, 'day-close:$dateStr'),
            'closeDate': dateStr,
            'cashOpening': cashOpening,
            'cashClosing': cashClosing,
            'cashVariance': cashVariance,
            'totalSales': summary['total_sales'],
            'totalExpenses': summary['total_expenses'],
            'totalReturns': summary['total_returns'],
            'totalPurchases': summary['total_purchases'],
            'cashSales': summary['cash_sales'],
            'digitalSales': summary['digital_sales'],
            'billCount': summary['bill_count'],
            'notes': notes,
            'closedBy': closedBy,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      }, allowManagementCalls: true);
      return;
    }
    final db = await _db.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final cashVariance = cashClosing -
        (cashOpening + (summary['cash_sales'] as num).toDouble() -
            (summary['total_expenses'] as num).toDouble());
    await db.insert('day_close', {
      'close_date': dateStr,
      'cash_opening': cashOpening,
      'cash_closing': cashClosing,
      'cash_variance': cashVariance,
      'total_sales': summary['total_sales'],
      'total_expenses': summary['total_expenses'],
      'total_returns': summary['total_returns'],
      'total_purchases': summary['total_purchases'],
      'cash_sales': summary['cash_sales'],
      'digital_sales': summary['digital_sales'],
      'bill_count': summary['bill_count'],
      'notes': notes,
      'closed_by': closedBy,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getDayCloseHistory({int limit = 30}) async {
    if (await _isOnlineMode()) {
      final rows = await _fetchOnlineRows(
        'day-close',
        queryParameters: {'limit': limit},
        listKey: 'dayCloseRecords',
      );
      return rows
          .map((row) => <String, dynamic>{
                'close_date': row['closeDate'] ?? row['close_date'],
                'cash_opening': _toDouble(row['cashOpening'] ?? row['cash_opening']),
                'cash_closing': _toDouble(row['cashClosing'] ?? row['cash_closing']),
                'cash_variance':
                    _toDouble(row['cashVariance'] ?? row['cash_variance']),
                'total_sales': _toDouble(row['totalSales'] ?? row['total_sales']),
                'total_expenses':
                    _toDouble(row['totalExpenses'] ?? row['total_expenses']),
                'total_returns':
                    _toDouble(row['totalReturns'] ?? row['total_returns']),
                'total_purchases':
                    _toDouble(row['totalPurchases'] ?? row['total_purchases']),
                'cash_sales': _toDouble(row['cashSales'] ?? row['cash_sales']),
                'digital_sales':
                    _toDouble(row['digitalSales'] ?? row['digital_sales']),
                'bill_count': row['billCount'] ?? row['bill_count'] ?? 0,
                'notes': row['notes'],
                'closed_by': row['closedBy'] ?? row['closed_by'],
                'created_at': row['createdAt'] ?? row['created_at'],
              })
          .toList();
    }
    final db = await _db.database;
    try {
      return db.query('day_close', orderBy: 'close_date DESC', limit: limit);
    } catch (_) { return []; }
  }
}
