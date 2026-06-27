package com.nammanban.backend.config;

import com.nammanban.backend.common.TenantContext;
import com.nammanban.backend.common.RoleScope;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;

    public JwtAuthFilter(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String p = request.getRequestURI();
        return p.startsWith("/auth") || p.startsWith("/ec/store") || p.startsWith("/ec/auth")
                || p.startsWith("/swagger-ui") || p.startsWith("/api-docs")
                || p.startsWith("/actuator/health") || p.startsWith("/actuator/info")
                || p.startsWith("/api/v1/upload/files");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header == null || !header.startsWith("Bearer ")) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Missing Bearer token");
            return;
        }

        try {
            String token = header.substring(7);
            Claims claims = jwtService.parse(token);
            UUID tenantId = uuidClaim(claims, "tenant_id", null);
            UUID organizationId = uuidClaim(claims, "organization_id", tenantId);
            UUID branchId = uuidClaim(claims, "branch_id", tenantId);
            String deviceId = String.valueOf(claims.get("device_id"));
            String legacyRole = stringClaim(claims, "legacy_role");
            String role = normalizeScopeRole(stringClaim(claims, "role"), legacyRole);
            String licenseType = normalizeLicenseType(stringClaim(claims, "license_type"));

            String tenantHeader = request.getHeader("X-Tenant-Id");
            String deviceHeader = request.getHeader("X-Device-Id");
            if (tenantHeader == null || deviceHeader == null) {
                response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Missing X-Tenant-Id or X-Device-Id header");
                return;
            }
            if (!tenantId.toString().equals(tenantHeader) || !deviceId.equals(deviceHeader)) {
                response.sendError(HttpServletResponse.SC_FORBIDDEN, "Header/token tenant or device mismatch");
                return;
            }

            // Reject data API calls from offline-licensed tenants.
            // Allow management endpoints (users, owner, subscription, auth).
            if (!"online".equals(licenseType)) {
                String uri = request.getRequestURI();
                boolean isManagementCall = uri.startsWith("/users") || 
                                           uri.startsWith("/owner") || 
                                           uri.startsWith("/subscription") ||
                                           uri.startsWith("/api/v1/upload") ||
                                           uri.startsWith("/day-close") ||
                                           uri.startsWith("/products") ||
                                           uri.startsWith("/categories") ||
                                           uri.startsWith("/brands");
                if (!isManagementCall) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN,
                            "Access denied: this endpoint requires an online license. "
                            + "Offline-licensed apps must use local storage for data.");
                    return;
                }
            }

            TenantContext.set(tenantId, deviceId, organizationId, branchId, role, licenseType);
            Set<SimpleGrantedAuthority> authorities = new LinkedHashSet<>();
            authorities.add(new SimpleGrantedAuthority(toAuthority(role)));
            if (legacyRole != null && !legacyRole.isBlank()) {
                authorities.add(new SimpleGrantedAuthority(toAuthority(legacyRole)));
            }
            var auth = new UsernamePasswordAuthenticationToken(
                    claims.getSubject(),
                    null,
                    List.copyOf(authorities)
            );
            SecurityContextHolder.getContext().setAuthentication(auth);
            filterChain.doFilter(request, response);
        } catch (Exception ex) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid token");
        } finally {
            TenantContext.clear();
            SecurityContextHolder.clearContext();
        }
    }

    private static String normalizeScopeRole(String roleClaim, String legacyRole) {
        if (roleClaim != null && !roleClaim.isBlank()) {
            return RoleScope.fromLegacyRole(roleClaim);
        }
        return RoleScope.fromLegacyRole(legacyRole);
    }

    private static UUID uuidClaim(Claims claims, String key, UUID fallback) {
        Object value = claims.get(key);
        if (value == null) {
            if (fallback != null) return fallback;
            throw new IllegalArgumentException("Missing claim: " + key);
        }
        try {
            return UUID.fromString(String.valueOf(value));
        } catch (IllegalArgumentException ex) {
            if (fallback != null) return fallback;
            throw ex;
        }
    }

    private static String stringClaim(Claims claims, String key) {
        Object value = claims.get(key);
        return value == null ? null : String.valueOf(value);
    }

    private static String toAuthority(String role) {
        return "ROLE_" + role.replaceAll("[^A-Za-z0-9]+", "_").toUpperCase();
    }

    private static String normalizeLicenseType(String rawValue) {
        if (rawValue == null) return "offline";
        String normalized = rawValue.trim().toLowerCase();
        return "online".equals(normalized) ? "online" : "offline";
    }
}
