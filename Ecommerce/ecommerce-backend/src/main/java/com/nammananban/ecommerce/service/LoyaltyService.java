package com.nammananban.ecommerce.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class LoyaltyService {
    private final JdbcTemplate jdbc;

    // Points policy: 1 point per ₹10 spent; 1 point = ₹0.10 on redemption; min redeem: 100 points
    private static final int POINTS_PER_RUPEE_DIVISOR = 10;
    private static final int MIN_REDEMPTION = 100;
    private static final double RUPEE_VALUE_PER_POINT = 0.10;

    public LoyaltyService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Map<String, Object> getBalance(UUID customerId, UUID tenantId) {
        Map<String, Object> row = jdbc.queryForMap("""
                SELECT loyalty_points, referral_code, referred_by_code FROM app_core.ec_customers
                WHERE server_id = ? AND tenant_id = ?
                """, customerId, tenantId);
        int points = ((Number) row.get("loyalty_points")).intValue();
        double rupeeValue = points * RUPEE_VALUE_PER_POINT;
        return Map.of(
                "points", points,
                "rupeeValue", String.format("%.2f", rupeeValue),
                "referralCode", row.getOrDefault("referral_code", ""),
                "referredByCode", row.getOrDefault("referred_by_code", "")
        );
    }

    public List<Map<String, Object>> getTransactions(UUID customerId, UUID tenantId) {
        return jdbc.queryForList("""
                SELECT server_id, points, type, description, order_id, created_at
                FROM app_core.ec_loyalty_transactions
                WHERE ec_customer_id = ? AND tenant_id = ?
                ORDER BY created_at DESC
                LIMIT 100
                """, customerId, tenantId);
    }

    @Transactional
    public Map<String, Object> earnPoints(UUID customerId, UUID tenantId, UUID orderId, long orderAmountPaise) {
        int points = (int) (orderAmountPaise / 100 / POINTS_PER_RUPEE_DIVISOR);
        if (points < 1) return Map.of("points", 0);
        jdbc.update("""
                INSERT INTO app_core.ec_loyalty_transactions(server_id, tenant_id, ec_customer_id, order_id, points, type, description, created_at)
                VALUES (gen_random_uuid(), ?, ?, ?, ?, 'earn', 'Earned on order', now())
                """, tenantId, customerId, orderId, points);
        jdbc.update("""
                UPDATE app_core.ec_customers SET loyalty_points = loyalty_points + ?, updated_at = now()
                WHERE server_id = ? AND tenant_id = ?
                """, points, customerId, tenantId);
        return Map.of("pointsEarned", points);
    }

    @Transactional
    public Map<String, Object> redeemPoints(UUID customerId, UUID tenantId, int points) {
        if (points < MIN_REDEMPTION) {
            throw new IllegalArgumentException("Minimum redemption is " + MIN_REDEMPTION + " points.");
        }
        Integer available = jdbc.queryForObject(
                "SELECT loyalty_points FROM app_core.ec_customers WHERE server_id = ? AND tenant_id = ?",
                Integer.class, customerId, tenantId);
        if (available == null || available < points) {
            throw new IllegalStateException("Insufficient loyalty points.");
        }
        double rupeeValue = points * RUPEE_VALUE_PER_POINT;
        jdbc.update("""
                INSERT INTO app_core.ec_loyalty_transactions(server_id, tenant_id, ec_customer_id, points, type, description, created_at)
                VALUES (gen_random_uuid(), ?, ?, ?, 'redeem', 'Redeemed for discount', now())
                """, tenantId, customerId, -points);
        jdbc.update("""
                UPDATE app_core.ec_customers SET loyalty_points = loyalty_points - ?, updated_at = now()
                WHERE server_id = ? AND tenant_id = ?
                """, points, customerId, tenantId);
        return Map.of("pointsRedeemed", points, "discountAmount", String.format("%.2f", rupeeValue));
    }

    @Transactional
    public Map<String, Object> generateReferralCode(UUID customerId, UUID tenantId) {
        String existing = jdbc.queryForObject(
                "SELECT referral_code FROM app_core.ec_customers WHERE server_id = ? AND tenant_id = ?",
                String.class, customerId, tenantId);
        if (existing != null && !existing.isBlank()) return Map.of("referralCode", existing);
        String code = "REF" + customerId.toString().replace("-", "").substring(0, 8).toUpperCase();
        jdbc.update("UPDATE app_core.ec_customers SET referral_code = ?, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                code, customerId, tenantId);
        return Map.of("referralCode", code);
    }

    @Transactional
    public Map<String, Object> applyReferralCode(UUID customerId, UUID tenantId, String code) {
        Integer referrerCount = jdbc.queryForObject(
                "SELECT COUNT(*) FROM app_core.ec_customers WHERE referral_code = ? AND tenant_id = ?",
                Integer.class, code, tenantId);
        if (referrerCount == null || referrerCount == 0) throw new IllegalArgumentException("Invalid referral code.");
        jdbc.update("UPDATE app_core.ec_customers SET referred_by_code = ?, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                code, customerId, tenantId);
        // Credit 50 bonus points to referrer
        jdbc.update("""
                UPDATE app_core.ec_customers SET loyalty_points = loyalty_points + 50, updated_at = now()
                WHERE referral_code = ? AND tenant_id = ?
                """, code, tenantId);
        jdbc.update("""
                INSERT INTO app_core.ec_loyalty_transactions(server_id, tenant_id, ec_customer_id, points, type, description, created_at)
                SELECT gen_random_uuid(), tenant_id, server_id, 50, 'referral', 'Referral bonus', now()
                FROM app_core.ec_customers WHERE referral_code = ? AND tenant_id = ?
                """, code, tenantId);
        // Credit 25 welcome points to new customer
        jdbc.update("UPDATE app_core.ec_customers SET loyalty_points = loyalty_points + 25, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                customerId, tenantId);
        jdbc.update("""
                INSERT INTO app_core.ec_loyalty_transactions(server_id, tenant_id, ec_customer_id, points, type, description, created_at)
                VALUES (gen_random_uuid(), ?, ?, 25, 'referral', 'Welcome bonus for referral sign-up', now())
                """, tenantId, customerId);
        return Map.of("status", "ok", "message", "Referral code applied. Bonus points credited.");
    }
}
