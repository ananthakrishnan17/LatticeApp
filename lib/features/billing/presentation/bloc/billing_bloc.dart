import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/bill.dart';
import '../../data/repositories/billing_repository_impl.dart';
import '../../../masters/domain/entities/masters.dart';

abstract class BillingEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AddToCart extends BillingEvent {
  final CartItem item;
  AddToCart(this.item);
  @override
  List<Object?> get props => [item.productId];
}

class RemoveFromCart extends BillingEvent {
  final int productId;
  final int? saleUomId;
  RemoveFromCart(this.productId, {this.saleUomId});
  @override
  List<Object?> get props => [productId, saleUomId];
}

class UpdateCartItemQty extends BillingEvent {
  final int productId;
  final double quantity;
  final int? saleUomId;
  UpdateCartItemQty({required this.productId, required this.quantity, this.saleUomId});
  @override
  List<Object?> get props => [productId, quantity, saleUomId];
}

class UpdateOpenRatePrice extends BillingEvent {
  final int productId;
  final double price;
  UpdateOpenRatePrice({required this.productId, required this.price});
  @override
  List<Object?> get props => [productId, price];
}

class UpdateCartItemDiscount extends BillingEvent {
  final int productId;
  final int? saleUomId;
  final ItemDiscountType discountType;
  final double discountValue;

  UpdateCartItemDiscount({
    required this.productId,
    this.saleUomId,
    required this.discountType,
    required this.discountValue,
  });

  @override
  List<Object?> get props => [productId, saleUomId, discountType, discountValue];
}

class ClearCart extends BillingEvent {}

class ApplyDiscount extends BillingEvent {
  final double amount;
  ApplyDiscount(this.amount);
  @override
  List<Object?> get props => [amount];
}

class SetPaymentMode extends BillingEvent {
  final String mode;
  SetPaymentMode(this.mode);
  @override
  List<Object?> get props => [mode];
}

class SetBillType extends BillingEvent {
  final BillType billType;
  SetBillType(this.billType);
  @override
  List<Object?> get props => [billType];
}

class SetCustomer extends BillingEvent {
  final Customer? customer;
  SetCustomer(this.customer);
  @override
  List<Object?> get props => [customer?.id];
}

class SetCustomerName extends BillingEvent {
  final String name;
  SetCustomerName(this.name);
  @override
  List<Object?> get props => [name];
}

class ApplyCoupon extends BillingEvent {
  final AppliedCoupon coupon;
  ApplyCoupon(this.coupon);

  @override
  List<Object?> get props => [coupon];
}

class ClearCoupon extends BillingEvent {}

class SetCashTendered extends BillingEvent {
  final double? amount;
  SetCashTendered(this.amount);

  @override
  List<Object?> get props => [amount];
}

class SaveBill extends BillingEvent {
  final int? billedByUserId;
  final String? billedByUsername;

  SaveBill({this.billedByUserId, this.billedByUsername});

  @override
  List<Object?> get props => [billedByUserId, billedByUsername];
}

class SetSplitPayments extends BillingEvent {
  final List<SplitPayment> splits;
  SetSplitPayments(this.splits);
  @override
  List<Object?> get props => [splits];
}

// ✅ NEW: Used after print/dismiss to fully reset the cart
class ResetAfterSave extends BillingEvent {}

class RestoreHeldCartItems extends BillingEvent {
  final List<CartItem> items;
  final String billType;
  final String? customerName;
  final double discountAmount;
  final AppliedCoupon? appliedCoupon;
  RestoreHeldCartItems({
    required this.items,
    this.billType = 'retail',
    this.customerName,
    this.discountAmount = 0,
    this.appliedCoupon,
  });
  @override
  List<Object?> get props => [items, billType, customerName, discountAmount, appliedCoupon];
}

// ─────────────────────────────────────────────────────────────────────────────

class CartState extends Equatable {
  final List<CartItem> items;
  final double discountAmount;
  final String paymentMode;
  final List<SplitPayment> splitPayments;
  final BillType billType;
  final Customer? selectedCustomer;
  final String? customerName;
  final AppliedCoupon? appliedCoupon;
  final double? cashTendered;
  final bool isSaving;
  final Bill? lastSavedBill;   // ✅ non-null = save just succeeded
  final String? errorMessage;

  const CartState({
    this.items = const [],
    this.discountAmount = 0.0,
    this.paymentMode = 'cash',
    this.splitPayments = const [],
    this.billType = BillType.retail,
    this.selectedCustomer,
    this.customerName,
    this.appliedCoupon,
    this.cashTendered,
    this.isSaving = false,
    this.lastSavedBill,
    this.errorMessage,
  });

