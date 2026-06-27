package com.nammanban.backend.owner;

import jakarta.validation.constraints.NotBlank;

import java.time.Instant;
import java.util.List;

public class OwnerDtos {

    public record BranchResponse(
            String id,
            String name,
            boolean isDefault,
            Instant createdAt
    ) {}

    public record CreateBranchRequest(
            @NotBlank String name
    ) {}

    public record RoleResponse(
            String code,
            String displayName,
            String scope
    ) {}

    public record AssignUserRequest(
            @NotBlank String branchId,
            @NotBlank String roleCode
    ) {}

    public record DashboardResponse(
            double todayRevenue,
            double trendPercent,
            double totalProfit,
            int transactionCount,
            int activeStaffCount,
            List<BranchSummary> branches
    ) {}

    public record BranchSummary(
            String branchId,
            String branchName,
            int transactionCount,
            int activeStaffCount,
            double revenueAmount,
            double targetPercent
    ) {}
}
