package com.nammanban.backend.auth;

import com.nammanban.backend.config.JwtService;
import com.nammanban.backend.common.RoleScope;
import com.nammanban.backend.auth.AuthDtos.BootstrapRequest;
import com.nammanban.backend.auth.AuthDtos.LoginRequest;
import com.nammanban.backend.auth.AuthDtos.LoginResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.dao.DataAccessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/auth")
public class AuthController {
    private static final Logger log = LoggerFactory.getLogger(AuthController.class);
    private static final String DUMMY_BCRYPT_HASH =
            "$2a$10$7EqJtq98hPqEX7fNZaFWoOhi6fF5pNl1UkcQfW4jz2oxEd4pqcoEu";

    private final JdbcTemplate jdbc;
    private final JwtService jwtService;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    public AuthController(JdbcTemplate jdbc, JwtService jwtService) {
        this.jdbc = jdbc;
        this.jwtService = jwtService;
    }

    @PostMapping("/login")
    public LoginResponse login(@Validated @RequestBody LoginRequest request) {
        String phoneNumber = normalizeIdentifier(request.phoneNumber());
        String username = normalizeIdentifier(request.username());
        if (phoneNumber != null && username != null) {
            throw new IllegalArgumentException("Provide either phone number or username, not both");
        }
        if (phoneNumber == null && username == null) {
            throw new IllegalArgumentException("Phone number or username is required");
        }
        boolean usingPhone = phoneNumber != null;
        String identifier = usingPhone ? phoneNumber : username;
        String queryBase = """
            SELECT
              u.server_id user_id,
              u.username,
              u.mobile_number,
              u.password_hash,
              t.server_id tenant_id,
              uom.organization_id,
              ubm.branch_id,
              r.role_code mapped_role,
              l.server_id license_id,
              COALESCE(l.license_type, 'offline') license_type,
              l.is_active license_active,
              l.activated_at license_activated_at,
              l.expires_at license_expires_at
            FROM app_core.users u
            JOIN app_core.tenants t ON u.tenant_id=t.server_id
            LEFT JOIN LATERAL (
              SELECT m.organization_id
              FROM app_core.user_organization_mappings m
              WHERE m.tenant_id = u.tenant_id
                AND m.user_id = u.server_id
                AND m.is_active = true
              ORDER BY m.is_primary DESC, m.updated_at DESC, m.created_at DESC
              LIMIT 1
            ) uom ON true
            LEFT JOIN LATERAL (
              SELECT m.branch_id
              FROM app_core.user_branch_mappings m
              WHERE m.tenant_id = u.tenant_id
                AND m.user_id = u.server_id
                AND m.is_active = true
              ORDER BY m.is_primary DESC, m.updated_at DESC, m.created_at DESC
              LIMIT 1
            ) ubm ON true
            LEFT JOIN LATERAL (
              SELECT m.role_id
              FROM app_core.user_scope_role_mappings m
              WHERE m.tenant_id = u.tenant_id
                AND m.user_id = u.server_id
                AND m.is_active = true
              ORDER BY m.is_primary DESC, m.updated_at DESC, m.created_at DESC
              LIMIT 1
            ) urm ON true
            LEFT JOIN app_core.roles r ON r.server_id = urm.role_id
            LEFT JOIN app_core.organization_license_mappings olm
              ON olm.tenant_id = u.tenant_id
             AND olm.organization_id = uom.organization_id
             AND olm.is_active = true
            LEFT JOIN app_core.tenant_licenses l
              ON l.server_id = olm.tenant_license_id
            WHERE %s
              AND u.is_active=true
              AND t.is_active=true
            """;
        String predicate = usingPhone ? "(u.mobile_number = ? OR u.username = ?)" : "u.username = ?";
        String query = queryBase.formatted(predicate);
        List<Map<String, Object>> candidates = usingPhone
                ? jdbc.queryForList(query, identifier, identifier)
                : jdbc.queryForList(query, identifier);
        // Run at least one bcrypt comparison even when no user rows exist, to reduce
        // account-enumeration timing differences.
        encoder.matches(request.password(), DUMMY_BCRYPT_HASH);
        List<Map<String, Object>> matchedUsers = candidates.stream()
               .filter(candidate -> encoder.matches(request.password(), String.valueOf(candidate.get("password_hash"))))
               .toList();
        if (matchedUsers.isEmpty()) {
            throw new IllegalArgumentException("Invalid credentials");
        }
        if (matchedUsers.size() > 1) {
            throw new IllegalArgumentException(
                   usingPhone
                           ? "Ambiguous phone number: multiple tenants use this phone number. Please contact your administrator."
                           : "Ambiguous username: multiple tenants have a user with this username. Please use phone number login.");
        }

        Map<String, Object> user = matchedUsers.getFirst();
        String resolvedUsername = String.valueOf(user.get("username"));

        UUID tenantId = (UUID) user.get("tenant_id");
        String mappedRole = user.get("mapped_role") == null ? "" : String.valueOf(user.get("mapped_role"));
        String scopeRole = mappedRole.isBlank() ? RoleScope.STAFF : RoleScope.fromLegacyRole(mappedRole);
        String legacyRole = legacyRoleFromScopeRole(scopeRole);
        OrgBranchContext orgBranchContext = resolveOrgBranchContext(
                tenantId,
                (UUID) user.get("organization_id"),
                (UUID) user.get("branch_id")
        );
        ensureLicenseActiveForOrganization(user, orgBranchContext.organizationId());
        String licenseType = normalizeLicenseType(user.get("license_type"));
        String token = jwtService.issueToken(
                tenantId,
                orgBranchContext.organizationId(),
                orgBranchContext.branchId(),
                request.deviceId(),
                resolvedUsername,
                scopeRole,
                legacyRole,
                licenseType
        );

        jdbc.update("""
            INSERT INTO app_core.devices(tenant_id, device_id, last_seen_at)
            VALUES(?, ?, now())
            ON CONFLICT (tenant_id, device_id)
            DO UPDATE SET last_seen_at=excluded.last_seen_at
            """, tenantId, request.deviceId());

        return new LoginResponse(
                token,
                tenantId.toString(),
                request.deviceId(),
                legacyRole,
                orgBranchContext.organizationId().toString(),
                orgBranchContext.branchId().toString(),
                scopeRole,
                user.get("license_id") == null ? null : String.valueOf(user.get("license_id")),
                licenseType,
                Boolean.TRUE.equals(user.get("license_active")),
                toInstant(user.get("license_activated_at")),
                toInstant(user.get("license_expires_at"))
        );
    }

