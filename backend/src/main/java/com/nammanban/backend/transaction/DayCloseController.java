package com.nammanban.backend.transaction;

import com.nammanban.backend.common.TenantContext;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/day-close")
public class DayCloseController {

    private final JdbcTemplate jdbc;

    public DayCloseController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record DayCloseUpsertRequest(
            @NotNull UUID clientRecordId,
            @NotNull String closeDate,
            BigDecimal cashOpening,
            @NotNull BigDecimal cashClosing,
            BigDecimal cashVariance,
            BigDecimal totalSales,
            BigDecimal totalExpenses,
            BigDecimal totalReturns,
            BigDecimal totalPurchases,
            BigDecimal cashSales,
            BigDecimal digitalSales,
            Integer billCount,
            String notes,
            String closedBy,
            Instant createdAt,
            Instant updatedAt
    ) {}

    private static BigDecimal dec(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    @PostMapping("/upsert")
    @Transactional
    public Map<String, Object> upsert(@Valid @RequestBody DayCloseUpsertRequest request) {
        UUID tenantId = TenantContext.tenantId();
        String deviceId = TenantContext.deviceId();
        Instant createdAt = request.createdAt() == null ? Instant.now() : request.createdAt();
        Instant updatedAt = request.updatedAt() == null ? createdAt : request.updatedAt();

        int inserted = jdbc.update("""
            INSERT INTO app_core.day_close(
              tenant_id, client_record_id, device_id, close_date,
              cash_opening, cash_closing, cash_variance,
              total_sales, total_expenses, total_returns, total_purchases,
              cash_sales, digital_sales, bill_count,
              notes, closed_by, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (tenant_id, client_record_id)
            DO UPDATE SET
              cash_closing = excluded.cash_closing,
              cash_variance = excluded.cash_variance,
              total_sales = excluded.total_sales,
              total_expenses = excluded.total_expenses,
              total_returns = excluded.total_returns,
              total_purchases = excluded.total_purchases,
              cash_sales = excluded.cash_sales,
              digital_sales = excluded.digital_sales,
              bill_count = excluded.bill_count,
              notes = excluded.notes,
              closed_by = excluded.closed_by,
              updated_at = excluded.updated_at
            WHERE day_close.updated_at <= excluded.updated_at
            """,
            tenantId, request.clientRecordId(), deviceId,
            Date.valueOf(LocalDate.parse(request.closeDate())),
            dec(request.cashOpening()), dec(request.cashClosing()), dec(request.cashVariance()),
            dec(request.totalSales()), dec(request.totalExpenses()), dec(request.totalReturns()),
            dec(request.totalPurchases()), dec(request.cashSales()), dec(request.digitalSales()),
            request.billCount() == null ? 0 : request.billCount(),
            request.notes(), request.closedBy(),
            Timestamp.from(createdAt), Timestamp.from(updatedAt)
        );

        return Map.of("status", "ok", "clientRecordId", request.clientRecordId());
    }

    @GetMapping
    public Map<String, Object> list(
            @RequestParam(required = false) String since,
            @RequestParam(defaultValue = "30") int limit
    ) {
        UUID tenantId = TenantContext.tenantId();
        Instant sinceInstant = since != null ? Instant.parse(since) : Instant.EPOCH;
        var rows = jdbc.queryForList("""
            SELECT server_id, client_record_id, close_date,
                   cash_opening, cash_closing, cash_variance,
                   total_sales, total_expenses, total_returns, total_purchases,
                   cash_sales, digital_sales, bill_count,
                   notes, closed_by, created_at, updated_at
            FROM app_core.day_close
            WHERE tenant_id = ? AND updated_at > ?
            ORDER BY close_date DESC
            LIMIT ?
            """, tenantId, Timestamp.from(sinceInstant), limit);
        return Map.of("dayCloseRecords", rows);
    }
}
