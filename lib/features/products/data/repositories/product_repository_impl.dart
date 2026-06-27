import 'dart:io' as io;

import 'package:dio/dio.dart' show Options, DioException;
import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/backend/backend_api_service.dart';
import '../../../../core/backend/backend_id_mapper.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/ledger/ledger_service.dart';
import '../../../../core/sync/data_access_mode_service.dart';
import '../../../../core/utils/uom_conversion_helper.dart';
import '../../domain/entities/product.dart';
import '../../../users/domain/entities/product_uom.dart';

abstract class ProductRepository {
  Future<List<Product>> getAllProducts();
  Future<List<Product>> searchProducts(String query);
  Future<List<Product>> getLowStockProducts();
  Future<int> addProduct(Product product);
  Future<bool> updateProduct(Product product);
  Future<bool> deleteProduct(int id);
  Future<bool> updateStock(int productId, double quantity);
  Future<List<Category>> getAllCategories();
  Future<int> addCategory(Category category);
  Future<bool> deleteCategory(int id);
  Future<List<ProductUom>> getProductUoms(int productId);
  Future<int> addProductUom(ProductUom uom);
  Future<bool> updateProductUom(ProductUom uom);
  Future<bool> deleteProductUom(int id);
  
  // Master Catalog methods (Owner Dashboard)
  Future<List<Product>> getMasterProducts();
  Future<int> upsertMasterProduct(Product product);
}

class ProductRepositoryImpl implements ProductRepository {
  final DatabaseHelper _dbHelper;
  static const _uuid = Uuid();
  ProductRepositoryImpl(this._dbHelper);

  Future<bool> _isOnlineMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.onlineApi;

  Future<String?> _lookupUuid(String namespace, int? id) async {
    if (id == null) return null;
    return BackendIdMapper.instance.lookupUuid(namespace: namespace, id: id);
  }

  Future<int> _registerUuid(String namespace, String? uuid) async {
    if (uuid == null || uuid.isEmpty) return 0;
    return BackendIdMapper.instance.register(namespace: namespace, uuid: uuid);
  }

  double _doubleValue(dynamic value, [double fallback = 0.0]) =>
      value is num ? value.toDouble() : fallback;

