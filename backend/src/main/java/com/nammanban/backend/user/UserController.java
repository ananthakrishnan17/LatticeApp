package com.nammanban.backend.user;

import com.nammanban.backend.common.TenantContext;
import com.nammanban.backend.user.UserDtos.ChangePinRequest;
import com.nammanban.backend.user.UserDtos.CreateUserRequest;
import com.nammanban.backend.user.UserDtos.UpdateUserRequest;
import com.nammanban.backend.user.UserDtos.UserResponse;
import jakarta.validation.Valid;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/users")
public class UserController {
    private static final Logger log = LoggerFactory.getLogger(UserController.class);

    private final JdbcTemplate jdbc;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    public UserController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/me")
    public UserResponse me() {
        return loadUser(requiredUsername());
    }

    @GetMapping
    public List<UserResponse> list() {
        UUID tenantId = TenantContext.tenantId();
        return jdbc.queryForList("""
            SELECT u.username,
                   u.is_active,
                   u.created_at,
                   u.updated_at,
                   r.role_code
            FROM app_core.users u
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
            WHERE u.tenant_id = ?
            ORDER BY CASE r.role_code
                        WHEN 'owner' THEN 0
                        WHEN 'branch_admin' THEN 1
                        ELSE 2
                     END,
                     u.username ASC
            """, tenantId).stream().map(this::mapUser).toList();
    }

    @PostMapping
    public UserResponse create(@Valid @RequestBody CreateUserRequest request) {
        requireAdmin();
        validatePin(request.pin());
        UUID tenantId = TenantContext.tenantId();
        String roleCode = normalizeRoleCode(request.role());
        ensureUserLimits(tenantId, roleCode, null);
        String hash = encoder.encode(request.pin());
        UUID userId = jdbc.queryForObject("""
            INSERT INTO app_core.users(
              server_id,
              tenant_id, username, password_hash, is_active
            ) VALUES (gen_random_uuid(), ?, ?, ?, ?)
            RETURNING server_id
            """,
            UUID.class,
            tenantId,
            request.username().trim(),
            hash,
            request.isActive() == null || request.isActive()
        );
        upsertPrimaryRoleMapping(
                tenantId,
                userId,
                roleCode,
                request.isActive() == null || request.isActive()
        );
        return loadUser(request.username().trim());
    }

    @PutMapping("/{username}")
    public UserResponse update(@PathVariable String username, @Valid @RequestBody UpdateUserRequest request) {
        requireAdmin();
        String roleCode = normalizeRoleCode(request.role());
        UUID tenantId = TenantContext.tenantId();
        ensureUserLimits(tenantId, roleCode, username);
        UUID userId = jdbc.queryForObject(
                "SELECT server_id FROM app_core.users WHERE tenant_id = ? AND username = ?",
                UUID.class,
                tenantId,
                username
        );
        if (userId == null) {
            throw new IllegalArgumentException("User not found: " + username);
        }
        boolean active = request.isActive() == null || request.isActive();
        jdbc.update("""
            UPDATE app_core.users
            SET is_active = ?,
                updated_at = now()
            WHERE tenant_id = ? AND username = ?
            """,
            active,
            tenantId,
            username
        );
        upsertPrimaryRoleMapping(
                tenantId,
                userId,
                roleCode,
                active
        );
        return loadUser(username);
    }

    @PutMapping("/{username}/pin")
    public Map<String, Object> changePin(@PathVariable String username, @Valid @RequestBody ChangePinRequest request) {
        if (!isAdmin() && !requiredUsername().equals(username)) {
            throw new IllegalArgumentException("Only admins can change other users' PINs");
        }
        validatePin(request.pin());
        String hash = encoder.encode(request.pin());
        int updated = jdbc.update("""
            UPDATE app_core.users
            SET password_hash = ?, updated_at = now()
            WHERE tenant_id = ? AND username = ?
            """, hash, TenantContext.tenantId(), username);
        if (updated == 0) {
            throw new IllegalArgumentException("User not found");
        }
        return Map.of("status", "ok");
    }

    @DeleteMapping("/{username}")
    public Map<String, Object> delete(@PathVariable String username) {
        requireAdmin();
        if (requiredUsername().equals(username)) {
            throw new IllegalArgumentException("You cannot delete the current user");
        }
        int updated = jdbc.update("DELETE FROM app_core.users WHERE tenant_id = ? AND username = ?", TenantContext.tenantId(), username);
        if (updated == 0) {
            throw new IllegalArgumentException("User not found");
        }
        return Map.of("status", "ok");
    }

