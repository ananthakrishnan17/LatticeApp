package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.RedeemPointsRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.ReferralRequest;
import com.nammananban.ecommerce.service.EcAuthService;
import com.nammananban.ecommerce.service.LoyaltyService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/ec/loyalty")
public class LoyaltyController {
    private final LoyaltyService loyaltyService;
    private final EcAuthService ecAuthService;

    public LoyaltyController(LoyaltyService loyaltyService, EcAuthService ecAuthService) {
        this.loyaltyService = loyaltyService;
        this.ecAuthService = ecAuthService;
    }

    @GetMapping
    public Map<String, Object> balance() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return loyaltyService.getBalance(principal.customerId(), principal.tenantId());
    }

    @GetMapping("/transactions")
    public List<Map<String, Object>> transactions() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return loyaltyService.getTransactions(principal.customerId(), principal.tenantId());
    }

    @PostMapping("/redeem")
    public Map<String, Object> redeem(@Valid @RequestBody RedeemPointsRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return loyaltyService.redeemPoints(principal.customerId(), principal.tenantId(), request.points());
    }

    @PostMapping("/referral")
    public Map<String, Object> generateReferralCode() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return loyaltyService.generateReferralCode(principal.customerId(), principal.tenantId());
    }

    @PostMapping("/apply-referral")
    public Map<String, Object> applyReferralCode(@Valid @RequestBody ReferralRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return loyaltyService.applyReferralCode(principal.customerId(), principal.tenantId(), request.referralCode());
    }
}
