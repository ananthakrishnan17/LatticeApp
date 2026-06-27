package com.nammananban.ecommerce.service;

import com.nammananban.ecommerce.dto.EcommerceDtos.AdminLoginRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.AuthResponse;
import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.ForgotPasswordRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.LoginRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.RegisterRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.ResetPasswordRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.UpdateProfileRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.VerifyEmailRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;
import java.util.UUID;

@Service
public class EcAuthService {
    private final JdbcTemplate jdbc;
    private final EcJwtService ecJwtService;
    private final NotificationService notificationService;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    public EcAuthService(JdbcTemplate jdbc, EcJwtService ecJwtService, NotificationService notificationService) {
        this.jdbc = jdbc;
        this.ecJwtService = ecJwtService;
        this.notificationService = notificationService;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        Map<String, Object> store = jdbc.queryForMap("SELECT tenant_id FROM app_core.ec_storefronts WHERE server_id = ? AND is_active = true", request.storefrontId());
        UUID tenantId = (UUID) store.get("tenant_id");
        String verifyToken = UUID.randomUUID().toString();
        UUID customerId = jdbc.queryForObject("""
                INSERT INTO app_core.ec_customers(
                    server_id, tenant_id, storefront_id, email, password_hash, email_verify_token,
                    first_name, last_name, phone, created_at, updated_at
                ) VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, ?, now(), now())
                RETURNING server_id
                """, UUID.class,
                tenantId, request.storefrontId(), request.email().trim().toLowerCase(), encoder.encode(request.password()), verifyToken,
                request.firstName(), request.lastName(), request.phone());
        notificationService.sendEmailVerification(tenantId, customerId, request.email(), verifyToken);
        String token = ecJwtService.issueToken(customerId, tenantId, request.storefrontId(), request.email().trim().toLowerCase());
        return new AuthResponse(token, customerId, tenantId, request.storefrontId(), request.email().trim().toLowerCase());
    }

    public AuthResponse adminLogin(AdminLoginRequest request) {
        Map<String, Object> storefront = jdbc.queryForMap(
                "SELECT tenant_id FROM app_core.ec_storefronts WHERE server_id = ? AND is_active = true",
                request.storefrontId());
        UUID tenantId = (UUID) storefront.get("tenant_id");
        Map<String, Object> user = jdbc.queryForMap("""
                SELECT server_id, username, password_hash
                FROM app_core.users
                WHERE tenant_id = ? AND username = ?
                """, tenantId, request.username().trim());
        if (!encoder.matches(request.password(), String.valueOf(user.get("password_hash")))) {
            throw new IllegalArgumentException("Invalid credentials");
        }
        UUID adminUserId = (UUID) user.get("server_id");
        String token = ecJwtService.issueAdminToken(adminUserId, tenantId, request.storefrontId(), request.username().trim());
        return new AuthResponse(token, adminUserId, tenantId, request.storefrontId(), request.username().trim());
    }

    public AuthResponse login(LoginRequest request) {
        Map<String, Object> row = jdbc.queryForMap("""
                SELECT server_id, tenant_id, storefront_id, email, password_hash
                FROM app_core.ec_customers
                WHERE storefront_id = ? AND email = ?
                """, request.storefrontId(), request.email().trim().toLowerCase());
        if (!encoder.matches(request.password(), String.valueOf(row.get("password_hash")))) {
            throw new IllegalArgumentException("Invalid credentials");
        }
        return new AuthResponse(
                ecJwtService.issueToken((UUID) row.get("server_id"), (UUID) row.get("tenant_id"), (UUID) row.get("storefront_id"), String.valueOf(row.get("email"))),
                (UUID) row.get("server_id"),
                (UUID) row.get("tenant_id"),
                (UUID) row.get("storefront_id"),
                String.valueOf(row.get("email"))
        );
    }

    @Transactional
    public Map<String, Object> verifyEmail(VerifyEmailRequest request) {
        int updated = jdbc.update("""
                UPDATE app_core.ec_customers
                SET email_verified = true, email_verify_token = null, updated_at = now()
                WHERE storefront_id = ? AND email_verify_token = ?
                """, request.storefrontId(), request.token());
        return Map.of("verified", updated > 0);
    }

    @Transactional
    public Map<String, Object> forgotPassword(ForgotPasswordRequest request) {
        ListRow row = jdbc.queryForObject("""
                SELECT server_id, tenant_id, email
                FROM app_core.ec_customers
                WHERE storefront_id = ? AND email = ?
                """, (rs, rn) -> new ListRow(rs.getObject("server_id", UUID.class), rs.getObject("tenant_id", UUID.class), rs.getString("email")),
                request.storefrontId(), request.email().trim().toLowerCase());
        String token = UUID.randomUUID().toString();
        jdbc.update("""
                UPDATE app_core.ec_customers
                SET reset_password_token = ?, reset_password_sent_at = now(), updated_at = now()
                WHERE server_id = ?
                """, token, row.customerId());
        notificationService.sendPasswordReset(row.tenantId(), row.customerId(), row.email(), token);
        return Map.of("status", "ok");
    }

    @Transactional
    public Map<String, Object> resetPassword(ResetPasswordRequest request) {
        int updated = jdbc.update("""
                UPDATE app_core.ec_customers
                SET password_hash = ?, reset_password_token = null, reset_password_sent_at = null, updated_at = now()
                WHERE storefront_id = ? AND reset_password_token = ?
                """, encoder.encode(request.password()), request.storefrontId(), request.token());
        return Map.of("updated", updated > 0);
    }

    public Map<String, Object> me() {
        EcPrincipal principal = requirePrincipal();
        return jdbc.queryForMap("""
                SELECT server_id, tenant_id, storefront_id, email, email_verified, first_name, last_name, phone, loyalty_points, created_at, updated_at
                FROM app_core.ec_customers
                WHERE server_id = ? AND tenant_id = ?
                """, principal.customerId(), principal.tenantId());
    }

    @Transactional
    public Map<String, Object> updateProfile(UpdateProfileRequest request) {
        EcPrincipal principal = requirePrincipal();
        jdbc.update("""
                UPDATE app_core.ec_customers
                SET first_name = ?, last_name = ?, phone = ?, updated_at = now()
                WHERE server_id = ? AND tenant_id = ?
                """, request.firstName(), request.lastName(), request.phone(), principal.customerId(), principal.tenantId());
        return me();
    }

    public EcPrincipal currentPrincipalOrNull() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof EcPrincipal principal)) {
            return null;
        }
        return principal;
    }

    public EcPrincipal requirePrincipal() {
        EcPrincipal principal = currentPrincipalOrNull();
        if (principal == null) {
            throw new IllegalStateException("Ecommerce customer is not authenticated");
        }
        return principal;
    }

    private record ListRow(UUID customerId, UUID tenantId, String email) {}
}
