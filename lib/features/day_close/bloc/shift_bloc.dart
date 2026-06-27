import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../reports/data/repositories/report_repository.dart';

class ShiftClosePreview extends Equatable {
  final double openingCash;
  final double expectedCash;
  final bool isClosed;
  final Map<String, dynamic> summary;

  const ShiftClosePreview({
    required this.openingCash,
    required this.expectedCash,
    required this.isClosed,
    required this.summary,
  });

  @override
  List<Object?> get props => [openingCash, expectedCash, isClosed, summary];
}

class ShiftStatus extends Equatable {
  final bool isOpened;
  final bool isClosed;
  final double openingCash;

  const ShiftStatus({
    required this.isOpened,
    required this.isClosed,
    required this.openingCash,
  });

  @override
  List<Object?> get props => [isOpened, isClosed, openingCash];
}

class ShiftRepository {
  final DatabaseHelper _dbHelper;
  final ReportRepository _reportRepository;

  ShiftRepository(this._dbHelper, this._reportRepository);

  String _dateKey(DateTime date) => date.toIso8601String().substring(0, 10);

  Future<ShiftStatus> getShiftStatus(DateTime date) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'day_close',
      where: 'close_date = ?',
      whereArgs: [_dateKey(date)],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const ShiftStatus(isOpened: false, isClosed: false, openingCash: 0);
    }
    final row = rows.first;
    final closedBy = row['closed_by'] as String?;
    return ShiftStatus(
      isOpened: true,
      isClosed: closedBy != null && closedBy.trim().isNotEmpty,
      openingCash: (row['cash_opening'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<void> openShift({
    required DateTime date,
    required double openingCash,
    required String openedBy,
  }) async {
    if (openingCash < 0) {
      throw StateError('Opening cash cannot be negative.');
    }
    final db = await _dbHelper.database;
    final status = await getShiftStatus(date);
    if (status.isOpened) return;

    await db.insert(
      'day_close',
      {
        'close_date': _dateKey(date),
        'cash_opening': openingCash,
        'cash_closing': 0.0,
        'cash_variance': 0.0,
        'total_sales': 0.0,
        'total_expenses': 0.0,
        'total_returns': 0.0,
        'total_purchases': 0.0,
        'cash_sales': 0.0,
        'digital_sales': 0.0,
        'bill_count': 0,
        'notes': 'Shift opened by $openedBy',
        'closed_by': null,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<ShiftClosePreview> getClosePreview(DateTime date) async {
    final status = await getShiftStatus(date);
    final summary = await _reportRepository.getDayCloseSummary(date);
    final expected = status.openingCash +
        (summary['cash_sales'] as num).toDouble() -
        (summary['total_expenses'] as num).toDouble();
    return ShiftClosePreview(
      openingCash: status.openingCash,
      expectedCash: expected,
      isClosed: status.isClosed,
      summary: summary,
    );
  }

  Future<double> closeShift({
    required DateTime date,
    required double countedCash,
    required String closedBy,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final status = await getShiftStatus(date);
    if (!status.isOpened) {
      throw StateError('Cannot close shift: no shift has been opened for today.');
    }
    if (status.isClosed) {
      throw StateError('The shift for today has already been closed.');
    }

    final preview = await getClosePreview(date);
    final variance = countedCash - preview.expectedCash;

    await db.update(
      'day_close',
      {
        'cash_closing': countedCash,
        'cash_variance': variance,
        'total_sales': preview.summary['total_sales'],
        'total_expenses': preview.summary['total_expenses'],
        'total_returns': preview.summary['total_returns'],
        'total_purchases': preview.summary['total_purchases'],
        'cash_sales': preview.summary['cash_sales'],
        'digital_sales': preview.summary['digital_sales'],
        'bill_count': preview.summary['bill_count'],
        'notes': notes,
        'closed_by': closedBy,
      },
      where: 'close_date = ?',
      whereArgs: [_dateKey(date)],
    );
    return variance;
  }
}

abstract class ShiftEvent extends Equatable {
  const ShiftEvent();
  @override
  List<Object?> get props => [];
}

class LoadShiftClosePreview extends ShiftEvent {
  final DateTime date;
  const LoadShiftClosePreview(this.date);

  @override
  List<Object?> get props => [date];
}

class OpenShiftRequested extends ShiftEvent {
  final DateTime date;
  final double openingCash;
  final String openedBy;

  const OpenShiftRequested({
    required this.date,
    required this.openingCash,
    required this.openedBy,
  });

  @override
  List<Object?> get props => [date, openingCash, openedBy];
}

class CloseShiftRequested extends ShiftEvent {
  final DateTime date;
  final double countedCash;
  final String closedBy;
  final String? notes;

  const CloseShiftRequested({
    required this.date,
    required this.countedCash,
    required this.closedBy,
    this.notes,
  });

  @override
  List<Object?> get props => [date, countedCash, closedBy, notes];
}

abstract class ShiftState extends Equatable {
  const ShiftState();
  @override
  List<Object?> get props => [];
}

class ShiftInitial extends ShiftState {}

class ShiftLoading extends ShiftState {}

class ShiftClosePreviewLoaded extends ShiftState {
  final ShiftClosePreview preview;
  const ShiftClosePreviewLoaded(this.preview);

  @override
  List<Object?> get props => [preview];
}

class ShiftOpened extends ShiftState {}

class ShiftClosed extends ShiftState {
  final double variance;
  const ShiftClosed(this.variance);

  @override
  List<Object?> get props => [variance];
}

class ShiftFailure extends ShiftState {
  final String message;
  const ShiftFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  final ShiftRepository _repository;
  ShiftBloc(this._repository) : super(ShiftInitial()) {
    on<LoadShiftClosePreview>(_onLoadShiftClosePreview);
    on<OpenShiftRequested>(_onOpenShiftRequested);
    on<CloseShiftRequested>(_onCloseShiftRequested);
  }

  Future<void> _onLoadShiftClosePreview(
    LoadShiftClosePreview event,
    Emitter<ShiftState> emit,
  ) async {
    emit(ShiftLoading());
    try {
      final preview = await _repository.getClosePreview(event.date);
      emit(ShiftClosePreviewLoaded(preview));
    } catch (e) {
      emit(ShiftFailure(e.toString()));
    }
  }

  Future<void> _onOpenShiftRequested(
    OpenShiftRequested event,
    Emitter<ShiftState> emit,
  ) async {
    emit(ShiftLoading());
    try {
      await _repository.openShift(
        date: event.date,
        openingCash: event.openingCash,
        openedBy: event.openedBy,
      );
      emit(ShiftOpened());
    } catch (e) {
      emit(ShiftFailure(e.toString()));
    }
  }

  Future<void> _onCloseShiftRequested(
    CloseShiftRequested event,
    Emitter<ShiftState> emit,
  ) async {
    emit(ShiftLoading());
    try {
      final variance = await _repository.closeShift(
        date: event.date,
        countedCash: event.countedCash,
        closedBy: event.closedBy,
        notes: event.notes,
      );
      emit(ShiftClosed(variance));
    } catch (e) {
      emit(ShiftFailure(e.toString()));
    }
  }
}
