package com.nammanban.backend.owner;

import com.nammanban.backend.common.RoleScope;
import com.nammanban.backend.common.TenantContext;
import com.nammanban.backend.owner.OwnerDtos.AssignUserRequest;
import com.nammanban.backend.owner.OwnerDtos.BranchResponse;
import com.nammanban.backend.owner.OwnerDtos.BranchSummary;
import com.nammanban.backend.owner.OwnerDtos.CreateBranchRequest;
import com.nammanban.backend.owner.OwnerDtos.DashboardResponse;
import com.nammanban.backend.owner.OwnerDtos.RoleResponse;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/owner")
public class OwnerController {

    private final JdbcTemplate jdbc;

    public OwnerController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ── Dashboard ─────────────────────────────────────────────────────────────

    @GetMapping("/dashboard")
    public DashboardResponse dashboard() {
        requireOwnerOrAdmin();
        UUID tenantId = TenantContext.tenantId();

        List<Map<String, Object>> branchRows = jdbc.queryForList("""
            SELECT
                b.server_id branch_id,
                b.name      branch_name,
                COUNT(DISTINCT ubm.user_id) FILTER (WHERE u.is_active = true) active_staff_count
            FROM app_core.branches b
            JOIN app_core.organizations o ON o.server_id = b.organization_id
            LEFT JOIN app_core.user_branch_mappings ubm
                   ON ubm.branch_id = b.server_id
                  AND ubm.tenant_id = b.tenant_id
                  AND ubm.is_active = true
            LEFT JOIN app_core.users u
                   ON u.server_id = ubm.user_id
                  AND u.tenant_id = b.tenant_id
            WHERE b.tenant_id = ?
            GROUP BY b.server_id, b.name
            ORDER BY b.is_default DESC, b.created_at ASC
            """, tenantId);

        List<BranchSummary> branches = branchRows.stream()
                .map(r -> new BranchSummary(
                        r.get("branch_id").toString(),
                        r.get("branch_name").toString(),
                        0,
                        toInt(r.get("active_staff_count")),
                        0.0,
                        0.0
                )).toList();

        int totalStaff = branches.stream().mapToInt(BranchSummary::activeStaffCount).sum();

        return new DashboardResponse(0, 0, 0, 0, totalStaff, branches);
    }

    // ── Branches ──────────────────────────────────────────────────────────────

    @GetMapping("/branches")
    public List<BranchResponse> listBranches() {
        requireOwnerOrAdmin();
        UUID tenantId = TenantContext.tenantId();

        return jdbc.queryForList("""
            SELECT b.server_id, b.name, b.is_default, b.created_at
            FROM app_core.branches b
            WHERE b.tenant_id = ?
            ORDER BY b.is_default DESC, b.created_at ASC
            """, tenantId)
                .stream()
                .map(r -> new BranchResponse(
                        r.get("server_id").toString(),
                        r.get("name").toString(),
                        Boolean.TRUE.equals(r.get("is_default")),
                        toInstant(r.get("created_at"))
                )).toList();
    }

    @PostMapping("/branches")
    public BranchResponse createBranch(@Valid @RequestBody CreateBranchRequest request) {
        requireOwnerOrAdmin();
        UUID tenantId = TenantContext.tenantId();

        var orgRows = jdbc.queryForList("""
            SELECT server_id
            FROM app_core.organizations
            WHERE tenant_id = ?
            ORDER BY is_default DESC, created_at ASC
            LIMIT 1
            """, tenantId);
        if (orgRows.isEmpty()) {
            throw new IllegalStateException("No organization found for tenant");
        }
        UUID organizationId = (UUID) orgRows.getFirst().get("server_id");

        String name = request.name().trim();
        var existing = jdbc.queryForList("""
            SELECT 1 FROM app_core.branches
            WHERE organization_id = ? AND lower(name) = lower(?)
            """, organizationId, name);
        if (!existing.isEmpty()) {
            throw new IllegalArgumentException("A branch with this name already exists");
        }

        UUID branchId = UUID.randomUUID();
        String code = slugify(name);
        jdbc.update("""
            INSERT INTO app_core.branches(server_id, tenant_id, organization_id, name, code, is_default)
            VALUES (?, ?, ?, ?, ?, false)
            """,
                branchId,
                tenantId,
                organizationId,
                name,
                code
        );

        var row = jdbc.queryForMap("""
            SELECT server_id, name, is_default, created_at
            FROM app_core.branches
            WHERE server_id = ?
            """, branchId);

        return new BranchResponse(
                row.get("server_id").toString(),
                row.get("name").toString(),
                Boolean.TRUE.equals(row.get("is_default")),
                toInstant(row.get("created_at"))
        );
    }

    // ── Roles ─────────────────────────────────────────────────────────────────

