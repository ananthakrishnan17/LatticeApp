package com.nammanban.backend.auth;

import jakarta.validation.constraints.NotBlank;

import java.time.Instant;

public class AuthDtos {
    public record LoginRequest(
            String tenantCode,
            String username,
            String phoneNumber,
            @NotBlank String password,
            @NotBlank String deviceId
    ) {}
    public record LoginResponse(
            String accessToken,
            String tenantId,
            String deviceId,
            String role,
            String organizationId,
            String branchId,
            String scopeRole,
            String licenseId,
            String licenseType,
            boolean licenseActive,
            Instant licenseActivatedAt,
            Instant licenseExpiresAt
    ) {}
    public record BootstrapRequest(@NotBlank String tenantCode, @NotBlank String username, @NotBlank String password, @NotBlank String deviceId) {}
}
