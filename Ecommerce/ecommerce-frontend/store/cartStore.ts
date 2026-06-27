"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";

export type CartItem = {
  id: string;
  listingId: string;
  variantId?: string;
  name: string;
  price: number;
  quantity: number;
  variantLabel?: string;
  imageUrl?: string;
  slug?: string;
};

type CartState = {
  items: CartItem[];
  coupon?: string;
  cartId?: string;
  storefrontId?: string;
  subtotal: number;
  couponDiscount: number;
  total: number;
  sessionToken: string;
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  updateQty: (id: string, quantity: number) => void;
  applyCoupon: (coupon: string) => void;
  syncFromServer: (payload: {
    cartId?: string;
    storefrontId?: string;
    sessionToken?: string;
    coupon?: string | null;
    subtotal?: number;
    couponDiscount?: number;
    total?: number;
    items?: Array<{
      server_id: string;
      listing_id: string;
      variant_id?: string | null;
      quantity: number;
      unit_price: number;
      product_name: string;
      seo_slug?: string;
      image_url?: string;
      variant_label?: string;
    }>;
  }) => void;
  syncWithServer: (items: CartItem[]) => void;
  clearCart: () => void;
};

const createSessionToken = () => {
  if (typeof window === "undefined") return "server-session";
  const existing = window.localStorage.getItem("ec_session_token");
  if (existing) return existing;
  const token = crypto.randomUUID();
  window.localStorage.setItem("ec_session_token", token);
  return token;
};

export const useCartStore = create<CartState>()(
  persist(
    (set) => ({
      items: [],
      coupon: undefined,
      cartId: undefined,
      storefrontId: undefined,
      subtotal: 0,
      couponDiscount: 0,
      total: 0,
      sessionToken: createSessionToken(),
      addItem: (item) =>
        set((state) => {
          const existing = state.items.find((entry) => entry.id === item.id);
          if (existing) {
            return {
              items: state.items.map((entry) =>
                entry.id === item.id ? { ...entry, quantity: entry.quantity + item.quantity } : entry
              ),
            };
          }
          return { items: [...state.items, item] };
        }),
      removeItem: (id) => set((state) => ({ items: state.items.filter((item) => item.id !== id) })),
      updateQty: (id, quantity) =>
        set((state) => ({
          items: state.items.map((item) => (item.id === id ? { ...item, quantity: Math.max(quantity, 1) } : item)),
        })),
      applyCoupon: (coupon) => set({ coupon }),
      syncFromServer: (payload) =>
        set((state) => ({
          cartId: payload.cartId ?? state.cartId,
          storefrontId: payload.storefrontId ?? state.storefrontId,
          sessionToken: payload.sessionToken || state.sessionToken || createSessionToken(),
          coupon: payload.coupon || undefined,
          subtotal: Number(payload.subtotal ?? 0),
          couponDiscount: Number(payload.couponDiscount ?? 0),
          total: Number(payload.total ?? 0),
          items: (payload.items ?? []).map((item) => ({
            id: String(item.server_id),
            listingId: String(item.listing_id),
            variantId: item.variant_id ? String(item.variant_id) : undefined,
            name: String(item.product_name),
            price: Number(item.unit_price),
            quantity: Number(item.quantity),
            imageUrl: item.image_url ? String(item.image_url) : undefined,
            slug: item.seo_slug ? String(item.seo_slug) : undefined,
            variantLabel: item.variant_label ? String(item.variant_label) : undefined,
          })),
        })),
      syncWithServer: (items) => set({ items }),
      clearCart: () => set({ items: [], coupon: undefined, subtotal: 0, couponDiscount: 0, total: 0, cartId: undefined }),
    }),
    {
      name: "ec_cart",
      partialize: (state) => ({
        items: state.items,
        coupon: state.coupon,
        sessionToken: state.sessionToken,
        subtotal: state.subtotal,
        couponDiscount: state.couponDiscount,
        total: state.total,
        cartId: state.cartId,
        storefrontId: state.storefrontId,
      }),
    }
  )
);
