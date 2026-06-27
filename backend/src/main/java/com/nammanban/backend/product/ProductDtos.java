package com.nammanban.backend.product;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public class ProductDtos {
    public record ProductUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotBlank String name,
            UUID categoryId,
            UUID brandId,
            String unit,
            BigDecimal sellingPrice,
            BigDecimal purchasePrice,
            BigDecimal wholesalePrice,
            BigDecimal stockQuantity,
            BigDecimal lowStockThreshold,
            BigDecimal gstRate,
            String barcode,
            String hsnCode,
            String itemType,
            Long version,
            Instant updatedAt,
            Boolean deleted,
            String imageUrl
    ) {}

    public record ProductResponse(
            UUID serverId,
            UUID clientRecordId,
            UUID categoryId,
            UUID brandId,
            String name,
            String unit,
            BigDecimal sellingPrice,
            BigDecimal purchasePrice,
            BigDecimal wholesalePrice,
            BigDecimal stockQuantity,
            BigDecimal lowStockThreshold,
            BigDecimal gstRate,
            String barcode,
            String hsnCode,
            String itemType,
            long version,
            Instant updatedAt,
            Instant deletedAt,
            String imageUrl
    ) {}
}
