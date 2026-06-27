package com.nammananban.ecommerce.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nammananban.ecommerce.dto.EcommerceDtos.CreateOrderRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.PaymentVerifyRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.ShipmentRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class CheckoutService {
    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;
    private final CartService cartService;
    private final PaymentService paymentService;
    private final NotificationService notificationService;
    private final LoyaltyService loyaltyService;

    public CheckoutService(JdbcTemplate jdbc, ObjectMapper objectMapper, CartService cartService,
                           PaymentService paymentService, NotificationService notificationService,
                           LoyaltyService loyaltyService) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.cartService = cartService;
        this.paymentService = paymentService;
        this.notificationService = notificationService;
        this.loyaltyService = loyaltyService;
    }

    public Map<String, Object> validateCart(UUID storefrontId, String sessionToken, String pincode, EcPrincipal principal) {
        CartService.CartSnapshot snapshot = cartService.snapshot(storefrontId, sessionToken, principal);
        if (snapshot.items().isEmpty()) {
            throw new IllegalArgumentException("Cart is empty");
        }
        List<Map<String, Object>> stockChecks = jdbc.queryForList("""
                SELECT ci.server_id AS cart_item_id, p.name, ci.quantity,
                       COALESCE(v.stock_override, p.stock_quantity) AS available_stock
                FROM app_core.ec_cart_items ci
                JOIN app_core.ec_product_listings l ON l.server_id = ci.listing_id AND l.tenant_id = ci.tenant_id
                JOIN app_core.products p ON p.server_id = l.product_id
                LEFT JOIN app_core.ec_product_variants v ON v.server_id = ci.variant_id AND v.tenant_id = ci.tenant_id
                WHERE ci.cart_id = ? AND ci.tenant_id = ?
                """, snapshot.cartId(), snapshot.tenantId());
        boolean inStock = stockChecks.stream().allMatch(item -> ((BigDecimal) item.get("available_stock")).compareTo(BigDecimal.valueOf(((Number) item.get("quantity")).intValue())) >= 0);
        List<Map<String, Object>> serviceableRows = jdbc.queryForList("""
                SELECT extra_shipping_charge
                FROM app_core.ec_serviceable_pincodes
                WHERE storefront_id = ? AND tenant_id = ? AND pincode = ?
                LIMIT 1
                """, storefrontId, snapshot.tenantId(), pincode);
        BigDecimal shippingCharge = serviceableRows.isEmpty() ? BigDecimal.ZERO : (BigDecimal) serviceableRows.getFirst().get("extra_shipping_charge");
        return Map.of(
                "cartId", snapshot.cartId(),
                "inStock", inStock,
                "serviceable", !serviceableRows.isEmpty(),
                "shippingCharge", shippingCharge,
                "items", stockChecks,
                "subtotal", snapshot.subtotal(),
                "couponDiscount", snapshot.couponDiscount() == null ? BigDecimal.ZERO : snapshot.couponDiscount()
        );
    }

    @Transactional
    public Map<String, Object> createOrder(CreateOrderRequest request, EcPrincipal principal) {
        CartService.CartSnapshot snapshot = cartService.snapshot(request.storefrontId(), request.sessionToken(), principal);
        if (snapshot.items().isEmpty()) {
            throw new IllegalArgumentException("Cannot checkout an empty cart");
        }
        UUID customerId = principal == null ? null : principal.customerId();
        String orderNumber = "EC-" + Instant.now().toEpochMilli();
        BigDecimal gstTotal = snapshot.items().stream()
                .map(item -> gstAmount((UUID) item.get("listing_id"), snapshot.tenantId(), (BigDecimal) item.get("unit_price"), ((Number) item.get("quantity")).intValue()))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        UUID orderId = jdbc.queryForObject("""
                INSERT INTO app_core.ec_orders(
                    server_id, tenant_id, storefront_id, ec_customer_id, order_number, status,
                    shipping_address, billing_address, subtotal, discount, coupon_discount,
                    shipping_charge, gst_total, payment_mode, created_at, updated_at
                ) VALUES (gen_random_uuid(), ?, ?, ?, ?, 'pending', ?::jsonb, ?::jsonb, ?, 0, ?, 0, ?, ?, now(), now())
                RETURNING server_id
                """, UUID.class,
                snapshot.tenantId(), request.storefrontId(), customerId, orderNumber,
                writeJson(request.shippingAddress()), writeJson(request.billingAddress()), snapshot.subtotal(),
                snapshot.couponDiscount() == null ? BigDecimal.ZERO : snapshot.couponDiscount(),
                gstTotal, request.paymentMode() == null ? "razorpay" : request.paymentMode());
        for (Map<String, Object> item : snapshot.items()) {
            jdbc.update("""
                    INSERT INTO app_core.ec_order_items(
                        server_id, tenant_id, order_id, listing_id, product_name, variant_label,
                        qty, unit_price, gst_rate, gst_amount, created_at
                    ) VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?, now())
                    """,
                    snapshot.tenantId(), orderId, item.get("listing_id"), item.get("product_name"), item.get("variant_label"),
                    item.get("quantity"), item.get("unit_price"), listingGstRate((UUID) item.get("listing_id"), snapshot.tenantId()),
                    gstAmount((UUID) item.get("listing_id"), snapshot.tenantId(), (BigDecimal) item.get("unit_price"), ((Number) item.get("quantity")).intValue()));
        }
        if (snapshot.couponDiscount() != null && snapshot.couponDiscount().compareTo(BigDecimal.ZERO) > 0) {
            Map<String, Object> cart = jdbc.queryForMap("SELECT coupon_id FROM app_core.ec_carts WHERE server_id = ? AND tenant_id = ?", snapshot.cartId(), snapshot.tenantId());
            if (cart.get("coupon_id") != null) {
                jdbc.update("""
                        INSERT INTO app_core.ec_coupon_usages(server_id, tenant_id, coupon_id, order_id, ec_customer_id, discount_applied, created_at)
                        VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, now())
                        """, snapshot.tenantId(), cart.get("coupon_id"), orderId, customerId, snapshot.couponDiscount());
                jdbc.update("UPDATE app_core.ec_coupons SET usage_count = usage_count + 1, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                        cart.get("coupon_id"), snapshot.tenantId());
            }
        }
        return Map.of("orderId", orderId, "orderNumber", orderNumber, "status", "pending");
    }

    @Transactional
    public Map<String, Object> initiatePayment(UUID orderId, EcPrincipal principal) {
        Map<String, Object> order = ownedOrder(orderId, principal);
        BigDecimal amount = ((BigDecimal) order.get("subtotal"))
                .subtract((BigDecimal) order.get("coupon_discount"))
                .add((BigDecimal) order.get("shipping_charge"))
                .setScale(2, RoundingMode.HALF_UP);
        Map<String, Object> razorpayOrder = paymentService.createRazorpayOrder(String.valueOf(order.get("order_number")), amount);
        jdbc.update("""
                INSERT INTO app_core.ec_payments(
                    server_id, tenant_id, order_id, gateway, gateway_order_id, amount, status, raw_response, created_at, updated_at
                ) VALUES (gen_random_uuid(), ?, ?, 'razorpay', ?, ?, 'initiated', ?::jsonb, now(), now())
                """, order.get("tenant_id"), orderId, razorpayOrder.get("id"), amount, writeJson(razorpayOrder));
        return Map.of("orderId", orderId, "amount", amount, "razorpay", razorpayOrder);
    }

    @Transactional
    public Map<String, Object> verifyPayment(PaymentVerifyRequest request, EcPrincipal principal) {
        Map<String, Object> order = ownedOrder(request.orderId(), principal);
        if (!paymentService.verifySignature(request.gatewayOrderId(), request.gatewayPaymentId(), request.gatewaySignature())) {
            throw new IllegalArgumentException("Invalid Razorpay signature");
        }
        UUID tenantId = (UUID) order.get("tenant_id");
        jdbc.update("""
                UPDATE app_core.ec_payments
                SET gateway_payment_id = ?, gateway_signature = ?, status = 'success', updated_at = now()
                WHERE order_id = ? AND tenant_id = ? AND gateway_order_id = ?
                """, request.gatewayPaymentId(), request.gatewaySignature(), request.orderId(), tenantId, request.gatewayOrderId());
        jdbc.update("UPDATE app_core.ec_orders SET status = 'confirmed', confirmed_at = now(), updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                request.orderId(), tenantId);
        List<Map<String, Object>> items = jdbc.queryForList("""
                SELECT oi.server_id, oi.listing_id, oi.qty, oi.unit_price, l.product_id, p.name
                FROM app_core.ec_order_items oi
                JOIN app_core.ec_product_listings l ON l.server_id = oi.listing_id AND l.tenant_id = oi.tenant_id
                JOIN app_core.products p ON p.server_id = l.product_id
                WHERE oi.order_id = ? AND oi.tenant_id = ?
                """, request.orderId(), tenantId);
        for (Map<String, Object> item : items) {
            BigDecimal quantity = BigDecimal.valueOf(((Number) item.get("qty")).intValue());
            jdbc.update("UPDATE app_core.products SET stock_quantity = stock_quantity - ? WHERE server_id = ? AND tenant_id = ?",
                    quantity, item.get("product_id"), tenantId);
            jdbc.update("""
                    INSERT INTO app_core.stock_ledger(server_id, tenant_id, product_id, source_type, source_id, quantity_change, created_at)
                    VALUES (gen_random_uuid(), ?, ?, 'ec_order', ?, ?, now())
                    """, tenantId, item.get("product_id"), request.orderId(), quantity.negate());
        }
        UUID billId = createBill(order, items);
        jdbc.update("UPDATE app_core.ec_orders SET bill_id = ?, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                billId, request.orderId(), tenantId);
        UUID customerId = (UUID) order.get("ec_customer_id");
        if (customerId != null) {
            String email = jdbc.queryForObject("SELECT email FROM app_core.ec_customers WHERE server_id = ? AND tenant_id = ?", String.class, customerId, tenantId);
            notificationService.sendOrderConfirmation(tenantId, customerId, request.orderId(), email, String.valueOf(order.get("order_number")));
            // Award loyalty points: 1 point per ₹10 spent
            BigDecimal paidAmount = ((BigDecimal) order.get("subtotal"))
                    .subtract((BigDecimal) order.get("coupon_discount"))
                    .add((BigDecimal) order.get("shipping_charge"));
            loyaltyService.earnPoints(customerId, tenantId, request.orderId(), paidAmount.multiply(BigDecimal.valueOf(100)).longValue());
        }
        return Map.of("orderId", request.orderId(), "status", "confirmed", "billId", billId);
    }

    public List<Map<String, Object>> listOrders(EcPrincipal principal) {
        return jdbc.queryForList("""
                SELECT server_id, order_number, status, subtotal, coupon_discount, shipping_charge, gst_total, payment_mode, confirmed_at, created_at, updated_at
                FROM app_core.ec_orders
                WHERE tenant_id = ? AND ec_customer_id = ?
                ORDER BY created_at DESC
                """, principal.tenantId(), principal.customerId());
    }

    public Map<String, Object> orderDetail(String orderNumber, EcPrincipal principal) {
        Map<String, Object> order = jdbc.queryForMap("""
                SELECT server_id, order_number, status, shipping_address, billing_address, subtotal, coupon_discount, shipping_charge, gst_total,
                       payment_mode, bill_id, confirmed_at, created_at, updated_at
                FROM app_core.ec_orders
                WHERE tenant_id = ? AND ec_customer_id = ? AND order_number = ?
                """, principal.tenantId(), principal.customerId(), orderNumber);
        List<Map<String, Object>> items = jdbc.queryForList("SELECT * FROM app_core.ec_order_items WHERE order_id = ? AND tenant_id = ? ORDER BY created_at ASC",
                order.get("server_id"), principal.tenantId());
        List<Map<String, Object>> shipments = jdbc.queryForList("SELECT * FROM app_core.ec_shipments WHERE order_id = ? AND tenant_id = ? ORDER BY created_at DESC",
                order.get("server_id"), principal.tenantId());
        LinkedHashMap<String, Object> response = new LinkedHashMap<>(order);
        response.put("items", items);
        response.put("shipments", shipments);
        return response;
    }

    @Transactional
    public Map<String, Object> cancelOrder(UUID orderId, EcPrincipal principal, String reason) {
        jdbc.update("UPDATE app_core.ec_orders SET status = 'cancel_requested', updated_at = now() WHERE server_id = ? AND tenant_id = ? AND ec_customer_id = ?",
                orderId, principal.tenantId(), principal.customerId());
        return Map.of("status", "cancel_requested", "reason", reason == null ? "" : reason);
    }

    @Transactional
    public Map<String, Object> returnRequest(UUID orderId, EcPrincipal principal, String reason) {
        jdbc.update("UPDATE app_core.ec_orders SET status = 'return_requested', updated_at = now() WHERE server_id = ? AND tenant_id = ? AND ec_customer_id = ?",
                orderId, principal.tenantId(), principal.customerId());
        return Map.of("status", "return_requested", "reason", reason == null ? "" : reason);
    }

    public List<Map<String, Object>> adminOrders(UUID tenantId, UUID storefrontId, String status) {
        String sql = "SELECT * FROM app_core.ec_orders WHERE tenant_id = ? AND storefront_id = ?" +
                (status == null || status.isBlank() ? "" : " AND status = ?") + " ORDER BY created_at DESC";
        return (status == null || status.isBlank())
                ? jdbc.queryForList(sql, tenantId, storefrontId)
                : jdbc.queryForList(sql, tenantId, storefrontId, status);
    }

    @Transactional
    public Map<String, Object> updateOrderStatus(UUID tenantId, UUID orderId, String status) {
        jdbc.update("UPDATE app_core.ec_orders SET status = ?, updated_at = now() WHERE server_id = ? AND tenant_id = ?", status, orderId, tenantId);
        return jdbc.queryForMap("SELECT server_id, order_number, status, updated_at FROM app_core.ec_orders WHERE server_id = ? AND tenant_id = ?", orderId, tenantId);
    }

    @Transactional
    public Map<String, Object> addShipment(UUID tenantId, UUID orderId, ShipmentRequest request) {
        jdbc.update("""
                INSERT INTO app_core.ec_shipments(
                    server_id, tenant_id, order_id, courier_name, tracking_number, tracking_url, estimated_delivery, shipped_at, created_at, updated_at
                ) VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, now(), now(), now())
                """, tenantId, orderId, request.courierName(), request.trackingNumber(), request.trackingUrl(), request.estimatedDelivery());
        jdbc.update("UPDATE app_core.ec_orders SET status = 'shipped', updated_at = now() WHERE server_id = ? AND tenant_id = ?", orderId, tenantId);
        return Map.of("status", "shipped", "orderId", orderId);
    }

    public Map<String, Object> dashboard(UUID tenantId, UUID storefrontId) {
        Map<String, Object> totals = jdbc.queryForMap("""
                SELECT COALESCE(SUM(subtotal - coupon_discount + shipping_charge), 0) AS revenue,
                       COUNT(*) AS orders,
                       COALESCE(SUM(CASE WHEN status = 'confirmed' THEN 1 ELSE 0 END), 0) AS confirmed_orders
                FROM app_core.ec_orders
                WHERE tenant_id = ? AND storefront_id = ?
                """, tenantId, storefrontId);
        Long customers = jdbc.queryForObject("SELECT COUNT(*) FROM app_core.ec_customers WHERE tenant_id = ? AND storefront_id = ?", Long.class, tenantId, storefrontId);
        LinkedHashMap<String, Object> response = new LinkedHashMap<>(totals);
        response.put("customers", customers == null ? 0L : customers);
        return response;
    }

    public List<Map<String, Object>> topProducts(UUID tenantId, UUID storefrontId) {
        return jdbc.queryForList("""
                SELECT oi.listing_id, oi.product_name, SUM(oi.qty) AS units_sold, SUM(oi.unit_price * oi.qty) AS revenue
                FROM app_core.ec_order_items oi
                JOIN app_core.ec_orders o ON o.server_id = oi.order_id AND o.tenant_id = oi.tenant_id
                WHERE o.tenant_id = ? AND o.storefront_id = ?
                GROUP BY oi.listing_id, oi.product_name
                ORDER BY units_sold DESC, revenue DESC
                LIMIT 10
                """, tenantId, storefrontId);
    }

    public Map<String, Object> abandonedCartStats(UUID tenantId, UUID storefrontId) {
        Map<String, Object> base = jdbc.queryForMap("""
                SELECT COUNT(*) AS total_abandoned,
                       COALESCE(SUM(CASE WHEN recovered_at IS NOT NULL THEN 1 ELSE 0 END), 0) AS recovered
                FROM app_core.ec_abandoned_carts ac
                JOIN app_core.ec_carts c ON c.server_id = ac.cart_id AND c.tenant_id = ac.tenant_id
                WHERE ac.tenant_id = ? AND c.storefront_id = ?
                """, tenantId, storefrontId);
        return base;
    }

    private Map<String, Object> ownedOrder(UUID orderId, EcPrincipal principal) {
        if (principal == null) {
            // Guest access: only permit orders that have no associated customer (guest checkout)
            return jdbc.queryForMap(
                    "SELECT * FROM app_core.ec_orders WHERE server_id = ? AND ec_customer_id IS NULL", orderId);
        }
        return jdbc.queryForMap("SELECT * FROM app_core.ec_orders WHERE server_id = ? AND tenant_id = ? AND ec_customer_id = ?",
                orderId, principal.tenantId(), principal.customerId());
    }

    private UUID createBill(Map<String, Object> order, List<Map<String, Object>> items) {
        UUID tenantId = (UUID) order.get("tenant_id");
        UUID billId = jdbc.queryForObject("""
                INSERT INTO app_core.bills(
                    server_id, tenant_id, client_record_id, device_id, bill_number, total_amount,
                    discount_amount, gst_total, payment_mode, status, snapshot_json, updated_at
                ) VALUES (gen_random_uuid(), ?, gen_random_uuid(), 'ecommerce', ?, ?, ?, ?, ?, 'active', ?::jsonb, now())
                RETURNING server_id
                """, UUID.class,
                tenantId,
                order.get("order_number"),
                totalAmount(order),
                order.get("coupon_discount"),
                order.get("gst_total"),
                order.get("payment_mode"),
                writeJson(order));
        for (Map<String, Object> item : items) {
            jdbc.update("""
                    INSERT INTO app_core.bill_items(
                        server_id, tenant_id, bill_id, client_record_id, device_id, product_id,
                        product_name, quantity, unit, unit_price, total_price, updated_at
                    ) VALUES (gen_random_uuid(), ?, ?, gen_random_uuid(), 'ecommerce', ?, ?, ?, 'piece', ?, ?, now())
                    """, tenantId, billId, item.get("product_id"), item.get("name"), item.get("qty"), item.get("unit_price"),
                    ((BigDecimal) item.get("unit_price")).multiply(BigDecimal.valueOf(((Number) item.get("qty")).intValue())));
        }
        return billId;
    }

    private BigDecimal totalAmount(Map<String, Object> order) {
        return ((BigDecimal) order.get("subtotal"))
                .subtract((BigDecimal) order.get("coupon_discount"))
                .add((BigDecimal) order.get("shipping_charge"))
                .setScale(2, RoundingMode.HALF_UP);
    }

    private BigDecimal listingGstRate(UUID listingId, UUID tenantId) {
        BigDecimal rate = jdbc.queryForObject("""
                SELECT p.gst_rate
                FROM app_core.ec_product_listings l
                JOIN app_core.products p ON p.server_id = l.product_id
                WHERE l.server_id = ? AND l.tenant_id = ?
                """, BigDecimal.class, listingId, tenantId);
        return rate == null ? BigDecimal.ZERO : rate;
    }

    private BigDecimal gstAmount(UUID listingId, UUID tenantId, BigDecimal unitPrice, int qty) {
        BigDecimal rate = listingGstRate(listingId, tenantId);
        BigDecimal divisor = BigDecimal.ONE.add(rate.divide(BigDecimal.valueOf(100), 6, RoundingMode.HALF_UP));
        return unitPrice.divide(divisor, 6, RoundingMode.HALF_UP)
                .multiply(rate.divide(BigDecimal.valueOf(100), 6, RoundingMode.HALF_UP))
                .multiply(BigDecimal.valueOf(qty))
                .setScale(2, RoundingMode.HALF_UP);
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception ex) {
            throw new IllegalArgumentException("Failed to serialize ecommerce payload", ex);
        }
    }
}
