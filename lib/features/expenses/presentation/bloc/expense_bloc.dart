// ─── Expense Entity ────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart' show Options;
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/backend/backend_api_service.dart';
import '../../../../core/backend/backend_id_mapper.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/ledger/ledger_service.dart';
import '../../../../core/sync/data_access_mode_service.dart';

class Expense extends Equatable {
  final int? id;
  final String category;
  final String? description;
  final double amount;
  final DateTime date;
  final DateTime createdAt;
  final bool isRawMaterial;

  const Expense({
    this.id,
    required this.category,
    this.description,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.isRawMaterial = false,
  });

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as int?,
    category: map['category'] as String,
    description: map['description'] as String?,
    amount: (map['amount'] as num).toDouble(),
    date: DateTime.parse(map['date'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
    isRawMaterial: (map['is_raw_material'] as int? ?? 0) == 1,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'category': category,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'is_raw_material': isRawMaterial ? 1 : 0,
  };

  @override
  List<Object?> get props => [id, category, amount, date, isRawMaterial];
}

const List<String> kExpenseCategories = [
  'Rent', 'Electricity', 'Water', 'Raw Materials',
  'Salary', 'Maintenance', 'Transport', 'Packaging', 'Other',
];

// ─── Repository ────────────────────────────────────────────────────────────────
abstract class ExpenseRepository {
  Future<List<Expense>> getExpensesByDate(DateTime date);
  Future<List<Expense>> getExpensesByMonth(int year, int month);
  Future<int> addExpense(Expense expense);
  Future<bool> deleteExpense(int id);
  Future<Map<String, double>> getDailyExpenseSummary(DateTime date);
  Future<Map<String, double>> getMonthlyExpenseSummary(int year, int month);
  Future<double> getTodayRawMaterialExpenses(DateTime date);
}

class ExpenseRepositoryImpl implements ExpenseRepository {
  final DatabaseHelper _dbHelper;
  static const _uuid = Uuid();
  ExpenseRepositoryImpl(this._dbHelper);

  Future<bool> _isOnlineMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.onlineApi;

