package com.nammananban.ecommerce.service;

import com.nammananban.ecommerce.dto.EcommerceDtos.AddressRequest;
import com.nammananban.ecommerce.dto.EcommerceDtos.EcPrincipal;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class AddressBookService {
    private final JdbcTemplate jdbc;

    public AddressBookService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Map<String, Object>> listAddresses(EcPrincipal principal) {
        return jdbc.queryForList("""
                SELECT server_id, full_name, phone, address_line1, address_line2, city, state, pincode,
                       country, is_default, label, created_at, updated_at
                FROM app_core.ec_addresses
                WHERE ec_customer_id = ? AND tenant_id = ?
                ORDER BY is_default DESC, created_at ASC
                """, principal.customerId(), principal.tenantId());
    }

    @Transactional
    public Map<String, Object> addAddress(AddressRequest request, EcPrincipal principal) {
        if (request.isDefault()) {
            jdbc.update("""
                    UPDATE app_core.ec_addresses
                    SET is_default = false, updated_at = now()
                    WHERE ec_customer_id = ? AND tenant_id = ?
                    """, principal.customerId(), principal.tenantId());
        }
        UUID id = jdbc.queryForObject("""
                INSERT INTO app_core.ec_addresses(
                    server_id, tenant_id, ec_customer_id, full_name, phone, address_line1, address_line2,
                    city, state, pincode, country, is_default, label, created_at, updated_at
                ) VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, now(), now())
                RETURNING server_id
                """, UUID.class,
                principal.tenantId(), principal.customerId(),
                request.fullName(), request.phone(), request.addressLine1(), request.addressLine2(),
                request.city(), request.state(), request.pincode(),
                request.country() == null ? "India" : request.country(),
                request.isDefault(),
                request.label() == null ? "home" : request.label());
        if (request.isDefault()) {
            jdbc.update("UPDATE app_core.ec_customers SET default_address_id = ?, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                    id, principal.customerId(), principal.tenantId());
        }
        return jdbc.queryForMap("SELECT * FROM app_core.ec_addresses WHERE server_id = ? AND tenant_id = ?", id, principal.tenantId());
    }

    @Transactional
    public Map<String, Object> updateAddress(UUID addressId, AddressRequest request, EcPrincipal principal) {
        if (request.isDefault()) {
            jdbc.update("UPDATE app_core.ec_addresses SET is_default = false, updated_at = now() WHERE ec_customer_id = ? AND tenant_id = ?",
                    principal.customerId(), principal.tenantId());
        }
        jdbc.update("""
                UPDATE app_core.ec_addresses
                SET full_name = ?, phone = ?, address_line1 = ?, address_line2 = ?,
                    city = ?, state = ?, pincode = ?, country = ?, is_default = ?, label = ?, updated_at = now()
                WHERE server_id = ? AND ec_customer_id = ? AND tenant_id = ?
                """,
                request.fullName(), request.phone(), request.addressLine1(), request.addressLine2(),
                request.city(), request.state(), request.pincode(),
                request.country() == null ? "India" : request.country(),
                request.isDefault(),
                request.label() == null ? "home" : request.label(),
                addressId, principal.customerId(), principal.tenantId());
        if (request.isDefault()) {
            jdbc.update("UPDATE app_core.ec_customers SET default_address_id = ?, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                    addressId, principal.customerId(), principal.tenantId());
        }
        return jdbc.queryForMap("SELECT * FROM app_core.ec_addresses WHERE server_id = ? AND tenant_id = ?", addressId, principal.tenantId());
    }

    @Transactional
    public Map<String, Object> deleteAddress(UUID addressId, EcPrincipal principal) {
        jdbc.update("DELETE FROM app_core.ec_addresses WHERE server_id = ? AND ec_customer_id = ? AND tenant_id = ?",
                addressId, principal.customerId(), principal.tenantId());
        return Map.of("status", "ok", "deleted", addressId);
    }

    @Transactional
    public Map<String, Object> setDefault(UUID addressId, EcPrincipal principal) {
        jdbc.update("UPDATE app_core.ec_addresses SET is_default = false, updated_at = now() WHERE ec_customer_id = ? AND tenant_id = ?",
                principal.customerId(), principal.tenantId());
        jdbc.update("UPDATE app_core.ec_addresses SET is_default = true, updated_at = now() WHERE server_id = ? AND ec_customer_id = ? AND tenant_id = ?",
                addressId, principal.customerId(), principal.tenantId());
        jdbc.update("UPDATE app_core.ec_customers SET default_address_id = ?, updated_at = now() WHERE server_id = ? AND tenant_id = ?",
                addressId, principal.customerId(), principal.tenantId());
        return Map.of("status", "ok", "defaultAddressId", addressId);
    }
}
