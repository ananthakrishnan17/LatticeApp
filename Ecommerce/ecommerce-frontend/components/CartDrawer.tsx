"use client";

import Link from "next/link";
import { useCartStore } from "@/store/cartStore";

export function CartDrawer() {
  const { items, subtotal, couponDiscount, total, coupon } = useCartStore();

  return (
    <aside className="card sticky top-6 p-5">
      <h2 className="text-lg font-semibold">Cart summary</h2>
      <div className="mt-4 space-y-3">
        {items.length === 0 ? <p className="text-sm text-slate-500">Your cart is empty.</p> : null}
        {items.map((item) => (
          <div key={item.id} className="flex items-center justify-between text-sm">
            <span>{item.name} × {item.quantity}</span>
            <span>₹{(item.price * item.quantity).toFixed(2)}</span>
          </div>
        ))}
      </div>
      <div className="mt-4 flex items-center justify-between border-t pt-4 font-semibold">
        <span>Subtotal</span>
        <span>₹{subtotal.toFixed(2)}</span>
      </div>
      <div className="mt-2 flex items-center justify-between text-sm">
        <span>Coupon</span>
        <span>{coupon ? `${coupon} (-₹${couponDiscount.toFixed(2)})` : "Not applied"}</span>
      </div>
      <div className="mt-2 flex items-center justify-between border-t pt-3 text-lg font-bold">
        <span>Total</span>
        <span>₹{total.toFixed(2)}</span>
      </div>
      <Link href="/checkout" className="btn-primary mt-4 w-full">Go to checkout</Link>
    </aside>
  );
}
