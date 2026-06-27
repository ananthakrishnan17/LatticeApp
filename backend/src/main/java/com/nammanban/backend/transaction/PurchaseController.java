package com.nammanban.backend.transaction;

import com.nammanban.backend.common.ServerIdResolver;
import com.nammanban.backend.common.TenantContext;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
@RestController
@RequestMapping("/purchases")
public class PurchaseController {

    private static final Logger log = LoggerFactory.getLogger(PurchaseController.class);

    private final JdbcTemplate jdbc;
    private final ServerIdResolver serverIdResolver;

    public PurchaseController(JdbcTemplate jdbc, ServerIdResolver serverIdResolver) {
        this.jdbc = jdbc;
        this.serverIdResolver = serverIdResolver;
    }

    public record PurchaseItemRequest(
            String productId,
            @NotBlank String productName,
            @NotNull @DecimalMin(value = "0.001", message = "quantity must be positive") BigDecimal quantity,
            String unit,
            @NotNull @DecimalMin(value = "0.00", message = "unitCost must be non-negative") BigDecimal unitCost,
            BigDecimal gstRate,
            BigDecimal gstAmount,
            @NotNull @DecimalMin(value = "0.00", message = "totalCost must be non-negative") BigDecimal totalCost,
            String batchNumber,
            String expiryDate
    ) {}

