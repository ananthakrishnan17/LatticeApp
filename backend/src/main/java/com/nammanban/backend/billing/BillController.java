package com.nammanban.backend.billing;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nammanban.backend.common.ServerIdResolver;
import com.nammanban.backend.common.TenantContext;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/bills")
@Validated
public class BillController {
    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;
    private final ServerIdResolver serverIdResolver;

    public BillController(JdbcTemplate jdbc, ObjectMapper mapper, ServerIdResolver serverIdResolver) {
        this.jdbc = jdbc;
        this.mapper = mapper;
        this.serverIdResolver = serverIdResolver;
    }

    // ── DTOs ──────────────────────────────────────────────────────────────────

    public record BillItemRequest(
            UUID productId,
            String productName,
            String productSku,
            String unit,
            BigDecimal quantity,
            BigDecimal unitPrice,
            BigDecimal purchasePrice,
            BigDecimal totalPrice,
            BigDecimal gstRate,
            BigDecimal conversionQty,
            String saleType,
            BigDecimal discountAmount,
            String itemDiscountType,
            BigDecimal itemDiscountValue
    ) {}

    public record BillUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String billNumber,
            String billType,
            String customerName,
            String customerAddress,
            String customerGstin,
            @NotNull @DecimalMin(value = "0.00", message = "totalAmount must be non-negative") BigDecimal totalAmount,
            BigDecimal totalProfit,
            BigDecimal discountAmount,
            BigDecimal gstTotal,
            BigDecimal cgstTotal,
            BigDecimal sgstTotal,
            BigDecimal igstTotal,
            String paymentMode,
            String couponCode,
            BigDecimal couponDiscountAmount,
            BigDecimal cashTendered,
            BigDecimal changeAmount,
            String splitPaymentSummary,
            List<BillItemRequest> items,
            Long version,
            Instant createdAt,
            Instant updatedAt
    ) {}

    // ── GET /bills ─────────────────────────────────────────────────────────────

    @GetMapping
    public Map<String, Object> list(
            @RequestParam(required = false) String billNumber,
            @RequestParam(required = false) String since,
            @RequestParam(defaultValue = "50") int limit
    ) {
        UUID tenantId = TenantContext.tenantId();
        List<Map<String, Object>> rows;
        if (billNumber != null && !billNumber.isBlank()) {
            rows = jdbc.queryForList("""
                SELECT b.server_id, b.client_record_id, b.bill_number, b.bill_type,
                       b.customer_id, b.status, b.billed_by_username,
                       b.customer_name, b.customer_address, b.customer_gstin,
                       b.total_amount, b.total_profit, b.discount_amount,
                       b.gst_total, b.cgst_total, b.sgst_total, b.igst_total,
                       b.payment_mode, b.coupon_code, b.coupon_discount_amount,
                       b.cash_tendered, b.change_amount, b.split_payment_summary,
                       b.created_at, b.updated_at,
                       COALESCE(
                           json_agg(
                               json_build_object(
                                   'product_id',         i.product_id,
                                   'product_name',       i.product_name,
                                   'product_sku',        i.product_sku,
                                   'unit',               i.unit,
                                   'quantity',           i.quantity,
                                   'unit_price',         i.unit_price,
                                   'total_price',        i.total_price,
                                   'purchase_price',     i.purchase_price,
                                   'gst_rate',           i.gst_rate,
                                   'conversion_qty',     i.conversion_qty,
                                  'sale_type',          i.sale_type,
                                  'discount_amount',    i.discount_amount,
                                  'item_discount_type', i.item_discount_type,
                                  'item_discount_value',i.item_discount_value
                               ) ORDER BY i.server_id
                           ) FILTER (WHERE i.server_id IS NOT NULL),
                           '[]'::json
                       ) AS items
                FROM app_core.bills b
                LEFT JOIN app_core.bill_items i ON i.bill_id = b.server_id AND i.deleted_at IS NULL
                WHERE b.tenant_id = ? AND b.bill_number = ? AND b.deleted_at IS NULL
                GROUP BY b.server_id
                LIMIT 1
                """, tenantId, billNumber.trim());
        } else {
            Instant sinceInstant = since != null ? Instant.parse(since) : Instant.EPOCH;
            rows = jdbc.queryForList("""
                SELECT b.server_id, b.client_record_id, b.bill_number, b.bill_type,
                       b.customer_id, b.status, b.billed_by_username,
                       b.customer_name, b.customer_address, b.customer_gstin,
                       b.total_amount, b.total_profit, b.discount_amount,
                       b.gst_total, b.cgst_total, b.sgst_total, b.igst_total,
                       b.payment_mode, b.coupon_code, b.coupon_discount_amount,
                       b.cash_tendered, b.change_amount, b.split_payment_summary,
                       b.created_at, b.updated_at,
                       COALESCE(
                           json_agg(
                               json_build_object(
                                   'product_id',         i.product_id,
                                   'product_name',       i.product_name,
                                   'product_sku',        i.product_sku,
                                   'unit',               i.unit,
                                   'quantity',           i.quantity,
                                   'unit_price',         i.unit_price,
                                   'total_price',        i.total_price,
                                   'purchase_price',     i.purchase_price,
                                   'gst_rate',           i.gst_rate,
                                   'conversion_qty',     i.conversion_qty,
                                  'sale_type',          i.sale_type,
                                  'discount_amount',    i.discount_amount,
                                  'item_discount_type', i.item_discount_type,
                                  'item_discount_value',i.item_discount_value
                               ) ORDER BY i.server_id
                           ) FILTER (WHERE i.server_id IS NOT NULL),
                           '[]'::json
                       ) AS items
                FROM app_core.bills b
                LEFT JOIN app_core.bill_items i ON i.bill_id = b.server_id AND i.deleted_at IS NULL
                WHERE b.tenant_id = ? AND b.updated_at > ? AND b.deleted_at IS NULL
                GROUP BY b.server_id
                ORDER BY b.updated_at DESC
                LIMIT ?
                """, tenantId, Timestamp.from(sinceInstant), limit);
        }
        return Map.of("bills", rows.stream().map(this::parseItemsInRow).toList());
    }

    // ── POST /bills/upsert ─────────────────────────────────────────────────────

    @PostMapping("/upsert")
    @Transactional
    public Map<String, Object> upsert(@RequestBody @Validated BillUpsertRequest request) throws Exception {
        UUID tenantId = TenantContext.tenantId();
        String deviceId = TenantContext.deviceId();
        long version = request.version() == null ? 1L : request.version();
        Instant updatedAt = request.updatedAt() == null ? Instant.now() : request.updatedAt();
        Instant createdAt = request.createdAt() != null ? request.createdAt() : updatedAt;

        int inserted = jdbc.update("""
            INSERT INTO app_core.bills(
              tenant_id, client_record_id, device_id,
              bill_number, bill_type,
              customer_name, customer_address, customer_gstin,
              total_amount, total_profit, discount_amount,
              gst_total, cgst_total, sgst_total, igst_total,
              payment_mode, coupon_code, coupon_discount_amount,
              cash_tendered, change_amount, split_payment_summary,
              created_at, version, updated_at
            ) VALUES (
              ?, ?, ?,
              ?, ?,
              ?, ?, ?,
              ?, ?, ?,
              ?, ?, ?, ?,
              ?, ?, ?,
              ?, ?, ?,
              ?, ?, ?
            )
            ON CONFLICT (tenant_id, client_record_id) DO NOTHING
            """,
            tenantId,
            request.clientRecordId(),
            deviceId,
            request.billNumber(),
            request.billType() == null ? "retail" : request.billType(),
            request.customerName(),
            request.customerAddress(),
            request.customerGstin(),
            request.totalAmount(),
            request.totalProfit() == null ? BigDecimal.ZERO : request.totalProfit(),
            request.discountAmount() == null ? BigDecimal.ZERO : request.discountAmount(),
            request.gstTotal() == null ? BigDecimal.ZERO : request.gstTotal(),
            request.cgstTotal() == null ? BigDecimal.ZERO : request.cgstTotal(),
            request.sgstTotal() == null ? BigDecimal.ZERO : request.sgstTotal(),
            request.igstTotal() == null ? BigDecimal.ZERO : request.igstTotal(),
            request.paymentMode() == null ? "cash" : request.paymentMode(),
            request.couponCode(),
            request.couponDiscountAmount() == null ? BigDecimal.ZERO : request.couponDiscountAmount(),
            request.cashTendered() != null ? request.cashTendered() : null,
            request.changeAmount() != null ? request.changeAmount() : null,
            request.splitPaymentSummary(),
            Timestamp.from(createdAt),
            version,
            Timestamp.from(updatedAt)
        );

        if (inserted == 0) {
            jdbc.update("""
                INSERT INTO app_core.conflict_log(tenant_id, table_name, client_record_id, device_id, reason, client_payload)
                VALUES (?, 'bills', ?, ?, 'IMMUTABLE_DUPLICATE', ?::jsonb)
                """, tenantId, request.clientRecordId(), deviceId, mapper.writeValueAsString(request));
            return Map.of("status", "duplicate", "message", "Bill already exists; use reversal flow for corrections");
        }

        var billRows = jdbc.queryForList("""
            SELECT server_id FROM app_core.bills
            WHERE tenant_id = ? AND client_record_id = ?
            LIMIT 1
            """, tenantId, request.clientRecordId());
        if (!billRows.isEmpty()) {
            Object serverId = billRows.getFirst().get("server_id");
            UUID billServerId = serverId instanceof UUID uid
                    ? uid
                    : UUID.fromString(String.valueOf(serverId));
            insertBillItems(tenantId, deviceId, billServerId, request.clientRecordId(),
                    request.items() == null ? Collections.emptyList() : request.items());
        }
        return Map.of("status", "ok", "clientRecordId", request.clientRecordId());
    }

    // ── helpers ────────────────────────────────────────────────────────────────

    private void insertBillItems(
            UUID tenantId,
            String deviceId,
            UUID billId,
            UUID billClientRecordId,
            List<BillItemRequest> items
    ) {
        for (int index = 0; index < items.size(); index++) {
            BillItemRequest item = items.get(index);
            if (item == null) continue;

            String productName = item.productName() == null || item.productName().isBlank()
                    ? "Unknown item" : item.productName().trim();
            String unit = item.unit() == null || item.unit().isBlank() ? "piece" : item.unit().trim();
            BigDecimal quantity  = item.quantity()  != null ? item.quantity()  : BigDecimal.ZERO;
            BigDecimal unitPrice = item.unitPrice()  != null ? item.unitPrice()  : BigDecimal.ZERO;
            BigDecimal totalPrice = item.totalPrice() != null
                    ? item.totalPrice()
                    : unitPrice.multiply(quantity);

            // Flutter sends client_record_id as productId; resolve to server_id for the FK.
            UUID resolvedProductId = serverIdResolver.resolve("products", item.productId(), tenantId);

            UUID itemClientRecordId = deterministicItemId(billClientRecordId, index);
            int rowsInserted = jdbc.update("""
                INSERT INTO app_core.bill_items(
                  tenant_id, bill_id, client_record_id, device_id, product_id,
                  product_name, product_sku, quantity, unit,
                  unit_price, purchase_price, total_price,
                  gst_rate, conversion_qty, sale_type,
                  discount_amount, item_discount_type, item_discount_value
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (tenant_id, client_record_id) DO NOTHING
                """,
                tenantId,
                billId,
                itemClientRecordId,
                deviceId,
                resolvedProductId,
                productName,
                item.productSku(),
                quantity,
                unit,
                unitPrice,
                item.purchasePrice() != null ? item.purchasePrice() : BigDecimal.ZERO,
                totalPrice,
                item.gstRate()            != null ? item.gstRate()            : BigDecimal.ZERO,
                item.conversionQty()      != null ? item.conversionQty()      : BigDecimal.ONE,
                item.saleType()           != null ? item.saleType()           : "retail",
                item.discountAmount()     != null ? item.discountAmount()     : BigDecimal.ZERO,
                item.itemDiscountType()   != null ? item.itemDiscountType()   : "none",
                item.itemDiscountValue()  != null ? item.itemDiscountValue()  : BigDecimal.ZERO
            );

            if (rowsInserted > 0 && resolvedProductId != null) {
                BigDecimal conversionQty = item.conversionQty() != null ? item.conversionQty() : BigDecimal.ONE;
                BigDecimal baseQuantity = quantity.multiply(conversionQty);
                
                jdbc.update("""
                    UPDATE app_core.products
                    SET stock_quantity = stock_quantity - ?,
                        updated_at = NOW()
                    WHERE tenant_id = ? AND server_id = ?
                    """,
                    baseQuantity, tenantId, resolvedProductId);
            }
        }
    }

    /**
     * Parses the {@code items} column of a bill row returned by {@link JdbcTemplate#queryForList}.
     * <p>
     * PostgreSQL's {@code json_agg()} result comes back from the JDBC driver as a
     * {@code PGobject}, whose {@code toString()} returns the raw JSON string.  Jackson
     * would otherwise serialise it as {@code {"type":"json","value":"[...]"}} which the
     * Flutter client cannot cast to a {@code List}.  We parse it here so the HTTP
     * response always contains a proper JSON array.
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> parseItemsInRow(Map<String, Object> row) {
        Map<String, Object> result = new LinkedHashMap<>(row);
        Object rawItems = result.get("items");
        if (rawItems != null) {
            try {
                result.put("items", mapper.readValue(rawItems.toString(), List.class));
            } catch (Exception e) {
                // Fall back to an empty list rather than propagating an unparseable items field.
                // This prevents a single malformed bill from breaking the entire bill list response.
                result.put("items", Collections.emptyList());
            }
        }
        return result;
    }

    private UUID deterministicItemId(UUID billClientRecordId, int index) {
        return UUID.nameUUIDFromBytes((billClientRecordId + ":" + index).getBytes(StandardCharsets.UTF_8));
    }
}
