package com.nammanban.backend.common;

import java.util.UUID;

public final class TenantContext {
    private static final ThreadLocal<UUID> TENANT = new ThreadLocal<>();
    private static final ThreadLocal<String> DEVICE = new ThreadLocal<>();
    private static final ThreadLocal<UUID> ORGANIZATION = new ThreadLocal<>();
    private static final ThreadLocal<UUID> BRANCH = new ThreadLocal<>();
    private static final ThreadLocal<String> SCOPE_ROLE = new ThreadLocal<>();
    private static final ThreadLocal<String> LICENSE_TYPE = new ThreadLocal<>();

    private TenantContext() {}

    public static void set(UUID tenantId, String deviceId) {
        set(tenantId, deviceId, null, null, null, null);
    }

    public static void set(UUID tenantId, String deviceId, UUID organizationId, UUID branchId, String scopeRole) {
        set(tenantId, deviceId, organizationId, branchId, scopeRole, null);
    }

    public static void set(UUID tenantId, String deviceId, UUID organizationId, UUID branchId, String scopeRole, String licenseType) {
        TENANT.set(tenantId);
        DEVICE.set(deviceId);
        ORGANIZATION.set(organizationId);
        BRANCH.set(branchId);
        SCOPE_ROLE.set(scopeRole);
        LICENSE_TYPE.set(licenseType != null ? licenseType : "offline");
    }

    public static UUID tenantId() {
        return TENANT.get();
    }

    public static String deviceId() {
        return DEVICE.get();
    }

    public static UUID organizationId() {
        return ORGANIZATION.get();
    }

    public static UUID branchId() {
        return BRANCH.get();
    }

    public static String scopeRole() {
        return SCOPE_ROLE.get();
    }

    public static String licenseType() {
        String lt = LICENSE_TYPE.get();
        return lt != null ? lt : "offline";
    }

    public static boolean isOnlineLicense() {
        return "online".equals(licenseType());
    }

    public static void clear() {
        TENANT.remove();
        DEVICE.remove();
        ORGANIZATION.remove();
        BRANCH.remove();
        SCOPE_ROLE.remove();
        LICENSE_TYPE.remove();
    }
}
