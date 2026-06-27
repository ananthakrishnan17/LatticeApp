"use client";

import { Heart } from "lucide-react";
import { useEffect, useMemo } from "react";
import { useRouter } from "next/navigation";
import { useWishlistStore } from "@/store/wishlistStore";

export function WishlistButton({ listingId }: { listingId: string }) {
  const router = useRouter();
  const { items, loading, hydrated, hydrate, toggle } = useWishlistStore();

  useEffect(() => {
    if (!hydrated) {
      void hydrate();
    }
  }, [hydrate, hydrated]);

  const active = useMemo(() => items.some((item) => item.listingId === listingId), [items, listingId]);

  const handleToggle = async () => {
    if (typeof window !== "undefined" && !window.localStorage.getItem("ec_token")) {
      router.push("/account/login");
      return;
    }
    await toggle(listingId);
  };

  return (
    <button
      type="button"
      onClick={handleToggle}
      disabled={loading}
      className={`inline-flex items-center gap-2 rounded-full px-4 py-2 text-sm font-medium disabled:opacity-60 ${active ? "bg-rose-100 text-rose-600" : "bg-slate-100 text-slate-700"}`}
    >
      <Heart className={`h-4 w-4 ${active ? "fill-current" : ""}`} />
      {loading ? "Updating..." : active ? "Wishlisted" : "Add to wishlist"}
    </button>
  );
}
