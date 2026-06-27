package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.WishlistRequest;
import com.nammananban.ecommerce.service.EcAuthService;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ec/wishlist")
public class WishlistController {
    private final JdbcTemplate jdbc;
    private final EcAuthService ecAuthService;

    public WishlistController(JdbcTemplate jdbc, EcAuthService ecAuthService) {
        this.jdbc = jdbc;
        this.ecAuthService = ecAuthService;
    }

    @GetMapping
    public List<Map<String, Object>> list() {
        var principal = ecAuthService.requirePrincipal();
        return jdbc.queryForList("""
                SELECT w.server_id, w.created_at, l.server_id AS listing_id, l.seo_slug, p.name, l.ec_selling_price
                FROM app_core.ec_wishlists w
                JOIN app_core.ec_product_listings l ON l.server_id = w.listing_id AND l.tenant_id = w.tenant_id
                JOIN app_core.products p ON p.server_id = l.product_id
                WHERE w.ec_customer_id = ? AND w.tenant_id = ?
                ORDER BY w.created_at DESC
                """, principal.customerId(), principal.tenantId());
    }

    @PostMapping
    @Transactional
    public Map<String, Object> add(@Valid @RequestBody WishlistRequest request) {
        var principal = ecAuthService.requirePrincipal();
        jdbc.update("""
                INSERT INTO app_core.ec_wishlists(server_id, tenant_id, ec_customer_id, listing_id, created_at)
                VALUES (gen_random_uuid(), ?, ?, ?, now())
                ON CONFLICT (ec_customer_id, listing_id) DO NOTHING
                """, principal.tenantId(), principal.customerId(), request.listingId());
        return Map.of("status", "ok");
    }

    @DeleteMapping("/{id}")
    @Transactional
    public Map<String, Object> remove(@PathVariable UUID id) {
        var principal = ecAuthService.requirePrincipal();
        jdbc.update("DELETE FROM app_core.ec_wishlists WHERE server_id = ? AND tenant_id = ? AND ec_customer_id = ?",
                id, principal.tenantId(), principal.customerId());
        return Map.of("status", "deleted");
    }
}
