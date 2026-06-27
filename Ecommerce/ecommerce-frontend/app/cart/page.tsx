"use client";

import { useCallback, useEffect, useState } from "react";
import { CartDrawer } from "@/components/CartDrawer";
import api from "@/lib/api";
import { readApiError, storefrontId } from "@/lib/ecommerce";
import { useCartStore } from "@/store/cartStore";

export default function CartPage() {
  const { items, sessionToken, coupon, subtotal, couponDiscount, total, syncFromServer } = useCartStore();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [couponCode, setCouponCode] = useState("");
  const [couponBusy, setCouponBusy] = useState(false);

  const loadCart = useCallback(async () => {
    if (!storefrontId) {
      setError("Storefront ID is not configured.");
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const { data } = await api.get("/ec/cart/items", { params: { storefrontId, sessionToken } });
      syncFromServer(data);
      setError("");
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to load cart."));
    } finally {
      setLoading(false);
    }
  }, [sessionToken, syncFromServer]);

  useEffect(() => {
    void loadCart();
  }, [loadCart]);

  const updateQty = async (itemId: string, quantity: number) => {
    if (!storefrontId) return;
    if (!Number.isFinite(quantity) || quantity < 1) {
      setError("Quantity must be at least 1.");
      return;
    }
    try {
      const { data } = await api.put(`/ec/cart/items/${itemId}`, {
        storefrontId,
        quantity: Number(quantity),
        sessionToken,
      });
      syncFromServer(data);
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to update item quantity."));
    }
  };

  const removeItem = async (itemId: string) => {
    if (!storefrontId) return;
    try {
      const { data } = await api.delete(`/ec/cart/items/${itemId}`, {
        params: { storefrontId, sessionToken },
      });
      syncFromServer(data);
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to remove item."));
    }
  };

  const applyCoupon = async () => {
    if (!storefrontId || !couponCode.trim()) return;
    try {
      setCouponBusy(true);
      const { data } = await api.post("/ec/cart/apply-coupon", {
        storefrontId,
        code: couponCode.trim(),
        sessionToken,
      });
      syncFromServer(data);
      setCouponCode("");
      setError("");
    } catch (err: unknown) {
      setError(readApiError(err, "Coupon could not be applied."));
    } finally {
      setCouponBusy(false);
    }
  };

  const removeCoupon = async () => {
    if (!storefrontId) return;
    try {
      setCouponBusy(true);
      const { data } = await api.delete("/ec/cart/coupon", {
        params: { storefrontId, sessionToken },
      });
      syncFromServer(data);
      setError("");
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to remove coupon."));
    } finally {
      setCouponBusy(false);
    }
  };

  if (loading) return <p className="text-slate-500">Loading cart…</p>;

  return (
    <div className="grid gap-8 lg:grid-cols-[1fr_320px]">
      <section className="space-y-4">
        <h1 className="text-3xl font-bold">Cart</h1>
        {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>}
        {items.length === 0 ? <p className="text-slate-500">Add products to begin checkout.</p> : null}
        {items.map((item) => (
          <article key={item.id} className="card flex items-center justify-between p-5">
            <div>
              <h2 className="font-semibold">{item.name}</h2>
              {item.variantLabel ? <p className="text-xs text-slate-500">{item.variantLabel}</p> : null}
              <p className="text-sm text-slate-500">₹{item.price.toFixed(2)}</p>
            </div>
            <div className="flex items-center gap-3">
              <input
                type="number"
                min={1}
                value={item.quantity}
                onChange={(event) => void updateQty(item.id, Number(event.target.value))}
                className="w-20 rounded-xl border border-slate-300 px-3 py-2"
              />
              <button type="button" onClick={() => void removeItem(item.id)} className="btn-secondary">Remove</button>
            </div>
          </article>
        ))}

        <div className="card space-y-3 p-5">
          <h2 className="font-semibold">Coupon</h2>
          <div className="flex gap-2">
            <input
              value={couponCode}
              onChange={(event) => setCouponCode(event.target.value)}
              placeholder="Enter coupon code"
              className="w-full rounded-xl border border-slate-300 px-3 py-2"
            />
            <button type="button" onClick={() => void applyCoupon()} disabled={couponBusy} className="btn-primary disabled:opacity-60">
              Apply
            </button>
          </div>
          {coupon && (
            <div className="flex items-center justify-between rounded-xl bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
              <span>Applied: {coupon}</span>
              <button type="button" onClick={() => void removeCoupon()} disabled={couponBusy} className="font-semibold underline">
                Remove
              </button>
            </div>
          )}
          <div className="space-y-1 text-sm text-slate-600">
            <div className="flex justify-between"><span>Subtotal</span><span>₹{subtotal.toFixed(2)}</span></div>
            <div className="flex justify-between"><span>Discount</span><span>-₹{couponDiscount.toFixed(2)}</span></div>
            <div className="flex justify-between border-t pt-1 font-semibold"><span>Total</span><span>₹{total.toFixed(2)}</span></div>
          </div>
        </div>
      </section>
      <CartDrawer />
    </div>
  );
}
