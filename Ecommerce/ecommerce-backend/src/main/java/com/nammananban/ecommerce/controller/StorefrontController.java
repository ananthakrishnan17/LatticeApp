package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.PagedResponse;
import com.nammananban.ecommerce.service.StorefrontService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/ec/store/{slug}")
public class StorefrontController {
    private final JdbcTemplate jdbc;
    private final StorefrontService storefrontService;

    public StorefrontController(JdbcTemplate jdbc, StorefrontService storefrontService) {
        this.jdbc = jdbc;
        this.storefrontService = storefrontService;
    }

    @GetMapping
    public Map<String, Object> storefront(@PathVariable String slug) {
        return storefrontService.getStorefront(slug);
    }

    @GetMapping("/products")
    public PagedResponse products(
            @PathVariable String slug,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String brand,
            @RequestParam(required = false) BigDecimal minPrice,
            @RequestParam(required = false) BigDecimal maxPrice,
            @RequestParam(required = false) Boolean inStock,
            @RequestParam(required = false) String sort,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return storefrontService.getProducts(slug, category, brand, minPrice, maxPrice, inStock, sort, page, size);
    }

    @GetMapping("/products/{productSlug}")
    public Map<String, Object> productDetail(@PathVariable String slug, @PathVariable String productSlug) {
        return storefrontService.getProductDetail(slug, productSlug);
    }

    @GetMapping("/categories")
    public List<Map<String, Object>> categories(@PathVariable String slug) {
        return storefrontService.getCategories(slug);
    }

    @GetMapping("/search")
    public List<Map<String, Object>> search(@PathVariable String slug, @RequestParam("q") String query) {
        return storefrontService.searchProducts(slug, query);
    }

    @GetMapping("/banners")
    public List<Map<String, Object>> banners(@PathVariable String slug) {
        return storefrontService.getBanners(slug);
    }

    @GetMapping("/pincode/{pincode}/check")
    public Map<String, Object> checkPincode(@PathVariable String slug, @PathVariable String pincode) {
        return storefrontService.checkPincode(slug, pincode);
    }
}
