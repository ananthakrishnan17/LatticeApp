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

  group('Manufacturing business integration', () {
    testWidgets('raw material stock can be added through purchase entry', (_) async {
      final rawMaterialId = await harness.addProduct(
        name: 'Flour',
        itemType: 'raw_material',
        unit: 'kg',
        purchasePrice: 30,
        sellingPrice: 0,
        lowStockThreshold: 1,
      );

      await harness.purchaseStock(
        productId: rawMaterialId,
        productName: 'Flour',
        quantity: 12,
        unitCost: 30,
        unit: 'kg',
        batchNumber: 'RM-001',
      );

      expect(await harness.productStock(rawMaterialId), 12);
    });

    testWidgets('selling a finished recipe deducts raw materials and reduces derived finished stock', (_) async {
      final rawMaterialId = await harness.addProduct(
        name: 'Steel Sheet',
        itemType: 'raw_material',
        unit: 'kg',
        purchasePrice: 50,
        sellingPrice: 0,
        lowStockThreshold: 4,
      );
      await harness.purchaseStock(
        productId: rawMaterialId,
        productName: 'Steel Sheet',
        quantity: 6,
        unitCost: 50,
        unit: 'kg',
        batchNumber: 'RM-STEEL-1',
      );

      final finishedGoodId = await harness.addProduct(
        name: 'Steel Cabinet',
        itemType: 'composite_recipe',
        purchasePrice: 120,
        sellingPrice: 250,
        stockQuantity: 0,
        attributes: {
          'bom': [
            {
              'product_id': rawMaterialId,
              'quantity': 2,
            },
          ],
        },
      );

      expect((await harness.getProduct(finishedGoodId)).stockQuantity, 3);

      await harness.billing.saveBill(
        items: [
          CartItem(
            productId: finishedGoodId,
            productName: 'Steel Cabinet',
            unit: 'piece',
            quantity: 1,
            purchasePrice: 120,
            sellingPrice: 250,
            wholesalePrice: 250,
          ),
        ],
        customerName: 'Factory Customer',
        paymentMode: 'upi',
      );

      expect(await harness.productStock(rawMaterialId), 4);
      expect((await harness.getProduct(finishedGoodId)).stockQuantity, 2);
    });

    testWidgets('low stock alert surfaces depleted raw materials after finished-good sale', (_) async {
      final rawMaterialId = await harness.addProduct(
        name: 'Fabric Roll',
        itemType: 'raw_material',
        unit: 'kg',
        purchasePrice: 20,
        sellingPrice: 0,
        lowStockThreshold: 4,
      );
      await harness.purchaseStock(
        productId: rawMaterialId,
        productName: 'Fabric Roll',
        quantity: 5,
        unitCost: 20,
        unit: 'kg',
        batchNumber: 'FAB-001',
      );

      final finishedGoodId = await harness.addProduct(
        name: 'Uniform Set',
        itemType: 'composite_recipe',
        purchasePrice: 80,
        sellingPrice: 180,
        attributes: {
          'bom': [
            {
              'product_id': rawMaterialId,
              'quantity': 2,
            },
          ],
        },
      );

      await harness.billing.saveBill(
        items: [
          CartItem(
            productId: finishedGoodId,
            productName: 'Uniform Set',
            unit: 'piece',
            quantity: 1,
            purchasePrice: 80,
            sellingPrice: 180,
            wholesalePrice: 180,
          ),
        ],
        paymentMode: 'card',
      );

      final lowStockProducts = await harness.products.getLowStockProducts();

      expect(
        lowStockProducts.any((product) => product.id == rawMaterialId),
        isTrue,
      );
    });

    testWidgets(
      'production entry converts raw material stock into finished stock before sale',
      (_) async {},
      skip: true, // No standalone production-entry repository or workflow was found; manufacturing is currently modeled through composite-recipe sales.
    );
  });
}
