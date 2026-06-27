import 'package:equatable/equatable.dart';
import '../../../products/domain/entities/product.dart';
import 'sale_type.dart';

enum BillType { retail, wholesale }
extension BillTypeExt on BillType {
  String get value => name;
  String get label => name == 'retail' ? 'Retail' : 'Wholesale';
  String get emoji => name == 'retail' ? '🛒' : '📦';
}

enum ItemDiscountType { none, amount, percent }

extension ItemDiscountTypeExt on ItemDiscountType {
  String get value => name;
  static ItemDiscountType fromValue(String? value) {
    return ItemDiscountType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ItemDiscountType.none,
    );
  }
  String get label {
    switch (this) {
      case ItemDiscountType.none:
        return 'None';
      case ItemDiscountType.amount:
        return 'Amount';
      case ItemDiscountType.percent:
        return 'Percent';
    }
  }
}

class CartItem extends Equatable {
  final int productId;
  final String productName;
  final String? productSku;
  final String unit;
  final double sellingPrice;
  final double wholesalePrice;
  final double purchasePrice;
  final double gstRate;
  final bool gstInclusive;
  final String rateType; // 'fixed' | 'open'
  final double quantity;
  final double? overridePrice; // for open rate
  final int? saleUomId;           // null = base unit sale
  final String? saleUomShortName;
  final double conversionQty;     // base units per sale unit, default 1.0
  // Wholesale/Retail sale type (v9)
  final SaleType saleType;
  final double retailPrice;       // retail price per retail unit
  final double wholesaleToRetailQty; // conversion factor
  final ItemDiscountType itemDiscountType;
  final double itemDiscountValue;

  const CartItem({
    required this.productId, required this.productName, this.productSku, required this.unit,
    required this.sellingPrice, required this.wholesalePrice,
    required this.purchasePrice, this.gstRate = 0, this.gstInclusive = true,
    this.rateType = 'fixed', required this.quantity, this.overridePrice,
    this.saleUomId, this.saleUomShortName, this.conversionQty = 1.0,
    this.saleType = SaleType.retail, this.retailPrice = 0.0,
    this.wholesaleToRetailQty = 1.0,
    this.itemDiscountType = ItemDiscountType.none,
    this.itemDiscountValue = 0.0,
  });

  double effectivePrice(BillType billType) {
    if (overridePrice != null) return overridePrice!;
    // For products configured with wholesale/retail split (wholesaleToRetailQty > 1),
    // use the per-item saleType to determine price independently of cart billType.
    if (wholesaleToRetailQty > 1.0) {
      if (saleType == SaleType.wholesale) {
        return wholesalePrice > 0 ? wholesalePrice : sellingPrice;
      }
      // SaleType.retail: use retailPrice if configured, otherwise sellingPrice
      return retailPrice > 0 ? retailPrice : sellingPrice;
    }
    // For regular products (not using the wholesale/retail split), fall back
    // to the traditional cart-level billType logic for backward compatibility.
    if (overridePrice != null) return overridePrice!;
    return billType == BillType.wholesale ? wholesalePrice : sellingPrice;
  }

  double baseTotalFor(BillType billType) => effectivePrice(billType) * quantity;

  double itemDiscountAmountFor(BillType billType) {
    final baseTotal = baseTotalFor(billType);
    if (baseTotal <= 0 || itemDiscountValue <= 0) return 0;
    switch (itemDiscountType) {
      case ItemDiscountType.none:
        return 0;
      case ItemDiscountType.amount:
        return itemDiscountValue.clamp(0, baseTotal).toDouble();
      case ItemDiscountType.percent:
        return (baseTotal * (itemDiscountValue.clamp(0, 100) / 100))
            .clamp(0, baseTotal)
            .toDouble();
    }
  }

  double totalFor(BillType billType) =>
      (baseTotalFor(billType) - itemDiscountAmountFor(billType))
          .clamp(0.0, double.infinity);

  double profitFor(BillType billType) =>
      totalFor(billType) - (purchasePrice * conversionQty * quantity);
  double gstAmountFor(BillType billType) {
    if (gstRate <= 0) return 0;
    final t = totalFor(billType);
    return gstInclusive ? t - (t / (1 + gstRate / 100)) : t * gstRate / 100;
  }
  bool get isOpenRate => rateType == 'open';
  bool get hasItemDiscount =>
      itemDiscountType != ItemDiscountType.none && itemDiscountValue > 0;

