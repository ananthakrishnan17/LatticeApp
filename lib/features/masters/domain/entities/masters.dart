import 'package:dio/dio.dart' show Options;
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';
import '../../../../core/backend/backend_api_service.dart';
import '../../../../core/backend/backend_id_mapper.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/data_access_mode_service.dart';
import '../../../products/domain/entities/product.dart';

// ─── Brand ─────────────────────────────────────────────────────────────────────
class Brand extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final DateTime createdAt;

  const Brand({this.id, required this.name, this.description, required this.createdAt});

  factory Brand.fromMap(Map<String, dynamic> m) => Brand(
      id: m['id'], name: m['name'], description: m['description'],
      createdAt: DateTime.parse(m['created_at']));

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name,
    'description': description, 'created_at': createdAt.toIso8601String()};

  @override List<Object?> get props => [id, name];
}

// ─── UOM Unit ─────────────────────────────────────────────────────────────────
class UomUnit extends Equatable {
  final int? id;
  final String name;
  final String shortName;
  final String uomType; // count, weight, volume, length
  final DateTime createdAt;

  const UomUnit({this.id, required this.name, required this.shortName,
    this.uomType = 'count', required this.createdAt});

  factory UomUnit.fromMap(Map<String, dynamic> m) => UomUnit(
      id: m['id'], name: m['name'], shortName: m['short_name'],
      uomType: m['uom_type'] ?? 'count', createdAt: DateTime.parse(m['created_at']));

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name, 'short_name': shortName,
    'uom_type': uomType, 'created_at': createdAt.toIso8601String()};

  String get displayName => '$name ($shortName)';
  @override List<Object?> get props => [id, name, shortName];
}

