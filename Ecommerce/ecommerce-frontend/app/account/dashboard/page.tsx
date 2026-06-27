"use client";

import Link from "next/link";
import { useEffect } from "react";
import { useWishlistStore } from "@/store/wishlistStore";

export default function DashboardPage() {
  const { items, hydrate, hydrated } = useWishlistStore();

  useEffect(() => {
    if (!hydrated) {
      void hydrate();
    }
  }, [hydrate, hydrated]);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold">Account dashboard</h1>
        <p className="mt-2 text-slate-500">Profile, orders, support, notifications, and loyalty lifecycle tools.</p>
      </div>
      <div className="grid gap-6 md:grid-cols-3">
        <div className="card p-6">
          <h2 className="font-semibold">Profile</h2>
          <p className="mt-2 text-sm text-slate-500">Manage customer details and email verification.</p>
        </div>
        <Link href="/account/orders" className="card p-6">
          <h2 className="font-semibold">Orders</h2>
          <p className="mt-2 text-sm text-slate-500">View order history, reorder quickly, and track shipments.</p>
        </Link>
        <Link href="/account/wishlist" className="card p-6">
          <h2 className="font-semibold">Wishlist</h2>
          <p className="mt-2 text-sm text-slate-500">Save items for later checkout. {items.length} item(s).</p>
        </Link>
        <Link href="/account/addresses" className="card p-6">
          <h2 className="font-semibold">Saved Addresses</h2>
          <p className="mt-2 text-sm text-slate-500">Manage synced shipping and billing addresses.</p>
        </Link>
        <Link href="/account/loyalty" className="card p-6">
          <h2 className="font-semibold">Loyalty &amp; Rewards</h2>
          <p className="mt-2 text-sm text-slate-500">View points balance, redeem rewards, and share referral code.</p>
        </Link>
        <Link href="/account/support" className="card p-6">
          <h2 className="font-semibold">Support &amp; Returns</h2>
          <p className="mt-2 text-sm text-slate-500">Manage support tickets and return/refund status.</p>
        </Link>
        <Link href="/account/notifications" className="card p-6">
          <h2 className="font-semibold">Notifications</h2>
          <p className="mt-2 text-sm text-slate-500">Configure email/SMS/WhatsApp alerts and stock/price updates.</p>
        </Link>
      </div>
    </div>
  );
}
