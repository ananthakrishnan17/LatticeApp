package com.nammanban.backend.product;

import com.nammanban.backend.common.ServerIdResolver;
import com.nammanban.backend.common.ScopeSql;
import com.nammanban.backend.common.TenantContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static com.nammanban.backend.product.ProductDtos.ProductResponse;
import static com.nammanban.backend.product.ProductDtos.ProductUpsertRequest;

@Service
public class ProductService {
    private final JdbcTemplate jdbc;
    private final ServerIdResolver serverIdResolver;

    public ProductService(JdbcTemplate jdbc, ServerIdResolver serverIdResolver) {
        this.jdbc = jdbc;
        this.serverIdResolver = serverIdResolver;
    }

    @Transactional
    public ProductResponse upsert(ProductUpsertRequest request) {
        UUID tenantId = TenantContext.tenantId();
        String deviceId = TenantContext.deviceId();
        UUID organizationId = TenantContext.organizationId();
        UUID branchId = TenantContext.branchId();
        boolean orgBranchColumnsPresent = hasOrgBranchColumns();
        long incomingVersion = request.version() == null ? 1L : request.version();
        Instant incomingUpdatedAt = request.updatedAt() == null ? Instant.now() : request.updatedAt();
        Instant deletedAt = Boolean.TRUE.equals(request.deleted()) ? Instant.now() : null;

        // Flutter sends client_record_id as the FK reference for category/brand.
        // Resolve to the actual server_id to satisfy FK constraints.
        UUID resolvedCategoryId = serverIdResolver.resolve("categories", request.categoryId(), tenantId);
        UUID resolvedBrandId = serverIdResolver.resolve("brands", request.brandId(), tenantId);

        if (orgBranchColumnsPresent) {
            jdbc.update("""
                INSERT INTO app_core.products(
                    tenant_id, client_record_id, device_id, organization_id, branch_id, category_id, brand_id,
                    name, unit, selling_price, purchase_price, wholesale_price,
                    stock_quantity, low_stock_threshold, gst_rate, barcode, hsn_code, item_type,
                    version, updated_at, deleted_at, image_url
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (tenant_id, client_record_id)
                DO UPDATE SET
                    organization_id=COALESCE(excluded.organization_id, products.organization_id),
                    branch_id=COALESCE(excluded.branch_id, products.branch_id),
                    category_id=excluded.category_id,
                    brand_id=excluded.brand_id,
                    name=excluded.name,
                    unit=excluded.unit,
                    selling_price=excluded.selling_price,
                    purchase_price=excluded.purchase_price,
                    wholesale_price=excluded.wholesale_price,
                    stock_quantity=excluded.stock_quantity,
                    low_stock_threshold=excluded.low_stock_threshold,
                    gst_rate=excluded.gst_rate,
                    barcode=excluded.barcode,
                    hsn_code=excluded.hsn_code,
                    item_type=excluded.item_type,
                    version=excluded.version,
                    updated_at=excluded.updated_at,
                    deleted_at=excluded.deleted_at,
                    device_id=excluded.device_id,
                    image_url=excluded.image_url
                """,
                tenantId,
                request.clientRecordId(),
                deviceId,
                organizationId,
                branchId,
                resolvedCategoryId,
                resolvedBrandId,
                request.name(),
                request.unit() == null ? "piece" : request.unit(),
                request.sellingPrice() == null ? BigDecimal.ZERO : request.sellingPrice(),
                request.purchasePrice() == null ? BigDecimal.ZERO : request.purchasePrice(),
                request.wholesalePrice() == null ? BigDecimal.ZERO : request.wholesalePrice(),
                request.stockQuantity() == null ? BigDecimal.ZERO : request.stockQuantity(),
                request.lowStockThreshold() == null ? BigDecimal.ZERO : request.lowStockThreshold(),
                request.gstRate() == null ? BigDecimal.ZERO : request.gstRate(),
                request.barcode(),
                request.hsnCode(),
                request.itemType() == null ? "physical" : request.itemType(),
                incomingVersion,
                Timestamp.from(incomingUpdatedAt),
                deletedAt == null ? null : Timestamp.from(deletedAt),
                request.imageUrl()
            );
        } else {
            jdbc.update("""
                INSERT INTO app_core.products(
                    tenant_id, client_record_id, device_id, category_id, brand_id,
                    name, unit, selling_price, purchase_price, wholesale_price,
                    stock_quantity, low_stock_threshold, gst_rate, barcode, hsn_code, item_type,
                    version, updated_at, deleted_at, image_url
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (tenant_id, client_record_id)
                DO UPDATE SET
                    category_id=excluded.category_id,
                    brand_id=excluded.brand_id,
                    name=excluded.name,
                    unit=excluded.unit,
                    selling_price=excluded.selling_price,
                    purchase_price=excluded.purchase_price,
                    wholesale_price=excluded.wholesale_price,
                    stock_quantity=excluded.stock_quantity,
                    low_stock_threshold=excluded.low_stock_threshold,
                    gst_rate=excluded.gst_rate,
                    barcode=excluded.barcode,
                    hsn_code=excluded.hsn_code,
                    item_type=excluded.item_type,
                    version=excluded.version,
                    updated_at=excluded.updated_at,
                    deleted_at=excluded.deleted_at,
                    device_id=excluded.device_id,
                    image_url=excluded.image_url
                """,
                tenantId,
                request.clientRecordId(),
                deviceId,
                resolvedCategoryId,
                resolvedBrandId,
                request.name(),
                request.unit() == null ? "piece" : request.unit(),
                request.sellingPrice() == null ? BigDecimal.ZERO : request.sellingPrice(),
                request.purchasePrice() == null ? BigDecimal.ZERO : request.purchasePrice(),
                request.wholesalePrice() == null ? BigDecimal.ZERO : request.wholesalePrice(),
                request.stockQuantity() == null ? BigDecimal.ZERO : request.stockQuantity(),
                request.lowStockThreshold() == null ? BigDecimal.ZERO : request.lowStockThreshold(),
                request.gstRate() == null ? BigDecimal.ZERO : request.gstRate(),
                request.barcode(),
                request.hsnCode(),
                request.itemType() == null ? "physical" : request.itemType(),
                incomingVersion,
                Timestamp.from(incomingUpdatedAt),
                deletedAt == null ? null : Timestamp.from(deletedAt),
                request.imageUrl()
            );
        }
        ScopeSql.ScopedQuery scopedQuery = ScopeSql.appendReadScope("""
            SELECT server_id, client_record_id, category_id, brand_id, name, unit,
                   selling_price, purchase_price, wholesale_price, stock_quantity,
                   low_stock_threshold, gst_rate, barcode, hsn_code, item_type,
                   version, updated_at, deleted_at, image_url
            FROM app_core.products p
            WHERE p.tenant_id=? AND p.client_record_id=?
            """, "p", orgBranchColumnsPresent,
            tenantId, request.clientRecordId());
        return jdbc.queryForObject(scopedQuery.sql(),
            (rs, rowNum) -> new ProductResponse(
                    rs.getObject("server_id", UUID.class),
                    rs.getObject("client_record_id", UUID.class),
                    rs.getObject("category_id", UUID.class),
                    rs.getObject("brand_id", UUID.class),
                    rs.getString("name"),
                    rs.getString("unit"),
                    rs.getBigDecimal("selling_price"),
                    rs.getBigDecimal("purchase_price"),
                    rs.getBigDecimal("wholesale_price"),
                    rs.getBigDecimal("stock_quantity"),
                    rs.getBigDecimal("low_stock_threshold"),
                    rs.getBigDecimal("gst_rate"),
                    rs.getString("barcode"),
                    rs.getString("hsn_code"),
                    rs.getString("item_type"),
                    rs.getLong("version"),
                    rs.getTimestamp("updated_at").toInstant(),
                    rs.getTimestamp("deleted_at") == null ? null : rs.getTimestamp("deleted_at").toInstant(),
                    rs.getString("image_url")
            ), scopedQuery.params());
    }

