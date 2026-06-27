package com.nammananban.ecommerce.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;

@Service
public class NotificationService {
    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final String whatsappApiUrl;
    private final String whatsappToken;
    private final String emailFrom;

    public NotificationService(
            JdbcTemplate jdbc,
            ObjectMapper objectMapper,
            @Value("${whatsapp.api-url:}") String whatsappApiUrl,
            @Value("${whatsapp.token:}") String whatsappToken,
            @Value("${email.from:noreply@nammananban.in}") String emailFrom
    ) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.whatsappApiUrl = whatsappApiUrl;
        this.whatsappToken = whatsappToken;
        this.emailFrom = emailFrom;
    }

    @Async
    public void sendEmailVerification(UUID tenantId, UUID customerId, String email, String token) {
        enqueue(tenantId, customerId, "email", "verify-email", Map.of("email", email, "token", token, "from", emailFrom));
        sendHttp(Map.of("channel", "email", "email", email, "token", token, "type", "verify-email"));
    }

    @Async
    public void sendPasswordReset(UUID tenantId, UUID customerId, String email, String token) {
        enqueue(tenantId, customerId, "email", "reset-password", Map.of("email", email, "token", token, "from", emailFrom));
        sendHttp(Map.of("channel", "email", "email", email, "token", token, "type", "reset-password"));
    }

    @Async
    public void sendOrderConfirmation(UUID tenantId, UUID customerId, UUID orderId, String email, String orderNumber) {
        enqueue(tenantId, customerId, "email", "order-confirmed", Map.of("email", email, "orderNumber", orderNumber, "orderId", orderId));
        sendHttp(Map.of("channel", "email", "email", email, "type", "order-confirmed", "orderNumber", orderNumber));
    }

    private void enqueue(UUID tenantId, UUID customerId, String channel, String type, Map<String, Object> payload) {
        jdbc.update("""
                INSERT INTO app_core.ec_notifications(server_id, tenant_id, ec_customer_id, channel, type, status, payload, created_at)
                VALUES (gen_random_uuid(), ?, ?, ?, ?, 'pending', ?::jsonb, now())
                """, tenantId, customerId, channel, type, writeJson(payload));
    }

    private void sendHttp(Map<String, Object> payload) {
        if (whatsappApiUrl == null || whatsappApiUrl.isBlank()) {
            return;
        }
        try {
            HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(whatsappApiUrl))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(writeJson(payload), StandardCharsets.UTF_8));
            if (whatsappToken != null && !whatsappToken.isBlank()) {
                builder.header("Authorization", "Bearer " + whatsappToken);
            }
            httpClient.send(builder.build(), HttpResponse.BodyHandlers.discarding());
        } catch (Exception ignored) {
        }
    }

    private String writeJson(Map<String, Object> payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (Exception ex) {
            throw new IllegalArgumentException("Failed to serialize notification payload", ex);
        }
    }
}
