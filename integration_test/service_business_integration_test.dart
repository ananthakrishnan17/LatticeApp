import 'package:NammaNanban/features/billing/domain/entities/bill.dart';
import 'package:NammaNanban/features/license/domain/entities/license.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mobile_pos_test_harness.dart';

void main() {
  ensureMobilePosTestBinding();

  final harness = MobilePosTestHarness();

  setUp(() async {
    await harness.resetState();
    await harness.setLicenseMode(LicenseType.offline);
  });

  group('Service business integration', () {
    testWidgets('service invoice saves successfully without deducting stock', (_) async {
      final serviceId = await harness.addProduct(
        name: 'AC Repair',
        itemType: 'service',
        purchasePrice: 0,
        sellingPrice: 750,
        stockQuantity: 0,
      );

      final bill = await harness.billing.saveBill(
        items: [
          CartItem(
            productId: serviceId,
            productName: 'AC Repair',
            unit: 'service',
            quantity: 1,
            purchasePrice: 0,
            sellingPrice: 750,
            wholesalePrice: 750,
          ),
        ],
        customerName: 'Service Customer',
        paymentMode: 'cash',
      );

      expect(bill.items.single.productId, serviceId);
      expect(await harness.productStock(serviceId), 0);
    });

    testWidgets('mixed bill deducts only physical product stock and keeps service stock unchanged', (_) async {
      final serviceId = await harness.addProduct(
        name: 'Installation Charge',
        itemType: 'service',
        purchasePrice: 0,
        sellingPrice: 150,
        stockQuantity: 0,
      );
      final productId = await harness.addProduct(
        name: 'Router',
        purchasePrice: 900,
        sellingPrice: 1200,
      );
      await harness.purchaseStock(
        productId: productId,
        productName: 'Router',
        quantity: 4,
        unitCost: 900,
        batchNumber: 'RTR-001',
      );

      await harness.billing.saveBill(
        items: [
          CartItem(
            productId: serviceId,
            productName: 'Installation Charge',
            unit: 'service',
            quantity: 1,
            purchasePrice: 0,
            sellingPrice: 150,
            wholesalePrice: 150,
          ),
          CartItem(
            productId: productId,
            productName: 'Router',
            unit: 'piece',
            quantity: 1,
            purchasePrice: 900,
            sellingPrice: 1200,
            wholesalePrice: 1200,
          ),
        ],
        customerName: 'Mixed Customer',
        paymentMode: 'card',
      );

      expect(await harness.productStock(serviceId), 0);
      expect(await harness.productStock(productId), 3);
    });

    testWidgets(
      'partial payment tracks outstanding balance for service invoices',
      (_) async {},
      skip: true, // Billing repositories do not currently persist receivable balances or installment settlement state for invoices.
    );

    testWidgets(
      'full payment clears the tracked service balance',
      (_) async {},
      skip: true, // No payment-settlement workflow was found to update and clear invoice balances after the original bill is saved.
    );

    testWidgets(
      'offline license should use local DB only after login and never call the API',
      (_) async {},
      skip: true, // Offline sync writes are covered, but there is no injectable API client seam to assert post-login repository calls stay fully local.
    );
  });
}
