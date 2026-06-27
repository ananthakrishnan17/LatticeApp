package com.nammanban.backend.transaction;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nammanban.backend.common.TenantContext;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

import static com.nammanban.backend.transaction.TransactionDtos.TransactionUpsertRequest;

@RestController
@RequestMapping("/transactions")
public class TransactionController {

    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;

    public TransactionController(JdbcTemplate jdbc, ObjectMapper mapper) {
        this.jdbc = jdbc;
        this.mapper = mapper;
    }

    @PostMapping("/upsert")
    @Transactional
    public Map<String, Object> upsert(@Valid @RequestBody TransactionUpsertRequest request) throws Exception {
        UUID tenantId = TenantContext.tenantId();
        String deviceId = TenantContext.deviceId();
        Instant createdAt = request.createdAt() == null ? Instant.now() : request.createdAt();
        Instant updatedAt = request.updatedAt() == null ? createdAt : request.updatedAt();

        jdbc.update("""
            INSERT INTO app_core.erp_transactions(
              tenant_id, client_record_id, device_id, tx_type, total_amount, tags_json, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?::jsonb, ?, ?)
            ON CONFLICT (tenant_id, client_record_id)
            DO UPDATE SET
              device_id = excluded.device_id,
              tx_type = excluded.tx_type,
              total_amount = excluded.total_amount,
              tags_json = excluded.tags_json,
              created_at = excluded.created_at,
              updated_at = excluded.updated_at
            WHERE erp_transactions.updated_at <= excluded.updated_at
            """,
            tenantId,
            request.clientRecordId(),
            deviceId,
            request.type().trim(),
            request.totalAmount(),
            mapper.writeValueAsString(request.tags() == null ? Map.of() : request.tags()),
            Timestamp.from(createdAt),
            Timestamp.from(updatedAt)
        );

        return Map.of(
                "status", "ok",
                "clientRecordId", request.clientRecordId()
        );
    }

    @GetMapping
    public Map<String, Object> list(
            @RequestParam(required = false) String types,
            @RequestParam(required = false) String since,
            @RequestParam(defaultValue = "50") int limit
    ) {
        UUID tenantId = TenantContext.tenantId();
        Instant sinceInstant = since != null ? Instant.parse(since) : Instant.EPOCH;

        List<Map<String, Object>> rows;
        if (types != null && !types.isBlank()) {
            List<String> typeList = Arrays.asList(types.split(","));
            String placeholders = String.join(",", java.util.Collections.nCopies(typeList.size(), "?"));
            List<Object> params = new java.util.ArrayList<>();
            params.add(tenantId);
            params.addAll(typeList);
            params.add(Timestamp.from(sinceInstant));
            params.add(limit);
            rows = jdbc.queryForList("""
                SELECT server_id, client_record_id, device_id, tx_type,
                       total_amount, tags_json, created_at, updated_at
                FROM app_core.erp_transactions
                WHERE tenant_id = ? AND tx_type IN (""" + placeholders + """
                ) AND created_at > ?
                ORDER BY created_at DESC
                LIMIT ?
                """, params.toArray());
        } else {
            rows = jdbc.queryForList("""
                SELECT server_id, client_record_id, device_id, tx_type,
                       total_amount, tags_json, created_at, updated_at
                FROM app_core.erp_transactions
                WHERE tenant_id = ? AND created_at > ?
                ORDER BY created_at DESC
                LIMIT ?
                """,
                tenantId, Timestamp.from(sinceInstant), limit
            );
        }

        return Map.of("transactions", rows);
    }
}
