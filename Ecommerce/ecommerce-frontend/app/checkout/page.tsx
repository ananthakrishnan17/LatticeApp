"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { AddressForm, AddressValue } from "@/components/AddressForm";
import { RazorpayButton } from "@/components/RazorpayButton";
import { useCartStore } from "@/store/cartStore";
import api from "@/lib/api";
import { asNumber, readApiError, storefrontId, storeSlug } from "@/lib/ecommerce";

type SavedAddress = AddressValue & { id: string; isDefault?: boolean };

const ADDRESS_BOOK_KEY = "ec_saved_addresses";
const ABANDONED_CART_KEY = "ec_abandoned_cart_recovery";
const getAddressFingerprint = (value: AddressValue) =>
  JSON.stringify({
    fullName: value.fullName.trim(),
    phone: value.phone.trim(),
    addressLine1: value.addressLine1.trim(),
    city: value.city.trim(),
    state: value.state.trim(),
    pincode: value.pincode.trim(),
  });

const createLocalId = () => {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  if (typeof crypto !== "undefined" && typeof crypto.getRandomValues === "function") {
    const buffer = new Uint8Array(16);
    crypto.getRandomValues(buffer);
    return `addr-${Array.from(buffer).map((n) => n.toString(16).padStart(2, "0")).join("")}`;
  }
  throw new Error("Secure ID generation is unavailable in this browser.");
};

