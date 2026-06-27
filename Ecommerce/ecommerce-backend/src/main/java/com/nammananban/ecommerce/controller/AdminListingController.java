package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.AdminListingRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.ImageReorderRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.ImageUploadRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.PagedResponse;
import com.nammananban.ecommerce.service.EcAuthService;
import com.nammananban.ecommerce.service.StorefrontService;
import jakarta.validation.Valid;
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
@RequestMapping("/ec/admin/listings")
public class AdminListingController {
    private final StorefrontService storefrontService;
    private final EcAuthService ecAuthService;

    public AdminListingController(StorefrontService storefrontService, EcAuthService ecAuthService) {
        this.storefrontService = storefrontService;
        this.ecAuthService = ecAuthService;
    }

    @GetMapping
    public PagedResponse list(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return storefrontService.listAdminListings(principal.tenantId(), principal.storefrontId(), page, size);
    }

    @PostMapping
    public Map<String, Object> create(@Valid @RequestBody AdminListingRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        AdminListingRequest authoritative = new AdminListingRequest(
                request.serverId(), principal.tenantId(), principal.storefrontId(),
                request.productId(), request.seoSlug(), request.sellingPrice(),
                request.comparePrice(), request.tags(), request.visibility());
        return storefrontService.upsertListing(authoritative);
    }

    @PutMapping("/{id}")
    public Map<String, Object> update(@PathVariable UUID id, @Valid @RequestBody AdminListingRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        AdminListingRequest authoritative = new AdminListingRequest(
                id, principal.tenantId(), principal.storefrontId(),
                request.productId(), request.seoSlug(), request.sellingPrice(),
                request.comparePrice(), request.tags(), request.visibility());
        return storefrontService.upsertListing(authoritative);
    }

    @DeleteMapping("/{id}")
    public Map<String, Object> delete(@PathVariable UUID id) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        storefrontService.deleteListing(principal.tenantId(), id);
        return Map.of("status", "deleted");
    }

    @PostMapping("/{id}/images")
    public Map<String, Object> uploadImages(@PathVariable UUID id, @Valid @RequestBody ImageUploadRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return storefrontService.addImages(principal.tenantId(), id, request.imageUrls());
    }

    @PutMapping("/{id}/images/reorder")
    public Map<String, Object> reorderImages(@PathVariable UUID id, @Valid @RequestBody ImageReorderRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return storefrontService.reorderImages(principal.tenantId(), id, request);
    }
}
