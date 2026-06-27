package com.nammanban.backend.subscription;

import com.nammanban.backend.common.TenantContext;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.UUID;

import static com.nammanban.backend.subscription.SubscriptionDtos.*;

@RestController
@RequestMapping("/subscription")
public class SubscriptionController {

    private final JdbcTemplate jdbc;

    public SubscriptionController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/status")
    public SubscriptionStatusResponse status() {
        return loadStatus(TenantContext.tenantId());
    }

    @PostMapping("/activate")
    public SubscriptionStatusResponse activate(@Valid @RequestBody ActivateRequest request) {
        UUID tenantId = TenantContext.tenantId();
        int updated = jdbc.update("""
            UPDATE app_core.tenant_licenses
            SET is_active = TRUE,
                activated_at = COALESCE(activated_at, now()),
                updated_at = now()
            WHERE tenant_id = ? AND upper(license_key) = upper(?)
            """, tenantId, request.licenseKey().trim());
        if (updated == 0) {
            throw new IllegalArgumentException("Invalid license key for this tenant");
        }
        return loadStatus(tenantId);
    }

    private SubscriptionStatusResponse loadStatus(UUID tenantId) {
        var rows = jdbc.queryForList("""
            SELECT t.name AS company_name,
                   l.server_id AS license_id,
                   l.license_key,
                   COALESCE(l.license_type, 'offline') AS license_type,
                   COALESCE(l.plan_code, 'basic') AS plan_code,
                   COALESCE(l.max_users, 2) AS max_users,
                   COALESCE(l.max_companies, 1) AS max_companies,
                   COALESCE(l.is_active, FALSE) AS license_active,
                   l.activated_at,
                   l.expires_at
            FROM app_core.tenants t
            LEFT JOIN app_core.tenant_licenses l ON l.tenant_id = t.server_id
            WHERE t.server_id = ?
            """, tenantId);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Tenant not found");
        }
        Map<String, Object> row = rows.getFirst();
        Instant expiresAt = row.get("expires_at") == null
                ? null
                : ((Timestamp) row.get("expires_at")).toInstant();
        boolean expired = expiresAt != null && Instant.now().isAfter(expiresAt);
        boolean active = Boolean.TRUE.equals(row.get("license_active")) && !expired;
        int daysLeft = expiresAt == null || !active
                ? 0
                : (int) Math.max(ChronoUnit.DAYS.between(Instant.now(), expiresAt), 0);
        return new SubscriptionStatusResponse(
                String.valueOf(row.get("company_name")),
                row.get("license_id") == null ? null : String.valueOf(row.get("license_id")),
                row.get("license_key") == null ? null : String.valueOf(row.get("license_key")),
                String.valueOf(row.get("license_type")),
                String.valueOf(row.get("plan_code")),
                ((Number) row.get("max_users")).intValue(),
                ((Number) row.get("max_companies")).intValue(),
                active,
                expired,
                row.get("activated_at") == null ? null : ((Timestamp) row.get("activated_at")).toInstant(),
                expiresAt,
                daysLeft
        );
    }
}