export default function CheckoutPage() {
  const router = useRouter();
  const { items, coupon, sessionToken, clearCart, subtotal, couponDiscount, total, syncFromServer } = useCartStore();
  const [address, setAddress] = useState<AddressValue | null>(null);
  const [savedAddresses, setSavedAddresses] = useState<SavedAddress[]>([]);
  const [orderId, setOrderId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [placingOrder, setPlacingOrder] = useState(false);
  const [validating, setValidating] = useState(false);
  const [validation, setValidation] = useState<{ serviceable: boolean; inStock: boolean; shippingCharge: number } | null>(null);
  const [guestCheckout, setGuestCheckout] = useState(false);
  const [guestEmail, setGuestEmail] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<"razorpay" | "cod" | "upi">("razorpay");
  const [recoveryOptIn, setRecoveryOptIn] = useState(false);
  const [syncingAddresses, setSyncingAddresses] = useState(false);

  const persistAddressBook = (value: SavedAddress[]) => {
    setSavedAddresses(value);
    if (typeof window !== "undefined") {
      window.localStorage.setItem(ADDRESS_BOOK_KEY, JSON.stringify(value));
    }
  };

  const syncAddressesToServer = async (nextAddresses: SavedAddress[]) => {
    setSyncingAddresses(true);
    try {
      for (const addr of nextAddresses) {
        await api.post("/ec/addresses", {
          fullName: addr.fullName,
          phone: addr.phone,
          addressLine1: addr.addressLine1,
          addressLine2: "",
          city: addr.city,
          state: addr.state,
          pincode: addr.pincode,
          country: "India",
          isDefault: addr.isDefault ?? false,
          label: "",
        }).catch(() => null);
      }
    } catch {
      // local-first fallback
    } finally {
      setSyncingAddresses(false);
    }
  };

  const bootstrapCheckout = useCallback(async () => {
    if (typeof window === "undefined") return;
    const raw = window.localStorage.getItem(ADDRESS_BOOK_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as SavedAddress[];
      setSavedAddresses(parsed);
      const defaultAddress = parsed.find((entry) => entry.isDefault) ?? parsed[0];
      if (defaultAddress) {
        setAddress(defaultAddress);
      }
    }

    try {
      const [{ data: cartData }, profileRes, addressRes] = await Promise.all([
        api.get("/ec/cart/items", { params: { storefrontId, sessionToken } }),
        api.get("/ec/auth/me"),
        api.get("/ec/addresses").catch(() => ({ data: [] })),
      ]);
      syncFromServer(cartData);
      const profile = profileRes.data;
      setAddress((current) =>
        current ?? {
          fullName: [profile.first_name, profile.last_name].filter(Boolean).join(" ").trim(),
          phone: String(profile.phone ?? ""),
          addressLine1: "",
          city: "",
          state: "",
          pincode: "",
        }
      );
      const remote = Array.isArray(addressRes.data) ? addressRes.data : [];
      if (remote.length > 0) {
        const normalized: SavedAddress[] = remote.slice(0, 5).map((entry: Record<string, unknown>, index: number) => ({
          id: String(entry.id ?? createLocalId()),
          fullName: String(entry.fullName ?? ""),
          phone: String(entry.phone ?? ""),
          addressLine1: String(entry.addressLine1 ?? ""),
          city: String(entry.city ?? ""),
          state: String(entry.state ?? ""),
          pincode: String(entry.pincode ?? ""),
          isDefault: Boolean(entry.isDefault ?? index === 0),
        }));
        persistAddressBook(normalized);
      }
    } catch {
      try {
        const { data } = await api.get("/ec/cart/items", { params: { storefrontId, sessionToken } });
        syncFromServer(data);
      } catch {
        // ignore bootstrap cart failures
      }
    }
  }, [sessionToken, syncFromServer]);

  useEffect(() => {
    void bootstrapCheckout();
  }, [bootstrapCheckout]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    if (!recoveryOptIn || items.length === 0) {
      window.localStorage.removeItem(ABANDONED_CART_KEY);
      return;
    }
    window.localStorage.setItem(
      ABANDONED_CART_KEY,
      JSON.stringify({
        savedAt: new Date().toISOString(),
        itemCount: items.length,
        total,
        email: guestCheckout ? guestEmail : undefined,
      })
    );
  }, [guestCheckout, guestEmail, items.length, recoveryOptIn, total]);

  const saveAddress = (value: AddressValue) => {
    try {
      setAddress(value);
      setValidation(null);
      const nextAddress: SavedAddress = { ...value, id: createLocalId() };
      const fingerprint = getAddressFingerprint(value);
      const next = [nextAddress, ...savedAddresses.filter((entry) => getAddressFingerprint(entry) !== fingerprint)]
        .slice(0, 5)
        .map((entry, index) => ({ ...entry, isDefault: index === 0 }));
      persistAddressBook(next);
      void syncAddressesToServer(next);
    } catch {
      setError("Failed to save address. Please try again.");
    }
  };

  const checkPincode = async () => {
    if (!address?.pincode) {
      setError("Please fill pincode to verify serviceability.");
      return;
    }
    setValidating(true);
    setError("");
    try {
      const [pincodeRes, validateRes] = await Promise.all([
        api.get(`/ec/store/${storeSlug}/pincode/${address.pincode}/check`),
        api.post("/ec/checkout/validate", { storefrontId, sessionToken, pincode: address.pincode }),
      ]);
      const serviceable = Boolean(pincodeRes.data?.serviceable) && Boolean(validateRes.data?.serviceable);
      setValidation({
        serviceable,
        inStock: Boolean(validateRes.data?.inStock),
        shippingCharge: asNumber(validateRes.data?.shippingCharge),
      });
      if (!serviceable) {
        setError("Delivery is not available for this pincode.");
      } else if (!validateRes.data?.inStock) {
        setError("One or more items are out of stock.");
      }
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to validate checkout details."));
    } finally {
      setValidating(false);
    }
  };

  const handlePlaceOrder = async () => {
    if (!address) return;
    if (guestCheckout && !guestEmail.trim()) {
      setError("Guest checkout requires an email for order updates.");
      return;
    }
    if (!validation?.serviceable || !validation.inStock) {
      setError("Please complete pincode/serviceability validation before payment.");
      return;
    }
    setError("");
    setPlacingOrder(true);
    try {
      const { data } = await api.post("/ec/checkout/create-order", {
        storefrontId,
        sessionToken,
        shippingAddress: address,
        billingAddress: address,
        paymentMethod,
        guestCheckout,
        guestEmail: guestCheckout ? guestEmail.trim() : undefined,
        abandonedCartRecoveryOptIn: recoveryOptIn,
      });
      setOrderId(data.orderId);
      if (paymentMethod === "cod") {
        handlePaymentSuccess();
      }
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to create order."));
    } finally {
      setPlacingOrder(false);
    }
  };

  const payable = useMemo(() => {
    const shipping = validation?.shippingCharge ?? 0;
    return total + shipping;
  }, [total, validation]);

  const handlePaymentSuccess = () => {
    clearCart();
    if (typeof window !== "undefined") {
      window.localStorage.removeItem(ABANDONED_CART_KEY);
    }
    router.push("/account/orders");
  };

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold">Checkout</h1>
        <p className="mt-2 text-slate-500">Guest checkout, payment choices, cart recovery, and synced address book.</p>
      </div>
      {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>}
      <div className="grid gap-8 lg:grid-cols-[1fr_360px]">
        <section className="card space-y-6 p-6">
          <h2 className="text-xl font-semibold">Step 1 · Address & customer</h2>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={guestCheckout} onChange={(event) => setGuestCheckout(event.target.checked)} />
            Continue as guest checkout
          </label>
          {guestCheckout && (
            <input
              type="email"
              value={guestEmail}
              onChange={(event) => setGuestEmail(event.target.value)}
              placeholder="Guest email for notifications"
              className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
            />
          )}
          <AddressForm onSubmit={saveAddress} initialValue={address ?? undefined} />

          {savedAddresses.length > 0 && (
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <h3 className="font-medium">Saved addresses</h3>
                {syncingAddresses && <span className="text-xs text-slate-400">Syncing to server…</span>}
              </div>
              <div className="grid gap-2">
                {savedAddresses.map((entry) => (
                  <button
                    type="button"
                    key={entry.id}
                    className="rounded-xl border border-slate-200 p-3 text-left text-sm hover:border-brand"
                    onClick={() => {
                      setAddress(entry);
                      setValidation(null);
                    }}
                  >
                    <p className="font-medium">{entry.fullName} {entry.isDefault ? "(Default)" : ""}</p>
                    <p className="text-slate-500">{entry.addressLine1}, {entry.city}, {entry.state} - {entry.pincode}</p>
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className="flex flex-wrap gap-2">
            <button type="button" className="btn-secondary disabled:opacity-60" onClick={() => void checkPincode()} disabled={validating || !address}>
              {validating ? "Checking…" : "Check pincode serviceability"}
            </button>
            {validation?.serviceable && validation.inStock && <span className="rounded-full bg-emerald-100 px-3 py-1 text-sm text-emerald-700">Ready for payment</span>}
          </div>

          <label className="flex items-center gap-2 text-sm text-slate-600">
            <input type="checkbox" checked={recoveryOptIn} onChange={(event) => setRecoveryOptIn(event.target.checked)} />
            Allow abandoned-cart reminders via email/SMS/WhatsApp
          </label>

          {address && !orderId && (
            <button
              className="btn-primary disabled:opacity-60"
              onClick={() => void handlePlaceOrder()}
              disabled={placingOrder || !validation?.serviceable || !validation?.inStock}
            >
              {placingOrder ? "Placing order…" : "Continue to payment"}
            </button>
          )}
        </section>

        <aside className="card space-y-4 p-6">
          <h2 className="text-xl font-semibold">Step 2 · Payment</h2>
          <p className="text-sm text-slate-500">Coupon: {coupon ?? "Not applied"}</p>
          <select className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm" value={paymentMethod} onChange={(event) => setPaymentMethod(event.target.value as "razorpay" | "cod" | "upi")}>
            <option value="razorpay">Razorpay (Card/Netbanking/UPI)</option>
            <option value="upi">Direct UPI intent</option>
            <option value="cod">Cash on Delivery</option>
          </select>
          <div className="space-y-2 text-sm">
            {items.map((item) => (
              <div key={item.id} className="flex items-center justify-between">
                <span>{item.name} × {item.quantity}</span>
                <span>₹{(item.price * item.quantity).toFixed(2)}</span>
              </div>
            ))}
          </div>
          <div className="space-y-1 border-t pt-4 text-sm">
            <div className="flex justify-between"><span>Subtotal</span><span>₹{subtotal.toFixed(2)}</span></div>
            <div className="flex justify-between"><span>Discount</span><span>-₹{couponDiscount.toFixed(2)}</span></div>
            <div className="flex justify-between"><span>Cart total</span><span>₹{total.toFixed(2)}</span></div>
            <div className="flex justify-between"><span>Shipping</span><span>₹{(validation?.shippingCharge ?? 0).toFixed(2)}</span></div>
          </div>
          <div className="border-t pt-4 text-lg font-semibold">Payable · ₹{payable.toFixed(2)}</div>
          {paymentMethod === "cod" && orderId ? (
            <p className="rounded-xl bg-emerald-50 px-4 py-3 text-sm text-emerald-700">COD order confirmed. We will notify you on shipment updates.</p>
          ) : paymentMethod === "razorpay" && orderId ? (
            <RazorpayButton
              orderId={orderId}
              amount={payable}
              onSuccess={handlePaymentSuccess}
              onFailure={(reason) => setError(reason)}
            />
          ) : paymentMethod === "upi" && orderId ? (
            <button className="btn-primary w-full" onClick={handlePaymentSuccess}>
              Simulate UPI success
            </button>
          ) : (
            <p className="text-sm text-slate-400">Complete address and validation above to proceed.</p>
          )}
        </aside>
      </div>
    </div>
  );
}
