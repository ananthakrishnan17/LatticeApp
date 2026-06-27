package com.nammananban.ecommerce.controller;

import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import com.nammananban.ecommerce.dto.EcommerceDtos.SupportTicketAdminUpdateRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.SupportTicketRequest;
import com.nammananban.ecommerce.service.EcAuthService;
import jakarta.validation.Valid;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
public class SupportTicketController {
    private final JdbcTemplate jdbc;
    private final EcAuthService ecAuthService;

    public SupportTicketController(JdbcTemplate jdbc, EcAuthService ecAuthService) {
        this.jdbc = jdbc;
        this.ecAuthService = ecAuthService;
    }

    /** Customer: submit a new support ticket. */
    @PostMapping("/ec/support/tickets")
    public Map<String, Object> create(@Valid @RequestBody SupportTicketRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        UUID ticketId = UUID.randomUUID();
        String ticketNumber = "SUP-" + ticketId.toString().substring(0, 8).toUpperCase();
        jdbc.update("""
                INSERT INTO app_core.ec_support_tickets
                    (server_id, tenant_id, storefront_id, ec_customer_id, subject, details, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, 'open', now(), now())
                """,
                ticketId, principal.tenantId(), principal.storefrontId(),
                principal.customerId(), request.subject(), request.details());
        return Map.of("serverId", ticketId, "ticketNumber", ticketNumber, "status", "open");
    }

    /** Customer: list own tickets. */
    @GetMapping("/ec/support/tickets")
    public List<Map<String, Object>> listOwn() {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        return jdbc.queryForList("""
                SELECT server_id, subject, status, admin_note, created_at, updated_at
                FROM app_core.ec_support_tickets
                WHERE ec_customer_id = ? AND tenant_id = ?
                ORDER BY created_at DESC
                """, principal.customerId(), principal.tenantId());
    }

    /** Admin: list all tickets, optionally filtered by status. */
    @GetMapping("/ec/admin/support/tickets")
    public List<Map<String, Object>> adminList(@RequestParam(required = false) String status) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        if (status != null && !status.isBlank()) {
            return jdbc.queryForList("""
                    SELECT t.server_id, t.subject, t.details, t.status, t.admin_note,
                           c.email AS customer_email, t.created_at, t.updated_at
                    FROM app_core.ec_support_tickets t
                    LEFT JOIN app_core.ec_customers c ON c.server_id = t.ec_customer_id
                    WHERE t.tenant_id = ? AND t.status = ?
                    ORDER BY t.created_at DESC
                    """, principal.tenantId(), status);
        }
        return jdbc.queryForList("""
                SELECT t.server_id, t.subject, t.details, t.status, t.admin_note,
                       c.email AS customer_email, t.created_at, t.updated_at
                FROM app_core.ec_support_tickets t
                LEFT JOIN app_core.ec_customers c ON c.server_id = t.ec_customer_id
                WHERE t.tenant_id = ?
                ORDER BY t.created_at DESC
                """, principal.tenantId());
    }

    /** Admin: update ticket status / add note. */
    @PutMapping("/ec/admin/support/tickets/{id}")
    public Map<String, Object> adminUpdate(@PathVariable UUID id, @Valid @RequestBody SupportTicketAdminUpdateRequest request) {
        EcPrincipal principal = ecAuthService.requirePrincipal();
        jdbc.update("""
                UPDATE app_core.ec_support_tickets
                SET status = ?, admin_note = ?, updated_at = now()
                WHERE server_id = ? AND tenant_id = ?
                """, request.status(), request.adminNote(), id, principal.tenantId());
        return Map.of("status", request.status(), "serverId", id);
    }
}