    public List<ProductResponse> list() {
        UUID tenantId = TenantContext.tenantId();
        boolean orgBranchColumnsPresent = hasOrgBranchColumns();
        ScopeSql.ScopedQuery scopedQuery = ScopeSql.appendReadScope("""
            SELECT server_id, client_record_id, category_id, brand_id, name, unit,
                   selling_price, purchase_price, wholesale_price, stock_quantity,
                   low_stock_threshold, gst_rate, barcode, hsn_code, item_type,
                   version, updated_at, deleted_at, image_url
            FROM app_core.products p
            WHERE p.tenant_id=? AND p.deleted_at IS NULL
            """, "p", orgBranchColumnsPresent, tenantId);
        return jdbc.query(scopedQuery.sql() + " ORDER BY updated_at DESC", (rs, rowNum) -> new ProductResponse(
                rs.getObject("server_id", UUID.class),
                rs.getObject("client_record_id", UUID.class),
                rs.getObject("category_id", UUID.class),
                rs.getObject("brand_id", UUID.class),
                rs.getString("name"),
                rs.getString("unit"),
                rs.getBigDecimal("selling_price"),
                rs.getBigDecimal("purchase_price"),
                rs.getBigDecimal("wholesale_price"),
                rs.getBigDecimal("stock_quantity"),
                rs.getBigDecimal("low_stock_threshold"),
                rs.getBigDecimal("gst_rate"),
                rs.getString("barcode"),
                rs.getString("hsn_code"),
                rs.getString("item_type"),
                rs.getLong("version"),
                rs.getTimestamp("updated_at").toInstant(),
                rs.getTimestamp("deleted_at") == null ? null : rs.getTimestamp("deleted_at").toInstant(),
                rs.getString("image_url")
            ), scopedQuery.params());
    }

    private boolean hasOrgBranchColumns() {
        try {
            Integer matchingColumns = jdbc.queryForObject("""
                SELECT COUNT(*)
                FROM information_schema.columns
                WHERE table_schema = 'app_core'
                  AND table_name = 'products'
                  AND column_name IN ('organization_id', 'branch_id')
                """, Integer.class);
            return matchingColumns != null && matchingColumns == 2;
        } catch (Exception ignored) {
            return false;
        }
    }

}
