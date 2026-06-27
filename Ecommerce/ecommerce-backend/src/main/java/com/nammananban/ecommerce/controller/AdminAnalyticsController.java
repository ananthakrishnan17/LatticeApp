package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.service.CheckoutService;
import com.nammananban.ecommerce.service.EcAuthService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/ec/admin/analytics")
public class AdminAnalyticsController {
    private final CheckoutService checkoutService;
    private final EcAuthService ecAuthService;

    public AdminAnalyticsController(CheckoutService checkoutService, EcAuthService ecAuthService) {
        this.checkoutService = checkoutService;
        this.ecAuthService = ecAuthService;
    }

    @GetMapping("/dashboard")
    public Map<String, Object> dashboard() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return checkoutService.dashboard(principal.tenantId(), principal.storefrontId());
    }

    @GetMapping("/top-products")
    public List<Map<String, Object>> topProducts() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return checkoutService.topProducts(principal.tenantId(), principal.storefrontId());
    }

    @GetMapping("/abandoned-carts")
    public Map<String, Object> abandonedCarts() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return checkoutService.abandonedCartStats(principal.tenantId(), principal.storefrontId());
    }
}
