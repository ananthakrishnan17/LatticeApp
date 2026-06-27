package com.nammanban.backend.common;

public final class RoleScope {
    public static final String OWNER = "Owner";
    public static final String BRANCH_ADMIN = "BranchAdmin";
    public static final String STAFF = "Staff";

    private RoleScope() {}

    public static String fromLegacyRole(String role) {
        if (role == null) return STAFF;
        if ("owner".equalsIgnoreCase(role) || "admin".equalsIgnoreCase(role)) return OWNER;
        if ("branchadmin".equalsIgnoreCase(role) || "branch_admin".equalsIgnoreCase(role)) return BRANCH_ADMIN;
        if (STAFF.equalsIgnoreCase(role)) return STAFF;
        if (OWNER.equalsIgnoreCase(role)) return OWNER;
        if (BRANCH_ADMIN.equalsIgnoreCase(role) || "branch_admin".equalsIgnoreCase(role)) return BRANCH_ADMIN;
        return STAFF;
    }
}
