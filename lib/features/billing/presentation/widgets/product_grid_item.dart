import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/bill.dart';

class ProductGridItem extends StatelessWidget {
  final Product product;
  final BillType billType; // ✅ NEW — shows correct price
  final VoidCallback onTap;

  const ProductGridItem({
    super.key,
    required this.product,
    required this.billType,
    required this.onTap,
  });

  // ✅ Returns the correct display price based on bill type
  double get _displayPrice {
    if (billType == BillType.wholesale && product.wholesalePrice > 0) {
      return product.wholesalePrice;
    }
    return product.sellingPrice;
  }

  @override
  Widget build(BuildContext context) {
    final isWholesale = billType == BillType.wholesale;
    final trimmedName = product.name.trim();
    final productName = trimmedName.isEmpty ? 'No Name' : trimmedName;
    final stockBadgeColor = _getStockBadgeColor();
    final stockBadgeLabel = _getStockBadgeLabel();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: product.isOutOfStock ? AppTheme.outOfStockColor : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: product.isLowStock
                ? AppTheme.warning
                : product.isOutOfStock
                ? AppTheme.danger.withOpacity(0.3)
                : AppTheme.divider,
            width: product.isLowStock ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(9.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 80.h,
                decoration: BoxDecoration(
                  color: _getCategoryColor(),
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: product.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(9.r),
                        child: product.imageUrl!.startsWith('http')
                            ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                            : Image.file(File(product.imageUrl!), fit: BoxFit.cover),
                      )
                    : Center(
                        child: Text(
                          _getCategoryEmoji(),
                          style: TextStyle(fontSize: 35.sp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
              SizedBox(height: 6.h),
              Text(
                productName,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Poppins',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Text(
                CurrencyFormatter.format(_displayPrice),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: product.isOutOfStock
                      ? AppTheme.textSecondary
                      : isWholesale
                      ? AppTheme.secondary
                      : AppTheme.primary,
                  fontFamily: 'Poppins',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: stockBadgeColor,
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      child: Text(
                        stockBadgeLabel,
                        style: TextStyle(
                          color: _getStockBadgeTextColor(),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (isWholesale && product.wholesalePrice > 0) ...[
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'WS',
                        style: TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    const colors = [
      Color(0xFFFFF3E0), Color(0xFFE8F5E9), Color(0xFFFCE4EC),
      Color(0xFFE3F2FD), Color(0xFFF3E5F5), Color(0xFFE0F2F1),
    ];
    return colors[(product.categoryId ?? 0) % colors.length];
  }

  String _getCategoryEmoji() {
    final name = (product.categoryName ?? '').toLowerCase();
    if (name.contains('beverage') || name.contains('drink')) return '☕';
    if (name.contains('food')) return '🍱';
    if (name.contains('snack')) return '🍪';
    if (name.contains('sweet')) return '🍬';
    if (name.contains('bakery') || name.contains('bread')) return '🥖';
    return '📦';
  }

  Color _getStockBadgeColor() {
    if (product.isOutOfStock) return AppTheme.outOfStockColor;
    if (product.isLowStock) return AppTheme.lowStockColor;
    return const Color(0xFFECFDF5);
  }

  Color _getStockBadgeTextColor() {
    if (product.isOutOfStock) return AppTheme.danger;
    if (product.isLowStock) return AppTheme.warning;
    return AppTheme.success;
  }

  String _getStockBadgeLabel() {
    if (product.isOutOfStock) return 'OUT';
    if (product.isLowStock) return 'LOW';
    final quantity = product.stockQuantity % 1 == 0
        ? product.stockQuantity.toInt()
        : product.stockQuantity;
    return '$quantity ${product.displayUnit}';
  }
}