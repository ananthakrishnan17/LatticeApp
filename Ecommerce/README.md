# Ecommerce Module

This folder contains a standalone ecommerce extension for Namma Nanban with database migrations, a Spring Boot backend, and a Next.js 14 storefront frontend.

## Structure

- `migrations/` – Flyway SQL migrations `V9` to `V13`
- `ecommerce-backend/` – Spring Boot 3.3.5 module using `JdbcTemplate`, Java records, JWT auth, Razorpay integration hooks, and async notifications
- `ecommerce-frontend/` – Next.js 14 App Router storefront and admin UI scaffold

## Database setup

1. Copy or verify the ecommerce migrations inside `backend/src/main/resources/db/migration/`.
2. Run the backend Flyway migration flow against the PostgreSQL database using the `app_core` schema.
3. Migrations create storefront, catalog, cart, order, payment, coupon, review, notification, and SEO slug tables.

## Backend setup

1. Configure environment variables:
   - `DB_URL`
   - `DB_USERNAME`
   - `DB_PASSWORD`
   - `JWT_SECRET`
   - `EC_JWT_SECRET`
   - `RAZORPAY_KEY_ID`
   - `RAZORPAY_KEY_SECRET`
   - `WHATSAPP_API_URL`
   - `WHATSAPP_TOKEN`
2. Start the module from `Ecommerce/ecommerce-backend` using Gradle.
3. The backend exposes public storefront routes under `/ec/store/**` and authenticated ecommerce customer routes under `/ec/**`.

## Frontend setup

1. Copy `.env.local.example` to `.env.local`.
2. Set `NEXT_PUBLIC_API_BASE`, `NEXT_PUBLIC_RAZORPAY_KEY_ID`, and `NEXT_PUBLIC_STORE_SLUG`.
3. Install dependencies and run the Next.js app from `Ecommerce/ecommerce-frontend`.

## API overview

### Public storefront
- `GET /ec/store/{slug}`
- `GET /ec/store/{slug}/products`
- `GET /ec/store/{slug}/products/{productSlug}`
- `GET /ec/store/{slug}/categories`
- `GET /ec/store/{slug}/search?q=`
- `GET /ec/store/{slug}/banners`
- `GET /ec/store/{slug}/pincode/{pincode}/check`

### Customer auth
- `POST /ec/auth/register`
- `POST /ec/auth/login`
- `POST /ec/auth/verify-email`
- `POST /ec/auth/forgot-password`
- `POST /ec/auth/reset-password`
- `GET /ec/auth/me`
- `PUT /ec/auth/me`

### Cart and checkout
- `GET/POST/PUT/DELETE /ec/cart/**`
- `POST /ec/cart/apply-coupon`
- `POST /ec/cart/merge`
- `POST /ec/checkout/validate`
- `POST /ec/checkout/create-order`
- `POST /ec/checkout/payment/initiate`
- `POST /ec/checkout/payment/verify`

### Orders, reviews, wishlist
- `GET /ec/orders`
- `GET /ec/orders/{number}`
- `POST /ec/orders/{id}/cancel`
- `POST /ec/orders/{id}/return-request`
- `POST /ec/reviews`
- `GET /ec/reviews/{listingId}`
- `GET/POST/DELETE /ec/wishlist/**`

### Admin
- `GET/POST/PUT/DELETE /ec/admin/listings`
- `POST /ec/admin/listings/{id}/images`
- `PUT /ec/admin/listings/{id}/images/reorder`
- `GET /ec/admin/orders`
- `PUT /ec/admin/orders/{id}`
- `POST /ec/admin/orders/{id}/shipment`
- `GET /ec/admin/analytics/dashboard`
- `GET /ec/admin/analytics/top-products`
- `GET /ec/admin/analytics/abandoned-carts`

## Notes

- The backend uses plain SQL with `JdbcTemplate`; no JPA entities are used.
- Ecommerce JWTs are separate from the POS JWTs and include `ec_customer_id`, `tenant_id`, and `storefront_id` claims.
- Payment verification uses Razorpay HMAC SHA-256 validation before order confirmation and stock deduction.
