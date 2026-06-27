# Java Backend + Flutter Direct Write Integration

## Backend module
- Path: `/home/runner/work/NammaNanban-2.0/NammaNanban-2.0/backend`
- Stack: Spring Boot 3, Java 21, PostgreSQL, Flyway, JWT, OpenAPI

## Required headers
- `Authorization: ******
- `X-Tenant-Id: <tenant-uuid>`
- `X-Device-Id: <device-id>`

## Auth flow
1. Flutter setup stores the backend base URL and tenant code before login.
2. Flutter calls `POST /auth/login` with `tenantCode`, `username`, `password`, and `deviceId`.
3. Backend validates credentials, binds device, returns JWT.
4. Flutter stores JWT securely and includes headers in every API call.

## Direct write flow (Flutter)
1. Generate `client_record_id` (UUIDv7) on create.
2. Write to local SQLite immediately.
3. If online, push directly to the matching domain endpoint such as `/products/upsert`, `/categories/upsert`, `/customers/upsert`, or `/bills/upsert`.
4. If offline in online-only mode, reject the write until connectivity is restored.

## Conflict handling
- Master data: optimistic version + timestamp fallback.
- Transactional data (bills): immutable insert behavior; duplicates are rejected and logged, correction should be done via reversal entries.

## Security notes
- JWT carries tenant/device claims and must match headers.
- Tenant isolation enforced in every query using tenant context.
- Keep DB credentials and JWT secret in environment variables.
