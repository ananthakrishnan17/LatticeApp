package com.nammananban.ecommerce.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Array;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class CouponService {
    private final JdbcTemplate jdbc;

    public CouponService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public CouponEvaluation validateCoupon(UUID storefrontId, String code, BigDecimal subtotal,
                                            List<UUID> listingIds, UUID customerId) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT server_id, tenant_id, discount_type, discount_value, min_order_amount, max_discount_cap,
                       usage_limit, usage_count, applicable_products, first_order_only, per_customer_limit
                FROM app_core.ec_coupons
                WHERE storefront_id = ?
                  AND code = ?
                  AND is_active = true
                  AND (valid_from IS NULL OR valid_from <= now())
                  AND (valid_until IS NULL OR valid_until >= now())
                LIMIT 1
                """, storefrontId, code);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Coupon not found or inactive");
        }
        Map<String, Object> row = rows.getFirst();
        Integer usageLimit = (Integer) row.get("usage_limit");
        Integer usageCount = (Integer) row.get("usage_count");
        BigDecimal minOrderAmount = (BigDecimal) row.get("min_order_amount");
        if (usageLimit != null && usageCount != null && usageCount >= usageLimit) {
            throw new IllegalArgumentException("Coupon usage limit reached");
        }
        if (subtotal.compareTo(minOrderAmount == null ? BigDecimal.ZERO : minOrderAmount) < 0) {
            throw new IllegalArgumentException("Cart total does not meet coupon minimum");
        }
        // First-order-only check
        Boolean firstOrderOnly = (Boolean) row.get("first_order_only");
        if (Boolean.TRUE.equals(firstOrderOnly) && customerId != null) {
            Integer priorOrders = jdbc.queryForObject(
                    "SELECT count(*) FROM app_core.ec_orders WHERE ec_customer_id = ? AND tenant_id = ?",
                    Integer.class, customerId, row.get("tenant_id"));
            if (priorOrders != null && priorOrders > 0) {
                throw new IllegalArgumentException("Coupon is valid only for first-time orders");
            }
        }
        // Per-customer usage cap
        Integer perCustomerLimit = (Integer) row.get("per_customer_limit");
        if (perCustomerLimit != null && customerId != null) {
            Integer customerUsage = jdbc.queryForObject(
                    "SELECT count(*) FROM app_core.ec_coupon_usages WHERE coupon_id = ? AND ec_customer_id = ?",
                    Integer.class, row.get("server_id"), customerId);
            if (customerUsage != null && customerUsage >= perCustomerLimit) {
                throw new IllegalArgumentException("You have already used this coupon the maximum number of times");
            }
        }
        Object applicableRaw = row.get("applicable_products");
        List<UUID> applicableProducts = toUuidList(applicableRaw);
        if (!applicableProducts.isEmpty() && listingIds.stream().noneMatch(applicableProducts::contains)) {
            throw new IllegalArgumentException("Coupon does not apply to selected items");
        }
        BigDecimal discountValue = (BigDecimal) row.get("discount_value");
        BigDecimal discount;
        String discountType = String.valueOf(row.get("discount_type"));
        if ("percentage".equalsIgnoreCase(discountType)) {
            discount = subtotal.multiply(discountValue).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        } else {
            discount = discountValue;
        }
        BigDecimal maxCap = (BigDecimal) row.get("max_discount_cap");
        if (maxCap != null && discount.compareTo(maxCap) > 0) {
            discount = maxCap;
        }
        if (discount.compareTo(subtotal) > 0) {
            discount = subtotal;
        }
        return new CouponEvaluation(
                (UUID) row.get("server_id"),
                (UUID) row.get("tenant_id"),
                code,
                discount.setScale(2, RoundingMode.HALF_UP)
        );
    }

    private List<UUID> toUuidList(Object raw) {
        try {
            if (raw == null) {
                return List.of();
            }
            Object arrayValue = raw instanceof Array sqlArray ? sqlArray.getArray() : raw;
            if (arrayValue instanceof UUID[] uuids) {
                return List.of(uuids);
            }
            if (arrayValue instanceof Object[] objects) {
                return java.util.Arrays.stream(objects).map(String::valueOf).map(UUID::fromString).toList();
            }
        } catch (Exception ignored) {
            return List.of();
        }
        return List.of();
    }

    public record CouponEvaluation(UUID couponId, UUID tenantId, String code, BigDecimal discount) {}
}
