package com.nammananban.ecommerce.service;

import com.nammananban.ecommerce.dto.EcommerceDtos.AdminListingRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.ImageReorderRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.PagedResponse;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class StorefrontService {
    private final JdbcTemplate jdbc;

    public StorefrontService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Map<String, Object> getStorefront(String slug) {
        return jdbc.queryForMap("""
                SELECT s.server_id, s.tenant_id, s.slug, s.custom_domain, s.store_name, s.theme_config,
                       s.logo, s.meta, s.is_active,
                       COALESCE((SELECT COUNT(*) FROM app_core.ec_product_listings l WHERE l.storefront_id = s.server_id), 0) AS listing_count
                FROM app_core.ec_storefronts s
                WHERE s.slug = ? AND s.is_active = true
                """, slug);
    }

    public PagedResponse getProducts(String slug, String category, String brand, BigDecimal minPrice,
                                     BigDecimal maxPrice, Boolean inStock, String sort, int page, int size) {
        StoreRef store = resolveStore(slug);
        StringBuilder where = new StringBuilder(" WHERE l.storefront_id = ? AND l.tenant_id = ? AND l.visibility = 'public' ");
        List<Object> params = new ArrayList<>();
        params.add(store.storefrontId());
        params.add(store.tenantId());
        if (category != null && !category.isBlank()) {
            where.append(" AND lower(c.name) = lower(?) ");
            params.add(category);
        }
        if (brand != null && !brand.isBlank()) {
            where.append(" AND lower(b.name) = lower(?) ");
            params.add(brand);
        }
        if (minPrice != null) {
            where.append(" AND l.ec_selling_price >= ? ");
            params.add(minPrice);
        }
        if (maxPrice != null) {
            where.append(" AND l.ec_selling_price <= ? ");
            params.add(maxPrice);
        }
        if (Boolean.TRUE.equals(inStock)) {
            where.append(" AND COALESCE(v.stock_override, p.stock_quantity) > 0 ");
        }
        String orderBy = switch (sort == null ? "latest" : sort) {
            case "price-asc" -> " ORDER BY l.ec_selling_price ASC ";
            case "price-desc" -> " ORDER BY l.ec_selling_price DESC ";
            case "name" -> " ORDER BY p.name ASC ";
            default -> " ORDER BY l.updated_at DESC ";
        };
        Long total = jdbc.queryForObject(
                "SELECT COUNT(DISTINCT l.server_id) FROM app_core.ec_product_listings l " +
                        "JOIN app_core.products p ON p.server_id = l.product_id " +
                        "LEFT JOIN app_core.categories c ON c.server_id = p.category_id " +
                        "LEFT JOIN app_core.brands b ON b.server_id = p.brand_id " +
                        "LEFT JOIN app_core.ec_product_variants v ON v.listing_id = l.server_id AND v.tenant_id = l.tenant_id " +
                        where,
                Long.class,
                params.toArray()
        );
        List<Object> itemParams = new ArrayList<>(params);
        itemParams.add(size);
        itemParams.add(Math.max(page, 0) * size);
        List<Map<String, Object>> items = jdbc.queryForList(
                "SELECT DISTINCT l.server_id, l.seo_slug, p.name, p.hsn_code, p.unit, l.ec_selling_price, l.ec_compare_price, " +
                        "COALESCE((SELECT image_url FROM app_core.ec_product_images i WHERE i.listing_id = l.server_id AND i.is_primary = true ORDER BY sort_order ASC LIMIT 1), " +
                        "         (SELECT image_url FROM app_core.ec_product_images i WHERE i.listing_id = l.server_id ORDER BY sort_order ASC LIMIT 1)) AS primary_image, " +
                        "c.name AS category_name, b.name AS brand_name, COALESCE(v.stock_override, p.stock_quantity) AS stock_quantity, " +
                        "l.low_stock_threshold, " +
                        "CASE WHEN COALESCE(v.stock_override, p.stock_quantity) <= COALESCE(l.low_stock_threshold, 5) AND COALESCE(v.stock_override, p.stock_quantity) > 0 THEN true ELSE false END AS is_low_stock " +
                        "FROM app_core.ec_product_listings l " +
                        "JOIN app_core.products p ON p.server_id = l.product_id " +
                        "LEFT JOIN app_core.categories c ON c.server_id = p.category_id " +
                        "LEFT JOIN app_core.brands b ON b.server_id = p.brand_id " +
                        "LEFT JOIN LATERAL (SELECT stock_override FROM app_core.ec_product_variants v WHERE v.listing_id = l.server_id AND v.tenant_id = l.tenant_id ORDER BY created_at ASC LIMIT 1) v ON true " +
                        where + orderBy + " LIMIT ? OFFSET ?",
                itemParams.toArray()
        );
        return new PagedResponse(items, total == null ? 0L : total, page, size);
    }

    public Map<String, Object> getProductDetail(String slug, String productSlug) {
        StoreRef store = resolveStore(slug);
        Map<String, Object> product = jdbc.queryForMap("""
                SELECT l.server_id, l.tenant_id, l.storefront_id, l.product_id, l.seo_slug, l.tags, l.visibility,
                       l.ec_selling_price, l.ec_compare_price, l.low_stock_threshold, p.name, p.barcode, p.hsn_code, p.unit,
                       p.stock_quantity, p.gst_rate, c.name AS category_name, b.name AS brand_name,
                       CASE WHEN p.stock_quantity <= COALESCE(l.low_stock_threshold, 5) AND p.stock_quantity > 0 THEN true ELSE false END AS is_low_stock
                FROM app_core.ec_product_listings l
                JOIN app_core.products p ON p.server_id = l.product_id
                LEFT JOIN app_core.categories c ON c.server_id = p.category_id
                LEFT JOIN app_core.brands b ON b.server_id = p.brand_id
                WHERE l.storefront_id = ? AND l.tenant_id = ? AND l.seo_slug = ?
                """, store.storefrontId(), store.tenantId(), productSlug);
        UUID listingId = (UUID) product.get("server_id");
        List<Map<String, Object>> images = jdbc.queryForList("""
                SELECT server_id, image_url, sort_order, is_primary
                FROM app_core.ec_product_images
                WHERE listing_id = ? AND tenant_id = ?
                ORDER BY is_primary DESC, sort_order ASC, created_at ASC
                """, listingId, store.tenantId());
        List<Map<String, Object>> variants = jdbc.queryForList("""
                SELECT server_id, variant_label, sku, ec_price, stock_override, created_at, updated_at
                FROM app_core.ec_product_variants
                WHERE listing_id = ? AND tenant_id = ?
                ORDER BY created_at ASC
                """, listingId, store.tenantId());
        List<Map<String, Object>> reviews = jdbc.queryForList("""
                SELECT r.server_id, r.rating, r.title, r.body, r.helpful_votes, r.created_at,
                       COALESCE(ec.first_name || ' ' || ec.last_name, ec.email) AS customer_name
                FROM app_core.ec_reviews r
                JOIN app_core.ec_customers ec ON ec.server_id = r.ec_customer_id AND ec.tenant_id = r.tenant_id
                WHERE r.listing_id = ? AND r.tenant_id = ? AND r.status = 'approved'
                ORDER BY r.created_at DESC
                LIMIT 20
                """, listingId, store.tenantId());
        product.put("images", images);
        product.put("variants", variants);
        product.put("reviews", reviews);
        return product;
    }

    public List<Map<String, Object>> getCategories(String slug) {
        StoreRef store = resolveStore(slug);
        return jdbc.queryForList("""
                SELECT c.server_id, c.name, COUNT(*) AS product_count
                FROM app_core.ec_product_listings l
                JOIN app_core.products p ON p.server_id = l.product_id
                JOIN app_core.categories c ON c.server_id = p.category_id
                WHERE l.storefront_id = ? AND l.tenant_id = ? AND l.visibility = 'public'
                GROUP BY c.server_id, c.name
                ORDER BY c.name ASC
                """, store.storefrontId(), store.tenantId());
    }

    public List<Map<String, Object>> searchProducts(String slug, String query) {
        StoreRef store = resolveStore(slug);
        String like = "%" + query.trim() + "%";
        return jdbc.queryForList("""
                SELECT l.server_id, l.seo_slug, p.name, l.ec_selling_price,
                       COALESCE((SELECT image_url FROM app_core.ec_product_images i WHERE i.listing_id = l.server_id ORDER BY is_primary DESC, sort_order ASC LIMIT 1), '') AS primary_image
                FROM app_core.ec_product_listings l
                JOIN app_core.products p ON p.server_id = l.product_id
                WHERE l.storefront_id = ?
                  AND l.tenant_id = ?
                  AND l.visibility = 'public'
                  AND (p.name ILIKE ? OR l.seo_slug ILIKE ? OR EXISTS (
                        SELECT 1 FROM unnest(COALESCE(l.tags, ARRAY[]::text[])) tag WHERE tag ILIKE ?
                  ))
                ORDER BY p.name ASC
                LIMIT 25
                """, store.storefrontId(), store.tenantId(), like, like, like);
    }

    public List<Map<String, Object>> getBanners(String slug) {
        StoreRef store = resolveStore(slug);
        return jdbc.queryForList("""
                SELECT server_id, image_url, position, valid_from, valid_until, cta_url, is_active, sort_order
                FROM app_core.ec_banners
                WHERE storefront_id = ? AND tenant_id = ? AND is_active = true
                  AND (valid_from IS NULL OR valid_from <= now())
                  AND (valid_until IS NULL OR valid_until >= now())
                ORDER BY sort_order ASC, created_at DESC
                """, store.storefrontId(), store.tenantId());
    }

    public Map<String, Object> checkPincode(String slug, String pincode) {
        StoreRef store = resolveStore(slug);
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT extra_shipping_charge
                FROM app_core.ec_serviceable_pincodes
                WHERE storefront_id = ? AND tenant_id = ? AND pincode = ?
                LIMIT 1
                """, store.storefrontId(), store.tenantId(), pincode);
        if (rows.isEmpty()) {
            return Map.of("serviceable", false, "pincode", pincode, "extraShippingCharge", BigDecimal.ZERO);
        }
        return Map.of("serviceable", true, "pincode", pincode, "extraShippingCharge", rows.getFirst().get("extra_shipping_charge"));
    }

    public PagedResponse listAdminListings(UUID tenantId, UUID storefrontId, int page, int size) {
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM app_core.ec_product_listings WHERE tenant_id = ? AND storefront_id = ?", Long.class, tenantId, storefrontId);
        List<Map<String, Object>> items = jdbc.queryForList("""
                SELECT l.server_id, l.seo_slug, l.ec_selling_price, l.ec_compare_price, l.tags, l.visibility,
                       p.name AS product_name, c.name AS category_name, b.name AS brand_name
                FROM app_core.ec_product_listings l
                JOIN app_core.products p ON p.server_id = l.product_id
                LEFT JOIN app_core.categories c ON c.server_id = p.category_id
                LEFT JOIN app_core.brands b ON b.server_id = p.brand_id
                WHERE l.tenant_id = ? AND l.storefront_id = ?
                ORDER BY l.updated_at DESC
                LIMIT ? OFFSET ?
                """, tenantId, storefrontId, size, Math.max(page, 0) * size);
        return new PagedResponse(items, total == null ? 0L : total, page, size);
    }

    @Transactional
    public Map<String, Object> upsertListing(AdminListingRequest request) {
        UUID listingId;
        if (request.serverId() == null) {
            listingId = jdbc.queryForObject("""
                    INSERT INTO app_core.ec_product_listings(
                        server_id, tenant_id, storefront_id, product_id, ec_selling_price, ec_compare_price, seo_slug, tags, visibility, created_at, updated_at
                    ) VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?::text[], ?, now(), now())
                    RETURNING server_id
                    """, UUID.class,
                    request.tenantId(), request.storefrontId(), request.productId(), request.sellingPrice(), request.comparePrice(),
                    request.seoSlug(), request.tags() == null ? new String[]{} : request.tags().toArray(String[]::new),
                    request.visibility() == null ? "public" : request.visibility());
        } else {
            listingId = request.serverId();
            jdbc.update("""
                    UPDATE app_core.ec_product_listings
                    SET product_id = ?, ec_selling_price = ?, ec_compare_price = ?, seo_slug = ?, tags = ?::text[], visibility = ?, updated_at = now()
                    WHERE server_id = ? AND tenant_id = ? AND storefront_id = ?
                    """,
                    request.productId(), request.sellingPrice(), request.comparePrice(), request.seoSlug(),
                    request.tags() == null ? new String[]{} : request.tags().toArray(String[]::new),
                    request.visibility() == null ? "public" : request.visibility(),
                    listingId, request.tenantId(), request.storefrontId());
        }
        return jdbc.queryForMap("SELECT * FROM app_core.ec_product_listings WHERE server_id = ? AND tenant_id = ?", listingId, request.tenantId());
    }

    @Transactional
    public Map<String, Object> addImages(UUID tenantId, UUID listingId, List<String> imageUrls) {
        int sortOrder = 0;
        for (String imageUrl : imageUrls) {
            jdbc.update("""
                    INSERT INTO app_core.ec_product_images(server_id, tenant_id, listing_id, image_url, sort_order, is_primary, created_at)
                    VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, now())
                    """, tenantId, listingId, imageUrl, sortOrder++, sortOrder == 1);
        }
        return Map.of("status", "ok", "listingId", listingId, "uploaded", imageUrls.size());
    }

    @Transactional
    public Map<String, Object> reorderImages(UUID tenantId, UUID listingId, ImageReorderRequest request) {
        for (var item : request.items()) {
            jdbc.update("""
                    UPDATE app_core.ec_product_images
                    SET sort_order = ?, is_primary = ?
                    WHERE server_id = ? AND tenant_id = ? AND listing_id = ?
                    """, item.sortOrder(), item.primary(), item.imageId(), tenantId, listingId);
        }
        return Map.of("status", "ok", "listingId", listingId, "updated", request.items().size());
    }

    @Transactional
    public void deleteListing(UUID tenantId, UUID listingId) {
        jdbc.update("DELETE FROM app_core.ec_product_images WHERE listing_id = ? AND tenant_id = ?", listingId, tenantId);
        jdbc.update("DELETE FROM app_core.ec_product_variants WHERE listing_id = ? AND tenant_id = ?", listingId, tenantId);
        jdbc.update("DELETE FROM app_core.ec_product_listings WHERE server_id = ? AND tenant_id = ?", listingId, tenantId);
    }

    private StoreRef resolveStore(String slug) {
        try {
            return jdbc.queryForObject("SELECT server_id, tenant_id FROM app_core.ec_storefronts WHERE slug = ? AND is_active = true", (rs, rowNum) ->
                    new StoreRef(rs.getObject("server_id", UUID.class), rs.getObject("tenant_id", UUID.class)), slug);
        } catch (EmptyResultDataAccessException ex) {
            throw new IllegalArgumentException("Storefront not found: " + slug);
        }
    }

    private record StoreRef(UUID storefrontId, UUID tenantId) {}
}
