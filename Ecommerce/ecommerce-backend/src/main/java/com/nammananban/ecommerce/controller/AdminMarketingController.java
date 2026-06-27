package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.AdminCouponRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.CampaignRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.service.EcAuthService;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.sql.Array;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ec/admin")
public class AdminMarketingController {
    private final JdbcTemplate jdbc;
    private final EcAuthService ecAuthService;

    public AdminMarketingController(JdbcTemplate jdbc, EcAuthService ecAuthService) {
        this.jdbc = jdbc;
        this.ecAuthService = ecAuthService;
    }

    // ── Coupons ──────────────────────────────────────────────────────────────

    @PostMapping("/coupons")
    public Map<String, Object> createCoupon(@Valid @RequestBody AdminCouponRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        UUID couponId = UUID.randomUUID();
        Array productsArray = toUuidArray(request.applicableProducts());
        Array categoriesArray = toUuidArray(request.applicableCategories());
        jdbc.update("""
                INSERT INTO app_core.ec_coupons
                    (server_id, tenant_id, storefront_id, code, discount_type, discount_value,
                     min_order_amount, max_discount_cap, usage_limit, per_customer_limit,
                     first_order_only, applicable_products, applicable_categories,
                     valid_from, valid_until, is_active, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::date, ?::date, true, now(), now())
                """,
                couponId, principal.tenantId(), request.storefrontId(),
                request.code().toUpperCase(), request.discountType(), request.discountValue(),
                request.minOrderAmount(), request.maxDiscountCap(), request.usageLimit(),
                request.perCustomerLimit(), request.firstOrderOnly(),
                productsArray, categoriesArray,
                request.validFrom(), request.validUntil());
        return Map.of("serverId", couponId, "code", request.code().toUpperCase(), "status", "created");
    }

    @GetMapping("/coupons")
    public List<Map<String, Object>> listCoupons() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return jdbc.queryForList("""
                SELECT server_id, code, discount_type, discount_value, min_order_amount,
                       usage_limit, usage_count, per_customer_limit, first_order_only,
                       valid_from, valid_until, is_active, created_at
                FROM app_core.ec_coupons
                WHERE tenant_id = ?
                ORDER BY created_at DESC
                """, principal.tenantId());
    }

    @DeleteMapping("/coupons/{id}")
    public Map<String, Object> deactivateCoupon(@PathVariable UUID id) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        jdbc.update("UPDATE app_core.ec_coupons SET is_active = false, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                id, principal.tenantId());
        return Map.of("status", "deactivated");
    }

    // ── Campaigns ─────────────────────────────────────────────────────────────

    @PostMapping("/campaigns")
    public Map<String, Object> createCampaign(@Valid @RequestBody CampaignRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        UUID campaignId = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO app_core.ec_campaigns
                    (server_id, tenant_id, storefront_id, name, banner, starts_at, ends_at, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?::date, ?::date, now(), now())
                """,
                campaignId, principal.tenantId(), request.storefrontId(),
                request.name(), request.banner(), request.startsAt(), request.endsAt());
        return Map.of("serverId", campaignId, "name", request.name(), "status", "created");
    }

    @GetMapping("/campaigns")
    public List<Map<String, Object>> listCampaigns() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return jdbc.queryForList("""
                SELECT server_id, name, banner, starts_at, ends_at,
                       impressions, clicks, orders_count, revenue, created_at
                FROM app_core.ec_campaigns
                WHERE tenant_id = ?
                ORDER BY starts_at DESC
                """, principal.tenantId());
    }

    @DeleteMapping("/campaigns/{id}")
    public Map<String, Object> deleteCampaign(@PathVariable UUID id) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        jdbc.update("DELETE FROM app_core.ec_campaigns WHERE server_id = ? AND tenant_id = ?",
                id, principal.tenantId());
        return Map.of("status", "deleted");
    }

    // ── Inventory low-stock ───────────────────────────────────────────────────

    @GetMapping("/inventory/low-stock")
    public List<Map<String, Object>> lowStock() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return jdbc.queryForList("""
                SELECT pl.server_id, pp.name, pl.stock_quantity, pl.low_stock_threshold,
                       COALESCE((
                           SELECT count(*) FROM app_core.ec_stock_alerts sa
                           WHERE sa.listing_id = pl.server_id AND sa.notified_at IS NULL
                       ), 0) AS waitlist_count
                FROM app_core.ec_product_listings pl
                JOIN app_core.ec_products pp ON pp.server_id = pl.product_id
                WHERE pl.tenant_id = ?
                  AND pl.stock_quantity <= pl.low_stock_threshold
                ORDER BY pl.stock_quantity ASC
                """, principal.tenantId());
    }

    @PostMapping("/inventory/{listingId}/back-in-stock")
    public Map<String, Object> markBackInStock(@PathVariable UUID listingId) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        jdbc.update("""
                UPDATE app_core.ec_product_listings
                SET stock_quantity = stock_quantity + 10, updated_at = now()
                WHERE server_id = ? AND tenant_id = ?
                """, listingId, principal.tenantId());
        return Map.of("status", "updated");
    }

    private Array toUuidArray(List<UUID> ids) {
        UUID[] arr = (ids == null) ? new UUID[0] : ids.toArray(new UUID[0]);
        return jdbc.execute((Connection con) -> {
            Array a = con.createArrayOf("uuid", arr);
            if (a == null) throw new SQLException("createArrayOf returned null");
            return a;
        });
    }
}
