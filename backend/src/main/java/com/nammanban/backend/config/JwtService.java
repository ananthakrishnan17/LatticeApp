package com.nammanban.backend.config;

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
public class JwtService {
    private final SecretKey key;
    private final String issuer;
    private final long minutes;

    public JwtService(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.issuer}") String issuer,
            @Value("${app.jwt.access-token-minutes}") long minutes
    ) {
        if (secret == null || secret.length() < 32) {
            throw new IllegalArgumentException(
                    "JWT secret must be at least 32 characters (256 bits for HMAC-SHA256). Got: "
                            + (secret == null ? "null" : secret.length()));
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.issuer = issuer;
        this.minutes = minutes;
    }

    public String issueToken(
            UUID tenantId,
            UUID organizationId,
            UUID branchId,
            String deviceId,
            String username,
            String role,
            String legacyRole,
            String licenseType
    ) {
        Instant now = Instant.now();
        return Jwts.builder()
                .issuer(issuer)
                .subject(username)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(minutes, ChronoUnit.MINUTES)))
                .claims(Map.of(
                        "tenant_id", tenantId.toString(),
                        "organization_id", organizationId.toString(),
                        "branch_id", branchId.toString(),
                        "device_id", deviceId,
                        "role", role,
                        "legacy_role", legacyRole,
                        "license_type", licenseType != null ? licenseType : "offline"
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
