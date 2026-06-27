import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/sync/data_access_mode_service.dart';

const List<int> kCashDenominations = [500, 200, 100, 50, 20, 10, 5, 1];

class CashSession {
  final int id;
  final int? cashierUserId;
  final String cashierUsername;
  final String status;
  final double openingAmount;
  final DateTime openedAt;
  final double totalCashCollected;
  final double totalCashRefunded;
  final double expectedClosing;
  final double? closingAmount;
  final DateTime? closedAt;
  final double? difference;

  const CashSession({
    required this.id,
    required this.cashierUserId,
    required this.cashierUsername,
    required this.status,
    required this.openingAmount,
    required this.openedAt,
    required this.totalCashCollected,
    required this.totalCashRefunded,
    required this.expectedClosing,
    required this.closingAmount,
    required this.closedAt,
    required this.difference,
  });

  bool get isOpen => status == 'OPEN';

  factory CashSession.fromMap(Map<String, dynamic> row) {
    return CashSession(
      id: row['id'] as int,
      cashierUserId: row['cashier_user_id'] as int?,
      cashierUsername: row['cashier_username'] as String,
      status: row['status'] as String? ?? 'OPEN',
      openingAmount: (row['opening_amount'] as num?)?.toDouble() ?? 0,
      openedAt: DateTime.parse(row['opened_at'] as String),
      totalCashCollected: (row['total_cash_collected'] as num?)?.toDouble() ?? 0,
      totalCashRefunded: (row['total_cash_refunded'] as num?)?.toDouble() ?? 0,
      expectedClosing: (row['expected_closing'] as num?)?.toDouble() ?? 0,
      closingAmount: (row['closing_amount'] as num?)?.toDouble(),
      closedAt: row['closed_at'] == null ? null : DateTime.parse(row['closed_at'] as String),
      difference: (row['difference'] as num?)?.toDouble(),
    );
  }
}

class CashSessionRepository {
  final DatabaseHelper _dbHelper;
  CashSessionRepository(this._dbHelper);

  Future<bool> _isOfflineMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.offlineSqlite;

  Future<Database> get _db async => _dbHelper.database;

