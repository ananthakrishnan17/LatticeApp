package com.nammananban.ecommerce.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nammananban.ecommerce.dto.EcommerceDtos.StoreEventRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class AnalyticsEventService {
    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public AnalyticsEventService(JdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    public void recordEvent(StoreEventRequest request, UUID customerId, UUID tenantId) {
        try {
            String metaJson = request.meta() != null ? objectMapper.writeValueAsString(request.meta()) : "{}";
            jdbc.update("""
                    INSERT INTO app_core.ec_storefront_events
                        (server_id, tenant_id, storefront_id, ec_customer_id, session_token, event_type, listing_id, order_id, meta, created_at)
                    VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, ?::jsonb, now())
                    """,
                    tenantId, request.storefrontId(), customerId, request.sessionToken(),
                    request.eventType(), request.listingId(), request.orderId(), metaJson);
        } catch (Exception e) {
            // Non-critical: swallow event recording errors
        }
    }

    /** Funnel metrics: view → cart_add → checkout_start → purchase (last 30 days). */
    public Map<String, Object> getFunnelMetrics(UUID storefrontId, UUID tenantId) {
        Map<String, Object> counts = new java.util.HashMap<>();
        for (String eventType : List.of("view", "cart_add", "checkout_start", "purchase")) {
            Long count = jdbc.queryForObject("""
                    SELECT count(*) FROM app_core.ec_storefront_events
                    WHERE storefront_id = ? AND tenant_id = ? AND event_type = ?
                      AND created_at > now() - interval '30 days'
                    """, Long.class, storefrontId, tenantId, eventType);
            counts.put(eventType, count == null ? 0L : count);
        }
        return counts;
    }

    /** Daily event counts for the last 14 days (chart data). */
    public List<Map<String, Object>> getDailyEvents(UUID storefrontId, UUID tenantId, String eventType) {
        return jdbc.queryForList("""
                SELECT date_trunc('day', created_at)::date AS day, count(*) AS count
                FROM app_core.ec_storefront_events
                WHERE storefront_id = ? AND tenant_id = ? AND event_type = ?
                  AND created_at > now() - interval '14 days'
                GROUP BY 1
                ORDER BY 1
                """, storefrontId, tenantId, eventType);
    }

    /**
     * Category conversion: view count vs purchase count per category (last 30 days).
     * Returns rows: { category_name, views, purchases, conversion_rate }.
     */
    public List<Map<String, Object>> getCategoryConversion(UUID storefrontId, UUID tenantId) {
        return jdbc.queryForList("""
                SELECT pc.name AS category_name,
                       count(DISTINCT CASE WHEN e.event_type = 'view' THEN e.server_id END)     AS views,
                       count(DISTINCT CASE WHEN e.event_type = 'purchase' THEN e.server_id END) AS purchases
                FROM app_core.ec_storefront_events e
                JOIN app_core.ec_product_listings pl ON pl.server_id = e.listing_id
                JOIN app_core.ec_product_categories pc ON pc.server_id = pl.category_id
                WHERE e.storefront_id = ? AND e.tenant_id = ?
                  AND e.created_at > now() - interval '30 days'
                GROUP BY pc.name
                ORDER BY views DESC
                LIMIT 20
                """, storefrontId, tenantId);
    }

    /**
     * Monthly cohort retention: for each calendar month cohort of new customers,
     * percentage who placed an order in month+1, month+2, month+3.
     */
    public List<Map<String, Object>> getCohortRetention(UUID storefrontId, UUID tenantId) {
        return jdbc.queryForList("""
                WITH cohort AS (
                    SELECT ec_customer_id,
                           date_trunc('month', min(created_at)) AS cohort_month
                    FROM app_core.ec_orders
                    WHERE storefront_id = ? AND tenant_id = ?
                    GROUP BY ec_customer_id
                ),
                orders AS (
                    SELECT o.ec_customer_id,
                           date_trunc('month', o.created_at) AS order_month
                    FROM app_core.ec_orders o
                    WHERE o.storefront_id = ? AND o.tenant_id = ?
                )
                SELECT to_char(c.cohort_month, 'Mon YYYY') AS cohort,
                       count(DISTINCT c.ec_customer_id) AS month1,
                       count(DISTINCT CASE WHEN o.order_month = c.cohort_month + interval '1 month' THEN o.ec_customer_id END) AS month2,
                       count(DISTINCT CASE WHEN o.order_month = c.cohort_month + interval '2 months' THEN o.ec_customer_id END) AS month3
                FROM cohort c
                LEFT JOIN orders o ON o.ec_customer_id = c.ec_customer_id
                WHERE c.cohort_month >= now() - interval '6 months'
                GROUP BY c.cohort_month
                ORDER BY c.cohort_month DESC
                LIMIT 6
                """, storefrontId, tenantId, storefrontId, tenantId);
    }
}
