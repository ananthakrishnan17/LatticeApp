package com.nammanban.backend.user;

import jakarta.validation.constraints.NotBlank;

import java.time.Instant;

public class UserDtos {
    public record UserResponse(
            String username,
            String role,
            boolean isActive,
            boolean canBill,
            boolean canViewReports,
            boolean canManageProducts,
            boolean canManageMasters,
            boolean canViewExpenses,
            boolean canManagePurchase,
            boolean canViewDashboard,
            Instant createdAt,
            Instant updatedAt
    ) {}

    public record CreateUserRequest(
            @NotBlank String username,
            @NotBlank String pin,
            String role,
            Boolean isActive,
            Boolean canBill,
            Boolean canViewReports,
            Boolean canManageProducts,
            Boolean canManageMasters,
            Boolean canViewExpenses,
            Boolean canManagePurchase,
            Boolean canViewDashboard
    ) {}

    public record UpdateUserRequest(
            String role,
            Boolean isActive,
            Boolean canBill,
            Boolean canViewReports,
            Boolean canManageProducts,
            Boolean canManageMasters,
            Boolean canViewExpenses,
            Boolean canManagePurchase,
            Boolean canViewDashboard
    ) {}

    public record ChangePinRequest(@NotBlank String pin) {}
}
