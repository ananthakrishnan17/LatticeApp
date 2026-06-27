import 'package:dio/dio.dart' show Options;
import '../../../../core/backend/backend_api_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/data_access_mode_service.dart';

abstract class SalesRepository {
  Future<Map<String, double>> getDailySummary(DateTime date);
  Future<Map<String, double>> getMonthlySummary(int year, int month);
  Future<List<Map<String, double>>> getLast7DaysSales();
  Future<Map<String, double>> getTodaySettlementByPaymentMode(DateTime date);
  Future<List<Map<String, dynamic>>> getProductWiseSales(DateTime from, DateTime to);
  Future<List<Map<String, dynamic>>> getDailyReport(DateTime date);
}

class SalesRepositoryImpl implements SalesRepository {
  final DatabaseHelper _dbHelper;
  SalesRepositoryImpl(this._dbHelper);

  Future<bool> _isOnlineMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.onlineApi;

  Future<List<Map<String, dynamic>>> _fetchOnlineBills() async {
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
    return ((body['bills'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  bool _isCancelledBill(Map<String, dynamic> bill) {
    final status = (bill['status'] ?? '').toString().toLowerCase().trim();
    return status == 'cancelled' || status == 'canceled';
  }

  @override
  Future<Map<String, double>> getDailySummary(DateTime date) async {
    if (await _isOnlineMode()) {
      final dateStr = date.toIso8601String().substring(0, 10);
      final bills = await _fetchOnlineBills();
      final todayBills = bills
          .where((bill) =>
              (bill['createdAt'] ?? bill['created_at'] ?? '')
                  .toString()
                  .startsWith(dateStr))
          .where((bill) => !_isCancelledBill(bill))
          .toList();
      return {
        'sales': todayBills.fold<double>(
          0.0,
          (sum, bill) =>
              sum +
              (((bill['totalAmount'] ?? bill['total_amount']) as num?)
                      ?.toDouble() ??
                  0.0),
        ),
        'profit': todayBills.fold<double>(
          0.0,
          (sum, bill) => sum + (((bill['totalProfit'] ?? bill['total_profit']) as num?)?.toDouble() ?? 0.0),
        ),
        'billCount': todayBills.length.toDouble(),
      };
    }
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0.0) as total_sales,
        COALESCE(SUM(total_profit), 0.0) as total_profit,
        COUNT(*) as bill_count
      FROM bills
      WHERE created_at LIKE ?
        AND (status IS NULL OR LOWER(status) NOT IN ('cancelled', 'canceled'))
    ''', ['$dateStr%']);
    final row = result.first;
    return {
      'sales': (row['total_sales'] as num).toDouble(),
      'profit': (row['total_profit'] as num).toDouble(),
      'billCount': (row['bill_count'] as num).toDouble(),
    };
  }

  @override
  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    if (await _isOnlineMode()) {
      final prefix = '$year-${month.toString().padLeft(2, '0')}';
      final bills = await _fetchOnlineBills();
      final monthlyBills = bills
          .where((bill) =>
              (bill['createdAt'] ?? bill['created_at'] ?? '')
                  .toString()
                  .startsWith(prefix))
          .where((bill) => !_isCancelledBill(bill))
          .toList();
      return {
        'sales': monthlyBills.fold<double>(
          0.0,
          (sum, bill) =>
              sum +
              (((bill['totalAmount'] ?? bill['total_amount']) as num?)
                      ?.toDouble() ??
                  0.0),
        ),
        'profit': monthlyBills.fold<double>(
          0.0,
          (sum, bill) => sum + (((bill['totalProfit'] ?? bill['total_profit']) as num?)?.toDouble() ?? 0.0),
        ),
        'billCount': monthlyBills.length.toDouble(),
      };
    }
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0.0) as total_sales,
        COALESCE(SUM(total_profit), 0.0) as total_profit,
        COUNT(*) as bill_count
      FROM bills
      WHERE created_at LIKE ?
        AND (status IS NULL OR LOWER(status) NOT IN ('cancelled', 'canceled'))
    ''', ['$prefix%']);
    final row = result.first;
    return {
      'sales': (row['total_sales'] as num).toDouble(),
      'profit': (row['total_profit'] as num).toDouble(),
      'billCount': (row['bill_count'] as num).toDouble(),
    };
  }

  @override
  Future<List<Map<String, double>>> getLast7DaysSales() async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineBills();
      final result = <Map<String, double>>[];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr = date.toIso8601String().substring(0, 10);
        final filtered = bills.where((bill) {
          return (bill['createdAt'] ?? bill['created_at'] ?? '')
              .toString()
              .startsWith(dateStr) &&
              !_isCancelledBill(bill);
        });
        result.add({
          'sales': filtered.fold<double>(
            0.0,
            (sum, bill) => sum + (((bill['totalAmount'] ?? bill['total_amount']) as num?)?.toDouble() ?? 0.0),
          ),
          'profit': filtered.fold<double>(
            0.0,
            (sum, bill) => sum + (((bill['totalProfit'] ?? bill['total_profit']) as num?)?.toDouble() ?? 0.0),
          ),
        });
      }
      return result;
    }
    final db = await _dbHelper.database;
    final result = <Map<String, double>>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);
      final rows = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount), 0.0) as sales,
               COALESCE(SUM(total_profit), 0.0) as profit
       FROM bills
       WHERE created_at LIKE ?
         AND (status IS NULL OR LOWER(status) NOT IN ('cancelled', 'canceled'))
      ''', ['$dateStr%']);
      result.add({
        'sales': (rows.first['sales'] as num).toDouble(),
        'profit': (rows.first['profit'] as num).toDouble(),
      });
    }
    return result;
  }

  @override
  Future<Map<String, double>> getTodaySettlementByPaymentMode(DateTime date) async {
    if (await _isOnlineMode()) {
      final dateStr = date.toIso8601String().substring(0, 10);
      final bills = await _fetchOnlineBills();
      final totals = <String, double>{
        'cash': 0.0,
        'upi': 0.0,
        'card': 0.0,
        'credit': 0.0,
        'other': 0.0,
      };
      for (final bill in bills) {
        final createdAt = (bill['createdAt'] ?? bill['created_at'] ?? '').toString();
        if (!createdAt.startsWith(dateStr)) continue;
        final mode = (bill['paymentMode'] ?? bill['payment_mode'] ?? 'other')
            .toString()
            .toLowerCase();
        final key = totals.containsKey(mode) ? mode : 'other';
        totals[key] = totals[key]! +
            (((bill['totalAmount'] ?? bill['total_amount']) as num?)?.toDouble() ?? 0.0);
      }
      return totals;
    }
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final nonSplit = await db.rawQuery('''
      SELECT LOWER(payment_mode) AS payment_mode, COALESCE(SUM(total_amount), 0) AS total
      FROM bills
      WHERE created_at LIKE ?
        AND (status IS NULL OR status != 'cancelled')
        AND LOWER(payment_mode) != 'split'
      GROUP BY LOWER(payment_mode)
    ''', ['$dateStr%']);

    final split = await db.rawQuery('''
      SELECT LOWER(bps.payment_mode) AS payment_mode, COALESCE(SUM(bps.amount), 0) AS total
      FROM bill_payment_splits bps
      JOIN bills b ON b.id = bps.bill_id
      WHERE b.created_at LIKE ?
        AND (b.status IS NULL OR b.status != 'cancelled')
      GROUP BY LOWER(bps.payment_mode)
    ''', ['$dateStr%']);

    final totals = <String, double>{
      'cash': 0.0,
      'upi': 0.0,
      'card': 0.0,
      'credit': 0.0,
      'other': 0.0,
    };
    void accumulate(Map<String, Object?> row) {
      final mode = row['payment_mode'] as String? ?? '';
      final key = totals.containsKey(mode) ? mode : 'other';
      totals[key] = totals[key]! + ((row['total'] as num?)?.toDouble() ?? 0.0);
    }
    for (final row in nonSplit) {
      accumulate(row);
    }
    for (final row in split) {
      accumulate(row);
    }
    return totals;
  }

  @override
  Future<List<Map<String, dynamic>>> getProductWiseSales(DateTime from, DateTime to) async {
    if (await _isOnlineMode()) {
      final bills = await _fetchOnlineBills();
      final totals = <String, Map<String, dynamic>>{};
      for (final bill in bills) {
        final createdAt =
            DateTime.tryParse((bill['createdAt'] ?? bill['created_at'] ?? '').toString());
        if (createdAt == null || createdAt.isBefore(from) || createdAt.isAfter(to)) {
          continue;
        }
        final items = (bill['items'] as List?) ?? const <dynamic>[];
        for (final rawItem in items.whereType<Map>()) {
          final item = Map<String, dynamic>.from(rawItem);
          final name = (item['product_name'] ?? item['productName'] ?? '').toString();
          final qty = ((item['quantity'] as num?)?.toDouble() ?? 0.0);
          final revenue = ((item['total_price'] ?? item['totalPrice']) as num?)?.toDouble() ?? 0.0;
          final profit = ((((item['unit_price'] ?? item['unitPrice']) as num?)?.toDouble() ?? 0.0) -
                  (((item['purchase_price'] ?? item['purchasePrice']) as num?)?.toDouble() ?? 0.0)) *
              qty;
          final current = totals.putIfAbsent(name, () => {
                'product_name': name,
                'total_qty': 0.0,
                'total_revenue': 0.0,
                'total_profit': 0.0,
                'bill_count': 0,
              });
          current['total_qty'] = (current['total_qty'] as double) + qty;
          current['total_revenue'] = (current['total_revenue'] as double) + revenue;
          current['total_profit'] = (current['total_profit'] as double) + profit;
          current['bill_count'] = (current['bill_count'] as int) + 1;
        }
      }
      final values = totals.values.toList();
      values.sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
      return values;
    }
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT 
        bi.product_name,
        SUM(bi.quantity) as total_qty,
        SUM(bi.total_price) as total_revenue,
        SUM((bi.unit_price - bi.purchase_price) * bi.quantity) as total_profit,
        COUNT(DISTINCT bi.bill_id) as bill_count
      FROM bill_items bi
      INNER JOIN bills b ON bi.bill_id = b.id
      WHERE b.created_at BETWEEN ? AND ?
      GROUP BY bi.product_id, bi.product_name
      ORDER BY total_revenue DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyReport(DateTime date) async {
    if (await _isOnlineMode()) {
      final dateStr = date.toIso8601String().substring(0, 10);
      final bills = await _fetchOnlineBills();
      return bills.where((bill) {
        return (bill['createdAt'] ?? bill['created_at'] ?? '')
            .toString()
            .startsWith(dateStr);
      }).toList();
    }
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.rawQuery('''
      SELECT b.*, 
             GROUP_CONCAT(bi.product_name || ' x' || bi.quantity, ', ') as items_summary
      FROM bills b
      LEFT JOIN bill_items bi ON b.id = bi.bill_id
      WHERE b.created_at LIKE ?
      GROUP BY b.id
      ORDER BY b.created_at DESC
    ''', ['$dateStr%']);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
}
