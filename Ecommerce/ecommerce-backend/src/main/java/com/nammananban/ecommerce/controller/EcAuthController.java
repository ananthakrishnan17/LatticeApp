package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.AdminLoginRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.AuthResponse;
import com.nammananban.ecommerce.dto.EcommerceDtos.ForgotPasswordRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.LoginRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.RegisterRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.ResetPasswordRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.UpdateProfileRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.VerifyEmailRequest;
import com.nammananban.ecommerce.service.EcAuthService;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/ec/auth")
public class EcAuthController {
    private final JdbcTemplate jdbc;
    private final EcAuthService ecAuthService;

    public EcAuthController(JdbcTemplate jdbc, EcAuthService ecAuthService) {
        this.jdbc = jdbc;
        this.ecAuthService = ecAuthService;
    }

    @PostMapping("/register")
    public AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return ecAuthService.register(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return ecAuthService.login(request);
    }

    @PostMapping("/admin/login")
    public AuthResponse adminLogin(@Valid @RequestBody AdminLoginRequest request) {
        return ecAuthService.adminLogin(request);
    }

    @PostMapping("/verify-email")
    public Map<String, Object> verifyEmail(@Valid @RequestBody VerifyEmailRequest request) {
        return ecAuthService.verifyEmail(request);
    }

    @PostMapping("/forgot-password")
    public Map<String, Object> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        return ecAuthService.forgotPassword(request);
    }

    @PostMapping("/reset-password")
    public Map<String, Object> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        return ecAuthService.resetPassword(request);
    }

    @GetMapping("/me")
    public Map<String, Object> me() {
        return ecAuthService.me();
    }

    @PutMapping("/me")
    public Map<String, Object> updateProfile(@Valid @RequestBody UpdateProfileRequest request) {
        return ecAuthService.updateProfile(request);
    }
}