  double get subtotal => items.fold(0.0, (s, i) => s + i.totalFor(billType));
  double get couponDiscountAmount {
    final coupon = appliedCoupon;
    if (coupon == null) return 0.0;
    final discountableTotal =
        (subtotal - discountAmount).clamp(0.0, double.infinity);
    if (discountableTotal <= 0) return 0.0;
    if (coupon.discountType == CouponType.percent) {
      return (discountableTotal *
              (coupon.discountValue.clamp(0.0, 100.0) / 100))
          .clamp(0.0, discountableTotal)
          .toDouble();
    }
    return coupon.discountValue.clamp(0.0, discountableTotal).toDouble();
  }
  double get totalAmount => (subtotal - discountAmount - couponDiscountAmount)
      .clamp(0.0, double.infinity);  // FIX BUG#4
  double get totalProfit => items.fold(0.0, (s, i) => s + i.profitFor(billType));
  double get gstTotal => items.fold(0.0, (s, i) => s + i.gstAmountFor(billType));
  int get itemCount => items.where((i) => i.quantity > 0).length;  // FIX BUG#5: toInt() was truncating 0.5kg → 0 items
  bool get isEmpty => items.isEmpty;
  double? get changeAmount {
    if (paymentMode != 'cash' || cashTendered == null) return null;
    return cashTendered! - totalAmount;
  }

