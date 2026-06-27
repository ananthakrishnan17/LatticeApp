import 'dart:convert';
import 'package:NammaNanban/core/database/database_helper.dart';
import 'package:NammaNanban/core/sync/data_access_mode_service.dart';
import 'package:NammaNanban/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:NammaNanban/features/license/data/repositories/license_repository_impl.dart';
import 'package:NammaNanban/features/license/domain/entities/license.dart';
import 'package:NammaNanban/features/products/data/repositories/product_repository_impl.dart';
import 'package:NammaNanban/features/products/domain/entities/product.dart';
import 'package:NammaNanban/features/purchase/domain/entities/purchase.dart';
import 'package:NammaNanban/features/reports/data/repositories/report_repository.dart';
import 'package:NammaNanban/features/sale_return/presentation/pages/sale_return_page.dart';
import 'package:NammaNanban/core/utils/uom_conversion_helper.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void ensureMobilePosTestBinding() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

class MobilePosTestHarness {
  MobilePosTestHarness()
      : dbHelper = DatabaseHelper.instance,
        products = ProductRepositoryImpl(DatabaseHelper.instance),
        billing = BillingRepositoryImpl(DatabaseHelper.instance),
        purchases = PurchaseRepository(DatabaseHelper.instance),
        reports = ReportRepository(DatabaseHelper.instance),
        saleReturns = SaleReturnRepository(DatabaseHelper.instance),
        licenseRepository = LicenseRepositoryImpl();

  final DatabaseHelper dbHelper;
  final ProductRepositoryImpl products;
  final BillingRepositoryImpl billing;
  final PurchaseRepository purchases;
  final ReportRepository reports;
  final SaleReturnRepository saleReturns;
  final LicenseRepositoryImpl licenseRepository;

  Future<void> resetState() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final db = await dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    final tables = await db.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name NOT LIKE 'sqlite_%'
        AND name != 'android_metadata'
    ''');
    for (final row in tables) {
      final tableName = row['name'] as String?;
      if (tableName == null) continue;
      await db.rawDelete('DELETE FROM "$tableName"');
    }
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> setLicenseMode(LicenseType licenseType) async {
    final now = DateTime.now();
    final license = License(
      id: 'test-${licenseType.value}',
      mobileNumber: '9999999999',
      licenseType: licenseType,
      deviceId: 'device-under-test',
      activatedAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      isActive: true,
      createdAt: now,
    );
    await licenseRepository.cacheLicense(license);
    DataAccessModeService.instance.clearCache();
  }

  Future<DataAccessMode> resolveAccessMode() async {
    return DataAccessModeService.instance.resolveMode();
  }

  Future<int> addProduct({
    required String name,
    String itemType = 'physical',
    double purchasePrice = 10,
    double sellingPrice = 15,
    double stockQuantity = 0,
    double lowStockThreshold = 1,
    String unit = 'piece',
    double wholesalePrice = 0,
    double wholesaleToRetailQty = 1,
    double retailPrice = 0,
    Map<String, dynamic>? attributes,
  }) {
    final now = DateTime.now();
    return products.addProduct(
      ProductModel(
        name: name,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        wholesalePrice: wholesalePrice,
        stockQuantity: stockQuantity,
        lowStockThreshold: lowStockThreshold,
        unit: unit,
        wholesaleUnit: unit,
        retailUnit: unit,
        wholesaleToRetailQty: wholesaleToRetailQty,
        retailPrice: retailPrice > 0 ? retailPrice : sellingPrice,
        itemType: itemType,
        attributes: jsonEncode(attributes ?? const {}),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> purchaseStock({
    required int productId,
    required String productName,
    required double quantity,
    required double unitCost,
    String unit = 'piece',
    String? batchNumber,
  }) async {
    await purchases.savePurchase(
      items: [
        PurchaseCartItem(
          productId: productId,
          productName: productName,
          unit: unit,
          quantity: quantity,
          unitCost: unitCost,
          batchNumber: batchNumber,
        ),
      ],
      supplierName: 'Test Supplier',
      paymentMode: 'cash',
    );
  }

  Future<double> productStock(int productId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'products',
      columns: ['stock_quantity', 'unit'],
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (rows.isEmpty) {
      throw StateError('Product $productId not found');
    }
    final stockQuantity =
        (rows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final unit = rows.first['unit'] as String? ?? 'piece';
    return stockQuantity / UomConversionHelper.baseFactor(unit);
  }

  Future<Product> getProduct(int productId) async {
    final allProducts = await products.getAllProducts();
    return allProducts.firstWhere((product) => product.id == productId);
  }

  Future<List<Map<String, dynamic>>> rawRows(
    String sql, [
    List<Object?> arguments = const [],
  ]) async {
    final db = await dbHelper.database;
    return db.rawQuery(sql, arguments);
  }

  Future<Database> database() => dbHelper.database;
}
