package com.nammananban.ecommerce.service;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.QAAnswerRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.QAQuestionRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class ProductQAService {
    private final JdbcTemplate jdbc;

    public ProductQAService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Map<String, Object>> listForListing(UUID listingId, UUID tenantId) {
        if (tenantId == null) {
            // Resolve tenant from listing
            tenantId = jdbc.queryForObject(
                    "SELECT tenant_id FROM app_core.ec_product_listings WHERE server_id = ?",
                    UUID.class, listingId);
        }
        return jdbc.queryForList("""
                SELECT q.server_id, q.question, q.answer, q.answered_at, q.created_at,
                       COALESCE(c.first_name || ' ' || c.last_name, c.email) AS customer_name
                FROM app_core.ec_product_qa q
                LEFT JOIN app_core.ec_customers c ON c.server_id = q.ec_customer_id AND c.tenant_id = q.tenant_id
                WHERE q.listing_id = ? AND q.tenant_id = ? AND q.is_visible = TRUE
                ORDER BY q.created_at DESC
                """, listingId, tenantId);
    }

    @Transactional
    public Map<String, Object> askQuestion(QAQuestionRequest request, EcPrincipal principal) {
        UUID id = jdbc.queryForObject("""
                INSERT INTO app_core.ec_product_qa(server_id, tenant_id, listing_id, ec_customer_id, question, created_at, updated_at)
                VALUES (gen_random_uuid(), ?, ?, ?, ?, now(), now())
                RETURNING server_id
                """, UUID.class,
                principal.tenantId(), request.listingId(), principal.customerId(), request.question());
        return jdbc.queryForMap("SELECT * FROM app_core.ec_product_qa WHERE server_id = ? AND tenant_id = ?", id, principal.tenantId());
    }

    @Transactional
    public Map<String, Object> answerQuestion(UUID questionId, QAAnswerRequest request, UUID tenantId) {
        jdbc.update("""
                UPDATE app_core.ec_product_qa
                SET answer = ?, answered_at = now(), updated_at = now()
                WHERE server_id = ? AND tenant_id = ?
                """, request.answer(), questionId, tenantId);
        return jdbc.queryForMap("SELECT * FROM app_core.ec_product_qa WHERE server_id = ? AND tenant_id = ?", questionId, tenantId);
    }

    @Transactional
    public Map<String, Object> deleteQuestion(UUID questionId, UUID tenantId) {
        jdbc.update("UPDATE app_core.ec_product_qa SET is_visible = false, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                questionId, tenantId);
        return Map.of("status", "ok");
    }

    /** Returns all unanswered questions for admin view. */
    public List<Map<String, Object>> listUnanswered(UUID storefrontId, UUID tenantId) {
        return jdbc.queryForList("""
                SELECT q.server_id, q.listing_id, pl.name AS product_name, q.question, q.created_at,
                       COALESCE(c.first_name || ' ' || c.last_name, c.email) AS customer_name
                FROM app_core.ec_product_qa q
                JOIN app_core.ec_product_listings pl ON pl.server_id = q.listing_id AND pl.tenant_id = q.tenant_id
                LEFT JOIN app_core.ec_customers c ON c.server_id = q.ec_customer_id AND c.tenant_id = q.tenant_id
                WHERE pl.storefront_id = ? AND q.tenant_id = ? AND q.answer IS NULL AND q.is_visible = TRUE
                ORDER BY q.created_at ASC
                """, storefrontId, tenantId);
    }
}
