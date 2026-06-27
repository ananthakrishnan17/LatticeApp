package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.NotificationPreferencesRequest;
import com.nammananban.ecommerce.service.EcAuthService;
import jakarta.validation.Valid;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ec/account/notification-preferences")
public class NotificationPreferencesController {
    private final JdbcTemplate jdbc;
    private final EcAuthService ecAuthService;

    public NotificationPreferencesController(JdbcTemplate jdbc, EcAuthService ecAuthService) {
        this.jdbc = jdbc;
        this.ecAuthService = ecAuthService;
    }

    @GetMapping
    public Map<String, Object> get() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        try {
            return jdbc.queryForMap("""
                    SELECT email_enabled, sms_enabled, whatsapp_enabled,
                           order_updates, price_drop_alerts, stock_alerts, updated_at
                    FROM app_core.ec_notification_preferences
                    WHERE ec_customer_id = ? AND tenant_id = ?
                    """, principal.customerId(), principal.tenantId());
        } catch (EmptyResultDataAccessException e) {
            // Return defaults if no row exists yet
            return Map.of(
                    "email_enabled", true,
                    "sms_enabled", false,
                    "whatsapp_enabled", true,
                    "order_updates", true,
                    "price_drop_alerts", true,
                    "stock_alerts", true
            );
        }
    }

    @PutMapping
    public Map<String, Object> upsert(@Valid @RequestBody NotificationPreferencesRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        jdbc.update("""
                INSERT INTO app_core.ec_notification_preferences
                    (server_id, tenant_id, ec_customer_id, email_enabled, sms_enabled, whatsapp_enabled,
                     order_updates, price_drop_alerts, stock_alerts, created_at, updated_at)
                VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, ?, now(), now())
                ON CONFLICT (ec_customer_id, tenant_id) DO UPDATE
                    SET email_enabled = EXCLUDED.email_enabled,
                        sms_enabled = EXCLUDED.sms_enabled,
                        whatsapp_enabled = EXCLUDED.whatsapp_enabled,
                        order_updates = EXCLUDED.order_updates,
                        price_drop_alerts = EXCLUDED.price_drop_alerts,
                        stock_alerts = EXCLUDED.stock_alerts,
                        updated_at = now()
                """,
                principal.tenantId(), principal.customerId(),
                request.emailEnabled(), request.smsEnabled(), request.whatsappEnabled(),
                request.orderUpdates(), request.priceDropAlerts(), request.stockAlerts());
        return Map.of("status", "saved");
    }
}