    @GetMapping("/roles")
    public List<RoleResponse> listRoles() {
        requireOwnerOrAdmin();
        return jdbc.queryForList("""
            SELECT role_code, display_name, scope
            FROM app_core.roles
            ORDER BY CASE role_code
                        WHEN 'owner'        THEN 0
                        WHEN 'branch_admin' THEN 1
                        ELSE                     2
                     END
            """)
                .stream()
                .map(r -> new RoleResponse(
                        r.get("role_code").toString(),
                        r.get("display_name").toString(),
                        r.get("scope").toString()
                )).toList();
    }

    // ── User Assignment ───────────────────────────────────────────────────────

    @PostMapping("/users/{username}/assign")
    public Map<String, Object> assignUser(
            @PathVariable String username,
            @Valid @RequestBody AssignUserRequest request) {
        requireOwnerOrAdmin();
        UUID tenantId = TenantContext.tenantId();

        var userRows = jdbc.queryForList(
                "SELECT server_id FROM app_core.users WHERE tenant_id = ? AND username = ?",
                tenantId, username);
        if (userRows.isEmpty()) {
            throw new IllegalArgumentException("User not found: " + username);
        }
        UUID userId = (UUID) userRows.getFirst().get("server_id");

        String roleCode = normalizeRoleCode(request.roleCode());
        var roleRows = jdbc.queryForList(
                "SELECT server_id FROM app_core.roles WHERE role_code = ?",
                roleCode);
        if (roleRows.isEmpty()) {
            throw new IllegalArgumentException("Role not found: " + roleCode);
        }
        UUID roleId = (UUID) roleRows.getFirst().get("server_id");

        UUID branchId = UUID.fromString(request.branchId());
        var branchRows = jdbc.queryForList("""
            SELECT organization_id FROM app_core.branches
            WHERE server_id = ? AND tenant_id = ?
            """, branchId, tenantId);
        if (branchRows.isEmpty()) {
            throw new IllegalArgumentException("Branch not found");
        }
        UUID organizationId = (UUID) branchRows.getFirst().get("organization_id");

        // Clear existing primary mappings
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

        // Upsert new primary mappings
        jdbc.update("""
            INSERT INTO app_core.user_organization_mappings(
                tenant_id, user_id, organization_id, is_primary, is_active, created_at, updated_at
            ) VALUES (?, ?, ?, true, true, now(), now())
            ON CONFLICT (tenant_id, user_id, organization_id)
            DO UPDATE SET is_primary = true, is_active = true, updated_at = now()
            """, tenantId, userId, organizationId);
        jdbc.update("""
            INSERT INTO app_core.user_branch_mappings(
                tenant_id, user_id, branch_id, is_primary, is_active, created_at, updated_at
            ) VALUES (?, ?, ?, true, true, now(), now())
            ON CONFLICT (tenant_id, user_id, branch_id)
            DO UPDATE SET is_primary = true, is_active = true, updated_at = now()
            """, tenantId, userId, branchId);
        jdbc.update("""
            INSERT INTO app_core.user_scope_role_mappings(
                tenant_id, user_id, role_id, is_primary, is_active, created_at, updated_at
            ) VALUES (?, ?, ?, true, true, now(), now())
            ON CONFLICT (tenant_id, user_id, role_id)
            DO UPDATE SET is_primary = true, is_active = true, updated_at = now()
            """, tenantId, userId, roleId);

        return Map.of("status", "ok");
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private void requireOwnerOrAdmin() {
        boolean allowed = SecurityContextHolder.getContext().getAuthentication().getAuthorities()
                .stream()
                .anyMatch(a -> {
                    String auth = a.getAuthority();
                    return "ROLE_ADMIN".equals(auth)
                            || "ROLE_OWNER".equals(auth)
                            || auth.equalsIgnoreCase("ROLE_" + RoleScope.OWNER.toUpperCase());
                });
        if (!allowed) {
            throw new org.springframework.security.access.AccessDeniedException("Insufficient permissions: Owner or Admin role required");
        }
    }

    private String normalizeRoleCode(String role) {
        if (role == null || role.isBlank()) return "staff";
        String normalized = role.trim().toLowerCase();
        if ("admin".equals(normalized) || "owner".equals(normalized)) return "owner";
        if ("branchadmin".equals(normalized) || "branch_admin".equals(normalized)) return "branch_admin";
        return "staff";
    }

    private static String slugify(String text) {
        return text.trim()
                .toLowerCase()
                .replaceAll("[^a-z0-9]+", "-")
                .replaceAll("^-+|-+$", "");
    }

    private static Instant toInstant(Object value) {
        if (value instanceof OffsetDateTime odt) return odt.toInstant();
        if (value instanceof Timestamp ts) return ts.toInstant();
        if (value instanceof Instant i) return i;
        return Instant.EPOCH;
    }

    private static int toInt(Object value) {
        if (value instanceof Number n) return n.intValue();
        return 0;
    }
}
