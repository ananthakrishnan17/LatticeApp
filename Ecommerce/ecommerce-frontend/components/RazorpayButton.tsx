"use client";

import { useState } from "react";
import api from "@/lib/api";

type RazorpayButtonProps = {
  orderId: string;
  amount: number;
  onSuccess?: () => void;
  onFailure?: (reason: string) => void;
};

declare global {
  interface Window {
    Razorpay: new (options: Record<string, unknown>) => { open(): void };
  }
}

function loadRazorpayScript(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (document.getElementById("razorpay-checkout-js")) {
      resolve();
      return;
    }
    const script = document.createElement("script");
    script.id = "razorpay-checkout-js";
    script.src = "https://checkout.razorpay.com/v1/checkout.js";
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("Failed to load Razorpay script"));
    document.body.appendChild(script);
  });
}

export function RazorpayButton({ orderId, amount, onSuccess, onFailure }: RazorpayButtonProps) {
  const [loading, setLoading] = useState(false);

  const openCheckout = async () => {
    setLoading(true);
    try {
      await loadRazorpayScript();

      const { data: initiateData } = await api.post("/ec/checkout/payment/initiate", { orderId });
      const razorpayOrder = initiateData.razorpay as Record<string, unknown>;

      const options: Record<string, unknown> = {
        key: process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID,
        amount: initiateData.amount * 100,
        currency: "INR",
        name: "NammaNanban",
        order_id: razorpayOrder.id,
        handler: async (response: { razorpay_order_id: string; razorpay_payment_id: string; razorpay_signature: string }) => {
          try {
            await api.post("/ec/checkout/payment/verify", {
              orderId,
              gatewayOrderId: response.razorpay_order_id,
              gatewayPaymentId: response.razorpay_payment_id,
              gatewaySignature: response.razorpay_signature,
            });
            onSuccess?.();
          } catch {
            onFailure?.("Payment verification failed. Please contact support.");
          }
        },
        modal: {
          ondismiss: () => setLoading(false),
        },
        theme: { color: "#6d28d9" },
      };

      const rzp = new window.Razorpay(options);
      rzp.open();
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Unable to initiate payment.";
      onFailure?.(message);
      setLoading(false);
    }
  };

  return (
    <button
      type="button"
      onClick={openCheckout}
      disabled={loading}
      className="btn-primary w-full disabled:opacity-60"
    >
      {loading ? "Opening payment…" : `Pay ₹${amount.toFixed(2)} with Razorpay`}
    </button>
  );
}
