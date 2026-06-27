"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import api from "@/lib/api";
import { useWishlistStore } from "@/store/wishlistStore";
import { useCartStore } from "@/store/cartStore";
import { readApiError, storefrontId } from "@/lib/ecommerce";

export default function WishlistPage() {
  const { items, hydrate, hydrated, loading, error, remove } = useWishlistStore();
  const { sessionToken, syncFromServer } = useCartStore();
  const [busyListingId, setBusyListingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState("");

  useEffect(() => {
    if (!hydrated) {
      void hydrate();
    }
  }, [hydrate, hydrated]);

  const moveToCart = async (listingId: string, wishlistId: string) => {
    if (!storefrontId) {
      setActionError("Storefront ID is not configured.");
      return;
    }
    try {
      setActionError("");
      setBusyListingId(listingId);
      const { data } = await api.post("/ec/cart/items", {
        storefrontId,
        listingId,
        quantity: 1,
        sessionToken,
      });
      syncFromServer(data);
      await remove(wishlistId);
    } catch (err: unknown) {
      setActionError(readApiError(err, "Failed to move item to cart."));
    } finally {
      setBusyListingId(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">My wishlist</h1>
        <Link href="/products" className="btn-secondary">Browse products</Link>
      </div>

      {loading && <p className="text-slate-500">Loading wishlist…</p>}
      {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>}
      {actionError && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{actionError}</p>}

      {!loading && items.length === 0 && (
        <div className="card p-6 text-sm text-slate-500">
          Your wishlist is empty.
        </div>
      )}

      <div className="grid gap-4">
        {items.map((item) => (
          <article key={item.id} className="card flex flex-wrap items-center justify-between gap-4 p-5">
            <div>
              <Link href={`/products/${item.seoSlug}`} className="font-semibold hover:text-brand">{item.name}</Link>
              <p className="text-sm text-slate-500">₹{Number(item.price).toFixed(2)}</p>
            </div>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => void moveToCart(item.listingId, item.id)}
                disabled={busyListingId === item.listingId}
                className="btn-primary disabled:opacity-60"
              >
                {busyListingId === item.listingId ? "Moving…" : "Move to cart"}
              </button>
              <button type="button" onClick={() => void remove(item.id)} className="btn-secondary">Remove</button>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
}
