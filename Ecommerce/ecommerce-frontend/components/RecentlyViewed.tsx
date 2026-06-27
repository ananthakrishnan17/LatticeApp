"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

interface ViewedItem {
  slug: string;
  name: string;
  ec_selling_price: number;
  primary_image?: string;
  viewedAt: number;
}

const STORAGE_KEY = "ec_recently_viewed";
const MAX_ITEMS = 8;

export function recordView(product: { slug: string; name: string; ec_selling_price: number; primary_image?: string }) {
  if (typeof window === "undefined") return;
  const existing: ViewedItem[] = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "[]");
  const filtered = existing.filter((i) => i.slug !== product.slug);
  const updated: ViewedItem[] = [{ ...product, viewedAt: Date.now() }, ...filtered].slice(0, MAX_ITEMS);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
}

export default function RecentlyViewed({ excludeSlug }: { excludeSlug?: string }) {
  const [items, setItems] = useState<ViewedItem[]>([]);

  useEffect(() => {
    const stored: ViewedItem[] = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "[]");
    setItems(stored.filter((i) => i.slug !== excludeSlug));
  }, [excludeSlug]);

  if (items.length === 0) return null;

  return (
    <section className="mt-12">
      <h2 className="text-xl font-bold mb-4">Recently Viewed</h2>
      <div className="flex gap-4 overflow-x-auto pb-2">
        {items.map((item) => (
          <Link
            key={item.slug}
            href={`/products/${item.slug}`}
            className="card flex-shrink-0 w-36 block overflow-hidden hover:shadow-md transition-shadow"
          >
            <div className="aspect-square bg-slate-100 overflow-hidden">
              {item.primary_image ? (
                <img
                  src={item.primary_image}
                  alt={item.name}
                  className="w-full h-full object-cover"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-slate-300 text-2xl">📦</div>
              )}
            </div>
            <div className="p-2">
              <p className="text-xs font-medium line-clamp-2">{item.name}</p>
              <p className="text-xs font-bold text-indigo-600 mt-1">₹{Number(item.ec_selling_price).toLocaleString("en-IN")}</p>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}
