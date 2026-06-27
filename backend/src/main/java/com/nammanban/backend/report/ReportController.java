package com.nammanban.backend.report;

import com.nammanban.backend.common.TenantContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/reports")
public class ReportController {

    private final JdbcTemplate jdbc;

    public ReportController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/inventory-dashboard")
    public Map<String, Object> getInventoryDashboard(
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to,
            @RequestParam(required = false) String productId,
            @RequestParam(required = false) String categoryId) {

        UUID tenantId = TenantContext.tenantId();
        
        Instant f = from != null ? Instant.parse(from + "T00:00:00Z") : Instant.parse("2020-01-01T00:00:00Z");
        Instant t = to != null ? Instant.parse(to + "T23:59:59Z") : Instant.now();

        String sql = """
            SELECT
              p.server_id as id,
              p.name,
              COALESCE(p.unit, 'pcs') as unit,
              COALESCE(p.unit, 'pcs') as wholesale_unit,
              COALESCE(p.unit, 'pcs') as retail_unit,
              1.0 as wholesale_to_retail_qty,
              p.selling_price,
              p.selling_price as retail_price,
              p.wholesale_price,
              CASE
                WHEN LOWER(COALESCE(p.unit, '')) IN ('kg', 'kilogram', 'l', 'litre', 'liter')
                  THEN p.stock_quantity / 1000.0
                ELSE p.stock_quantity
              END as current_stock,

              COALESCE(pur.total_purchased_qty, 0) as total_purchased_qty,
              COALESCE(pur.total_purchase_value, 0) as total_purchase_value,

              COALESCE(wsales.total_wholesale_qty, 0) as total_wholesale_sold_qty,
              COALESCE(wsales.total_wholesale_value, 0) as total_wholesale_sold_value,

              COALESCE(rsales.total_retail_qty, 0) as total_retail_sold_qty,
              COALESCE(rsales.total_retail_value, 0) as total_retail_sold_value,

              COALESCE(
                COALESCE(wsales.total_wholesale_qty,0)
                + COALESCE(rsales.total_retail_qty, 0),
                0
              ) as total_sold_base_qty,

              COALESCE(c.name, 'Uncategorized') as category_name

            FROM app_core.products p
            LEFT JOIN app_core.categories c ON c.server_id = p.category_id

            LEFT JOIN (
              SELECT pi.product_id,
                SUM(pi.quantity) as total_purchased_qty,
                SUM(pi.total_cost) as total_purchase_value
              FROM app_core.purchase_items pi
              JOIN app_core.purchases pu ON pu.server_id = pi.purchase_id
              WHERE pu.purchase_date BETWEEN ? AND ? AND pu.tenant_id = ?
              GROUP BY pi.product_id
            ) pur ON pur.product_id = p.server_id

            LEFT JOIN (
              SELECT bi.product_id,
                SUM(bi.quantity) as total_wholesale_qty,
                SUM(bi.total_price) as total_wholesale_value
              FROM app_core.bill_items bi
              JOIN app_core.bills b ON b.server_id = bi.bill_id
              WHERE b.created_at BETWEEN ? AND ? AND b.tenant_id = ?
                AND COALESCE(bi.sale_type, 'retail') = 'wholesale'
                AND (b.status IS NULL OR b.status != 'cancelled')
              GROUP BY bi.product_id
            ) wsales ON wsales.product_id = p.server_id

            LEFT JOIN (
              SELECT bi.product_id,
                SUM(bi.quantity) as total_retail_qty,
                SUM(bi.total_price) as total_retail_value
              FROM app_core.bill_items bi
              JOIN app_core.bills b ON b.server_id = bi.bill_id
              WHERE b.created_at BETWEEN ? AND ? AND b.tenant_id = ?
                AND COALESCE(bi.sale_type, 'retail') != 'wholesale'
                AND (b.status IS NULL OR b.status != 'cancelled')
              GROUP BY bi.product_id
            ) rsales ON rsales.product_id = p.server_id

            WHERE p.tenant_id = ? AND p.is_active = true
        """;

        List<Object> args = new ArrayList<>();
        args.add(Timestamp.from(f));
        args.add(Timestamp.from(t));
        args.add(tenantId);
        
        args.add(Timestamp.from(f));
        args.add(Timestamp.from(t));
        args.add(tenantId);

        args.add(Timestamp.from(f));
        args.add(Timestamp.from(t));
        args.add(tenantId);

        args.add(tenantId);

        if (productId != null && !productId.isBlank()) {
            sql += " AND p.server_id = ? ";
            args.add(UUID.fromString(productId));
        }
        if (categoryId != null && !categoryId.isBlank()) {
            sql += " AND p.category_id = ? ";
            args.add(UUID.fromString(categoryId));
        }

        sql += " ORDER BY p.name ASC ";

        List<Map<String, Object>> rows = jdbc.queryForList(sql, args.toArray());

        return Map.of("reports", rows);
    }
}