  Future<List<Expense>> _fetchOnlineExpenses() async {
    final rows = await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
      dio,
      headers,
    ) async {
      final response = await dio.get<Map<String, dynamic>>(
        'transactions',
        queryParameters: {'types': 'expense', 'limit': 500},
        options: Options(headers: headers),
      );
      return response.data ?? <String, dynamic>{};
    });
    final expenses = <Expense>[];
    for (final raw in ((rows['transactions'] as List?) ?? const <dynamic>[]).whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final dynamic rawTags = row['tagsJson'] ?? row['tags_json'] ?? const <String, dynamic>{};
      final Map<String, dynamic> tags = rawTags is String
          ? Map<String, dynamic>.from(jsonDecode(rawTags) as Map)
          : Map<String, dynamic>.from(rawTags as Map);
      final createdAt =
          DateTime.tryParse((row['createdAt'] ?? row['created_at'] ?? '').toString()) ??
              DateTime.now();
      final date = DateTime.tryParse((tags['date'] ?? createdAt.toIso8601String()).toString()) ??
          createdAt;
      expenses.add(
        Expense(
          id: await BackendIdMapper.instance.register(
            namespace: 'transactions',
            uuid: (row['clientRecordId'] ?? row['client_record_id'] ?? row['serverId'])
                .toString(),
          ),
          category: (tags['category'] ?? 'Other').toString(),
          description: tags['description']?.toString(),
          amount: ((row['totalAmount'] ?? row['total_amount']) as num?)?.toDouble() ?? 0.0,
          date: date,
          createdAt: createdAt,
          isRawMaterial: tags['isRawMaterial'] == true ||
              tags['is_raw_material'] == true ||
              (tags['category']?.toString().toLowerCase() == 'raw materials'),
        ),
      );
    }
    return expenses;
  }

  @override
  Future<List<Expense>> getExpensesByDate(DateTime date) async {
    if (await _isOnlineMode()) {
      final dateStr = date.toIso8601String().substring(0, 10);
      final expenses = await _fetchOnlineExpenses();
      return expenses
          .where((expense) => expense.date.toIso8601String().startsWith(dateStr))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query(
      'expenses',
      where: "date LIKE ?",
      whereArgs: ['$dateStr%'],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  @override
  Future<List<Expense>> getExpensesByMonth(int year, int month) async {
    if (await _isOnlineMode()) {
      final prefix = '$year-${month.toString().padLeft(2, '0')}';
      final expenses = await _fetchOnlineExpenses();
      return expenses
          .where((expense) => expense.date.toIso8601String().startsWith(prefix))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final rows = await db.query(
      'expenses',
      where: "date LIKE ?",
      whereArgs: ['$prefix%'],
      orderBy: 'date DESC',
    );
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  @override
  Future<int> addExpense(Expense expense) async {
    if (await _isOnlineMode()) {
      final clientRecordId = _uuid.v4();
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'transactions/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'type': 'expense',
            'totalAmount': expense.amount,
            'tags': {
              'category': expense.category,
              'description': expense.description,
              'date': expense.date.toIso8601String(),
              'isRawMaterial': expense.isRawMaterial,
            },
            'createdAt': expense.createdAt.toUtc().toIso8601String(),
            'updatedAt': expense.createdAt.toUtc().toIso8601String(),
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      return BackendIdMapper.instance.register(
        namespace: 'transactions',
        uuid: clientRecordId,
      );
    }
    final db = await _dbHelper.database;
    final id = await db.insert('expenses', expense.toMap());

    // Write double-entry ledger (best-effort)
    try {
      final licenseId = await LedgerService.resolveLicenseId(_dbHelper);
      await db.transaction((txn) async {
        await LedgerService.instance.recordExpense(
          txn: txn,
          amount: expense.amount,
          licenseId: licenseId,
          tags: {
            'category': expense.category,
            'description': expense.description,
            'date': expense.date.toIso8601String(),
          },
        );
      });
    } catch (_) {}

    return id;
  }

  @override
  Future<bool> deleteExpense(int id) async {
    if (await _isOnlineMode()) {
      return false;
    }
    final db = await _dbHelper.database;
    final count = await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  @override
  Future<Map<String, double>> getDailyExpenseSummary(DateTime date) async {
    if (await _isOnlineMode()) {
      final expenses = await getExpensesByDate(date);
      return {
        'total': expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount),
      };
    }
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total FROM expenses WHERE date LIKE ?
    ''', ['$dateStr%']);
    final row = result.isNotEmpty ? result.first : const <String, Object?>{};
    return {'total': (row['total'] as num?)?.toDouble() ?? 0.0};
  }

  @override
  Future<Map<String, double>> getMonthlyExpenseSummary(int year, int month) async {
    if (await _isOnlineMode()) {
      final expenses = await getExpensesByMonth(year, month);
      final map = <String, double>{};
      for (final expense in expenses) {
        map[expense.category] = (map[expense.category] ?? 0.0) + expense.amount;
      }
      return map;
    }
    final db = await _dbHelper.database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total,
             category, COUNT(*) as count
      FROM expenses WHERE date LIKE ?
      GROUP BY category
    ''', ['$prefix%']);
    final map = <String, double>{};
    for (final r in result) {
      map[r['category'] as String] = (r['total'] as num).toDouble();
    }
    return map;
  }

  @override
  Future<double> getTodayRawMaterialExpenses(DateTime date) async {
    if (await _isOnlineMode()) {
      final expenses = await getExpensesByDate(date);
      return expenses
          .where((expense) => expense.isRawMaterial)
          .fold<double>(0.0, (sum, expense) => sum + expense.amount);
    }
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total FROM expenses
      WHERE date LIKE ? AND is_raw_material = 1
    ''', ['$dateStr%']);
    final row = result.isNotEmpty ? result.first : const <String, Object?>{};
    return (row['total'] as num?)?.toDouble() ?? 0.0;
  }
}

// ─── Events ────────────────────────────────────────────────────────────────────
abstract class ExpenseEvent extends Equatable {
  @override List<Object?> get props => [];
}
class LoadExpenses extends ExpenseEvent {}
class AddExpenseEvent extends ExpenseEvent {
  final Expense expense;
  AddExpenseEvent(this.expense);
  @override List<Object?> get props => [expense];
}
class DeleteExpenseEvent extends ExpenseEvent {
  final int id;
  DeleteExpenseEvent(this.id);
  @override List<Object?> get props => [id];
}

// ─── States ────────────────────────────────────────────────────────────────────
abstract class ExpenseState extends Equatable {
  @override List<Object?> get props => [];
}
class ExpenseInitial extends ExpenseState {}
class ExpenseLoading extends ExpenseState {}
class ExpenseLoaded extends ExpenseState {
  final List<Expense> todayExpenses;
  final List<Expense> monthlyExpenses;
  final double todayTotal;
  final double monthlyTotal;
  final Map<String, double> categoryBreakdown;

  ExpenseLoaded({
    required this.todayExpenses,
    required this.monthlyExpenses,
    required this.todayTotal,
    required this.monthlyTotal,
    required this.categoryBreakdown,
  });

  @override List<Object?> get props => [todayExpenses, monthlyExpenses];
}
class ExpenseError extends ExpenseState {
  final String message;
  ExpenseError(this.message);
  @override List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────────────────
class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseRepository _repository;

  ExpenseBloc(this._repository) : super(ExpenseInitial()) {
    on<LoadExpenses>(_onLoad);
    on<AddExpenseEvent>(_onAdd);
    on<DeleteExpenseEvent>(_onDelete);
  }

  Future<void> _onLoad(LoadExpenses event, Emitter<ExpenseState> emit) async {
    emit(ExpenseLoading());
    try {
      final now = DateTime.now();
      final todayExpenses = await _repository.getExpensesByDate(now);
      final monthlyExpenses = await _repository.getExpensesByMonth(now.year, now.month);
      final categoryBreakdown = await _repository.getMonthlyExpenseSummary(now.year, now.month);
      final todayTotal = todayExpenses.fold(0.0, (sum, e) => sum + e.amount);
      final monthlyTotal = monthlyExpenses.fold(0.0, (sum, e) => sum + e.amount);

      emit(ExpenseLoaded(
        todayExpenses: todayExpenses,
        monthlyExpenses: monthlyExpenses,
        todayTotal: todayTotal,
        monthlyTotal: monthlyTotal,
        categoryBreakdown: categoryBreakdown,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onAdd(AddExpenseEvent event, Emitter<ExpenseState> emit) async {
    try {
      await _repository.addExpense(event.expense);
      add(LoadExpenses());
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteExpenseEvent event, Emitter<ExpenseState> emit) async {
    try {
      await _repository.deleteExpense(event.id);
      add(LoadExpenses());
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }
}