    @PostMapping("/bootstrap")
    public Map<String, Object> bootstrap(@Validated @RequestBody BootstrapRequest request) {
        var tenantRows = jdbc.queryForList("""
            SELECT t.server_id tenant_id
            FROM app_core.tenants t
            WHERE t.tenant_code = ?
              AND t.is_active = true
            """, request.tenantCode());
        if (tenantRows.isEmpty()) {
            throw new IllegalArgumentException("Active tenant not found");
        }
        UUID tenantId = (UUID) tenantRows.getFirst().get("tenant_id");
        Integer existingUsers = jdbc.queryForObject(
                "SELECT COUNT(*) FROM app_core.users WHERE tenant_id = ?",
                Integer.class,
                tenantId
        );
        if (existingUsers != null && existingUsers > 0) {
            throw new IllegalArgumentException("Bootstrap is allowed only when the tenant has no users");
        }
        if (!request.password().matches("\\d{4}")) {
            throw new IllegalArgumentException("PIN must be exactly 4 digits");
        }
        String hash = encoder.encode(request.password());
        UUID userId = jdbc.queryForObject("""
            INSERT INTO app_core.users(
              server_id,
              tenant_id, username, password_hash, is_active
            ) VALUES (gen_random_uuid(), ?, ?, ?, true)
            RETURNING server_id
            """,
            UUID.class,
            tenantId,
            request.username().trim(),
            hash
        );
        upsertPrimaryRoleMapping(tenantId, userId, RoleScope.OWNER, true);
        jdbc.update("""
            INSERT INTO app_core.devices(tenant_id, device_id, last_seen_at)
            VALUES(?, ?, now())
            ON CONFLICT (tenant_id, device_id)
            DO UPDATE SET last_seen_at=excluded.last_seen_at
            """, tenantId, request.deviceId());
        return Map.of("status", "ok");
    }

    @GetMapping("/health")
    public String health() {
        return "ok";
    }

    private OrgBranchContext resolveOrgBranchContext(UUID tenantId, UUID mappedOrganizationId, UUID mappedBranchId) {
        if (mappedOrganizationId != null && mappedBranchId != null) {
            return new OrgBranchContext(mappedOrganizationId, mappedBranchId);
        }
        try {
            var rows = jdbc.queryForList("""
                SELECT o.server_id organization_id, b.server_id branch_id
                FROM app_core.organizations o
                LEFT JOIN app_core.branches b
                  ON b.organization_id = o.server_id
                 AND b.is_default = true
                WHERE o.tenant_id = ?
                ORDER BY o.is_default DESC, o.created_at ASC
                LIMIT 1
                """, tenantId);
            if (!rows.isEmpty()) {
                Map<String, Object> row = rows.getFirst();
                UUID organizationId = (UUID) row.get("organization_id");
                UUID branchId = (UUID) row.get("branch_id");
                if (organizationId != null && branchId != null) {
                    return new OrgBranchContext(organizationId, branchId);
                }
            }
        } catch (DataAccessException ex) {
            log.debug("Organization/branch context lookup unavailable, using tenant fallback", ex);
        }
        return new OrgBranchContext(tenantId, tenantId);
    }

