package com.nammananban.ecommerce.config;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.service.EcJwtService;
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
import java.util.List;
import java.util.UUID;

@Component
public class EcJwtAuthFilter extends OncePerRequestFilter {
    private final EcJwtService ecJwtService;

    public EcJwtAuthFilter(EcJwtService ecJwtService) {
        this.ecJwtService = ecJwtService;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return !path.startsWith("/ec/")
                || path.startsWith("/ec/store/")
                || path.startsWith("/ec/auth/")
                || path.startsWith("/actuator/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header == null || !header.startsWith("Bearer ")) {
            String path = request.getRequestURI();
            if (path.startsWith("/ec/cart/") || path.startsWith("/ec/checkout/")) {
                filterChain.doFilter(request, response);
                return;
            }
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Missing ecommerce token");
            return;
        }
        try {
            Claims claims = ecJwtService.parse(header.substring(7));
            String role = claims.get("role", String.class);
            if (role == null || role.isBlank()) {
                response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid ecommerce token: missing role");
                return;
            }
            EcPrincipal principal = new EcPrincipal(
                    UUID.fromString(String.valueOf(claims.get("ec_customer_id"))),
                    UUID.fromString(String.valueOf(claims.get("tenant_id"))),
                    UUID.fromString(String.valueOf(claims.get("storefront_id"))),
                    claims.getSubject(),
                    role
            );
            var authentication = new UsernamePasswordAuthenticationToken(
                    principal, null, List.of(new SimpleGrantedAuthority(role)));
            SecurityContextHolder.getContext().setAuthentication(authentication);
            filterChain.doFilter(request, response);
        } catch (Exception ex) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid ecommerce token");
        } finally {
            SecurityContextHolder.clearContext();
        }
    }
}
