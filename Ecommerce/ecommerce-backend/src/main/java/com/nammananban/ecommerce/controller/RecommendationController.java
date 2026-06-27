package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.service.EcAuthService;
import com.nammananban.ecommerce.service.RecommendationService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ec")
public class RecommendationController {
    private final RecommendationService recommendationService;
    private final EcAuthService ecAuthService;

    public RecommendationController(RecommendationService recommendationService, EcAuthService ecAuthService) {
        this.recommendationService = recommendationService;
        this.ecAuthService = ecAuthService;
    }

    @GetMapping("/store/{slug}/related/{productSlug}")
    public List<Map<String, Object>> related(
            @PathVariable String slug,
            @PathVariable String productSlug,
            @RequestParam(defaultValue = "6") int limit
    ) {
        // Resolve storefront + listing from slug
        return recommendationService.getRelatedByProductSlug(slug, productSlug, limit);
    }

    @GetMapping("/store/{slug}/trending")
    public List<Map<String, Object>> trending(
            @PathVariable String slug,
            @RequestParam(defaultValue = "8") int limit
    ) {
        return recommendationService.getTrendingByStoreSlug(slug, limit);
    }

    @GetMapping("/recommendations/recently-viewed")
    public List<Map<String, Object>> recentlyViewed(
            @RequestParam UUID storefrontId,
            @RequestParam(defaultValue = "8") int limit
    ) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return recommendationService.getRecentlyViewed(principal.customerId(), storefrontId, principal.tenantId(), limit);
    }
}
