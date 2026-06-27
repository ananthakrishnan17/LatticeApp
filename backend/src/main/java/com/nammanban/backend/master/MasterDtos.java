package com.nammanban.backend.master;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public class MasterDtos {

    public record CategoryUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String name,
            Long version,
            Instant updatedAt,
            Boolean deleted
    ) {}

    public record CategoryRecord(
            String serverId,
            String clientRecordId,
            String name,
            long version,
            Instant updatedAt
    ) {}

    public record BrandUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String name,
            Long version,
            Instant updatedAt,
            Boolean deleted
    ) {}

    public record BrandRecord(
            String serverId,
            String clientRecordId,
            String name,
            long version,
            Instant updatedAt
    ) {}

    public record CustomerUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String name,
            String phone,
            String address,
            String gstNumber,
            BigDecimal creditLimit,
            BigDecimal outstandingBalance,
            Long version,
            Instant updatedAt,
            Boolean deleted
    ) {}

    public record CustomerRecord(
            String serverId,
            String clientRecordId,
            String name,
            String phone,
            String address,
            String gstNumber,
            BigDecimal creditLimit,
            BigDecimal outstandingBalance,
            long version,
            Instant updatedAt
    ) {}

    public record SupplierUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String name,
            String phone,
            String address,
            String gstNumber,
            BigDecimal outstandingBalance,
            Long version,
            Instant updatedAt,
            Boolean deleted
    ) {}

    public record SupplierRecord(
            String serverId,
            String clientRecordId,
            String name,
            String phone,
            String address,
            String gstNumber,
            BigDecimal outstandingBalance,
            long version,
            Instant updatedAt
    ) {}
}
