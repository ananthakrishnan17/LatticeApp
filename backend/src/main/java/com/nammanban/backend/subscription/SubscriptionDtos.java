package com.nammanban.backend.subscription;

import jakarta.validation.constraints.NotBlank;

import java.time.Instant;

public class SubscriptionDtos {
    public record SubscriptionStatusResponse(
            String companyName,
            String licenseId,
            String licenseKey,
            String licenseType,
            String planCode,
            int maxUsers,
            int maxCompanies,
            boolean active,
            boolean expired,
            Instant activatedAt,
            Instant expiresAt,
            int daysLeft
    ) {}

    public record ActivateRequest(@NotBlank String licenseKey) {}
}
