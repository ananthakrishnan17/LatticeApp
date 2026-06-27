package com.nammanban.backend.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.Set;
import java.util.UUID;

/**
 * Resolves a UUID that may be either a {@code client_record_id} or a {@code server_id}
 * to the canonical {@code server_id} used by FK columns.
 *
 * <p>Flutter clients register the {@code client_record_id} returned by upsert endpoints
 * and send it back as a foreign-key reference (e.g. {@code brandId}, {@code categoryId},
 * {@code productId}).  Because FK columns point at {@code server_id}, resolution is
 * required before any INSERT/UPDATE.
 */
@Component
public class ServerIdResolver {

    private static final Logger log = LoggerFactory.getLogger(ServerIdResolver.class);

    /** Tables that may be queried through this resolver. Acts as a SQL-injection allowlist. */
    private static final Set<String> ALLOWED_TABLES = Set.of(
            "brands", "categories", "products", "customers", "suppliers"
    );

    private final JdbcTemplate jdbc;

    public ServerIdResolver(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Resolves {@code uuid} to the canonical {@code server_id} in {@code app_core.<table>}
     * for the given tenant.
     *
     * @param table    table name — must be in the {@link #ALLOWED_TABLES} allowlist
     * @param uuid     UUID that may be a {@code client_record_id} or {@code server_id}
     * @param tenantId the current tenant
     * @return the matching {@code server_id}, or {@code null} if {@code uuid} is null or not found
     * @throws IllegalArgumentException if {@code table} is not in the allowlist
     */
    public UUID resolve(String table, UUID uuid, UUID tenantId) {
        if (uuid == null) return null;
        if (!ALLOWED_TABLES.contains(table)) {
            throw new IllegalArgumentException("Table '" + table + "' is not permitted for server-id resolution");
        }
        try {
            var rows = jdbc.queryForList(
                    "SELECT server_id FROM app_core." + table +
                    " WHERE tenant_id = ? AND (server_id = ? OR client_record_id = ?) LIMIT 1",
                    tenantId, uuid, uuid);
            if (!rows.isEmpty()) {
                Object sid = rows.getFirst().get("server_id");
                return sid instanceof UUID u ? u : UUID.fromString(String.valueOf(sid));
            }
        } catch (Exception e) {
            log.warn("Could not resolve server_id for table={} uuid={}: {}", table, uuid, e.getMessage());
        }
        return null;
    }
}
