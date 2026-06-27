package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.CartItemRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.CartItemUpdateRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.CouponRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.MergeCartRequest;
import com.nammananban.ecommerce.service.CartService;
import com.nammananban.ecommerce.service.EcAuthService;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ec/cart")
public class CartController {
    private final JdbcTemplate jdbc;
    private final CartService cartService;
    private final EcAuthService ecAuthService;

    public CartController(JdbcTemplate jdbc, CartService cartService, EcAuthService ecAuthService) {
        this.jdbc = jdbc;
        this.cartService = cartService;
        this.ecAuthService = ecAuthService;
    }

    @GetMapping("/items")
    public Map<String, Object> items(@RequestParam UUID storefrontId, @RequestParam(required = false) String sessionToken) {
        return cartService.getCart(storefrontId, sessionToken, ecAuthService.currentPrincipalOrNull());
    }

    @PostMapping("/items")
    public Map<String, Object> addItem(@Valid @RequestBody CartItemRequest request) {
        return cartService.addItem(request, ecAuthService.currentPrincipalOrNull());
    }

    @PutMapping("/items/{id}")
    public Map<String, Object> updateItem(@PathVariable UUID id, @Valid @RequestBody CartItemUpdateRequest request) {
        return cartService.updateItem(id, request, ecAuthService.currentPrincipalOrNull());
    }

    @DeleteMapping("/items/{id}")
    public Map<String, Object> removeItem(@PathVariable UUID id, @RequestParam UUID storefrontId, @RequestParam(required = false) String sessionToken) {
        return cartService.removeItem(id, storefrontId, sessionToken, ecAuthService.currentPrincipalOrNull());
    }

    @PostMapping("/apply-coupon")
    public Map<String, Object> applyCoupon(@Valid @RequestBody CouponRequest request) {
        return cartService.applyCoupon(request, ecAuthService.currentPrincipalOrNull());
    }

    @DeleteMapping("/coupon")
    public Map<String, Object> removeCoupon(@RequestParam UUID storefrontId, @RequestParam(required = false) String sessionToken) {
        return cartService.removeCoupon(storefrontId, sessionToken, ecAuthService.currentPrincipalOrNull());
    }

    @PostMapping("/merge")
    public Map<String, Object> merge(@Valid @RequestBody MergeCartRequest request) {
        return cartService.merge(request, ecAuthService.currentPrincipalOrNull());
    }
}