  // FIX BUG#6: clearOverridePrice flag lets callers reset an open-rate override.
  // Passing null for overridePrice previously meant 'keep existing'; now you
  // can pass clearOverridePrice: true to explicitly set it back to null.
  CartItem copyWith({
    double? quantity,
    double? overridePrice,
    SaleType? saleType,
    ItemDiscountType? itemDiscountType,
    double? itemDiscountValue,
    bool clearOverridePrice = false,
  }) => CartItem(
    productId: productId, productName: productName, productSku: productSku, unit: unit,
    sellingPrice: sellingPrice, wholesalePrice: wholesalePrice, purchasePrice: purchasePrice,
    gstRate: gstRate, gstInclusive: gstInclusive, rateType: rateType,
    quantity: quantity ?? this.quantity,
    overridePrice: clearOverridePrice ? null : (overridePrice ?? this.overridePrice),
    saleUomId: saleUomId, saleUomShortName: saleUomShortName, conversionQty: conversionQty,
    saleType: saleType ?? this.saleType, retailPrice: retailPrice,
    wholesaleToRetailQty: wholesaleToRetailQty,
    itemDiscountType: itemDiscountType ?? this.itemDiscountType,
    itemDiscountValue: itemDiscountValue ?? this.itemDiscountValue,
  );

  @override List<Object?> get props => [
    productId,
    saleUomId,
    quantity,
    overridePrice,
    saleType,
    itemDiscountType,
    itemDiscountValue,
  ];
}

class BillItem extends Equatable {
  final int? id;
  final int billId;
  final int productId;
  final String productName;
  final String? productSku;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double purchasePrice;
  final double discountAmount;
  final String itemDiscountType;
  final double itemDiscountValue;
  final double gstRate;
  final double gstAmount;
  final double totalPrice;

  const BillItem({this.id, required this.billId, required this.productId,
    required this.productName, this.productSku, required this.quantity, required this.unit,
    required this.unitPrice, required this.purchasePrice, this.discountAmount = 0,
    this.itemDiscountType = 'none', this.itemDiscountValue = 0.0,
    this.gstRate = 0, this.gstAmount = 0, required this.totalPrice});

  double get profit => (unitPrice - purchasePrice) * quantity;
  @override List<Object?> get props => [id, billId, productId];
}

class Bill extends Equatable {
  final int? id;
  final String billNumber;
  final String billType;
  final List<BillItem> items;
  final double totalAmount;
  final double totalProfit;
  final double discountAmount;
  final double gstTotal;
  final double cgstTotal;
  final double sgstTotal;
  final double igstTotal;  // FIX BUG#2: added for inter-state transactions
  final String paymentMode;
  final int? customerId;
  final String? customerName;
  final String? customerAddress;
  final String? customerGstin;
  final int? couponId;
  final String? couponCode;
  final double couponDiscountAmount;
  final double? cashTendered;
  final double? changeAmount;
  final String? notes;
  final String? splitPaymentSummary;
  final DateTime createdAt;

  const Bill({this.id, required this.billNumber, this.billType = 'retail',
    required this.items, required this.totalAmount, required this.totalProfit,
    this.discountAmount = 0.0, this.gstTotal = 0.0, this.cgstTotal = 0.0,
    this.sgstTotal = 0.0, this.igstTotal = 0.0,  // FIX BUG#2
    this.paymentMode = 'cash', this.customerId,
    this.customerName, this.customerAddress, this.customerGstin,
    this.couponId, this.couponCode, this.couponDiscountAmount = 0.0,
    this.cashTendered, this.changeAmount,
    this.notes, this.splitPaymentSummary, required this.createdAt});

  double get finalAmount => totalAmount;
  @override List<Object?> get props => [id, billNumber, createdAt];
}

enum PaymentMode { cash, upi, card, credit }
extension PaymentModeExt on PaymentMode {
  String get label { switch (this) { case PaymentMode.cash: return 'Cash'; case PaymentMode.upi: return 'UPI'; case PaymentMode.card: return 'Card'; case PaymentMode.credit: return 'Credit'; } }
  String get icon { switch (this) { case PaymentMode.cash: return '💵'; case PaymentMode.upi: return '📱'; case PaymentMode.card: return '💳'; case PaymentMode.credit: return '📋'; } }
}

class SplitPayment {
  final String mode;   // 'cash', 'upi', 'card', 'credit'
  final double amount;
  const SplitPayment({required this.mode, required this.amount});
}

enum CouponType { flat, percent }

extension CouponTypeExt on CouponType {
  String get value => name;
  String get label => this == CouponType.flat ? 'Flat' : '%';
}

