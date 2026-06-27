import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/ledger/ledger_service.dart';
import '../../../users/domain/entities/app_user.dart';

class OwnerCapitalRepository {
  final DatabaseHelper _dbHelper;
  OwnerCapitalRepository(this._dbHelper);

  Future<int> addOwnerCapital({
    required AppUser actor,
    required double amount,
  }) async {
    if (!actor.isAdmin) {
      throw StateError('Only admin users can add owner capital.');
    }
    if (amount <= 0) {
      throw StateError('Amount must be greater than zero.');
    }

    // Resolve before transaction to avoid sqflite deadlock.
    final licenseId = await LedgerService.resolveLicenseId(_dbHelper);
    final db = await _dbHelper.forceLocalDatabase;
    return db.transaction((txn) async {
      return LedgerService.instance.recordTransaction(
        executor: txn,
        type: 'internal_transfer',
        totalAmount: amount,
        licenseId: licenseId,
        entries: [
          LedgerEntryInput(
            accountType: 'asset',
            direction: 'debit',
            amount: amount,
          ),
          LedgerEntryInput(
            accountType: 'liability',
            direction: 'credit',
            amount: amount,
          ),
        ],
        tags: {
          'purpose': 'owner_capital',
          'entered_by': actor.username,
        },
      );
    });
  }
}

abstract class OwnerCapitalEvent extends Equatable {
  const OwnerCapitalEvent();
  @override
  List<Object?> get props => [];
}

class SubmitOwnerCapital extends OwnerCapitalEvent {
  final AppUser actor;
  final double amount;
  const SubmitOwnerCapital({required this.actor, required this.amount});

  @override
  List<Object?> get props => [actor, amount];
}

abstract class OwnerCapitalState extends Equatable {
  const OwnerCapitalState();
  @override
  List<Object?> get props => [];
}

class OwnerCapitalInitial extends OwnerCapitalState {}

class OwnerCapitalSubmitting extends OwnerCapitalState {}

class OwnerCapitalSuccess extends OwnerCapitalState {
  final int transactionId;
  const OwnerCapitalSuccess(this.transactionId);

  @override
  List<Object?> get props => [transactionId];
}

class OwnerCapitalFailure extends OwnerCapitalState {
  final String message;
  const OwnerCapitalFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class OwnerCapitalBloc extends Bloc<OwnerCapitalEvent, OwnerCapitalState> {
  final OwnerCapitalRepository _repository;
  OwnerCapitalBloc(this._repository) : super(OwnerCapitalInitial()) {
    on<SubmitOwnerCapital>(_onSubmitOwnerCapital);
  }

  Future<void> _onSubmitOwnerCapital(
    SubmitOwnerCapital event,
    Emitter<OwnerCapitalState> emit,
  ) async {
    emit(OwnerCapitalSubmitting());
    try {
      final txId = await _repository.addOwnerCapital(
        actor: event.actor,
        amount: event.amount,
      );
      emit(OwnerCapitalSuccess(txId));
    } catch (e) {
      emit(OwnerCapitalFailure(e.toString()));
    }
  }
}