    private void upsertPrimaryRoleMapping(UUID tenantId, UUID userId, String scopeRole, boolean isActive) {
        try {
            UUID roleId = jdbc.queryForObject(
                    "SELECT server_id FROM app_core.roles WHERE role_code = ?",
                    UUID.class,
                    roleCodeFromScope(scopeRole)
            );
            if (roleId == null) return;
            var orgRows = jdbc.queryForList("""
                SELECT server_id
                FROM app_core.organizations
                WHERE tenant_id = ?
                ORDER BY is_default DESC, created_at ASC
                LIMIT 1
                """, tenantId);
            if (orgRows.isEmpty()) return;
            UUID organizationId = (UUID) orgRows.getFirst().get("server_id");

            var branchRows = jdbc.queryForList("""
                SELECT server_id
                FROM app_core.branches
                WHERE organization_id = ?
                ORDER BY is_default DESC, created_at ASC
                LIMIT 1
                """, organizationId);
            if (branchRows.isEmpty()) return;
            UUID branchId = (UUID) branchRows.getFirst().get("server_id");

            jdbc.update("""
                UPDATE app_core.user_organization_mappings
                SET is_primary = false, updated_at = now()
                WHERE tenant_id = ? AND user_id = ? AND is_primary = true
                """, tenantId, userId);
            jdbc.update("""
                UPDATE app_core.user_branch_mappings
                SET is_primary = false, updated_at = now()
                WHERE tenant_id = ? AND user_id = ? AND is_primary = true
                """, tenantId, userId);
            jdbc.update("""
                UPDATE app_core.user_scope_role_mappings
                SET is_primary = false, updated_at = now()
                WHERE tenant_id = ? AND user_id = ? AND is_primary = true
                """, tenantId, userId);

            jdbc.update("""
                INSERT INTO app_core.user_organization_mappings(
                  tenant_id, user_id, organization_id, is_primary, is_active, created_at, updated_at
                ) VALUES (?, ?, ?, true, ?, now(), now())
                ON CONFLICT (tenant_id, user_id, organization_id)
                DO UPDATE SET is_primary = true, is_active = excluded.is_active, updated_at = now()
                """, tenantId, userId, organizationId, isActive);
            jdbc.update("""
                INSERT INTO app_core.user_branch_mappings(
                  tenant_id, user_id, branch_id, is_primary, is_active, created_at, updated_at
                ) VALUES (?, ?, ?, true, ?, now(), now())
                ON CONFLICT (tenant_id, user_id, branch_id)
                DO UPDATE SET is_primary = true, is_active = excluded.is_active, updated_at = now()
                """, tenantId, userId, branchId, isActive);
            jdbc.update("""
                INSERT INTO app_core.user_scope_role_mappings(
                  tenant_id, user_id, role_id, is_primary, is_active, created_at, updated_at
                ) VALUES (?, ?, ?, true, ?, now(), now())
                ON CONFLICT (tenant_id, user_id, role_id)
                DO UPDATE SET is_primary = true, is_active = excluded.is_active, updated_at = now()
                """, tenantId, userId, roleId, isActive);
        } catch (DataAccessException ex) {
            log.warn("Role mapping update skipped during bootstrap: {}", ex.getMessage());
            log.debug("Role mapping update skipped during bootstrap", ex);
        }
    }

    private record OrgBranchContext(UUID organizationId, UUID branchId) {}

    private String roleCodeFromScope(String scopeRole) {
        String normalized = RoleScope.fromLegacyRole(scopeRole);
        if (RoleScope.OWNER.equalsIgnoreCase(normalized)) return "owner";
        if (RoleScope.BRANCH_ADMIN.equalsIgnoreCase(normalized)) return "branch_admin";
        return "staff";
    }

    private void ensureLicenseActiveForOrganization(Map<String, Object> user, UUID organizationId) {
        UUID mappedLicenseId = (UUID) user.get("license_id");
        if (mappedLicenseId == null) {
            throw new IllegalArgumentException("No active license mapped for organization: " + organizationId);
        }
        boolean active = Boolean.TRUE.equals(user.get("license_active"));
        Instant expiresAt = toInstant(user.get("license_expires_at"));
        if (!active || (expiresAt != null && Instant.now().isAfter(expiresAt))) {
            throw new IllegalArgumentException("Organization license is inactive or expired");
        }
    }

    private static Instant toInstant(Object value) {
        if (value == null) return null;
        if (value instanceof OffsetDateTime odt) return odt.toInstant();
        if (value instanceof Timestamp ts) return ts.toInstant();
        if (value instanceof Instant i) return i;
        return null;
    }

    private String legacyRoleFromScopeRole(String scopeRole) {
        String normalized = RoleScope.fromLegacyRole(scopeRole);
        if (RoleScope.OWNER.equalsIgnoreCase(normalized)) return "admin";
        if (RoleScope.BRANCH_ADMIN.equalsIgnoreCase(normalized)) return "branchadmin";
        return "user";
    }

    private String normalizeIdentifier(String rawValue) {
        if (rawValue == null) return null;
        String trimmed = rawValue.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private String normalizeLicenseType(Object rawValue) {
        if (rawValue == null) return "offline";
        String normalized = String.valueOf(rawValue).trim().toLowerCase();
        return "online".equals(normalized) ? "online" : "offline";
    }
}