// ─── Customer ─────────────────────────────────────────────────────────────────
class Customer extends Equatable {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? gstNumber;
  final double creditLimit;
  final double outstandingBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({this.id, required this.name, this.phone, this.address,
    this.gstNumber, this.creditLimit = 0.0, this.outstandingBalance = 0.0,
    this.isActive = true, required this.createdAt, required this.updatedAt});

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
      id: m['id'], name: m['name'], phone: m['phone'], address: m['address'],
      gstNumber: m['gst_number'],
      creditLimit: (m['credit_limit'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance: (m['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: (m['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(m['created_at']),
      updatedAt: DateTime.parse(m['updated_at']));

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name, 'phone': phone, 'address': address,
    'gst_number': gstNumber, 'credit_limit': creditLimit,
    'outstanding_balance': outstandingBalance, 'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String()};

  Customer copyWith({String? name, String? phone, String? address, String? gstNumber,
    double? creditLimit, double? outstandingBalance, bool? isActive}) =>
      Customer(id: id, name: name ?? this.name, phone: phone ?? this.phone,
          address: address ?? this.address, gstNumber: gstNumber ?? this.gstNumber,
          creditLimit: creditLimit ?? this.creditLimit,
          outstandingBalance: outstandingBalance ?? this.outstandingBalance,
          isActive: isActive ?? this.isActive,
          createdAt: createdAt, updatedAt: DateTime.now());

  @override List<Object?> get props => [id, name, phone];
}

// ─── Supplier ─────────────────────────────────────────────────────────────────
class Supplier extends Equatable {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? gstNumber;
  final double outstandingBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({this.id, required this.name, this.phone, this.address,
    this.gstNumber, this.outstandingBalance = 0.0, this.isActive = true,
    required this.createdAt, required this.updatedAt});

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
      id: m['id'], name: m['name'], phone: m['phone'], address: m['address'],
      gstNumber: m['gst_number'],
      outstandingBalance: (m['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: (m['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(m['created_at']),
      updatedAt: DateTime.parse(m['updated_at']));

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'name': name, 'phone': phone, 'address': address,
    'gst_number': gstNumber, 'outstanding_balance': outstandingBalance,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String()};

  @override List<Object?> get props => [id, name, phone];
}

// ─── Masters Repository ────────────────────────────────────────────────────────
abstract class MastersRepository {
  // Brands
  Future<List<Brand>> getAllBrands();
  Future<int> addBrand(String name, {String? description});
  Future<bool> deleteBrand(int id);

  // UOM
  Future<List<UomUnit>> getAllUnits();
  Future<int> addUnit(UomUnit unit);
  Future<bool> deleteUnit(int id);

  // Customers
  Future<List<Customer>> getAllCustomers({String? search});
  Future<Customer?> getCustomerById(int id);
  Future<int> addCustomer(Customer customer);
  Future<bool> updateCustomer(Customer customer);
  Future<bool> deleteCustomer(int id);
  Future<void> addCategory(Category category);
  // Suppliers
  Future<List<Supplier>> getAllSuppliers({String? search});
  Future<Supplier?> getSupplierById(int id);
  Future<int> addSupplier(Supplier supplier);
  Future<bool> updateSupplier(Supplier supplier);
  Future<bool> deleteSupplier(int id);
}

class MastersRepositoryImpl implements MastersRepository {
  final DatabaseHelper _db;
  static const _uuid = Uuid();
  MastersRepositoryImpl(this._db);

  Future<bool> _isOnlineMode() async =>
      (await DataAccessModeService.instance.resolveMode()) ==
      DataAccessMode.onlineApi;

  Future<int> _registerUuid(String namespace, String? uuid) async {
    if (uuid == null || uuid.isEmpty) return 0;
    return BackendIdMapper.instance.register(namespace: namespace, uuid: uuid);
  }

  Future<String?> _lookupUuid(String namespace, int? id) async {
    if (id == null) return null;
    return BackendIdMapper.instance.lookupUuid(namespace: namespace, id: id);
  }

  double _doubleValue(dynamic value, [double fallback = 0.0]) =>
      value is num ? value.toDouble() : fallback;

  // ── Brands ─────────────────────────────────────────────────────────────────
  @override Future<List<Brand>> getAllBrands() async {
    if (await _isOnlineMode()) {
      final rows = await BackendApiService.instance.withAuthRetry<List<dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.get<List<dynamic>>(
          'brands',
          options: Options(headers: headers),
        );
        return response.data ?? const <dynamic>[];
      });
      final now = DateTime.now();
      return Future.wait(rows.whereType<Map>().map((raw) async {
        final row = Map<String, dynamic>.from(raw);
        return Brand(
          id: await _registerUuid(
            'brands',
            (row['clientRecordId'] ?? row['client_record_id'] ?? row['serverId'])
                ?.toString(),
          ),
          name: (row['name'] ?? '').toString(),
          createdAt:
              DateTime.tryParse((row['updatedAt'] ?? row['updated_at'] ?? '').toString()) ??
                  now,
        );
      }));
    }
    final db = await _db.database;
    final rows = await db.query('brands', orderBy: 'name ASC');
    return rows.map((r) => Brand.fromMap(r)).toList();
  }
  @override
  Future<void> addCategory(Category category) async {
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
      await _registerUuid('categories', clientRecordId);
      return;
    }
    final db = await _db.database;
    await db.insert('categories', category.toMap());
  }
  @override Future<int> addBrand(String name, {String? description}) async {
    if (await _isOnlineMode()) {
      final clientRecordId = _uuid.v4();
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'brands/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': name,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            'version': 1,
            'deleted': false,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      return _registerUuid('brands', clientRecordId);
    }
    final db = await _db.database;
    return await db.insert('brands', {
      'name': name, 'description': description,
      'created_at': DateTime.now().toIso8601String()});
  }

