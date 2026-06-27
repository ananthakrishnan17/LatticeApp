"use client";

import { create } from "zustand";
import api from "@/lib/api";
import { readApiError } from "@/lib/ecommerce";

export type WishlistItem = {
  id: string;
  listingId: string;
  seoSlug: string;
  name: string;
  price: number;
};

type WishlistState = {
  items: WishlistItem[];
  loading: boolean;
  error: string;
  hydrated: boolean;
  hydrate: () => Promise<void>;
  add: (listingId: string) => Promise<void>;
  remove: (wishlistId: string) => Promise<void>;
  toggle: (listingId: string) => Promise<void>;
  clear: () => void;
};

export const useWishlistStore = create<WishlistState>((set, get) => ({
  items: [],
  loading: false,
  error: "",
  hydrated: false,
  hydrate: async () => {
    if (typeof window !== "undefined" && !window.localStorage.getItem("ec_token")) {
      set({ items: [], hydrated: true, loading: false, error: "" });
      return;
    }
    set({ loading: true, error: "" });
    try {
      const { data } = await api.get("/ec/wishlist");
      set({
        items: (data ?? []).map((entry: Record<string, unknown>) => ({
          id: String(entry.server_id),
          listingId: String(entry.listing_id),
          seoSlug: String(entry.seo_slug ?? ""),
          name: String(entry.name ?? ""),
          price: Number(entry.ec_selling_price ?? 0),
        })),
        hydrated: true,
        loading: false,
      });
    } catch (error: unknown) {
      set({
        loading: false,
        hydrated: true,
        error: readApiError(error, "Failed to load wishlist."),
      });
    }
  },
  add: async (listingId) => {
    await api.post("/ec/wishlist", { listingId });
    await get().hydrate();
  },
  remove: async (wishlistId) => {
    await api.delete(`/ec/wishlist/${wishlistId}`);
    await get().hydrate();
  },
  toggle: async (listingId) => {
    const current = get().items.find((item) => item.listingId === listingId);
    try {
      set({ loading: true, error: "" });
      if (current) {
        await api.delete(`/ec/wishlist/${current.id}`);
      } else {
        await api.post("/ec/wishlist", { listingId });
      }
      await get().hydrate();
    } catch (error: unknown) {
      set({ loading: false, error: readApiError(error, "Failed to update wishlist.") });
    }
  },
  clear: () => set({ items: [], hydrated: false, loading: false, error: "" }),
}));
