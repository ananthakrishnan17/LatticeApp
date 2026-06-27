package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.ReviewSubmitRequest;
import com.nammananban.ecommerce.service.EcAuthService;
import com.nammananban.ecommerce.service.ReviewService;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
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
@RequestMapping("/ec/reviews")
public class ReviewController {
    private final JdbcTemplate jdbc;
    private final ReviewService reviewService;
    private final EcAuthService ecAuthService;

    public ReviewController(JdbcTemplate jdbc, ReviewService reviewService, EcAuthService ecAuthService) {
        this.jdbc = jdbc;
        this.reviewService = reviewService;
        this.ecAuthService = ecAuthService;
    }

    @PostMapping
    public Map<String, Object> submit(@Valid @RequestBody ReviewSubmitRequest request) {
        return reviewService.submit(request, ecAuthService.requirePrincipal());
    }

    @GetMapping("/{listingId}")
    public List<Map<String, Object>> reviews(@PathVariable UUID listingId) {
        return reviewService.getByListing(listingId);
    }
}
