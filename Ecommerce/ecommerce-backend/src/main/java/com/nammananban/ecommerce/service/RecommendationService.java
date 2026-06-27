package com.nammananban.ecommerce.service;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class RecommendationService {
    private final JdbcTemplate jdbc;

    public RecommendationService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Map<String, Object>> getRelatedByProductSlug(String storeSlug, String productSlug, int limit) {
        StoreRef store = resolveStore(storeSlug);
        UUID listingId = jdbc.queryForObject(
                "SELECT server_id FROM app_core.ec_product_listings WHERE storefront_id = ? AND tenant_id = ? AND seo_slug = ?",
                UUID.class, store.storefrontId(), store.tenantId(), productSlug);
        if (listingId == null) return List.of();
        return getRelatedProducts(store.storefrontId(), store.tenantId(), listingId, limit);
    }

    public List<Map<String, Object>> getTrendingByStoreSlug(String storeSlug, int limit) {
        StoreRef store = resolveStore(storeSlug);
        return getTrendingProducts(store.storefrontId(), store.tenantId(), limit);
    }

    /** Products in the same category (by shared tags), excluding the current listing. */
    public List<Map<String, Object>> getRelatedProducts(UUID storefrontId, UUID tenantId, UUID listingId, int limit) {
        return jdbc.queryForList("""
                SELECT pl.server_id, pl.seo_slug AS slug, p.name, pl.ec_selling_price,
                       pl.ec_compare_price, pl.tags, p.stock_quantity, pl.low_stock_threshold,
                       (SELECT image_url FROM app_core.ec_product_images i
                        WHERE i.listing_id = pl.server_id AND i.tenant_id = pl.tenant_id AND i.is_primary
                        ORDER BY i.sort_order LIMIT 1) AS primary_image
                FROM app_core.ec_product_listings pl
                JOIN app_core.products p ON p.server_id = pl.product_id
                WHERE pl.storefront_id = ?
                  AND pl.tenant_id = ?
                  AND pl.server_id <> ?
                  AND EXISTS (
                      SELECT 1 FROM unnest(pl.tags) t(tag)
                      WHERE tag IN (SELECT unnest(tags) FROM app_core.ec_product_listings WHERE server_id = ? AND tenant_id = ?)
                  )
                ORDER BY random()
                LIMIT ?
                """, storefrontId, tenantId, listingId, listingId, tenantId, limit);
    }

    /** Top-viewed products from analytics events (last 30 days). */
    public List<Map<String, Object>> getTrendingProducts(UUID storefrontId, UUID tenantId, int limit) {
        return jdbc.queryForList("""
                SELECT pl.server_id, pl.seo_slug AS slug, p.name, pl.ec_selling_price,
                       pl.ec_compare_price, p.stock_quantity, pl.low_stock_threshold,
                       count(ev.server_id) AS view_count,
                       (SELECT image_url FROM app_core.ec_product_images i
                        WHERE i.listing_id = pl.server_id AND i.tenant_id = pl.tenant_id AND i.is_primary
                        ORDER BY i.sort_order LIMIT 1) AS primary_image
                FROM app_core.ec_product_listings pl
                JOIN app_core.products p ON p.server_id = pl.product_id
                LEFT JOIN app_core.ec_storefront_events ev
                  ON ev.listing_id = pl.server_id AND ev.event_type = 'view'
                     AND ev.created_at > now() - interval '30 days'
                WHERE pl.storefront_id = ?
                  AND pl.tenant_id = ?
                GROUP BY pl.server_id, p.name, p.stock_quantity
                ORDER BY view_count DESC, pl.created_at DESC
                LIMIT ?
                """, storefrontId, tenantId, limit);
    }

    /** Products recently viewed by a customer (from analytics events). */
    public List<Map<String, Object>> getRecentlyViewed(UUID customerId, UUID storefrontId, UUID tenantId, int limit) {
        return jdbc.queryForList("""
                SELECT DISTINCT ON (pl.server_id)
                       pl.server_id, pl.seo_slug AS slug, p.name, pl.ec_selling_price,
                       pl.ec_compare_price, p.stock_quantity, pl.low_stock_threshold,
                       ev.created_at AS last_viewed,
                       (SELECT image_url FROM app_core.ec_product_images i
                        WHERE i.listing_id = pl.server_id AND i.tenant_id = pl.tenant_id AND i.is_primary
                        ORDER BY i.sort_order LIMIT 1) AS primary_image
                FROM app_core.ec_storefront_events ev
                JOIN app_core.ec_product_listings pl
                  ON pl.server_id = ev.listing_id AND pl.tenant_id = ev.tenant_id
                JOIN app_core.products p ON p.server_id = pl.product_id
                WHERE ev.ec_customer_id = ?
                  AND ev.storefront_id = ?
                  AND ev.tenant_id = ?
                  AND ev.event_type = 'view'
                ORDER BY pl.server_id, ev.created_at DESC
                LIMIT ?
                """, customerId, storefrontId, tenantId, limit);
    }

    /** Top search terms (last 30 days). */
    public List<Map<String, Object>> getTopSearchTerms(UUID storefrontId, UUID tenantId, int limit) {
        return jdbc.queryForList("""
                SELECT meta->>'query' AS query, count(*) AS count
                FROM app_core.ec_storefront_events
                WHERE storefront_id = ?
                  AND tenant_id = ?
                  AND event_type = 'search'
                  AND meta->>'query' IS NOT NULL
                  AND created_at > now() - interval '30 days'
                GROUP BY meta->>'query'
                ORDER BY count DESC
                LIMIT ?
                """, storefrontId, tenantId, limit);
    }

    private StoreRef resolveStore(String slug) {
        try {
            return jdbc.queryForObject(
                    "SELECT server_id, tenant_id FROM app_core.ec_storefronts WHERE slug = ? AND is_active = true",
                    (rs, rowNum) -> new StoreRef(
                            rs.getObject("server_id", UUID.class),
                            rs.getObject("tenant_id", UUID.class)), slug);
        } catch (EmptyResultDataAccessException ex) {
            throw new IllegalArgumentException("Storefront not found: " + slug);
        }
    }

    private record StoreRef(UUID storefrontId, UUID tenantId) {}
}
