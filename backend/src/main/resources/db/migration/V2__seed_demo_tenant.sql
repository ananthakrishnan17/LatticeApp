INSERT INTO app_core.tenants(server_id, tenant_code, name)
VALUES ('11111111-1111-1111-1111-111111111111', 'demo-tenant', 'Demo Tenant')
ON CONFLICT (tenant_code) DO NOTHING;

-- password: admin123
INSERT INTO app_core.users(server_id, tenant_id, username, password_hash, role)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  'admin',
  '$2a$10$RAXlAjklqRPw3Y6j8fROTOQfWn2hMhN8jY5OnKwZq2UTWyxlL6Z5.',
  'admin'
)
ON CONFLICT (tenant_id, username) DO NOTHING;
