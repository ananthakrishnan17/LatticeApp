package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.QAAnswerRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.QAQuestionRequest;
import com.nammananban.ecommerce.service.EcAuthService;
import com.nammananban.ecommerce.service.ProductQAService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ec/qa")
public class ProductQAController {
    private final ProductQAService productQAService;
    private final EcAuthService ecAuthService;

    public ProductQAController(ProductQAService productQAService, EcAuthService ecAuthService) {
        this.productQAService = productQAService;
        this.ecAuthService = ecAuthService;
    }

    /** Public: list approved Q&A for a listing. */
    @GetMapping("/{listingId}")
    public List<Map<String, Object>> list(@PathVariable UUID listingId) {
        EcPrincipal principal = ecAuthService.currentPrincipalOrNull();
        UUID tenantId = principal != null ? principal.tenantId() : null;
        if (tenantId == null) {
            // Resolve tenant from listing
            return productQAService.listForListing(listingId, null);
        }
        return productQAService.listForListing(listingId, tenantId);
    }

    /** Authenticated customers can ask questions. */
    @PostMapping
    public Map<String, Object> ask(@Valid @RequestBody QAQuestionRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return productQAService.askQuestion(request, principal);
    }

    /** Admin: answer a question. */
    @PostMapping("/{id}/answer")
    public Map<String, Object> answer(@PathVariable UUID id, @Valid @RequestBody QAAnswerRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return productQAService.answerQuestion(id, request, principal.tenantId());
    }

    /** Admin: hide a question. */
    @DeleteMapping("/{id}")
    public Map<String, Object> delete(@PathVariable UUID id) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return productQAService.deleteQuestion(id, principal.tenantId());
    }

    /** Admin: list all unanswered questions for a storefront. */
    @GetMapping("/admin/unanswered/{storefrontId}")
    public List<Map<String, Object>> unanswered(@PathVariable UUID storefrontId) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return productQAService.listUnanswered(storefrontId, principal.tenantId());
    }
}
