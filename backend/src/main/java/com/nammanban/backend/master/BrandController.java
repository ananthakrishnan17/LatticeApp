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

import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static com.nammanban.backend.master.MasterDtos.BrandRecord;
import static com.nammanban.backend.master.MasterDtos.BrandUpsertRequest;

@RestController
@RequestMapping("/brands")
public class BrandController {

    private final JdbcTemplate jdbc;

    public BrandController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<BrandRecord> list() {
        UUID tenantId = TenantContext.tenantId();
        return jdbc.queryForList("""
            SELECT server_id, client_record_id, name, version, updated_at
            FROM app_core.brands
            WHERE tenant_id = ? AND deleted_at IS NULL
            ORDER BY name ASC
            """, tenantId)
                .stream()
                .map(r -> new BrandRecord(
                        r.get("server_id").toString(),
                        r.get("client_record_id").toString(),
                        r.get("name").toString(),
                        toLong(r.get("version")),
                        toInstant(r.get("updated_at"))
                )).toList();
    }

    @PostMapping("/upsert")
    @Transactional
    public Map<String, Object> upsert(@Valid @RequestBody BrandUpsertRequest request) {
        UUID tenantId = TenantContext.tenantId();
        String deviceId = TenantContext.deviceId();
        long version = request.version() == null ? 1L : request.version();
        Instant updatedAt = request.updatedAt() == null ? Instant.now() : request.updatedAt();
        Instant deletedAt = Boolean.TRUE.equals(request.deleted()) ? Instant.now() : null;

        jdbc.update("""
            INSERT INTO app_core.brands(
              tenant_id, client_record_id, device_id, name, version, updated_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (tenant_id, name)
            DO UPDATE SET
              client_record_id = excluded.client_record_id,
              device_id = excluded.device_id,
              -- name is intentionally omitted: it is the conflict key, so it cannot change
              version = excluded.version,
              updated_at = excluded.updated_at,
              deleted_at = excluded.deleted_at
            """,
            tenantId,
            request.clientRecordId(),
            deviceId,
            request.name().trim(),
            version,
            Timestamp.from(updatedAt),
            deletedAt == null ? null : Timestamp.from(deletedAt)
        );
        return Map.of(
                "status", "ok",
                "clientRecordId", request.clientRecordId()
        );
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
}