  @override Future<List<Product>> getAllProducts() async {
    if (await _isOnlineMode()) {
      final rows = await BackendApiService.instance.withAuthRetry<List<dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.get<List<dynamic>>(
          'products',
          options: Options(headers: headers),
        );
        return response.data ?? const <dynamic>[];
      });
      final products = <Product>[];
      for (final raw in rows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final clientRecordId =
            (row['clientRecordId'] ?? row['client_record_id'] ?? row['serverId'])
                ?.toString();
        final categoryUuid =
            (row['categoryId'] ?? row['category_id'])?.toString();
        final brandUuid = (row['brandId'] ?? row['brand_id'])?.toString();
        final updatedAtRaw = (row['updatedAt'] ?? row['updated_at'])?.toString();
        final updatedAt =
            DateTime.tryParse(updatedAtRaw ?? '') ?? DateTime.now();
        products.add(
          ProductModel(
            id: await _registerUuid('products', clientRecordId),
            name: (row['name'] ?? '').toString(),
            categoryId: categoryUuid == null
                ? null
                : await _registerUuid('categories', categoryUuid),
            brandId: brandUuid == null
                ? null
                : await _registerUuid('brands', brandUuid),
            purchasePrice: _doubleValue(
              row['purchasePrice'] ?? row['purchase_price'],
            ),
            sellingPrice: _doubleValue(
              row['sellingPrice'] ?? row['selling_price'],
            ),
            wholesalePrice: _doubleValue(
              row['wholesalePrice'] ?? row['wholesale_price'],
            ),
            stockQuantity: _doubleValue(
              row['stockQuantity'] ?? row['stock_quantity'],
            ),
            unit: (row['unit'] ?? 'piece').toString(),
            lowStockThreshold: _doubleValue(
                      row['lowStockThreshold'] ?? row['low_stock_threshold'],
                    ) ==
                    0
                ? 5.0
                : _doubleValue(
                    row['lowStockThreshold'] ?? row['low_stock_threshold'],
                  ),
            gstRate: _doubleValue(row['gstRate'] ?? row['gst_rate']),
            barcode: row['barcode']?.toString(),
            hsnCode: row['hsnCode']?.toString() ?? row['hsn_code']?.toString(),
            isActive: row['deletedAt'] == null && row['deleted_at'] == null,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            itemType:
                (row['itemType'] ?? row['item_type'] ?? 'physical').toString(),
            imageUrl: row['imageUrl']?.toString() ?? row['image_url']?.toString(),
          ),
        );
      }
      return products;
    }
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name, b.name as brand_name, u.short_name as uom_short_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN uom_units u ON p.uom_id = u.id
      WHERE p.is_active = 1 ORDER BY p.name ASC''');
    final products = rows.map((m) => ProductModel.fromMap(m)).toList();
    return _enrichWithDerivedStock(db, products);
  }

  @override Future<List<Product>> searchProducts(String query) async {
    if (await _isOnlineMode()) {
      final normalized = query.trim().toLowerCase();
      final products = await getAllProducts();
      if (normalized.isEmpty) return products;
      return products.where((product) {
        return product.name.toLowerCase().contains(normalized) ||
            (product.barcode?.toLowerCase().contains(normalized) ?? false) ||
            (product.sku?.toLowerCase().contains(normalized) ?? false);
      }).toList();
    }
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name, b.name as brand_name, u.short_name as uom_short_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN uom_units u ON p.uom_id = u.id
      WHERE p.is_active = 1 AND (p.name LIKE ? OR p.barcode LIKE ? OR p.sku LIKE ?)
      ORDER BY p.name ASC''', ['%$query%', '%$query%', '%$query%']);
    final products = rows.map((m) => ProductModel.fromMap(m)).toList();
    return _enrichWithDerivedStock(db, products);
  }

  /// Exact barcode lookup — returns the matching product or null.
  Future<Product?> findByBarcode(String barcode) async {
    if (barcode.isEmpty) return null;
    if (await _isOnlineMode()) {
      final normalized = barcode.trim();
      final products = await getAllProducts();
      for (final product in products) {
        if (product.barcode == normalized) {
          return product;
        }
      }
      return null;
    }
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name, b.name as brand_name, u.short_name as uom_short_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN uom_units u ON p.uom_id = u.id
      WHERE p.is_active = 1 AND p.barcode = ?
      LIMIT 1''', [barcode]);
    if (rows.isEmpty) return null;
    return ProductModel.fromMap(rows.first);
  }

  @override Future<List<Product>> getLowStockProducts() async {
    if (await _isOnlineMode()) {
      final products = await getAllProducts();
      return products.where((product) => product.isLowStock).toList();
    }
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name, b.name as brand_name, u.short_name as uom_short_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN uom_units u ON p.uom_id = u.id
      WHERE p.is_active = 1 AND p.stock_quantity > 0
        AND p.stock_quantity <= p.low_stock_threshold
        AND p.item_type != 'composite_recipe'
      ORDER BY p.stock_quantity ASC''');
    return rows.map((m) => ProductModel.fromMap(m)).toList();
  }

  @override Future<int> addProduct(Product product) async {
    if (await _isOnlineMode()) {
      var finalProduct = product;
      if (product.imageUrl != null && !product.imageUrl!.startsWith('http')) {
        final uploadUrl = await BackendApiService.instance.uploadImage(io.File(product.imageUrl!));
        if (uploadUrl != null) {
          finalProduct = product.copyWith(imageUrl: uploadUrl);
        }
      }

      final clientRecordId = _uuid.v4();
      final response =
          await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'products/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'categoryId': await _lookupUuid('categories', finalProduct.categoryId),
            'brandId': await _lookupUuid('brands', finalProduct.brandId),
            'name': finalProduct.name,
            'unit': finalProduct.unit,
            'sellingPrice': finalProduct.sellingPrice,
            'purchasePrice': finalProduct.purchasePrice,
            'wholesalePrice': finalProduct.wholesalePrice,
            'stockQuantity': finalProduct.stockQuantity,
            'lowStockThreshold': finalProduct.lowStockThreshold,
            'gstRate': finalProduct.gstRate,
            'barcode': finalProduct.barcode,
            'hsnCode': finalProduct.hsnCode,
            'itemType': finalProduct.itemType,
            'sku': finalProduct.sku,
            'attributes': finalProduct.attributes,
            'imageUrl': finalProduct.imageUrl,
            'updatedAt': finalProduct.updatedAt.toUtc().toIso8601String(),
            'version': 1,
            'deleted': false,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      }).catchError((e) {
        if (e is DioException) {
          final serverMsg = e.response?.data?['message'] ?? e.response?.data ?? e.message;
          throw Exception('Server Error: $serverMsg');
        }
        throw e;
      });
      return _registerUuid(
        'products',
        (response['clientRecordId'] ?? clientRecordId).toString(),
      );
    }
    final db = await _dbHelper.database;
    final productId = await db.insert('products', (product as ProductModel).toMap());

    // ── Opening stock ledger ─────────────────────────────────────────────
    // Only create a ledger entry when the product is added with stock > 0.
    // Normal add-product (no stock) does NOT create any ledger entries.
    if (product.stockQuantity > 0) {
      try {
        final ledger = LedgerService.instance;
        final licenseId = await LedgerService.resolveLicenseId(_dbHelper);
        final nowStr = DateTime.now().toIso8601String();
        // purchasePrice is per user-facing unit (e.g. per kg).
        // stockQuantity on the entity is user-facing (e.g. 10 kg).
        final inventoryValue = product.purchasePrice * product.stockQuantity;
        // quantityChange in ledger uses base units to match DB stock_quantity.
        final stockFactor = UomConversionHelper.baseFactor(product.unit);
        final stockBase = product.stockQuantity * stockFactor;
        await ledger.recordTransaction(
          executor: db,
          type: 'stock_adjustment',
          totalAmount: inventoryValue,
          tags: {
            'product_id': productId,
            'product_name': product.name,
            'reason': 'opening_stock',
          },
          licenseId: licenseId,
          createdAt: nowStr,
          entries: [
            LedgerEntryInput(
              accountType: 'inventory', direction: 'debit',
              amount: inventoryValue, quantityChange: stockBase,
            ),
            LedgerEntryInput(
              accountType: 'liability', direction: 'credit',
              amount: inventoryValue,
            ),
          ],
        );
      } catch (e, st) {
        // Ledger failure must not block product creation.
        // Log for audit purposes.
        debugPrint('[LedgerService] opening stock ledger write failed: $e\n$st');
      }
    }

    return productId;
  }

  @override Future<bool> updateProduct(Product product) async {
    if (await _isOnlineMode()) {
      var finalProduct = product;
      if (product.imageUrl != null && !product.imageUrl!.startsWith('http')) {
        final uploadUrl = await BackendApiService.instance.uploadImage(io.File(product.imageUrl!));
        if (uploadUrl != null) {
          finalProduct = product.copyWith(imageUrl: uploadUrl);
        }
      }

      final clientRecordId = await _lookupUuid('products', finalProduct.id) ?? _uuid.v4();
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'products/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'categoryId': await _lookupUuid('categories', finalProduct.categoryId),
            'brandId': await _lookupUuid('brands', finalProduct.brandId),
            'name': finalProduct.name,
            'unit': finalProduct.unit,
            'sellingPrice': finalProduct.sellingPrice,
            'purchasePrice': finalProduct.purchasePrice,
            'wholesalePrice': finalProduct.wholesalePrice,
            'stockQuantity': finalProduct.stockQuantity,
            'lowStockThreshold': finalProduct.lowStockThreshold,
            'gstRate': finalProduct.gstRate,
            'barcode': finalProduct.barcode,
            'hsnCode': finalProduct.hsnCode,
            'itemType': finalProduct.itemType,
            'sku': finalProduct.sku,
            'attributes': finalProduct.attributes,
            'imageUrl': finalProduct.imageUrl,
            'updatedAt': finalProduct.updatedAt.toUtc().toIso8601String(),
            'version': 1,
            'deleted': !finalProduct.isActive,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      await _registerUuid('products', clientRecordId);
      return true;
    }
    final db = await _dbHelper.database;
    final updated = (await db.update('products', (product as ProductModel).toMap(), where: 'id=?', whereArgs: [product.id])) > 0;
    return updated;
  }

  @override Future<bool> deleteProduct(int id) async {
    if (await _isOnlineMode()) {
      final clientRecordId = await _lookupUuid('products', id);
      if (clientRecordId == null) return false;
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'products/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': 'Deleted product',
            'unit': 'piece',
            'sellingPrice': 0,
            'purchasePrice': 0,
            'stockQuantity': 0,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            'version': 1,
            'deleted': true,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      return true;
    }
    final db = await _dbHelper.database;
    final updated = (await db.update('products', {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [id])) > 0;
    return updated;
  }

  @override Future<bool> updateStock(int productId, double quantityChange) async {
    final db = await _dbHelper.database;

    // quantityChange is supplied in user-facing units by callers (e.g., 2 Kg).
    // DB stores stock in the smallest base unit (e.g., grams), so we look up
    // the product unit and apply the conversion factor before persisting.
    final productUnitRows = await db.query('products',
        columns: ['unit', 'purchase_price', 'name'],
        where: 'id = ?', whereArgs: [productId]);
    final productUnit = productUnitRows.isNotEmpty
        ? productUnitRows.first['unit'] as String? ?? 'piece'
        : 'piece';
    final factor = UomConversionHelper.baseFactor(productUnit);
    final baseQtyChange = quantityChange * factor;

    final updated = (await db.rawUpdate(
        'UPDATE products SET stock_quantity = stock_quantity + ?, updated_at = ? WHERE id = ?',
        [baseQtyChange, DateTime.now().toIso8601String(), productId])) > 0;

    if (updated) {
      // ── Stock adjustment ledger ────────────────────────────────────────
      // Increase:  DR Inventory  / CR Asset (adjustment gain)
      // Decrease:  DR Expense    / CR Inventory
      // quantityChange entries use base units to match stock_quantity in DB.
      try {
        final ledger = LedgerService.instance;
        final licenseId = await LedgerService.resolveLicenseId(_dbHelper);
        final nowStr = DateTime.now().toIso8601String();

        // Reuse already-fetched product rows; avoid a second round-trip.
        final purchasePrice = productUnitRows.isNotEmpty
            ? (productUnitRows.first['purchase_price'] as num?)?.toDouble() ?? 0.0
            : 0.0;
        final productName = productUnitRows.isNotEmpty
            ? productUnitRows.first['name'] as String? ?? 'Product'
            : 'Product';
        // Valuation uses user-facing quantity × purchase price (price is per
        // user unit, e.g. per kg, not per gram).
        final inventoryValue = purchasePrice * quantityChange.abs();

        final List<LedgerEntryInput> entries;
        if (quantityChange > 0) {
          // Stock increase: DR Inventory / CR Asset (adjustment)
          entries = [
            LedgerEntryInput(
              accountType: 'inventory', direction: 'debit',
              amount: inventoryValue, quantityChange: baseQtyChange,
            ),
            LedgerEntryInput(
              accountType: 'asset', direction: 'credit',
              amount: inventoryValue,
            ),
          ];
        } else {
          // Stock decrease (write-down): DR Expense / CR Inventory
          entries = [
            LedgerEntryInput(
              accountType: 'expense', direction: 'debit',
              amount: inventoryValue,
            ),
            LedgerEntryInput(
              accountType: 'inventory', direction: 'credit',
              amount: inventoryValue, quantityChange: baseQtyChange,
            ),
          ];
        }

        await ledger.recordTransaction(
          executor: db,
          type: 'stock_adjustment',
          totalAmount: inventoryValue,
          tags: {
            'product_id': productId,
            'product_name': productName,
            'quantity_change': quantityChange,
          },
          licenseId: licenseId,
          createdAt: nowStr,
          entries: entries,
        );
      } catch (e, st) {
        // Ledger failure must not block stock update.
        // Log for audit purposes.
        debugPrint('[LedgerService] stock adjustment ledger write failed: $e\n$st');
      }
    }

    return updated;
  }

  /// Replaces [stockQuantity] in-memory for every composite_recipe product with
  /// the derived stock: the maximum whole units that can be produced given the
  /// current raw-material inventory.
  ///
  ///   derived = floor( min over all BOM ingredients of (ingredient_stock / qty_per_unit) )
  ///
  /// This keeps the displayed and billing-checked stock accurate without
  /// requiring a separate DB column for composite recipes.
  Future<List<Product>> _enrichWithDerivedStock(
      Database db, List<Product> products) async {
    final recipes = products.where((p) => p.isCompositeRecipe).toList();
    if (recipes.isEmpty) return products;

    // Collect all ingredient product IDs referenced across all recipes.
    final allIngIds = <int>{};
    for (final r in recipes) {
      for (final ing in r.bomIngredients) {
        if (ing.productId != null) allIngIds.add(ing.productId!);
      }
    }
    if (allIngIds.isEmpty) {
      // No linked ingredients — all recipes report 0 stock.
      return products.map((p) =>
          p.isCompositeRecipe ? p.copyWith(stockQuantity: 0.0) : p).toList();
    }

    // Fetch stock AND unit for all ingredient products in a single query.
    // unit is needed to convert DB base-unit stock back to user-facing units
    // so we can compare against BOM ingredient quantities (stored in user units).
    final placeholders = List.filled(allIngIds.length, '?').join(',');
    final materialRows = await db.rawQuery(
        'SELECT id, stock_quantity, unit FROM products WHERE id IN ($placeholders)',
        allIngIds.toList());
    final materialStocks = <int, double>{
      for (final row in materialRows)
        row['id'] as int: (row['stock_quantity'] as num).toDouble()
    };
    final materialUnits = <int, String>{
      for (final row in materialRows)
        row['id'] as int: row['unit'] as String? ?? 'piece'
    };

    return products.map((p) {
      if (!p.isCompositeRecipe) return p;
      final ings = p.bomIngredients;
      if (ings.isEmpty) return p.copyWith(stockQuantity: 0.0);
      double minCanMake = double.infinity;
      for (final ing in ings) {
        if (ing.productId == null || ing.quantity <= 0) continue;
        // materialStocks holds the DB value in base units (g / ml).
        // Convert to user-facing units before comparing with ing.quantity
        // (which is also in user-facing units, e.g. 100 g stored as 100, not
        // 100000 — BOM JSON is never migrated to base units).
        final ingUnit = materialUnits[ing.productId!] ?? 'piece';
        final ingFactor = UomConversionHelper.baseFactor(ingUnit);
        final availBase = materialStocks[ing.productId!] ?? 0.0;
        final availUser = availBase / ingFactor;
        final canMake = availUser / ing.quantity;
        if (canMake < minCanMake) minCanMake = canMake;
      }
      if (minCanMake == double.infinity) minCanMake = 0;
      return p.copyWith(stockQuantity: minCanMake.floorToDouble());
    }).toList();
  }

  @override Future<List<Category>> getAllCategories() async {
    if (await _isOnlineMode()) {
      final rows = await BackendApiService.instance.withAuthRetry<List<dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.get<List<dynamic>>(
          'categories',
          options: Options(headers: headers),
        );
        return response.data ?? const <dynamic>[];
      });
      final categories = <Category>[];
      for (final raw in rows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        categories.add(
          Category(
            id: await _registerUuid(
              'categories',
              (row['clientRecordId'] ?? row['client_record_id'] ?? row['serverId'])
                  ?.toString(),
            ),
            name: (row['name'] ?? '').toString(),
          ),
        );
      }
      return categories;
    }
    final db = await _dbHelper.database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map((m) => Category.fromMap(m)).toList();
  }

  @override Future<int> addCategory(Category category) async {
    if (await _isOnlineMode()) {
      final clientRecordId = _uuid.v4();
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'categories/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': category.name,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            'version': 1,
            'deleted': false,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      return _registerUuid('categories', clientRecordId);
    }
    final db = await _dbHelper.database;
    final categoryId = await db.insert('categories', category.toMap());
    return categoryId;
  }

  @override Future<bool> deleteCategory(int id) async {
    if (await _isOnlineMode()) {
      final clientRecordId = await _lookupUuid('categories', id);
      if (clientRecordId == null) return false;
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'categories/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': 'Deleted category',
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            'version': 1,
            'deleted': true,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      return true;
    }
    final db = await _dbHelper.database;
    final deleted = (await db.delete('categories', where: 'id=?', whereArgs: [id])) > 0;
    return deleted;
  }

  @override Future<List<ProductUom>> getProductUoms(int productId) async {
    if (await _isOnlineMode()) {
      return const <ProductUom>[];
    }
    final db = await _dbHelper.database;
    final rows = await db.query('product_uoms',
        where: "product_id = ? AND unit_role = 'sale'",
        whereArgs: [productId],
        orderBy: 'is_default DESC, id ASC');
    return rows.map((m) => ProductUom.fromMap(m)).toList();
  }

  @override Future<int> addProductUom(ProductUom uom) async {
    if (await _isOnlineMode()) {
      return 0;
    }
    final db = await _dbHelper.database;
    if (uom.isDefault) {
      await db.update('product_uoms', {'is_default': 0},
          where: 'product_id = ?', whereArgs: [uom.productId]);
    }
    return await db.insert('product_uoms', uom.toMap());
  }

  @override Future<bool> updateProductUom(ProductUom uom) async {
    if (await _isOnlineMode()) {
      return false;
    }
    final db = await _dbHelper.database;
    if (uom.isDefault) {
      await db.update('product_uoms', {'is_default': 0},
          where: 'product_id = ? AND id != ?', whereArgs: [uom.productId, uom.id]);
    }
    return (await db.update('product_uoms', uom.toMap(),
        where: 'id = ?', whereArgs: [uom.id])) > 0;
  }

  @override Future<bool> deleteProductUom(int id) async {
    if (await _isOnlineMode()) {
      return false;
    }
    final db = await _dbHelper.database;
    return (await db.delete('product_uoms', where: 'id = ?', whereArgs: [id])) > 0;
  }

  // ── Master Catalog Operations ───────────────────────────────────────────────

  @override
  Future<List<Product>> getMasterProducts() async {
    // Master catalog always fetches from the backend API directly, bypassing SQLite
    final rows = await BackendApiService.instance.withAuthRetry<List<dynamic>>((
      dio,
      headers,
    ) async {
      final response = await dio.get<List<dynamic>>(
        'products',
        options: Options(headers: headers),
      );
      return response.data ?? const <dynamic>[];
    }, allowManagementCalls: true);
    
    final products = <Product>[];
    for (final raw in rows.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final clientRecordId = (row['clientRecordId'] ?? row['client_record_id'] ?? row['serverId'])?.toString();
      final categoryUuid = (row['categoryId'] ?? row['category_id'])?.toString();
      final brandUuid = (row['brandId'] ?? row['brand_id'])?.toString();
      final updatedAtRaw = (row['updatedAt'] ?? row['updated_at'])?.toString();
      final updatedAt = DateTime.tryParse(updatedAtRaw ?? '') ?? DateTime.now();
      products.add(
        ProductModel(
          id: await _registerUuid('products', clientRecordId),
          name: (row['name'] ?? '').toString(),
          categoryId: categoryUuid == null ? null : await _registerUuid('categories', categoryUuid),
          brandId: brandUuid == null ? null : await _registerUuid('brands', brandUuid),
          purchasePrice: _doubleValue(row['purchasePrice'] ?? row['purchase_price']),
          sellingPrice: _doubleValue(row['sellingPrice'] ?? row['selling_price']),
          wholesalePrice: _doubleValue(row['wholesalePrice'] ?? row['wholesale_price']),
          stockQuantity: _doubleValue(row['stockQuantity'] ?? row['stock_quantity']),
          unit: (row['unit'] ?? 'piece').toString(),
          lowStockThreshold: _doubleValue(row['lowStockThreshold'] ?? row['low_stock_threshold']) == 0 ? 5.0 : _doubleValue(row['lowStockThreshold'] ?? row['low_stock_threshold']),
          gstRate: _doubleValue(row['gstRate'] ?? row['gst_rate']),
          barcode: row['barcode']?.toString(),
          hsnCode: row['hsnCode']?.toString() ?? row['hsn_code']?.toString(),
          isActive: row['deletedAt'] == null && row['deleted_at'] == null,
          createdAt: updatedAt,
          updatedAt: updatedAt,
          itemType: (row['itemType'] ?? row['item_type'] ?? 'physical').toString(),
          imageUrl: row['imageUrl']?.toString() ?? row['image_url']?.toString(),
        ),
      );
    }
    return products;
  }

  @override
  Future<int> upsertMasterProduct(Product product) async {
    var finalProduct = product;
    if (product.imageUrl != null && !product.imageUrl!.startsWith('http')) {
      final uploadUrl = await BackendApiService.instance.uploadImage(io.File(product.imageUrl!));
      if (uploadUrl != null) {
        finalProduct = product.copyWith(imageUrl: uploadUrl);
      }
    }
    
    final clientRecordId = finalProduct.id != null 
        ? await BackendIdMapper.instance.lookupUuid(namespace: 'products', id: finalProduct.id!) ?? _uuid.v4()
        : _uuid.v4();

    final response = await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
      dio,
      headers,
    ) async {
      final response = await dio.post<Map<String, dynamic>>(
        'products/upsert',
        data: {
          'clientRecordId': clientRecordId,
          'categoryId': await _lookupUuid('categories', finalProduct.categoryId),
          'brandId': await _lookupUuid('brands', finalProduct.brandId),
          'name': finalProduct.name,
          'unit': finalProduct.unit,
          'sellingPrice': finalProduct.sellingPrice,
          'purchasePrice': finalProduct.purchasePrice,
          'wholesalePrice': finalProduct.wholesalePrice,
          'stockQuantity': finalProduct.stockQuantity,
          'lowStockThreshold': finalProduct.lowStockThreshold,
          'gstRate': finalProduct.gstRate,
          'barcode': finalProduct.barcode,
          'hsnCode': finalProduct.hsnCode,
          'itemType': finalProduct.itemType,
          'sku': finalProduct.sku,
          'attributes': finalProduct.attributes,
          'imageUrl': finalProduct.imageUrl,
          'updatedAt': finalProduct.updatedAt.toUtc().toIso8601String(),
          'version': 1,
          'deleted': !finalProduct.isActive,
        },
        options: Options(headers: headers),
      );
      return response.data ?? <String, dynamic>{};
    }, allowManagementCalls: true).catchError((e) {
      if (e is DioException) {
        final serverMsg = e.response?.data?['message'] ?? e.response?.data ?? e.message;
        throw Exception('Server Error: $serverMsg');
      }
      throw e;
    });
    
    return _registerUuid(
      'products',
      (response['clientRecordId'] ?? clientRecordId).toString(),
    );
  }
}