  Future<CashSession?> getActiveSession(String cashierUsername) async {
    if (!await _isOfflineMode()) return null;
    final db = await _db;
    final rows = await db.query(
      'cashier_sessions',
      where: 'cashier_username = ? AND status = ?',
      whereArgs: [cashierUsername, 'OPEN'],
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CashSession.fromMap(rows.first);
  }

  Future<List<CashSession>> getOpenSessions() async {
    if (!await _isOfflineMode()) return const [];
    final db = await _db;
    final rows = await db.query(
      'cashier_sessions',
      where: 'status = ?',
      whereArgs: ['OPEN'],
      orderBy: 'opened_at DESC',
    );
    return rows.map(CashSession.fromMap).toList();
  }

  Map<String, int> convertDenominationKeysToStrings(Map<int, int> counts) {
    // JSON objects use string keys, so denomination values are normalized as
    // strings to keep stored payload stable across platforms/decoders.
    final result = <String, int>{};
    for (final value in kCashDenominations) {
      final raw = counts[value] ?? 0;
      result[value.toString()] = raw < 0 ? 0 : raw;
    }
    return result;
  }

  double totalFromDenominationCounts(Map<int, int> counts) {
    var total = 0.0;
    for (final value in kCashDenominations) {
      final count = counts[value] ?? 0;
      if (count > 0) {
        total += value * count;
      }
    }
    return total;
  }

  Future<CashSession> openSession({
    required String cashierUsername,
    int? cashierUserId,
    required double openingAmount,
    Map<int, int>? openingDenominationCounts,
  }) async {
    if (!await _isOfflineMode()) {
      throw StateError('Cash sessions are unavailable in online API mode.');
    }
    final now = DateTime.now().toIso8601String();
    final db = await _db;
    final existing = await getActiveSession(cashierUsername);
    if (existing != null) return existing;
    final resolvedCashierUserId = await _resolveCashierUserId(
      db: db,
      cashierUserId: cashierUserId,
      cashierUsername: cashierUsername,
    );
    final openingDenominations = openingDenominationCounts == null
        ? null
        : jsonEncode(convertDenominationKeysToStrings(openingDenominationCounts));
    try {
      final id = await db.insert(
        'cashier_sessions',
        _buildSessionInsertRow(
          cashierUsername: cashierUsername,
          cashierUserId: resolvedCashierUserId,
          openingAmount: openingAmount,
          openingDenominations: openingDenominations,
          now: now,
        ),
      );
      final row = await db.query(
        'cashier_sessions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return CashSession.fromMap(row.first);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        final resumed = await getActiveSession(cashierUsername);
        if (resumed != null) return resumed;
      }
      if (e.toString().contains('FOREIGN KEY constraint')) {
        final id = await db.insert(
          'cashier_sessions',
          _buildSessionInsertRow(
            cashierUsername: cashierUsername,
            cashierUserId: null,
            openingAmount: openingAmount,
            openingDenominations: openingDenominations,
            now: now,
          ),
        );
        final row = await db.query(
          'cashier_sessions',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        return CashSession.fromMap(row.first);
      }
      rethrow;
    }
  }

  /// Resolves the optional `cashier_user_id` foreign-key value safely.
  ///
  /// Returns the provided id when it exists in `app_users`; otherwise falls
  /// back to a username lookup. Returns null when no local row is found so the
  /// session can still be opened without violating foreign-key constraints.
  Future<int?> _resolveCashierUserId({
    required Database db,
    required int? cashierUserId,
    required String cashierUsername,
  }) async {
    if (cashierUserId != null) {
      final byId = await db.query(
        'app_users',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [cashierUserId],
        limit: 1,
      );
      if (byId.isNotEmpty) {
        return (byId.first['id'] as num?)?.toInt();
      }
    }

    final byUsername = await db.query(
      'app_users',
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [cashierUsername],
      limit: 1,
    );
    if (byUsername.isEmpty) return null;
    return (byUsername.first['id'] as num?)?.toInt();
  }

  Map<String, Object?> _buildSessionInsertRow({
    required String cashierUsername,
    required int? cashierUserId,
    required double openingAmount,
    required String? openingDenominations,
    required String now,
  }) {
    return {
      'cashier_user_id': cashierUserId,
      'cashier_username': cashierUsername,
      'status': 'OPEN',
      'opening_amount': openingAmount,
      'opening_denominations': openingDenominations,
      'opened_at': now,
      'total_cash_collected': 0.0,
      'total_cash_refunded': 0.0,
      'expected_closing': openingAmount,
      'created_at': now,
      'updated_at': now,
    };
  }

  Future<void> addCashCollection({
    required String cashierUsername,
    required double amount,
  }) async {
    if (!await _isOfflineMode()) return;
    if (amount <= 0) return;
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final count = await db.rawUpdate(
      '''
      UPDATE cashier_sessions
      SET total_cash_collected = total_cash_collected + ?,
          expected_closing = opening_amount + (total_cash_collected + ?) - total_cash_refunded,
          updated_at = ?
      WHERE cashier_username = ? AND status = 'OPEN'
      ''',
      [amount, amount, now, cashierUsername],
    );
    if (count == 0) {
      throw StateError('No active cashier session found for $cashierUsername.');
    }
  }

  Future<void> addCashRefund({
    required String cashierUsername,
    required double amount,
  }) async {
    if (!await _isOfflineMode()) return;
    if (amount <= 0) return;
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final count = await db.rawUpdate(
      '''
      UPDATE cashier_sessions
      SET total_cash_refunded = total_cash_refunded + ?,
          expected_closing = opening_amount + total_cash_collected - (total_cash_refunded + ?),
          updated_at = ?
      WHERE cashier_username = ? AND status = 'OPEN'
      ''',
      [amount, amount, now, cashierUsername],
    );
    if (count == 0) {
      throw StateError('No active cashier session found for $cashierUsername.');
    }
  }

  Future<CashSession> closeSession({
    required String cashierUsername,
    required double closingAmount,
    Map<int, int>? closingDenominationCounts,
    required String closedBy,
    bool force = false,
    String? notes,
  }) async {
    if (!await _isOfflineMode()) {
      throw StateError('Cash sessions are unavailable in online API mode.');
    }
    final db = await _db;
    final active = await getActiveSession(cashierUsername);
    if (active == null) {
      throw StateError('No active session found for $cashierUsername.');
    }
    final diff = closingAmount - active.expectedClosing;
    final now = DateTime.now().toIso8601String();
    final closingDenominations = closingDenominationCounts == null
        ? null
        : jsonEncode(convertDenominationKeysToStrings(closingDenominationCounts));

    await db.update(
      'cashier_sessions',
      {
        'status': 'CLOSED',
        'closing_amount': closingAmount,
        'closing_denominations': closingDenominations,
        'difference': diff,
        'closed_at': now,
        'closed_by': closedBy,
        'notes': force ? 'Force closed${notes == null ? '' : ': $notes'}' : notes,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [active.id],
    );
    final row = await db.query(
      'cashier_sessions',
      where: 'id = ?',
      whereArgs: [active.id],
      limit: 1,
    );
    return CashSession.fromMap(row.first);
  }
}