  @override Future<bool> deleteBrand(int id) async {
    if (await _isOnlineMode()) {
      final clientRecordId = await _lookupUuid('brands', id);
      if (clientRecordId == null) return false;
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'brands/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': 'Deleted brand',
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
    final db = await _db.database;
    return (await db.delete('brands', where: 'id=?', whereArgs: [id])) > 0;
  }

  // ── UOM ────────────────────────────────────────────────────────────────────
  @override Future<List<UomUnit>> getAllUnits() async {
    if (await _isOnlineMode()) {
      final now = DateTime.now();
      return ProductUnits.all
          .asMap()
          .entries
          .map((entry) => UomUnit(
                id: entry.key + 1,
                name: entry.value,
                shortName: entry.value,
                createdAt: now,
              ))
          .toList();
    }
    final db = await _db.database;
    final rows = await db.query('uom_units', orderBy: 'name ASC');
    return rows.map((r) => UomUnit.fromMap(r)).toList();
  }

  @override Future<int> addUnit(UomUnit unit) async {
    if (await _isOnlineMode()) {
      throw StateError('Custom units are unavailable in online API mode.');
    }
    final db = await _db.database;
    return await db.insert('uom_units', unit.toMap());
  }

  @override Future<bool> deleteUnit(int id) async {
    if (await _isOnlineMode()) {
      throw StateError('Custom units are unavailable in online API mode.');
    }
    final db = await _db.database;
    return (await db.delete('uom_units', where: 'id=?', whereArgs: [id])) > 0;
  }

  // ── Customers ──────────────────────────────────────────────────────────────
  @override Future<List<Customer>> getAllCustomers({String? search}) async {
    if (await _isOnlineMode()) {
      final rows = await BackendApiService.instance.withAuthRetry<List<dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.get<List<dynamic>>(
          'customers',
          options: Options(headers: headers),
        );
        return response.data ?? const <dynamic>[];
      });
      final customers = <Customer>[];
      for (final raw in rows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final customer = Customer(
          id: await _registerUuid(
            'customers',
            (row['clientRecordId'] ?? row['client_record_id'] ?? row['serverId'])
                ?.toString(),
          ),
          name: (row['name'] ?? '').toString(),
          phone: row['phone']?.toString(),
          address: row['address']?.toString(),
          gstNumber: row['gstNumber']?.toString() ?? row['gst_number']?.toString(),
          creditLimit: _doubleValue(row['creditLimit'] ?? row['credit_limit']),
          outstandingBalance: _doubleValue(
            row['outstandingBalance'] ?? row['outstanding_balance'],
          ),
          createdAt:
              DateTime.tryParse((row['updatedAt'] ?? row['updated_at'] ?? '').toString()) ??
                  DateTime.now(),
          updatedAt:
              DateTime.tryParse((row['updatedAt'] ?? row['updated_at'] ?? '').toString()) ??
                  DateTime.now(),
        );
        customers.add(customer);
      }
      if (search == null || search.isEmpty) return customers;
      final normalized = search.toLowerCase();
      return customers
          .where((customer) =>
              customer.name.toLowerCase().contains(normalized) ||
              (customer.phone?.toLowerCase().contains(normalized) ?? false))
          .toList();
    }
    final db = await _db.database;
    if (search != null && search.isNotEmpty) {
      final rows = await db.query('customers',
          where: 'is_active=1 AND (name LIKE ? OR phone LIKE ?)',
          whereArgs: ['%$search%', '%$search%'], orderBy: 'name ASC');
      return rows.map((r) => Customer.fromMap(r)).toList();
    }
    final rows = await db.query('customers', where: 'is_active=1', orderBy: 'name ASC');
    return rows.map((r) => Customer.fromMap(r)).toList();
  }

  @override Future<Customer?> getCustomerById(int id) async {
    if (await _isOnlineMode()) {
      final customers = await getAllCustomers();
      for (final customer in customers) {
        if (customer.id == id) return customer;
      }
      return null;
    }
    final db = await _db.database;
    final rows = await db.query('customers', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  @override Future<int> addCustomer(Customer customer) async {
    if (await _isOnlineMode()) {
      final clientRecordId = _uuid.v4();
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'customers/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': customer.name,
            'phone': customer.phone,
            'address': customer.address,
            'gstNumber': customer.gstNumber,
            'creditLimit': customer.creditLimit,
            'outstandingBalance': customer.outstandingBalance,
            'updatedAt': customer.updatedAt.toUtc().toIso8601String(),
            'version': 1,
            'deleted': false,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      return _registerUuid('customers', clientRecordId);
    }
    final db = await _db.database;
    final customerId = await db.insert('customers', customer.toMap());
    return customerId;
  }

  @override Future<bool> updateCustomer(Customer customer) async {
    if (await _isOnlineMode()) {
      final clientRecordId =
          await _lookupUuid('customers', customer.id) ?? _uuid.v4();
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'customers/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': customer.name,
            'phone': customer.phone,
            'address': customer.address,
            'gstNumber': customer.gstNumber,
            'creditLimit': customer.creditLimit,
            'outstandingBalance': customer.outstandingBalance,
            'updatedAt': customer.updatedAt.toUtc().toIso8601String(),
            'version': 1,
            'deleted': !customer.isActive,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      await _registerUuid('customers', clientRecordId);
      return true;
    }
    final db = await _db.database;
    final updated = (await db.update('customers', customer.toMap(),
        where: 'id=?', whereArgs: [customer.id])) > 0;
    return updated;
  }

  @override Future<bool> deleteCustomer(int id) async {
    if (await _isOnlineMode()) {
      final clientRecordId = await _lookupUuid('customers', id);
      if (clientRecordId == null) return false;
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'customers/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': 'Deleted customer',
            'creditLimit': 0,
            'outstandingBalance': 0,
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
    final db = await _db.database;
    final now = DateTime.now();
    final deleted = (await db.update(
      'customers',
      {
        'is_active': 0,
        'updated_at': now.toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    )) > 0;
    return deleted;
  }

  // ── Suppliers ──────────────────────────────────────────────────────────────
  @override Future<List<Supplier>> getAllSuppliers({String? search}) async {
    if (await _isOnlineMode()) {
      final rows = await BackendApiService.instance.withAuthRetry<List<dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.get<List<dynamic>>(
          'suppliers',
          options: Options(headers: headers),
        );
        return response.data ?? const <dynamic>[];
      });
      final suppliers = <Supplier>[];
      for (final raw in rows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        suppliers.add(
          Supplier(
            id: await _registerUuid(
              'suppliers',
              (row['clientRecordId'] ?? row['client_record_id'] ?? row['serverId'])
                  ?.toString(),
            ),
            name: (row['name'] ?? '').toString(),
            phone: row['phone']?.toString(),
            address: row['address']?.toString(),
            gstNumber: row['gstNumber']?.toString() ?? row['gst_number']?.toString(),
            outstandingBalance: _doubleValue(
              row['outstandingBalance'] ?? row['outstanding_balance'],
            ),
            createdAt:
                DateTime.tryParse((row['updatedAt'] ?? row['updated_at'] ?? '').toString()) ??
                    DateTime.now(),
            updatedAt:
                DateTime.tryParse((row['updatedAt'] ?? row['updated_at'] ?? '').toString()) ??
                    DateTime.now(),
          ),
        );
      }
      if (search == null || search.isEmpty) return suppliers;
      final normalized = search.toLowerCase();
      return suppliers
          .where((supplier) =>
              supplier.name.toLowerCase().contains(normalized) ||
              (supplier.phone?.toLowerCase().contains(normalized) ?? false))
          .toList();
    }
    final db = await _db.database;
    if (search != null && search.isNotEmpty) {
      final rows = await db.query('suppliers',
          where: 'is_active=1 AND (name LIKE ? OR phone LIKE ?)',
          whereArgs: ['%$search%', '%$search%'], orderBy: 'name ASC');
      return rows.map((r) => Supplier.fromMap(r)).toList();
    }
    final rows = await db.query('suppliers', where: 'is_active=1', orderBy: 'name ASC');
    return rows.map((r) => Supplier.fromMap(r)).toList();
  }

  @override Future<Supplier?> getSupplierById(int id) async {
    if (await _isOnlineMode()) {
      final suppliers = await getAllSuppliers();
      for (final supplier in suppliers) {
        if (supplier.id == id) return supplier;
      }
      return null;
    }
    final db = await _db.database;
    final rows = await db.query('suppliers', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : Supplier.fromMap(rows.first);
  }

  @override Future<int> addSupplier(Supplier supplier) async {
    if (await _isOnlineMode()) {
      final clientRecordId = _uuid.v4();
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'suppliers/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': supplier.name,
            'phone': supplier.phone,
            'address': supplier.address,
            'gstNumber': supplier.gstNumber,
            'outstandingBalance': supplier.outstandingBalance,
            'updatedAt': supplier.updatedAt.toUtc().toIso8601String(),
            'version': 1,
            'deleted': false,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      return _registerUuid('suppliers', clientRecordId);
    }
    final db = await _db.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  @override Future<bool> updateSupplier(Supplier supplier) async {
    if (await _isOnlineMode()) {
      final clientRecordId =
          await _lookupUuid('suppliers', supplier.id) ?? _uuid.v4();
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'suppliers/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': supplier.name,
            'phone': supplier.phone,
            'address': supplier.address,
            'gstNumber': supplier.gstNumber,
            'outstandingBalance': supplier.outstandingBalance,
            'updatedAt': supplier.updatedAt.toUtc().toIso8601String(),
            'version': 1,
            'deleted': !supplier.isActive,
          },
          options: Options(headers: headers),
        );
        return response.data ?? <String, dynamic>{};
      });
      await _registerUuid('suppliers', clientRecordId);
      return true;
    }
    final db = await _db.database;
    return (await db.update('suppliers', supplier.toMap(),
        where: 'id=?', whereArgs: [supplier.id])) > 0;
  }

  @override Future<bool> deleteSupplier(int id) async {
    if (await _isOnlineMode()) {
      final clientRecordId = await _lookupUuid('suppliers', id);
      if (clientRecordId == null) return false;
      await BackendApiService.instance.withAuthRetry<Map<String, dynamic>>((
        dio,
        headers,
      ) async {
        final response = await dio.post<Map<String, dynamic>>(
          'suppliers/upsert',
          data: {
            'clientRecordId': clientRecordId,
            'name': 'Deleted supplier',
            'outstandingBalance': 0,
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
    final db = await _db.database;
    return (await db.update('suppliers', {'is_active': 0},
        where: 'id=?', whereArgs: [id])) > 0;
  }

}
