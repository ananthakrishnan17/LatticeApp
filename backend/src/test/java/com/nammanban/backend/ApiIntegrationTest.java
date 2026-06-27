package com.nammanban.backend;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
class ApiIntegrationTest {

    private static final BCryptPasswordEncoder ENCODER = new BCryptPasswordEncoder();

    @Autowired
    JdbcTemplate jdbc;

    @Autowired
    MockMvc mockMvc;

    @Autowired
    ObjectMapper objectMapper;

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16")
            .withDatabaseName("nammanban")
            .withUsername("postgres")
            .withPassword("postgres");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Test
    void containerStarts() {
        assertThat(postgres.isRunning()).isTrue();
    }

    @Test
    void loginSupportsFollowUpUserAndSubscriptionCalls() throws Exception {
        String passwordHash = ENCODER.encode("admin123");
        jdbc.update("""
                UPDATE app_core.users
                SET password_hash = ?,
                    mobile_number = ?
                WHERE tenant_id = ? AND username = ?
                """,
                passwordHash,
                "9000000001",
                java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"),
                "admin");
        // Set license to "online" so data API calls are permitted.
        jdbc.update("""
                UPDATE app_core.tenant_licenses
                SET license_type = 'online'
                WHERE tenant_id = ?
                """,
                java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"));

        var loginResponse = mockMvc.perform(post("/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "phoneNumber", "9000000001",
                                "password", "admin123",
                                "deviceId", "test-device"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.tenantId").isNotEmpty())
                .andExpect(jsonPath("$.licenseType").value("online"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        @SuppressWarnings("unchecked")
        Map<String, Object> body = objectMapper.readValue(loginResponse, Map.class);
        String accessToken = String.valueOf(body.get("accessToken"));
        String tenantId = String.valueOf(body.get("tenantId"));

        mockMvc.perform(get("/users/me")
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Tenant-Id", tenantId)
                        .header("X-Device-Id", "test-device"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("admin"));

        mockMvc.perform(get("/subscription/status")
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Tenant-Id", tenantId)
                        .header("X-Device-Id", "test-device"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.companyName").value("Demo Tenant"))
                .andExpect(jsonPath("$.licenseType").value("online"));
    }

    @Test
    void offlineLicenseIsBlockedFromDataApi() throws Exception {
        String passwordHash = ENCODER.encode("admin123");
        jdbc.update("""
                UPDATE app_core.users
                SET password_hash = ?,
                    mobile_number = ?
                WHERE tenant_id = ? AND username = ?
                """,
                passwordHash,
                "9000000001",
                java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"),
                "admin");
        // Ensure license is offline for this test.
        jdbc.update("""
                UPDATE app_core.tenant_licenses
                SET license_type = 'offline'
                WHERE tenant_id = ?
                """,
                java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"));

        var loginResponse = mockMvc.perform(post("/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "phoneNumber", "9000000001",
                                "password", "admin123",
                                "deviceId", "test-device"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.licenseType").value("offline"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        @SuppressWarnings("unchecked")
        Map<String, Object> body = objectMapper.readValue(loginResponse, Map.class);
        String accessToken = String.valueOf(body.get("accessToken"));
        String tenantId = String.valueOf(body.get("tenantId"));

        // Data API endpoints must be blocked for offline license.
        mockMvc.perform(get("/users/me")
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Tenant-Id", tenantId)
                        .header("X-Device-Id", "test-device"))
                .andExpect(status().isForbidden());
    }

    @Test
    void billUpsertCreatesNewBillAndReturnsDuplicateOnRetry() throws Exception {
        String passwordHash = ENCODER.encode("admin123");
        jdbc.update("""
                UPDATE app_core.users
                SET password_hash = ?,
                    mobile_number = ?
                WHERE tenant_id = ? AND username = ?
                """,
                passwordHash,
                "9000000001",
                java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"),
                "admin");
        // Set license to "online" so data API calls are permitted.
        jdbc.update("""
                UPDATE app_core.tenant_licenses
                SET license_type = 'online'
                WHERE tenant_id = ?
                """,
                java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"));

        var loginResponse = mockMvc.perform(post("/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "phoneNumber", "9000000001",
                                "password", "admin123",
                                "deviceId", "test-device"
                        ))))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        @SuppressWarnings("unchecked")
        Map<String, Object> loginBody = objectMapper.readValue(loginResponse, Map.class);
        String accessToken = String.valueOf(loginBody.get("accessToken"));
        String tenantId = String.valueOf(loginBody.get("tenantId"));

        String clientRecordId = java.util.UUID.randomUUID().toString();
        // updatedAt must be a UTC ISO-8601 string (with 'Z') so Jackson can
        // deserialize it as Instant. Local-time strings without a timezone
        // designator cause a 400 Bad Request — this test verifies the fix.
        String updatedAt = java.time.Instant.now().toString(); // e.g. "2026-05-21T09:12:02.182Z"

        Map<String, Object> billRequest = new java.util.HashMap<>();
        billRequest.put("clientRecordId", clientRecordId);
        billRequest.put("billNumber", "20260521-091202182");
        billRequest.put("customerName", "Test Customer");
        billRequest.put("totalAmount", 150.00);
        billRequest.put("discountAmount", 0.00);
        billRequest.put("gstTotal", 0.00);
        billRequest.put("paymentMode", "cash");
        billRequest.put("items", java.util.List.of(Map.of(
                "productName", "Test Product",
                "quantity", 3,
                "unit", "piece",
                "unitPrice", 50.00,
                "totalPrice", 150.00,
                "gstRate", 0.00
        )));
        billRequest.put("version", 1);
        billRequest.put("updatedAt", updatedAt);

        // First upsert — should create the bill and return "ok"
        mockMvc.perform(post("/bills/upsert")
                        .contentType(APPLICATION_JSON)
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Tenant-Id", tenantId)
                        .header("X-Device-Id", "test-device")
                        .content(objectMapper.writeValueAsString(billRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ok"));

        // Second upsert with the same clientRecordId — should return "duplicate"
        mockMvc.perform(post("/bills/upsert")
                        .contentType(APPLICATION_JSON)
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Tenant-Id", tenantId)
                        .header("X-Device-Id", "test-device")
                        .content(objectMapper.writeValueAsString(billRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("duplicate"));

        mockMvc.perform(get("/bills")
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Tenant-Id", tenantId)
                        .header("X-Device-Id", "test-device"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.bills[0].bill_number").value("20260521-091202182"))
                .andExpect(jsonPath("$.bills[0].client_record_id").value(clientRecordId));

        // Verify bill row exists in DB
        var bills = jdbc.queryForList(
                "SELECT bill_number FROM app_core.bills WHERE tenant_id = ? AND client_record_id = ?::uuid",
                java.util.UUID.fromString(tenantId),
                clientRecordId);
        assertThat(bills).hasSize(1);
        assertThat(bills.getFirst().get("bill_number")).isEqualTo("20260521-091202182");

        // Verify bill_items were inserted
        var items = jdbc.queryForList(
                "SELECT product_name FROM app_core.bill_items WHERE tenant_id = ?",
                java.util.UUID.fromString(tenantId));
        assertThat(items).isNotEmpty();
        assertThat(items.getFirst().get("product_name")).isEqualTo("Test Product");
    }

    @Test
    void productUpsertRemainsVisibleWhenScopedColumnsExist() throws Exception {
        jdbc.execute("""
                ALTER TABLE app_core.products
                ADD COLUMN organization_id UUID,
                ADD COLUMN branch_id UUID
                """);

        String passwordHash = ENCODER.encode("admin123");
        jdbc.update("""
                UPDATE app_core.users
                SET password_hash = ?,
                    mobile_number = ?
                WHERE tenant_id = ? AND username = ?
                """,
                passwordHash,
                "9000000001",
                java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"),
                "admin");
        jdbc.update("""
                UPDATE app_core.tenant_licenses
                SET license_type = 'online'
                WHERE tenant_id = ?
                """,
                java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"));

        var loginResponse = mockMvc.perform(post("/auth/login")
                        .contentType(APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "phoneNumber", "9000000001",
                                "password", "admin123",
                                "deviceId", "test-device"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.licenseType").value("online"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        @SuppressWarnings("unchecked")
        Map<String, Object> loginBody = objectMapper.readValue(loginResponse, Map.class);
        String accessToken = String.valueOf(loginBody.get("accessToken"));
        String tenantId = String.valueOf(loginBody.get("tenantId"));
        String organizationId = String.valueOf(loginBody.get("organizationId"));
        String branchId = String.valueOf(loginBody.get("branchId"));
        String clientRecordId = java.util.UUID.randomUUID().toString();
        Map<String, Object> productRequest = new java.util.HashMap<>();
        productRequest.put("clientRecordId", clientRecordId);
        productRequest.put("name", "Scoped Product");
        productRequest.put("unit", "piece");
        productRequest.put("sellingPrice", 10.0);
        productRequest.put("purchasePrice", 8.0);
        productRequest.put("wholesalePrice", 9.0);
        productRequest.put("stockQuantity", 5.0);
        productRequest.put("lowStockThreshold", 1.0);
        productRequest.put("gstRate", 0.0);
        productRequest.put("itemType", "physical");
        productRequest.put("version", 1);
        productRequest.put("updatedAt", java.time.Instant.now().toString());
        productRequest.put("deleted", false);

        mockMvc.perform(post("/products/upsert")
                        .contentType(APPLICATION_JSON)
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Tenant-Id", tenantId)
                        .header("X-Device-Id", "test-device")
                        .content(objectMapper.writeValueAsString(productRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.clientRecordId").value(clientRecordId));

        mockMvc.perform(get("/products")
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Tenant-Id", tenantId)
                        .header("X-Device-Id", "test-device"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("Scoped Product"))
                .andExpect(jsonPath("$[0].clientRecordId").value(clientRecordId));

        var products = jdbc.queryForList("""
                SELECT organization_id, branch_id
                FROM app_core.products
                WHERE tenant_id = ? AND client_record_id = ?::uuid
                """,
                java.util.UUID.fromString(tenantId),
                clientRecordId);
        assertThat(products).hasSize(1);
        assertThat(products.getFirst().get("organization_id")).hasToString(organizationId);
        assertThat(products.getFirst().get("branch_id")).hasToString(branchId);
    }
}
