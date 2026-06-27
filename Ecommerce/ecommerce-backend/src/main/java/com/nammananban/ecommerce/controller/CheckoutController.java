package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.CheckoutValidateRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.CreateOrderRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.PaymentInitiateRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.PaymentVerifyRequest;
import com.nammananban.ecommerce.service.CheckoutService;
import com.nammananban.ecommerce.service.EcAuthService;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/ec/checkout")
public class CheckoutController {
    private final JdbcTemplate jdbc;
    private final CheckoutService checkoutService;
    private final EcAuthService ecAuthService;

    public CheckoutController(JdbcTemplate jdbc, CheckoutService checkoutService, EcAuthService ecAuthService) {
        this.jdbc = jdbc;
        this.checkoutService = checkoutService;
        this.ecAuthService = ecAuthService;
    }

    @PostMapping("/validate")
    public Map<String, Object> validate(@Valid @RequestBody CheckoutValidateRequest request) {
        return checkoutService.validateCart(request.storefrontId(), request.sessionToken(), request.pincode(), ecAuthService.currentPrincipalOrNull());
    }

    @PostMapping("/create-order")
    public Map<String, Object> createOrder(@Valid @RequestBody CreateOrderRequest request) {
        return checkoutService.createOrder(request, ecAuthService.currentPrincipalOrNull());
    }

    @PostMapping("/payment/initiate")
    public Map<String, Object> initiatePayment(@Valid @RequestBody PaymentInitiateRequest request) {
        return checkoutService.initiatePayment(request.orderId(), ecAuthService.currentPrincipalOrNull());
    }

    @PostMapping("/payment/verify")
    public Map<String, Object> verify(@Valid @RequestBody PaymentVerifyRequest request) {
        return checkoutService.verifyPayment(request, ecAuthService.currentPrincipalOrNull());
    }
}
