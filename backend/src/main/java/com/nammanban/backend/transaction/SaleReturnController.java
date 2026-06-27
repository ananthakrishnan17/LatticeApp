package com.nammanban.backend.transaction;

import com.nammanban.backend.common.TenantContext;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
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
@RequestMapping("/sale-returns")
public class SaleReturnController {

    private final JdbcTemplate jdbc;

    public SaleReturnController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record SaleReturnItemRequest(
            String productId,
            @NotBlank String productName,
            @NotNull @DecimalMin(value = "0.001", message = "quantity must be positive") BigDecimal quantity,
            String unit,
            @NotNull @DecimalMin(value = "0.00", message = "unitPrice must be non-negative") BigDecimal unitPrice,
            @NotNull @DecimalMin(value = "0.00", message = "totalPrice must be non-negative") BigDecimal totalPrice
    ) {}

    public record SaleReturnUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String returnNumber,
            String originalBillNumber,
            String customerName,
            String returnType,
            String refundMode,
            String reason,
            @NotNull @DecimalMin(value = "0.00", message = "totalReturnAmount must be non-negative") BigDecimal totalReturnAmount,
            List<SaleReturnItemRequest> items,
            Instant createdAt,
            Instant updatedAt
    ) {}

    @PostMapping("/upsert")
    @Transactional
    public Map<String, Object> upsert(@Valid @RequestBody SaleReturnUpsertRequest request) {
        UUID tenantId = TenantContext.tenantId();
        String deviceId = TenantContext.deviceId();
        Instant createdAt = request.createdAt() == null ? Instant.now() : request.createdAt();
        Instant updatedAt = request.updatedAt() == null ? createdAt : request.updatedAt();

        int inserted = jdbc.update("""
            INSERT INTO app_core.sale_returns(
              tenant_id, client_record_id, device_id, return_number,
              original_bill_number, customer_name, return_type, refund_mode,
              reason, total_return_amount, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (tenant_id, client_record_id) DO NOTHING
            """,
            tenantId, request.clientRecordId(), deviceId, request.returnNumber(),
            request.originalBillNumber(), request.customerName(),
            request.returnType() == null ? "return" : request.returnType(),
            request.refundMode() == null ? "cash" : request.refundMode(),
            request.reason(), request.totalReturnAmount(),
            Timestamp.from(createdAt), Timestamp.from(updatedAt)
        );

        if (inserted > 0 && request.items() != null && !request.items().isEmpty()) {
            var retRows = jdbc.queryForList("""
                SELECT server_id FROM app_core.sale_returns
                WHERE tenant_id = ? AND client_record_id = ? LIMIT 1
                """, tenantId, request.clientRecordId());
            if (!retRows.isEmpty()) {
                Object serverId = retRows.getFirst().get("server_id");
                UUID retServerId = serverId instanceof UUID u ? u : UUID.fromString(String.valueOf(serverId));
                insertReturnItems(tenantId, deviceId, retServerId, request.clientRecordId(), request.items());
            }
        }

        return Map.of("status", inserted > 0 ? "ok" : "duplicate", "clientRecordId", request.clientRecordId());
    }

    @GetMapping
    public Map<String, Object> list(
            @RequestParam(required = false) String since,
            @RequestParam(defaultValue = "50") int limit
    ) {
        UUID tenantId = TenantContext.tenantId();
        Instant sinceInstant = since != null ? Instant.parse(since) : Instant.EPOCH;
        var rows = jdbc.queryForList("""
            SELECT server_id, client_record_id, return_number, original_bill_number,
                   customer_name, return_type, refund_mode, reason,
                   total_return_amount, created_at, updated_at
            FROM app_core.sale_returns
            WHERE tenant_id = ? AND updated_at > ?
            ORDER BY created_at DESC
            LIMIT ?
            """, tenantId, Timestamp.from(sinceInstant), limit);
        return Map.of("saleReturns", rows);
    }

    private void insertReturnItems(UUID tenantId, String deviceId, UUID returnId,
                                   UUID returnClientRecordId, List<SaleReturnItemRequest> items) {
        for (int i = 0; i < items.size(); i++) {
            SaleReturnItemRequest item = items.get(i);
            UUID itemClientRecordId = UUID.nameUUIDFromBytes(
                    (returnClientRecordId + ":item:" + i).getBytes(StandardCharsets.UTF_8));
            UUID productId = null;
            try {
                if (item.productId() != null) productId = UUID.fromString(item.productId());
            } catch (Exception ignored) {}

            jdbc.update("""
                INSERT INTO app_core.sale_return_items(
                  tenant_id, return_id, client_record_id, device_id, product_id,
                  product_name, quantity, unit, unit_price, total_price
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (tenant_id, client_record_id) DO NOTHING
                """,
                tenantId, returnId, itemClientRecordId, deviceId, productId,
                item.productName(), item.quantity(),
                item.unit() == null ? "piece" : item.unit(),
                item.unitPrice(), item.totalPrice()
            );
        }
    }
}
