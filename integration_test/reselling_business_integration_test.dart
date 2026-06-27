import 'package:NammaNanban/core/sync/data_access_mode_service.dart';
import 'package:NammaNanban/features/billing/domain/entities/bill.dart';
import 'package:NammaNanban/features/license/domain/entities/license.dart';
import 'package:NammaNanban/features/sale_return/presentation/pages/sale_return_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mobile_pos_test_harness.dart';

void main() {
  ensureMobilePosTestBinding();

  final harness = MobilePosTestHarness();

  setUp(() async {
    await harness.resetState();
    await harness.setLicenseMode(LicenseType.offline);
  });

  group('Reselling business integration', () {
    testWidgets('product add and save persists the product master', (_) async {
      final productId = await harness.addProduct(
        name: 'Reselling Product',
        purchasePrice: 80,
        sellingPrice: 120,
        lowStockThreshold: 2,
      );

      final product = await harness.getProduct(productId);

      expect(product.name, 'Reselling Product');
      expect(product.purchasePrice, 80);
      expect(product.sellingPrice, 120);
      expect(product.stockQuantity, 0);
    });

    testWidgets('purchase stock increases available stock', (_) async {
      final productId = await harness.addProduct(
        name: 'Rice Bag',
        purchasePrice: 40,
        sellingPrice: 60,
      );

      await harness.purchaseStock(
        productId: productId,
        productName: 'Rice Bag',
        quantity: 8,
        unitCost: 40,
        batchNumber: 'RB-001',
      );

      expect(await harness.productStock(productId), 8);
    });

    testWidgets('create bill reduces stock and appears in sales report', (_) async {
      final productId = await harness.addProduct(
        name: 'Tea Powder',
        purchasePrice: 20,
        sellingPrice: 35,
      );
      await harness.purchaseStock(
        productId: productId,
        productName: 'Tea Powder',
        quantity: 10,
        unitCost: 20,
        batchNumber: 'TP-001',
      );

      final bill = await harness.billing.saveBill(
        items: [
          CartItem(
            productId: productId,
            productName: 'Tea Powder',
            unit: 'piece',
            quantity: 3,
            purchasePrice: 20,
            sellingPrice: 35,
            wholesalePrice: 35,
          ),
        ],
        customerName: 'Customer A',
        paymentMode: 'upi',
      );

      expect(await harness.productStock(productId), 7);

      final salesByBill = await harness.reports.getSalesByBill(
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 1)),
      );

      expect(
        salesByBill.any((row) => row['bill_number'] == bill.billNumber),
        isTrue,
      );
    });

    testWidgets('customer return restores stock', (_) async {
      final productId = await harness.addProduct(
        name: 'Notebook',
        purchasePrice: 25,
        sellingPrice: 40,
      );
      await harness.purchaseStock(
        productId: productId,
        productName: 'Notebook',
        quantity: 5,
        unitCost: 25,
        batchNumber: 'NB-001',
      );

      final bill = await harness.billing.saveBill(
        items: [
          CartItem(
            productId: productId,
            productName: 'Notebook',
            unit: 'piece',
            quantity: 2,
            purchasePrice: 25,
            sellingPrice: 40,
            wholesalePrice: 40,
          ),
        ],
        customerName: 'Customer B',
        paymentMode: 'card',
      );

      await harness.saleReturns.saveSaleReturn(
        items: [
          SaleReturnItem(
            productId: productId,
            productName: 'Notebook',
            unit: 'piece',
            quantity: 1,
            unitPrice: 40,
            unitCost: 25,
          ),
        ],
        returnType: 'return',
        originalBillId: bill.id,
        originalBillNumber: bill.billNumber,
        customerName: 'Customer B',
        refundMode: 'card',
      );

      expect(await harness.productStock(productId), 4);
    });

    testWidgets('offline and online license modes resolve expected data access routes', (_) async {
      expect(
        await harness.resolveAccessMode(),
        DataAccessMode.offlineSqlite,
      );

      await harness.setLicenseMode(LicenseType.online);

      expect(
        await harness.resolveAccessMode(),
        DataAccessMode.onlineApi,
      );
    });

    testWidgets(
      'different company login should only expose tenant-scoped data',
      (_) async {},
      skip: true, // Mobile SQLite repositories currently have no tenant-scoping columns or injectable multi-tenant auth seam for end-to-end validation.
    );

    testWidgets(
      'online license should fetch data from API only and never from local DB',
      (_) async {},
      skip: true, // Current mobile repositories still read SQLite directly; API-only read routing is not implemented outside sync writes.
    );
  });
}
