package com.nammanban.backend.transaction;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public class TransactionDtos {
    public record TransactionUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String type,
            @NotNull @DecimalMin(value = "0.00", message = "totalAmount must be non-negative") BigDecimal totalAmount,
            Map<String, Object> tags,
            Instant createdAt,
            Instant updatedAt
    ) {}
}
