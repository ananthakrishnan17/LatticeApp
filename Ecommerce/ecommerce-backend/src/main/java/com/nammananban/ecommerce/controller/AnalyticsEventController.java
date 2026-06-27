package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.StoreEventRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.StockAlertRequest;
import com.nammananban.ecommerce.service.AnalyticsEventService;
import com.nammananban.ecommerce.service.EcAuthService;
import com.nammananban.ecommerce.service.RecommendationService;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ec")
public class AnalyticsEventController {
    private final AnalyticsEventService analyticsEventService;
    private final EcAuthService ecAuthService;
    private final RecommendationService recommendationService;
    private final JdbcTemplate jdbc;

    public AnalyticsEventController(AnalyticsEventService analyticsEventService, EcAuthService ecAuthService,
                                    RecommendationService recommendationService, JdbcTemplate jdbc) {
        this.analyticsEventService = analyticsEventService;
        this.ecAuthService = ecAuthService;
        this.recommendationService = recommendationService;
        this.jdbc = jdbc;
    }

    /** Track storefront events (view, cart_add, checkout_start, purchase). No auth required. */
    @PostMapping("/events")
    public Map<String, Object> track(@Valid @RequestBody StoreEventRequest request) {
        EcPrincipal principal = ecAuthService.currentPrincipalOrNull();
        UUID customerId = principal != null ? principal.customerId() : null;
        UUID tenantId = resolveTenantFromStorefront(request.storefrontId());
        analyticsEventService.recordEvent(request, customerId, tenantId);
        return Map.of("status", "ok");
    }

    /** Back-in-stock alert subscription. No auth required (email-based). */
    @PostMapping("/stock-alerts")
    public Map<String, Object> subscribeStockAlert(@Valid @RequestBody StockAlertRequest request) {
        EcPrincipal principal = ecAuthService.currentPrincipalOrNull();
        UUID tenantId = resolveTenantFromListing(request.listingId());
        UUID customerId = principal != null ? principal.customerId() : null;
        jdbc.update("""
                INSERT INTO app_core.ec_stock_alerts(server_id, tenant_id, listing_id, ec_customer_id, email, created_at)
                VALUES (gen_random_uuid(), ?, ?, ?, ?, now())
                ON CONFLICT (listing_id, email) DO NOTHING
                """, tenantId, request.listingId(), customerId, request.email());
        return Map.of("status", "ok", "message", "You will be notified when this item is back in stock.");
    }

    /** Admin: funnel metrics. */
    @GetMapping("/admin/analytics/funnel")
    public Map<String, Object> funnel(@RequestParam UUID storefrontId) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return analyticsEventService.getFunnelMetrics(storefrontId, principal.tenantId());
    }

    /** Admin: daily event chart data. */
    @GetMapping("/admin/analytics/daily-events")
    public List<Map<String, Object>> dailyEvents(
            @RequestParam UUID storefrontId,
            @RequestParam(defaultValue = "view") String eventType
    ) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return analyticsEventService.getDailyEvents(storefrontId, principal.tenantId(), eventType);
    }

    /** Admin: top search terms (last 30 days). */
    @GetMapping("/admin/analytics/top-searches")
    public List<Map<String, Object>> topSearches(
            @RequestParam UUID storefrontId,
            @RequestParam(defaultValue = "10") int limit
    ) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return recommendationService.getTopSearchTerms(storefrontId, principal.tenantId(), limit);
    }

    /** Admin: category conversion rates (last 30 days). */
    @GetMapping("/admin/analytics/category-conversion")
    public List<Map<String, Object>> categoryConversion(@RequestParam UUID storefrontId) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return analyticsEventService.getCategoryConversion(storefrontId, principal.tenantId());
    }

    /** Admin: monthly cohort retention (last 6 months). */
    @GetMapping("/admin/analytics/cohorts")
    public List<Map<String, Object>> cohorts(@RequestParam UUID storefrontId) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return analyticsEventService.getCohortRetention(storefrontId, principal.tenantId());
    }

    private UUID resolveTenantFromStorefront(UUID storefrontId) {
        return jdbc.queryForObject("SELECT tenant_id FROM app_core.ec_storefronts WHERE server_id = ?", UUID.class, storefrontId);
    }

    private UUID resolveTenantFromListing(UUID listingId) {
        return jdbc.queryForObject("SELECT tenant_id FROM app_core.ec_product_listings WHERE server_id = ?", UUID.class, listingId);
    }
}
