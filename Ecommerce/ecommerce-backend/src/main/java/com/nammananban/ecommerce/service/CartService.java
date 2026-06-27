package com.nammananban.ecommerce.service;

import com.nammananban.ecommerce.dto.EcommerceDtos.CartItemRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.CartItemUpdateRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.CouponRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.MergeCartRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class CartService {
    private final JdbcTemplate jdbc;
    private final CouponService couponService;

    public CartService(JdbcTemplate jdbc, CouponService couponService) {
        this.jdbc = jdbc;
        this.couponService = couponService;
    }

    public Map<String, Object> getCart(UUID storefrontId, String sessionToken, EcPrincipal principal) {
        ResolvedCart cart = resolveOrCreateCart(storefrontId, sessionToken, principal, true);
        return buildCartResponse(cart);
    }

    @Transactional
    public Map<String, Object> addItem(CartItemRequest request, EcPrincipal principal) {
        ResolvedCart cart = resolveOrCreateCart(request.storefrontId(), request.sessionToken(), principal, true);
        BigDecimal unitPrice = jdbc.queryForObject("""
                SELECT COALESCE(v.ec_price, l.ec_selling_price)
                FROM app_core.ec_product_listings l
                LEFT JOIN app_core.ec_product_variants v ON v.server_id = ? AND v.tenant_id = l.tenant_id
                WHERE l.server_id = ? AND l.tenant_id = ?
                """, BigDecimal.class, request.variantId(), request.listingId(), cart.tenantId());
        Integer updated = jdbc.update("""
                UPDATE app_core.ec_cart_items
                SET quantity = quantity + ?, unit_price = ?, updated_at = now()
                WHERE cart_id = ? AND listing_id = ? AND tenant_id = ?
                  AND ((variant_id IS NULL AND ? IS NULL) OR variant_id = ?)
                """, request.quantity(), unitPrice, cart.cartId(), request.listingId(), cart.tenantId(), request.variantId(), request.variantId());
        if (updated == 0) {
            jdbc.update("""
                    INSERT INTO app_core.ec_cart_items(server_id, tenant_id, cart_id, listing_id, variant_id, quantity, unit_price, created_at, updated_at)
                    VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, now(), now())
                    """, cart.tenantId(), cart.cartId(), request.listingId(), request.variantId(), request.quantity(), unitPrice);
        }
        touchCart(cart.cartId());
        return buildCartResponse(cart);
    }

    @Transactional
    public Map<String, Object> updateItem(UUID itemId, CartItemUpdateRequest request, EcPrincipal principal) {
        ResolvedCart cart = resolveOrCreateCart(request.storefrontId(), request.sessionToken(), principal, false);
        jdbc.update("UPDATE app_core.ec_cart_items SET quantity = ?, updated_at = now() WHERE server_id = ? AND tenant_id = ? AND cart_id = ?",
                request.quantity(), itemId, cart.tenantId(), cart.cartId());
        touchCart(cart.cartId());
        return buildCartResponse(cart);
    }

    @Transactional
    public Map<String, Object> removeItem(UUID itemId, UUID storefrontId, String sessionToken, EcPrincipal principal) {
        ResolvedCart cart = resolveOrCreateCart(storefrontId, sessionToken, principal, false);
        jdbc.update("DELETE FROM app_core.ec_cart_items WHERE server_id = ? AND tenant_id = ? AND cart_id = ?", itemId, cart.tenantId(), cart.cartId());
        touchCart(cart.cartId());
        return buildCartResponse(cart);
    }

    @Transactional
    public Map<String, Object> applyCoupon(CouponRequest request, EcPrincipal principal) {
        ResolvedCart cart = resolveOrCreateCart(request.storefrontId(), request.sessionToken(), principal, false);
        List<Map<String, Object>> items = cartItems(cart.cartId(), cart.tenantId());
        BigDecimal subtotal = subtotal(items);
        List<UUID> listingIds = items.stream().map(it -> (UUID) it.get("listing_id")).toList();
        UUID customerId = principal == null ? null : principal.customerId();
        CouponService.CouponEvaluation evaluation = couponService.validateCoupon(request.storefrontId(), request.code(), subtotal, listingIds, customerId);
        jdbc.update("""
                UPDATE app_core.ec_carts
                SET coupon_id = ?, coupon_code = ?, coupon_discount = ?, updated_at = now()
                WHERE server_id = ? AND tenant_id = ?
                """, evaluation.couponId(), evaluation.code(), evaluation.discount(), cart.cartId(), cart.tenantId());
        return buildCartResponse(cart);
    }

    @Transactional
    public Map<String, Object> removeCoupon(UUID storefrontId, String sessionToken, EcPrincipal principal) {
        ResolvedCart cart = resolveOrCreateCart(storefrontId, sessionToken, principal, false);
        jdbc.update("UPDATE app_core.ec_carts SET coupon_id = null, coupon_code = null, coupon_discount = 0, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                cart.cartId(), cart.tenantId());
        return buildCartResponse(cart);
    }

    @Transactional
    public Map<String, Object> merge( MergeCartRequest request, EcPrincipal principal) {
        ResolvedCart source = resolveOrCreateCart(request.storefrontId(), request.sourceSessionToken(), null, false);
        ResolvedCart target = resolveOrCreateCart(request.storefrontId(), request.targetSessionToken(), principal, true);
        List<Map<String, Object>> sourceItems = cartItems(source.cartId(), source.tenantId());
        for (Map<String, Object> item : sourceItems) {
            jdbc.update("""
                    INSERT INTO app_core.ec_cart_items(server_id, tenant_id, cart_id, listing_id, variant_id, quantity, unit_price, created_at, updated_at)
                    VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, now(), now())
                    ON CONFLICT DO NOTHING
                    """,
                    target.tenantId(), target.cartId(), item.get("listing_id"), item.get("variant_id"), item.get("quantity"), item.get("unit_price"));
        }
        jdbc.update("DELETE FROM app_core.ec_cart_items WHERE cart_id = ? AND tenant_id = ?", source.cartId(), source.tenantId());
        touchCart(target.cartId());
        return buildCartResponse(target);
    }

    public CartSnapshot snapshot(UUID storefrontId, String sessionToken, EcPrincipal principal) {
        ResolvedCart cart = resolveOrCreateCart(storefrontId, sessionToken, principal, false);
        List<Map<String, Object>> items = cartItems(cart.cartId(), cart.tenantId());
        Map<String, Object> meta = jdbc.queryForMap("SELECT coupon_id, coupon_code, coupon_discount FROM app_core.ec_carts WHERE server_id = ? AND tenant_id = ?", cart.cartId(), cart.tenantId());
        return new CartSnapshot(cart.cartId(), cart.tenantId(), cart.storefrontId(), cart.sessionToken(), cart.customerId(), items,
                subtotal(items), (BigDecimal) meta.get("coupon_discount"));
    }

    private Map<String, Object> buildCartResponse(ResolvedCart cart) {
        List<Map<String, Object>> items = cartItems(cart.cartId(), cart.tenantId());
        Map<String, Object> meta = jdbc.queryForMap("SELECT coupon_code, coupon_discount, expires_at FROM app_core.ec_carts WHERE server_id = ? AND tenant_id = ?", cart.cartId(), cart.tenantId());
        BigDecimal subtotal = subtotal(items);
        BigDecimal couponDiscount = (BigDecimal) meta.get("coupon_discount");
        BigDecimal total = subtotal.subtract(couponDiscount == null ? BigDecimal.ZERO : couponDiscount).setScale(2, RoundingMode.HALF_UP);
        java.util.LinkedHashMap<String, Object> response = new java.util.LinkedHashMap<>();
        response.put("cartId", cart.cartId());
        response.put("tenantId", cart.tenantId());
        response.put("storefrontId", cart.storefrontId());
        response.put("sessionToken", cart.sessionToken());
        response.put("customerId", cart.customerId());
        response.put("coupon", meta.get("coupon_code"));
        response.put("couponDiscount", couponDiscount == null ? BigDecimal.ZERO : couponDiscount);
        response.put("subtotal", subtotal);
        response.put("total", total);
        response.put("expiresAt", meta.get("expires_at"));
        response.put("items", items);
        return response;
    }

    private List<Map<String, Object>> cartItems(UUID cartId, UUID tenantId) {
        return jdbc.queryForList("""
                SELECT ci.server_id, ci.listing_id, ci.variant_id, ci.quantity, ci.unit_price,
                       p.name AS product_name, l.seo_slug,
                       COALESCE(v.variant_label, '') AS variant_label,
                       COALESCE((SELECT image_url FROM app_core.ec_product_images i WHERE i.listing_id = ci.listing_id ORDER BY is_primary DESC, sort_order ASC LIMIT 1), '') AS image_url
                FROM app_core.ec_cart_items ci
                JOIN app_core.ec_product_listings l ON l.server_id = ci.listing_id AND l.tenant_id = ci.tenant_id
                JOIN app_core.products p ON p.server_id = l.product_id
                LEFT JOIN app_core.ec_product_variants v ON v.server_id = ci.variant_id AND v.tenant_id = ci.tenant_id
                WHERE ci.cart_id = ? AND ci.tenant_id = ?
                ORDER BY ci.created_at ASC
                """, cartId, tenantId);
    }

    private BigDecimal subtotal(List<Map<String, Object>> items) {
        return items.stream()
                .map(item -> ((BigDecimal) item.get("unit_price")).multiply(BigDecimal.valueOf(((Number) item.get("quantity")).longValue())))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);
    }

    private ResolvedCart resolveOrCreateCart(UUID storefrontId, String sessionToken, EcPrincipal principal, boolean createIfMissing) {
        UUID customerId = principal == null ? null : principal.customerId();
        List<Map<String, Object>> rows;
        if (customerId != null) {
            rows = jdbc.queryForList("SELECT server_id, tenant_id, session_token, ec_customer_id FROM app_core.ec_carts WHERE storefront_id = ? AND ec_customer_id = ? ORDER BY updated_at DESC LIMIT 1",
                    storefrontId, customerId);
            if (!rows.isEmpty()) {
                Map<String, Object> row = rows.getFirst();
                return new ResolvedCart((UUID) row.get("server_id"), (UUID) row.get("tenant_id"), storefrontId, String.valueOf(row.get("session_token")), customerId);
            }
        }
        if (sessionToken != null && !sessionToken.isBlank()) {
            rows = jdbc.queryForList("SELECT server_id, tenant_id, storefront_id, ec_customer_id FROM app_core.ec_carts WHERE session_token = ? LIMIT 1", sessionToken);
            if (!rows.isEmpty()) {
                Map<String, Object> row = rows.getFirst();
                return new ResolvedCart((UUID) row.get("server_id"), (UUID) row.get("tenant_id"), (UUID) row.get("storefront_id"), sessionToken, (UUID) row.get("ec_customer_id"));
            }
        }
        if (!createIfMissing) {
            throw new IllegalArgumentException("Cart not found");
        }
        UUID tenantId = jdbc.queryForObject("SELECT tenant_id FROM app_core.ec_storefronts WHERE server_id = ?", UUID.class, storefrontId);
        String resolvedSession = sessionToken == null || sessionToken.isBlank() ? UUID.randomUUID().toString() : sessionToken;
        UUID cartId = jdbc.queryForObject("""
                INSERT INTO app_core.ec_carts(server_id, tenant_id, storefront_id, ec_customer_id, session_token, created_at, updated_at)
                VALUES (gen_random_uuid(), ?, ?, ?, ?, now(), now())
                RETURNING server_id
                """, UUID.class, tenantId, storefrontId, customerId, resolvedSession);
        return new ResolvedCart(cartId, tenantId, storefrontId, resolvedSession, customerId);
    }

    private void touchCart(UUID cartId) {
        jdbc.update("UPDATE app_core.ec_carts SET updated_at = now() WHERE server_id = ?", cartId);
    }

    public record CartSnapshot(UUID cartId, UUID tenantId, UUID storefrontId, String sessionToken, UUID customerId,
                               List<Map<String, Object>> items, BigDecimal subtotal, BigDecimal couponDiscount) {}

    private record ResolvedCart(UUID cartId, UUID tenantId, UUID storefrontId, String sessionToken, UUID customerId) {}
}