    private UserResponse loadUser(String username) {
        var rows = jdbc.queryForList("""
            SELECT u.username,
                   u.is_active,
                   u.created_at,
                   u.updated_at,
                   r.role_code
            FROM app_core.users u
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
            WHERE u.tenant_id = ? AND u.username = ?
            """, TenantContext.tenantId(), username);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("User not found");
        }
        return mapUser(rows.getFirst());
    }

    private UserResponse mapUser(Map<String, Object> row) {
        String roleCode = row.get("role_code") == null ? "staff" : String.valueOf(row.get("role_code"));
        String role = legacyRoleFromRoleCode(roleCode);
        Permissions permissions = permissionsForRole(roleCode);
        return new UserResponse(
                String.valueOf(row.get("username")),
                role,
                Boolean.TRUE.equals(row.get("is_active")),
                permissions.canBill(),
                permissions.canViewReports(),
                permissions.canManageProducts(),
                permissions.canManageMasters(),
                permissions.canViewExpenses(),
                permissions.canManagePurchase(),
                permissions.canViewDashboard(),
                toInstant(row.get("created_at")),
                toInstant(row.get("updated_at"))
        );
    }

    private static Instant toInstant(Object value) {
        if (value instanceof OffsetDateTime odt) return odt.toInstant();
        if (value instanceof Timestamp ts)        return ts.toInstant();
        if (value instanceof Instant i)           return i;
        return Instant.EPOCH;
    }

    private void ensureUserLimits(UUID tenantId, String requestedRoleCode, String existingUsername) {
        Integer maxUsers = jdbc.queryForObject("""
            SELECT COALESCE(max_users, 2)
            FROM app_core.tenant_licenses
            WHERE tenant_id = ?
            """, Integer.class, tenantId);
        if (maxUsers != null) {
            Integer userCount = jdbc.queryForObject("SELECT COUNT(*) FROM app_core.users WHERE tenant_id = ?", Integer.class, tenantId);
            boolean isNewUser = existingUsername == null || existingUsername.isBlank();
            if (isNewUser && userCount != null && userCount >= maxUsers) {
                throw new IllegalArgumentException("User limit reached for this tenant");
            }
        }
        if ("owner".equals(requestedRoleCode)) {
            Integer ownerCount = existingUsername == null || existingUsername.isBlank()
                    ? jdbc.queryForObject("""
                        SELECT COUNT(*)
                        FROM app_core.user_scope_role_mappings m
                        JOIN app_core.roles r ON r.server_id = m.role_id
                        JOIN app_core.users u ON u.server_id = m.user_id AND u.tenant_id = m.tenant_id
                        WHERE m.tenant_id = ?
                          AND m.is_primary = true
                          AND m.is_active = true
                          AND r.role_code = 'owner'
                        """, Integer.class, tenantId)
                    : jdbc.queryForObject("""
                        SELECT COUNT(*)
                        FROM app_core.user_scope_role_mappings m
                        JOIN app_core.roles r ON r.server_id = m.role_id
                        JOIN app_core.users u ON u.server_id = m.user_id AND u.tenant_id = m.tenant_id
                        WHERE m.tenant_id = ?
                          AND m.is_primary = true
                          AND m.is_active = true
                          AND r.role_code = 'owner'
                          AND u.username <> ?
                        """, Integer.class, tenantId, existingUsername);
            if (ownerCount != null && ownerCount >= 1) {
                throw new IllegalArgumentException("Only one owner is allowed per tenant");
            }
        }
    }

    private void requireAdmin() {
        if (!isAdmin()) {
            throw new IllegalArgumentException("Admin access required");
        }
    }

    private boolean isAdmin() {
        return SecurityContextHolder.getContext().getAuthentication().getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()) || 
                               "ROLE_OWNER".equals(a.getAuthority()) || 
                               "ROLE_BRANCH_ADMIN".equals(a.getAuthority()));
    }

    private String requiredUsername() {
        return SecurityContextHolder.getContext().getAuthentication().getName();
    }

    private void validatePin(String pin) {
        if (pin == null || !pin.matches("\\d{4}")) {
            throw new IllegalArgumentException("PIN must be exactly 4 digits");
        }
    }

    private String normalizeRoleCode(String role) {
        if (role == null || role.isBlank()) {
            return "staff";
        }
        String normalized = role.trim().toLowerCase();
        if ("admin".equals(normalized) || "owner".equals(normalized)) {
            return "owner";
        }
        if ("branchadmin".equals(normalized) || "branch_admin".equals(normalized)) {
            return "branch_admin";
        }
        return "staff";
    }

    private String legacyRoleFromRoleCode(String roleCode) {
        if ("owner".equals(roleCode)) {
            return "admin";
        }
        if ("branch_admin".equals(roleCode)) {
            return "branchadmin";
        }
        return "user";
    }

    private Permissions permissionsForRole(String roleCode) {
        String normalized = roleCode == null ? "staff" : roleCode;
        if ("owner".equals(normalized)) {
            return new Permissions(true, true, true, true, true, true, true);
        }
        if ("branch_admin".equals(normalized)) {
            return new Permissions(true, true, true, true, true, true, true);
        }
        return new Permissions(true, false, false, false, false, false, true);
    }

    private void upsertPrimaryRoleMapping(UUID tenantId, UUID userId, String roleCode, boolean isActive) {
        try {
            UUID roleId = jdbc.queryForObject(
                    "SELECT server_id FROM app_core.roles WHERE role_code = ?",
                    UUID.class,
                    roleCode
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
        } catch (DataAccessException ignored) {
            log.debug("Skipping role mapping update for user {} due to data access issue", userId, ignored);
        }
    }

    private record Permissions(
            boolean canBill,
            boolean canViewReports,
            boolean canManageProducts,
            boolean canManageMasters,
            boolean canViewExpenses,
            boolean canManagePurchase,
            boolean canViewDashboard
    ) {}
}
