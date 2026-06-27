package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.OrderStatusUpdateRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.ShipmentRequest;
import com.nammananban.ecommerce.service.CheckoutService;
import com.nammananban.ecommerce.service.EcAuthService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ec/admin/orders")
public class AdminOrderController {
    private final CheckoutService checkoutService;
    private final EcAuthService ecAuthService;

    public AdminOrderController(CheckoutService checkoutService, EcAuthService ecAuthService) {
        this.checkoutService = checkoutService;
        this.ecAuthService = ecAuthService;
    }

    @GetMapping
    public List<Map<String, Object>> orders(@RequestParam(required = false) String status) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return checkoutService.adminOrders(principal.tenantId(), principal.storefrontId(), status);
    }

    @PutMapping("/{id}")
    public Map<String, Object> updateStatus(@PathVariable UUID id, @Valid @RequestBody OrderStatusUpdateRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return checkoutService.updateOrderStatus(principal.tenantId(), id, request.status());
    }

    @PostMapping("/{id}/shipment")
    public Map<String, Object> shipment(@PathVariable UUID id, @Valid @RequestBody ShipmentRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return checkoutService.addShipment(principal.tenantId(), id, request);
    }
}
