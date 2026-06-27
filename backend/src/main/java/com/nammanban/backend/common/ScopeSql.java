package com.nammanban.backend.common;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;

public final class ScopeSql {
    private ScopeSql() {}

    public record ScopedQuery(String sql, Object[] params) {}

    public static ScopedQuery appendReadScope(
            String baseSql,
            String tableAlias,
            boolean orgBranchColumnsPresent,
            Object... baseParams
    ) {
        String alias = tableAlias == null || tableAlias.isBlank() ? "" : tableAlias + ".";
        List<Object> params = new ArrayList<>(Arrays.asList(baseParams));
        String role = TenantContext.scopeRole();
        UUID organizationId = TenantContext.organizationId();
        UUID branchId = TenantContext.branchId();

        if (orgBranchColumnsPresent && role != null) {
            if (RoleScope.OWNER.equalsIgnoreCase(role) && organizationId != null) {
                params.add(organizationId);
                return new ScopedQuery(baseSql + " AND " + alias + "organization_id = ?", params.toArray());
            }
            if ((RoleScope.BRANCH_ADMIN.equalsIgnoreCase(role) || RoleScope.STAFF.equalsIgnoreCase(role)) && branchId != null) {
                params.add(branchId);
                return new ScopedQuery(baseSql + " AND " + alias + "branch_id = ?", params.toArray());
            }
        }

        return new ScopedQuery(baseSql, params.toArray());
    }
}
