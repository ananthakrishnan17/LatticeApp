package com.nammananban.ecommerce.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.Map;
import java.util.UUID;

@Service
public class EcJwtService {
    private final SecretKey key;
    private final String issuer;
    private final long minutes;

    public EcJwtService(
            @Value("${app.ec-jwt.secret:${app.jwt.ec-secret:0123456789abcdef0123456789abcdef}}") String secret,
            @Value("${app.ec-jwt.issuer:namma-nanban-ecommerce}") String issuer,
            @Value("${app.ec-jwt.access-token-minutes:1440}") long minutes
    ) {
        if (secret.length() < 32) {
            throw new IllegalArgumentException("EC JWT secret must be at least 32 characters");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.issuer = issuer;
        this.minutes = minutes;
    }

    public String issueToken(UUID customerId, UUID tenantId, UUID storefrontId, String email) {
        Instant now = Instant.now();
        return Jwts.builder()
                .issuer(issuer)
                .subject(email)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(minutes, ChronoUnit.MINUTES)))
                .claims(Map.of(
                        "ec_customer_id", customerId.toString(),
                        "tenant_id", tenantId.toString(),
                        "storefront_id", storefrontId.toString(),
                        "role", "CUSTOMER"
                ))
                .signWith(key)
                .compact();
    }

    public String issueAdminToken(UUID adminUserId, UUID tenantId, UUID storefrontId, String username) {
        Instant now = Instant.now();
        return Jwts.builder()
                .issuer(issuer)
                .subject(username)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(minutes, ChronoUnit.MINUTES)))
                .claims(Map.of(
                        "ec_customer_id", adminUserId.toString(),
                        "tenant_id", tenantId.toString(),
                        "storefront_id", storefrontId.toString(),
                        "role", "EC_ADMIN"
                ))
                .signWith(key)
                .compact();
    }

    public Claims parse(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .requireIssuer(issuer)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