    public record PurchaseUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String purchaseNumber,
            String supplierName,
            @NotNull @DecimalMin(value = "0.00", message = "totalAmount must be non-negative") BigDecimal totalAmount,
            BigDecimal gstTotal,
            String paymentMode,
            String invoiceNumber,
            BigDecimal invoiceAmount,
            String notes,
            List<PurchaseItemRequest> items,
            Instant purchaseDate,
            Instant createdAt,
            Instant updatedAt
    ) {}

    @PostMapping("/upsert")
    @Transactional
    public Map<String, Object> upsert(@Valid @RequestBody PurchaseUpsertRequest request) {
        UUID tenantId = TenantContext.tenantId();
        String deviceId = TenantContext.deviceId();
        Instant createdAt = request.createdAt() == null ? Instant.now() : request.createdAt();
        Instant updatedAt = request.updatedAt() == null ? createdAt : request.updatedAt();
        Instant purchaseDate = request.purchaseDate() == null ? createdAt : request.purchaseDate();

        int inserted = jdbc.update("""
            INSERT INTO app_core.purchases(
              tenant_id, client_record_id, device_id, purchase_number,
              supplier_name, total_amount, gst_total, payment_mode,
              invoice_number, invoice_amount, notes, purchase_date, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (tenant_id, client_record_id) DO NOTHING
            """,
            tenantId, request.clientRecordId(), deviceId, request.purchaseNumber(),
            request.supplierName(), request.totalAmount(),
            request.gstTotal() == null ? BigDecimal.ZERO : request.gstTotal(),
            request.paymentMode() == null ? "cash" : request.paymentMode(),
            request.invoiceNumber(), request.invoiceAmount(), request.notes(),
            Timestamp.from(purchaseDate), Timestamp.from(createdAt), Timestamp.from(updatedAt)
        );

        if (inserted > 0 && request.items() != null && !request.items().isEmpty()) {
            var purchaseRows = jdbc.queryForList("""
                SELECT server_id FROM app_core.purchases
                WHERE tenant_id = ? AND client_record_id = ? LIMIT 1
                """, tenantId, request.clientRecordId());
            if (!purchaseRows.isEmpty()) {
                Object serverId = purchaseRows.getFirst().get("server_id");
                UUID purchaseServerId = serverId instanceof UUID u ? u : UUID.fromString(String.valueOf(serverId));
                insertPurchaseItems(tenantId, deviceId, purchaseServerId, request.clientRecordId(), request.items());
            }
        }

        return Map.of("status", inserted > 0 ? "ok" : "duplicate", "clientRecordId", request.clientRecordId());
    }

    @GetMapping
    public Map<String, Object> list(
            @RequestParam(required = false) String purchaseNumber,
            @RequestParam(required = false) String since,
            @RequestParam(defaultValue = "50") int limit
    ) {
        UUID tenantId = TenantContext.tenantId();
        List<Map<String, Object>> rows;
        if (purchaseNumber != null && !purchaseNumber.isBlank()) {
            rows = jdbc.queryForList("""
                SELECT server_id, client_record_id, purchase_number, supplier_name,
                       total_amount, gst_total, payment_mode, invoice_number, notes,
                       purchase_date, created_at, updated_at
                FROM app_core.purchases
                WHERE tenant_id = ? AND purchase_number = ?
                LIMIT 1
                """, tenantId, purchaseNumber.trim());
        } else {
            Instant sinceInstant = since != null ? Instant.parse(since) : Instant.EPOCH;
            rows = jdbc.queryForList("""
                SELECT server_id, client_record_id, purchase_number, supplier_name,
                       total_amount, gst_total, payment_mode, invoice_number, notes,
                       purchase_date, created_at, updated_at
                FROM app_core.purchases
                WHERE tenant_id = ? AND updated_at > ?
                ORDER BY created_at DESC
                LIMIT ?
                """, tenantId, Timestamp.from(sinceInstant), limit);
        }
        
        for (Map<String, Object> row : rows) {
            Object serverId = row.get("server_id");
            if (serverId != null) {
                var items = jdbc.queryForList("""
                    SELECT product_id as "productId", product_name as "productName", 
                           quantity, unit, unit_cost as "unitCost", 
                           gst_rate as "gstRate", gst_amount as "gstAmount", 
                           total_cost as "totalCost"
                    FROM app_core.purchase_items
                    WHERE tenant_id = ? AND purchase_id = ?
                    """, tenantId, serverId instanceof UUID ? (UUID) serverId : UUID.fromString(serverId.toString()));
                row.put("items", items);
            }
        }
        
        return Map.of("purchases", rows);
    }

    @GetMapping("/{id}/items")
    public Map<String, Object> getItems(@PathVariable String id) {
        UUID tenantId = TenantContext.tenantId();
        UUID purchaseId;
        try {
            purchaseId = UUID.fromString(id);
        } catch (Exception e) {
            return Map.of("items", List.of());
        }
        var items = jdbc.queryForList("""
            SELECT pi.product_id, pi.product_name, pi.quantity, pi.unit, pi.unit_cost, pi.gst_rate, pi.gst_amount, pi.total_cost
            FROM app_core.purchase_items pi
            JOIN app_core.purchases p ON p.server_id = pi.purchase_id
            WHERE p.tenant_id = ? AND pi.purchase_id = ?
            """, tenantId, purchaseId);
        return Map.of("items", items);
    }

    private void insertPurchaseItems(UUID tenantId, String deviceId, UUID purchaseId,
                                     UUID purchaseClientRecordId, List<PurchaseItemRequest> items) {
        for (int i = 0; i < items.size(); i++) {
            PurchaseItemRequest item = items.get(i);
            UUID itemClientRecordId = UUID.nameUUIDFromBytes(
                    (purchaseClientRecordId + ":item:" + i).getBytes(StandardCharsets.UTF_8));
            UUID rawProductId = null;
            try {
                if (item.productId() != null) rawProductId = UUID.fromString(item.productId());
            } catch (Exception ignored) {}

            UUID productId = serverIdResolver.resolve("products", rawProductId, tenantId);
            if (productId == null) {
                productId = rawProductId;
            }

            String sql = """
                INSERT INTO app_core.purchase_items(
                  tenant_id, purchase_id, client_record_id, device_id, product_id,
                  product_name, quantity, unit, unit_cost, gst_rate, gst_amount, total_cost
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (tenant_id, client_record_id) DO NOTHING
                """;
            Object[] params = {
                tenantId, purchaseId, itemClientRecordId, deviceId, productId,
                item.productName(), item.quantity(),
                item.unit() == null ? "piece" : item.unit(),
                item.unitCost(),
                item.gstRate() == null ? BigDecimal.ZERO : item.gstRate(),
                item.gstAmount() == null ? BigDecimal.ZERO : item.gstAmount(),
                item.totalCost()
            };
            int rowsInserted = jdbc.update(sql, params);

            // Update product stock and latest purchase price only for newly
            // inserted items — rowsInserted == 0 means this was a duplicate
            // request that was already processed (ON CONFLICT DO NOTHING).
            if (rowsInserted > 0 && productId != null) {
                // Fetch product details to determine the base unit factor
                var productRows = jdbc.queryForList("""
                    SELECT unit 
                    FROM app_core.products 
                    WHERE tenant_id = ? AND server_id = ?
                    """, tenantId, productId);
                
                BigDecimal baseQuantity = item.quantity();
                if (!productRows.isEmpty()) {
                    Map<String, Object> product = productRows.getFirst();
                    String pUnit = product.get("unit") == null ? "piece" : product.get("unit").toString();
                    
                    BigDecimal factor = BigDecimal.ONE;
                    String lUnit = pUnit.toLowerCase();
                    if (lUnit.equals("kg") || lUnit.equals("kgs") || lUnit.equals("kilogram") || lUnit.equals("l") || lUnit.equals("ltr") || lUnit.equals("liter") || lUnit.equals("liters")) {
                        factor = new BigDecimal("1000");
                    } else if (lUnit.equals("m") || lUnit.equals("meter") || lUnit.equals("meters")) {
                        factor = new BigDecimal("100");
                    } else if (lUnit.equals("dz") || lUnit.equals("dozen")) {
                        factor = new BigDecimal("12");
                    }
                    
                    baseQuantity = item.quantity().multiply(factor);
                }

                int stockUpdated = jdbc.update("""
                    UPDATE app_core.products
                    SET stock_quantity = stock_quantity + ?,
                        purchase_price = ?,
                        updated_at = NOW()
                    WHERE tenant_id = ? AND server_id = ?
                    """,
                    baseQuantity, item.unitCost(), tenantId, productId);
                if (stockUpdated == 0) {
                    log.warn("purchase stock update: product {} not found for tenant {} (purchase_client_record_id={})",
                            productId, tenantId, purchaseClientRecordId);
                }

                // Parse expiryDate
                java.sql.Date expDate = (item.expiryDate() != null && !item.expiryDate().isBlank())
                        ? java.sql.Date.valueOf(item.expiryDate())
                        : null;

                // Insert into batches table for FEFO billing
                jdbc.update("""
                    INSERT INTO app_core.batches(
                      tenant_id, client_record_id, device_id, product_id, purchase_id,
                      batch_number, expiry_date, qty_in, qty_remaining, unit_cost, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
                    ON CONFLICT (tenant_id, client_record_id) DO NOTHING
                    """,
                    tenantId, itemClientRecordId, deviceId, productId, purchaseId,
                    item.batchNumber(), expDate, baseQuantity, baseQuantity, item.unitCost()
                );
            }
        }
    }
}
