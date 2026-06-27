package com.nammananban.ecommerce.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;

@Service
public class PaymentService {
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final String razorpayKeyId;
    private final String razorpayKeySecret;

    public PaymentService(
            ObjectMapper objectMapper,
            @Value("${razorpay.key-id:}") String razorpayKeyId,
            @Value("${razorpay.key-secret:}") String razorpayKeySecret
    ) {
        this.objectMapper = objectMapper;
        this.razorpayKeyId = razorpayKeyId;
        this.razorpayKeySecret = razorpayKeySecret;
    }

    public Map<String, Object> createRazorpayOrder(String orderNumber, BigDecimal amount) {
        try {
            String auth = Base64.getEncoder().encodeToString((razorpayKeyId + ":" + razorpayKeySecret).getBytes(StandardCharsets.UTF_8));
            String payload = objectMapper.writeValueAsString(Map.of(
                    "amount", amount.multiply(BigDecimal.valueOf(100)).intValueExact(),
                    "currency", "INR",
                    "receipt", orderNumber
            ));
            HttpRequest request = HttpRequest.newBuilder(URI.create("https://api.razorpay.com/v1/orders"))
                    .header("Authorization", "Basic " + auth)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(payload, StandardCharsets.UTF_8))
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("Razorpay order creation failed: " + response.body());
            }
            return objectMapper.readValue(response.body(), new TypeReference<>() {});
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to create Razorpay order", ex);
        }
    }

    public boolean verifySignature(String gatewayOrderId, String gatewayPaymentId, String gatewaySignature) {
        try {
            String payload = gatewayOrderId + "|" + gatewayPaymentId;
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(razorpayKeySecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] digest = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            StringBuilder encoded = new StringBuilder();
            for (byte b : digest) {
                encoded.append(String.format("%02x", b));
            }
            return encoded.toString().equals(gatewaySignature);
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to verify Razorpay signature", ex);
        }
    }
}