  CartState copyWith({
    List<CartItem>? items,
    double? discountAmount,
    String? paymentMode,
    List<SplitPayment>? splitPayments,
    BillType? billType,
    Customer? selectedCustomer,
    String? customerName,
    AppliedCoupon? appliedCoupon,
    double? cashTendered,
    bool? isSaving,
    Bill? lastSavedBill,
    String? errorMessage,
    bool clearLastSavedBill = false,   // ✅ explicit null-clear flag
    bool clearError = false,
    bool clearCustomer = false,        // ✅ explicit null-clear for customer
    bool clearAppliedCoupon = false,
    bool clearCashTendered = false,
  }) =>
      CartState(
        items: items ?? this.items,
        discountAmount: discountAmount ?? this.discountAmount,
        paymentMode: paymentMode ?? this.paymentMode,
        splitPayments: splitPayments ?? this.splitPayments,
        billType: billType ?? this.billType,
        selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
        customerName: clearCustomer ? null : (customerName ?? this.customerName),
        appliedCoupon:
            clearAppliedCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
        cashTendered:
            clearCashTendered ? null : (cashTendered ?? this.cashTendered),
        isSaving: isSaving ?? this.isSaving,
        // ✅ allow explicit null-clear without losing value on other copies
        lastSavedBill: clearLastSavedBill ? null : (lastSavedBill ?? this.lastSavedBill),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [
    items,
    discountAmount,
    paymentMode,
    splitPayments,
    billType,
    selectedCustomer,
    customerName,
    appliedCoupon,
    cashTendered,
    isSaving,
    lastSavedBill,
    errorMessage,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────

class BillingBloc extends Bloc<BillingEvent, CartState> {
  static const double _kPaymentTolerance = 0.01;
  final BillingRepository _repository;

  BillingBloc(this._repository) : super(const CartState()) {
    on<AddToCart>(_onAdd);
    on<RemoveFromCart>(_onRemove);
    on<UpdateCartItemQty>(_onUpdateQty);
    on<UpdateOpenRatePrice>(_onUpdateOpenRate);
    on<UpdateCartItemDiscount>(_onUpdateItemDiscount);
    on<ClearCart>((e, emit) => emit(const CartState()));
    on<ApplyDiscount>((e, emit) => emit(state.copyWith(discountAmount: e.amount)));
    on<SetPaymentMode>((e, emit) => emit(state.copyWith(
      paymentMode: e.mode,
      clearCashTendered: e.mode != 'cash',
    )));
    on<SetSplitPayments>((e, emit) => emit(state.copyWith(splitPayments: e.splits)));
    on<SetBillType>((e, emit) => emit(state.copyWith(billType: e.billType)));
    on<SetCustomer>((e, emit) => emit(e.customer == null
        ? state.copyWith(clearCustomer: true)
        : state.copyWith(selectedCustomer: e.customer, customerName: e.customer?.name)));
    on<SetCustomerName>((e, emit) => emit(state.copyWith(customerName: e.name)));
    on<ApplyCoupon>((e, emit) => emit(state.copyWith(appliedCoupon: e.coupon)));
    on<ClearCoupon>((e, emit) => emit(state.copyWith(clearAppliedCoupon: true)));
    on<SetCashTendered>((e, emit) => emit(
      e.amount == null
          ? state.copyWith(clearCashTendered: true)
          : state.copyWith(cashTendered: e.amount),
    ));
    on<SaveBill>(_onSave);
    on<ResetAfterSave>((e, emit) => emit(const CartState())); // ✅ clean reset
    on<RestoreHeldCartItems>(_onRestoreHeld);
  }

  void _onAdd(AddToCart e, Emitter<CartState> emit) {
    final idx = state.items.indexWhere(
          (i) => i.productId == e.item.productId && i.saleUomId == e.item.saleUomId,
    );
    final updated = List<CartItem>.from(state.items);
    if (idx >= 0) {
      updated[idx] = updated[idx].copyWith(quantity: updated[idx].quantity + e.item.quantity);  // FIX BUG#3: was always +1, ignoring item quantity
    } else {
      updated.add(e.item);
    }
    emit(state.copyWith(items: updated));
  }

  void _onRemove(RemoveFromCart e, Emitter<CartState> emit) => emit(
    state.copyWith(
        items: state.items.where((i) =>
        !(i.productId == e.productId &&
            (e.saleUomId == null || i.saleUomId == e.saleUomId))
        ).toList()),
  );

  void _onUpdateQty(UpdateCartItemQty e, Emitter<CartState> emit) {
    if (e.quantity <= 0) {
      add(RemoveFromCart(e.productId, saleUomId: e.saleUomId));
      return;
    }
    emit(state.copyWith(
      items: state.items
          .map((i) =>
      (i.productId == e.productId &&
          (e.saleUomId == null || i.saleUomId == e.saleUomId))
          ? i.copyWith(quantity: e.quantity)
          : i)
          .toList(),
    ));
  }

  void _onUpdateOpenRate(UpdateOpenRatePrice e, Emitter<CartState> emit) =>
      emit(state.copyWith(
        items: state.items
            .map((i) => i.productId == e.productId
            ? i.copyWith(overridePrice: e.price)
            : i)
            .toList(),
      ));

  void _onUpdateItemDiscount(
    UpdateCartItemDiscount e,
    Emitter<CartState> emit,
  ) => emit(
    state.copyWith(
      items: state.items
          .map(
            (i) => (i.productId == e.productId &&
                    (e.saleUomId == null || i.saleUomId == e.saleUomId))
                ? i.copyWith(
                    itemDiscountType: e.discountType,
                    itemDiscountValue: e.discountValue,
                  )
                : i,
          )
          .toList(),
    ),
  );

  Future<void> _onSave(SaveBill e, Emitter<CartState> emit) async {
    if (state.isSaving) return;
    if (state.items.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Cart is empty. Add items before saving bill.',
          clearLastSavedBill: true,
        ),
      );
      return;
    }
    if (state.totalAmount <= 0) {
      emit(
        state.copyWith(
          errorMessage: 'Bill total must be greater than zero.',
          clearLastSavedBill: true,
        ),
      );
      return;
    }

    if (state.paymentMode == 'cash') {
      final tendered = state.cashTendered;
      if (tendered == null || tendered < state.totalAmount) {
        emit(
          state.copyWith(
            errorMessage: 'Cash tendered must be at least total amount.',
            clearLastSavedBill: true,
          ),
        );
        return;
      }
    }

    if (state.paymentMode == 'split') {
      if (state.splitPayments.isEmpty) {
        emit(
          state.copyWith(
            errorMessage: 'Split payment details are missing.',
            clearLastSavedBill: true,
          ),
        );
        return;
      }
      final splitTotal = state.splitPayments.fold<double>(
        0.0,
        (sum, split) => sum + split.amount,
      );
      if ((splitTotal - state.totalAmount).abs() > _kPaymentTolerance) {
        emit(
          state.copyWith(
            errorMessage: 'Split payment total must match bill total.',
            clearLastSavedBill: true,
          ),
        );
        return;
      }
    }

    debugPrint('[BillingBloc] confirm payment — SaveBill event, items: ${state.items.length}');

    // ✅ FIX 1: Set isSaving=true, clear any previous error
    emit(state.copyWith(isSaving: true, clearError: true));

    try {
      final bill = await _repository.saveBill(
        items: state.items,
        billType: state.billType.value,
        discountAmount: state.discountAmount,
        paymentMode: state.paymentMode,
        splitPayments: state.splitPayments.isNotEmpty ? state.splitPayments : null,
        customerId: state.selectedCustomer?.id,
        customerName: state.selectedCustomer?.name ?? state.customerName,
        customerAddress: state.selectedCustomer?.address,
        customerGstin: state.selectedCustomer?.gstNumber,
        couponId: state.appliedCoupon?.couponId,
        couponCode: state.appliedCoupon?.code,
        couponDiscountAmount: state.couponDiscountAmount,
        cashTendered: state.cashTendered,
        changeAmount: state.changeAmount,
        billedByUserId: e.billedByUserId,
        billedByUsername: e.billedByUsername,
      );

      debugPrint('[BillingBloc] saveBill completed: bill #${bill.billNumber}');

      // ✅ FIX 2: Keep items in state so print has full bill data.
      //           Set isSaving=false AND set lastSavedBill so listener fires.
      //           Do NOT wipe cart here — ResetAfterSave does that later.
      emit(state.copyWith(
        isSaving: false,
        lastSavedBill: bill,
        clearError: true,
      ));
    } catch (err) {
      debugPrint('[BillingBloc] saveBill failed: $err');
      // ✅ FIX 3: Always reset isSaving on error
      emit(state.copyWith(
        isSaving: false,
        errorMessage: err.toString(),
        clearLastSavedBill: true,
      ));
    }
  }

  void _onRestoreHeld(RestoreHeldCartItems e, Emitter<CartState> emit) =>
      emit(CartState(
        items: e.items,
        billType:
        e.billType == 'wholesale' ? BillType.wholesale : BillType.retail,
        customerName: e.customerName,
        discountAmount: e.discountAmount,
        appliedCoupon: e.appliedCoupon,
      ));
}
