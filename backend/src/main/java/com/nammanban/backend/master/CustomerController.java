package com.nammanban.backend.master;

import com.nammanban.backend.common.TenantContext;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static com.nammanban.backend.master.MasterDtos.CustomerRecord;
import static com.nammanban.backend.master.MasterDtos.CustomerUpsertRequest;

@RestController
@RequestMapping("/customers")
public class CustomerController {

    private final JdbcTemplate jdbc;

    public CustomerController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<CustomerRecord> list() {
        UUID tenantId = TenantContext.tenantId();
        return jdbc.queryForList("""
            SELECT server_id, client_record_id, name, phone, address, gst_number,
                   credit_limit, outstanding_balance, version, updated_at
            FROM app_core.customers
            WHERE tenant_id = ? AND deleted_at IS NULL
            ORDER BY name ASC
            """, tenantId)
                .stream()
                .map(r -> new CustomerRecord(
                        r.get("server_id").toString(),
                        r.get("client_record_id").toString(),
                        r.get("name").toString(),
                        (String) r.get("phone"),
                        (String) r.get("address"),
                        (String) r.get("gst_number"),
                        toBigDecimal(r.get("credit_limit")),
                        toBigDecimal(r.get("outstanding_balance")),
                        toLong(r.get("version")),
                        toInstant(r.get("updated_at"))
                )).toList();
    }

    @PostMapping("/upsert")
    @Transactional
    public Map<String, Object> upsert(@Valid @RequestBody CustomerUpsertRequest request) throws Exception {
        UUID tenantId = TenantContext.tenantId();
        String deviceId = TenantContext.deviceId();
        long version = request.version() == null ? 1L : request.version();
        Instant updatedAt = request.updatedAt() == null ? Instant.now() : request.updatedAt();
        Instant deletedAt = Boolean.TRUE.equals(request.deleted()) ? Instant.now() : null;

        jdbc.update("""
            INSERT INTO app_core.customers(
              tenant_id, client_record_id, device_id, name, phone, address, gst_number,
              credit_limit, outstanding_balance, version, updated_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (tenant_id, client_record_id)
            DO UPDATE SET
              device_id = excluded.device_id,
              name = excluded.name,
              phone = excluded.phone,
              address = excluded.address,
              gst_number = excluded.gst_number,
              credit_limit = excluded.credit_limit,
              outstanding_balance = excluded.outstanding_balance,
              version = excluded.version,
              updated_at = excluded.updated_at,
              deleted_at = excluded.deleted_at
            """,
            tenantId,
            request.clientRecordId(),
            deviceId,
            request.name().trim(),
            toNullableString(request.phone()),
            toNullableString(request.address()),
            toNullableString(request.gstNumber()),
            request.creditLimit() == null ? BigDecimal.ZERO : request.creditLimit(),
            request.outstandingBalance() == null ? BigDecimal.ZERO : request.outstandingBalance(),
            version,
            Timestamp.from(updatedAt),
            deletedAt == null ? null : Timestamp.from(deletedAt)
        );
        return Map.of(
                "status", "ok",
                "clientRecordId", request.clientRecordId()
        );
    }

    private String toNullableString(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private static Instant toInstant(Object value) {
        if (value instanceof OffsetDateTime odt) return odt.toInstant();
        if (value instanceof Timestamp ts) return ts.toInstant();
        if (value instanceof Instant i) return i;
        return Instant.EPOCH;
    }

    private static long toLong(Object value) {
        if (value instanceof Number n) return n.longValue();
        return 1L;
    }

    private static BigDecimal toBigDecimal(Object value) {
        if (value instanceof BigDecimal bd) return bd;
        if (value instanceof Number n) return BigDecimal.valueOf(n.doubleValue());
        return BigDecimal.ZERO;
    }
}
