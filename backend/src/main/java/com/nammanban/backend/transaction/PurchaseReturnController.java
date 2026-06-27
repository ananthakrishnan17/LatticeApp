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
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/purchase-returns")
public class PurchaseReturnController {

    private final JdbcTemplate jdbc;

    public PurchaseReturnController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record PurchaseReturnUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String returnNumber,
            String originalPurchaseNumber,
            String supplierName,
            @NotNull @DecimalMin(value = "0.00", message = "totalReturnAmount must be non-negative") BigDecimal totalReturnAmount,
            String notes,
            Instant createdAt,
            Instant updatedAt
    ) {}

    @PostMapping("/upsert")
    @Transactional
    public Map<String, Object> upsert(@Valid @RequestBody PurchaseReturnUpsertRequest request) {
        UUID tenantId = TenantContext.tenantId();
        String deviceId = TenantContext.deviceId();
        Instant createdAt = request.createdAt() == null ? Instant.now() : request.createdAt();
        Instant updatedAt = request.updatedAt() == null ? createdAt : request.updatedAt();

        int inserted = jdbc.update("""
            INSERT INTO app_core.purchase_returns(
              tenant_id, client_record_id, device_id, return_number,
              original_purchase_number, supplier_name, total_return_amount, notes,
              created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (tenant_id, client_record_id) DO NOTHING
            """,
            tenantId, request.clientRecordId(), deviceId, request.returnNumber(),
            request.originalPurchaseNumber(), request.supplierName(),
            request.totalReturnAmount(), request.notes(),
            Timestamp.from(createdAt), Timestamp.from(updatedAt)
        );

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
            SELECT server_id, client_record_id, return_number, original_purchase_number,
                   supplier_name, total_return_amount, notes, created_at, updated_at
            FROM app_core.purchase_returns
            WHERE tenant_id = ? AND updated_at > ?
            ORDER BY created_at DESC
            LIMIT ?
            """, tenantId, Timestamp.from(sinceInstant), limit);
        return Map.of("purchaseReturns", rows);
    }
}
