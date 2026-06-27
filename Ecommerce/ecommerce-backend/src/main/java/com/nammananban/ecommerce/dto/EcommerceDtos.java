package com.nammananban.ecommerce.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class EcommerceDtos {
    public record ApiMessage(String status, String message) {}

    public record PagedResponse(List<Map<String, Object>> items, long total, int page, int size) {}

    public record EcPrincipal(UUID customerId, UUID tenantId, UUID storefrontId, String email, String role) {}

    public record AdminLoginRequest(
            @NotNull UUID storefrontId,
            @NotBlank String username,
            @NotBlank String password
    ) {}

    public record RegisterRequest(
            @NotNull UUID storefrontId,
            @Email @NotBlank String email,
            @NotBlank String password,
            String firstName,
            String lastName,
            String phone
    ) {}

    public record LoginRequest(
            @NotNull UUID storefrontId,
            @Email @NotBlank String email,
            @NotBlank String password
    ) {}

    public record AuthResponse(String token, UUID ecCustomerId, UUID tenantId, UUID storefrontId, String email) {}

    public record VerifyEmailRequest(@NotNull UUID storefrontId, @NotBlank String token) {}

    public record ForgotPasswordRequest(@NotNull UUID storefrontId, @Email @NotBlank String email) {}

    public record ResetPasswordRequest(
            @NotNull UUID storefrontId,
            @NotBlank String token,
            @NotBlank String password
    ) {}

    public record UpdateProfileRequest(String firstName, String lastName, String phone) {}

    public record CartItemRequest(
            @NotNull UUID storefrontId,
            @NotNull UUID listingId,
            UUID variantId,
            @Min(1) int quantity,
            String sessionToken
    ) {}

    public record CartItemUpdateRequest(
            @NotNull UUID storefrontId,
            @Min(1) int quantity,
            String sessionToken
    ) {}

    public record CouponRequest(@NotNull UUID storefrontId, @NotBlank String code, String sessionToken) {}

    public record MergeCartRequest(
            @NotNull UUID storefrontId,
            @NotBlank String sourceSessionToken,
            String targetSessionToken
    ) {}

    public record CheckoutValidateRequest(
            @NotNull UUID storefrontId,
            String sessionToken,
            @NotBlank String pincode
    ) {}

    public record CreateOrderRequest(
            @NotNull UUID storefrontId,
            String sessionToken,
            @NotNull Map<String, Object> shippingAddress,
            @NotNull Map<String, Object> billingAddress,
            String paymentMode
    ) {}

    public record PaymentInitiateRequest(@NotNull UUID orderId) {}

    public record PaymentVerifyRequest(
            @NotNull UUID orderId,
            @NotBlank String gatewayOrderId,
            @NotBlank String gatewayPaymentId,
            @NotBlank String gatewaySignature
    ) {}

    public record ReviewSubmitRequest(
            @NotNull UUID listingId,
            @NotNull UUID orderId,
            @Min(1) @Max(5) int rating,
            String title,
            String body
    ) {}

    public record WishlistRequest(@NotNull UUID listingId) {}

    public record AdminListingRequest(
            UUID serverId,
            UUID tenantId,
            UUID storefrontId,
            @NotNull UUID productId,
            @NotBlank String seoSlug,
            @NotNull BigDecimal sellingPrice,
            BigDecimal comparePrice,
            List<String> tags,
            String visibility
    ) {}

    public record ImageUploadRequest(@NotEmpty List<String> imageUrls) {}

    public record ImageReorderItem(@NotNull UUID imageId, @Min(0) int sortOrder, boolean primary) {}

    public record ImageReorderRequest(@NotEmpty List<ImageReorderItem> items) {}

    public record OrderStatusUpdateRequest(@NotBlank String status) {}

    public record ShipmentRequest(
            String courierName,
            String trackingNumber,
            String trackingUrl,
            LocalDate estimatedDelivery
    ) {}

    public record CancelOrderRequest(String reason) {}

    public record ReturnRequest(String reason) {}

    // Address book
    public record AddressRequest(
            @NotBlank String fullName,
            @NotBlank String phone,
            @NotBlank String addressLine1,
            String addressLine2,
            @NotBlank String city,
            @NotBlank String state,
            @NotBlank String pincode,
            String country,
            boolean isDefault,
            String label
    ) {}

    // Loyalty / referral
    public record RedeemPointsRequest(@Min(1) int points) {}

    public record ReferralRequest(@NotBlank String referralCode) {}

    // Product Q&A
    public record QAQuestionRequest(
            @NotNull UUID listingId,
            @NotBlank String question
    ) {}

    public record QAAnswerRequest(@NotBlank String answer) {}

    // Analytics event tracking
    public record StoreEventRequest(
            @NotNull UUID storefrontId,
            @NotBlank String eventType,
            UUID listingId,
            UUID orderId,
            String sessionToken,
            Map<String, Object> meta
    ) {}

    // Back-in-stock alert
    public record StockAlertRequest(
            @NotNull UUID listingId,
            @Email @NotBlank String email
    ) {}

    // Enhanced coupon admin creation
    public record AdminCouponRequest(
            @NotNull UUID storefrontId,
            @NotBlank String code,
            @NotBlank String discountType,
            @NotNull BigDecimal discountValue,
            BigDecimal minOrderAmount,
            BigDecimal maxDiscountCap,
            Integer usageLimit,
            Integer perCustomerLimit,
            boolean firstOrderOnly,
            List<UUID> applicableProducts,
            List<UUID> applicableCategories,
            String validFrom,
            String validUntil
    ) {}

    // Campaign banner scheduling
    public record CampaignRequest(
            @NotNull UUID storefrontId,
            @NotBlank String name,
            @NotBlank String banner,
            @NotBlank String startsAt,
            @NotBlank String endsAt
    ) {}

    // Support ticket
    public record SupportTicketRequest(
            @NotBlank String subject,
            String details
    ) {}

    public record SupportTicketAdminUpdateRequest(
            @NotBlank String status,
            String adminNote
    ) {}

    // Notification preferences
    public record NotificationPreferencesRequest(
            boolean emailEnabled,
            boolean smsEnabled,
            boolean whatsappEnabled,
            boolean orderUpdates,
            boolean priceDropAlerts,
            boolean stockAlerts
    ) {}
}