class Coupon extends Equatable {
  final int? id;
  final String code;
  final CouponType discountType;
  final double discountValue;
  final int? maxUsage;
  final int usedCount;
  final DateTime? expiryDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Coupon({
    this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.maxUsage,
    this.usedCount = 0,
    this.expiryDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Coupon.fromMap(Map<String, dynamic> map) => Coupon(
    id: map['id'] as int?,
    code: map['code'] as String? ?? '',
    discountType: (map['discount_type'] as String? ?? 'flat') == 'percent'
        ? CouponType.percent
        : CouponType.flat,
    discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0.0,
    maxUsage: map['max_usage'] as int?,
    usedCount: map['used_count'] as int? ?? 0,
    expiryDate: map['expiry_date'] != null
        ? DateTime.tryParse(map['expiry_date'] as String)
        : null,
    isActive: (map['is_active'] as int? ?? 1) == 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'code': code,
    'discount_type': discountType.value,
    'discount_value': discountValue,
    'max_usage': maxUsage,
    'used_count': usedCount,
    'expiry_date': expiryDate?.toIso8601String(),
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Coupon copyWith({
    String? code,
    CouponType? discountType,
    double? discountValue,
    int? maxUsage,
    int? usedCount,
    DateTime? expiryDate,
    bool? isActive,
  }) => Coupon(
    id: id,
    code: code ?? this.code,
    discountType: discountType ?? this.discountType,
    discountValue: discountValue ?? this.discountValue,
    maxUsage: maxUsage ?? this.maxUsage,
    usedCount: usedCount ?? this.usedCount,
    expiryDate: expiryDate ?? this.expiryDate,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  @override
  List<Object?> get props => [id, code, discountType, discountValue, maxUsage, usedCount, expiryDate, isActive];
}

class AppliedCoupon extends Equatable {
  final int? couponId;
  final String code;
  final CouponType discountType;
  final double discountValue;
  final double discountAmount;

  const AppliedCoupon({
    this.couponId,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
  });

  @override
  List<Object?> get props => [couponId, code, discountType, discountValue, discountAmount];
}


// ─── Bill Model (DB) ──────────────────────────────────────────────────────────
class BillModel extends Bill {
  const BillModel({
    super.id,
    required super.billNumber,
    required super.items,
    required super.totalAmount,
    required super.totalProfit,
    super.discountAmount,
    super.paymentMode,
    super.customerName,
    super.couponId,
    super.couponCode,
    super.couponDiscountAmount,
    super.cashTendered,
    super.changeAmount,
    super.notes,
    required super.createdAt,
    // FIX BUG#9: expose GST fields so fromMap can populate them
    super.gstTotal,
    super.cgstTotal,
    super.sgstTotal,
    super.igstTotal,  // FIX BUG#2
    super.billType,
    super.customerId,
    super.customerAddress,
    super.customerGstin,
    super.splitPaymentSummary,
  });

  factory BillModel.fromMap(Map<String, dynamic> map, List<BillItem> items) {
    return BillModel(
      id: map['id'] as int?,
      billNumber: map['bill_number'] as String,
      items: items,
      totalAmount: (map['total_amount'] as num).toDouble(),
      totalProfit: (map['total_profit'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['payment_mode'] as String? ?? 'cash',
      customerName: map['customer_name'] as String?,
      couponId: map['coupon_id'] as int?,
      couponCode: map['coupon_code'] as String?,
      couponDiscountAmount:
          (map['coupon_discount_amount'] as num?)?.toDouble() ?? 0.0,
      cashTendered: (map['cash_tendered'] as num?)?.toDouble(),
      changeAmount: (map['change_amount'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      // FIX BUG#9: read GST columns that were silently dropped before
      gstTotal: (map['gst_total'] as num?)?.toDouble() ?? 0.0,
      cgstTotal: (map['cgst_total'] as num?)?.toDouble() ?? 0.0,
      sgstTotal: (map['sgst_total'] as num?)?.toDouble() ?? 0.0,
      igstTotal: (map['igst_total'] as num?)?.toDouble() ?? 0.0,  // FIX BUG#2
      billType: map['bill_type'] as String? ?? 'retail',
      customerId: map['customer_id'] as int?,
      customerAddress: map['customer_address'] as String?,
      customerGstin: map['customer_gstin'] as String?,
      splitPaymentSummary: map['split_payment_summary'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bill_number': billNumber,
      'total_amount': totalAmount,
      'total_profit': totalProfit,
      'discount_amount': discountAmount,
      'coupon_id': couponId,
      'coupon_code': couponCode,
      'coupon_discount_amount': couponDiscountAmount,
      'cash_tendered': cashTendered,
      'change_amount': changeAmount,
      'payment_mode': paymentMode,
      'customer_name': customerName,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
