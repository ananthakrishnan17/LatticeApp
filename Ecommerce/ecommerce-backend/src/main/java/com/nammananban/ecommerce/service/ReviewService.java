package com.nammananban.ecommerce.service;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.ReviewSubmitRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class ReviewService {
    private final JdbcTemplate jdbc;

    public ReviewService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional
    public Map<String, Object> submit(ReviewSubmitRequest request, EcPrincipal principal) {
        Integer purchased = jdbc.queryForObject("""
                SELECT COUNT(*)
                FROM app_core.ec_orders o
                JOIN app_core.ec_order_items oi ON oi.order_id = o.server_id AND oi.tenant_id = o.tenant_id
                WHERE o.server_id = ?
                  AND o.tenant_id = ?
                  AND o.ec_customer_id = ?
                  AND oi.listing_id = ?
                  AND o.status IN ('confirmed', 'delivered')
                """, Integer.class, request.orderId(), principal.tenantId(), principal.customerId(), request.listingId());
        if (purchased == null || purchased == 0) {
            throw new IllegalArgumentException("Review allowed only for verified purchases");
        }
        jdbc.update("""
                INSERT INTO app_core.ec_reviews(
                    server_id, tenant_id, listing_id, ec_customer_id, order_id, rating, title, body,
                    is_verified_purchase, status, created_at, updated_at
                ) VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, true, 'pending', now(), now())
                ON CONFLICT (listing_id, ec_customer_id, order_id)
                DO UPDATE SET rating = excluded.rating, title = excluded.title, body = excluded.body, updated_at = now()
                """, principal.tenantId(), request.listingId(), principal.customerId(), request.orderId(),
                request.rating(), request.title(), request.body());
        return Map.of("status", "submitted");
    }

    public List<Map<String, Object>> getByListing(UUID listingId) {
        return jdbc.queryForList("""
                SELECT r.server_id, r.rating, r.title, r.body, r.helpful_votes, r.is_verified_purchase, r.created_at,
                       COALESCE(ec.first_name || ' ' || ec.last_name, ec.email) AS customer_name
                FROM app_core.ec_reviews r
                JOIN app_core.ec_customers ec ON ec.server_id = r.ec_customer_id AND ec.tenant_id = r.tenant_id
                WHERE r.listing_id = ? AND r.status = 'approved'
                ORDER BY r.created_at DESC
                """, listingId);
    }
}
