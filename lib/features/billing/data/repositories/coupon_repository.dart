import '../../../../core/database/database_helper.dart';
import '../../domain/entities/bill.dart';

class CouponRepository {
  final DatabaseHelper _dbHelper;

  CouponRepository(this._dbHelper);

  Future<List<Coupon>> getCoupons({String? search}) async {
    final db = await _dbHelper.forceLocalDatabase;
    final normalizedSearch = search?.trim();
    final rows = await db.query(
      'coupons',
      where: normalizedSearch == null || normalizedSearch.isEmpty
          ? null
          : 'code LIKE ?',
      whereArgs: normalizedSearch == null || normalizedSearch.isEmpty
          ? null
          : ['%${normalizedSearch.toUpperCase()}%'],
      orderBy: 'created_at DESC',
    );
    return rows.map(Coupon.fromMap).toList();
  }

  Future<int> createCoupon(Coupon coupon) async {
    final db = await _dbHelper.forceLocalDatabase;
    return db.insert('coupons', coupon.toMap());
  }

  Future<void> updateCouponStatus({
    required int id,
    required bool isActive,
  }) async {
    final db = await _dbHelper.forceLocalDatabase;
    await db.update(
      'coupons',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<AppliedCoupon> validateCoupon({
    required String code,
    required double amount,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw Exception('Enter a coupon code.');
    }

    final db = await _dbHelper.forceLocalDatabase;
    final rows = await db.query(
      'coupons',
      where: 'code = ?',
      whereArgs: [normalizedCode],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('Coupon not found.');
    }

    final coupon = Coupon.fromMap(rows.first);
    if (!coupon.isActive) {
      throw Exception('Coupon is disabled.');
    }

    final today = DateTime.now();
    if (coupon.expiryDate != null) {
      final expiry = DateTime(
        coupon.expiryDate!.year,
        coupon.expiryDate!.month,
        coupon.expiryDate!.day,
      );
      final nowDate = DateTime(today.year, today.month, today.day);
      if (nowDate.isAfter(expiry)) {
        throw Exception('Coupon has expired.');
      }
    }

    if (coupon.maxUsage != null && coupon.usedCount >= coupon.maxUsage!) {
      throw Exception('Coupon usage limit reached.');
    }

    if (amount <= 0) {
      throw Exception('Coupon cannot be applied to an empty bill.');
    }

    final discountAmount = coupon.discountType == CouponType.percent
        ? (amount * (coupon.discountValue.clamp(0, 100) / 100))
            .clamp(0.0, amount)
            .toDouble()
        : coupon.discountValue.clamp(0.0, amount).toDouble();

    if (discountAmount <= 0) {
      throw Exception('Coupon discount is invalid.');
    }

    return AppliedCoupon(
      couponId: coupon.id,
      code: coupon.code,
      discountType: coupon.discountType,
      discountValue: coupon.discountValue,
      discountAmount: discountAmount,
    );
  }
}
