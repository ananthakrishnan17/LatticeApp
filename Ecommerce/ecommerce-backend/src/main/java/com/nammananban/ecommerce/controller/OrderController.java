package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.CancelOrderRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.CartItemRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.ReturnRequest;
import com.nammananban.ecommerce.service.CartService;
import com.nammananban.ecommerce.service.CheckoutService;
import com.nammananban.ecommerce.service.EcAuthService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
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
@RequestMapping("/ec/orders")
public class OrderController {
    private static final Logger log = LoggerFactory.getLogger(OrderController.class);
    private final JdbcTemplate jdbc;
    private final CheckoutService checkoutService;
    private final EcAuthService ecAuthService;
    private final CartService cartService;

    public OrderController(JdbcTemplate jdbc, CheckoutService checkoutService, EcAuthService ecAuthService,
                           CartService cartService) {
        this.jdbc = jdbc;
        this.checkoutService = checkoutService;
        this.ecAuthService = ecAuthService;
        this.cartService = cartService;
    }

    @GetMapping
    public List<Map<String, Object>> listOrders() {
        return checkoutService.listOrders(ecAuthService.requirePrincipal());
    }

    @GetMapping("/{number}")
    public Map<String, Object> orderDetail(@PathVariable String number) {
        return checkoutService.orderDetail(number, ecAuthService.requirePrincipal());
    }

    @PostMapping("/{id}/cancel")
    public Map<String, Object> cancel(@PathVariable UUID id, @Valid @RequestBody(required = false) CancelOrderRequest request) {
        return checkoutService.cancelOrder(id, ecAuthService.requirePrincipal(), request == null ? null : request.reason());
    }

    @PostMapping("/{id}/return-request")
    public Map<String, Object> returnRequest(@PathVariable UUID id, @Valid @RequestBody(required = false) ReturnRequest request) {
        return checkoutService.returnRequest(id, ecAuthService.requirePrincipal(), request == null ? null : request.reason());
    }

    /** Reorder: copy all items from a previous order into the active cart. */
    @PostMapping("/{id}/reorder")
    public Map<String, Object> reorder(@PathVariable UUID id) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        // Fetch items from the original order
        List<Map<String, Object>> items = jdbc.queryForList("""
                SELECT oi.listing_id, oi.variant_id, oi.quantity,
                       pl.storefront_id
                FROM app_core.ec_order_items oi
                JOIN app_core.ec_orders o ON o.server_id = oi.order_id
                JOIN app_core.ec_product_listings pl ON pl.server_id = oi.listing_id
                WHERE o.server_id = ? AND o.tenant_id = ? AND o.ec_customer_id = ?
                """, id, principal.tenantId(), principal.customerId());
        if (items.isEmpty()) {
            return Map.of("status", "no_items", "message", "Order not found or has no items.");
        }
        UUID storefrontId = (UUID) items.getFirst().get("storefront_id");
        int added = 0;
        for (Map<String, Object> item : items) {
            try {
                CartItemRequest req = new CartItemRequest(
                        storefrontId,
                        (UUID) item.get("listing_id"),
                        (UUID) item.get("variant_id"),
                        ((Number) item.get("quantity")).intValue(),
                        null
                );
                cartService.addItem(req, principal);
                added++;
            } catch (Exception e) {
                log.warn("Skipping reorder item listing={} — {}", item.get("listing_id"), e.getMessage());
            }
        }
        return Map.of("status", "ok", "itemsAdded", added);
    }
}
