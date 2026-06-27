"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import api from "@/lib/api";

interface RelatedProduct {
  server_id: string;
  slug: string;
  name: string;
  ec_selling_price: number;
  ec_compare_price?: number;
  primary_image?: string;
  stock_quantity: number;
  low_stock_threshold: number;
  is_low_stock?: boolean;
}

interface Props {
  storeSlug: string;
  productSlug: string;
  limit?: number;
}

export default function RelatedProducts({ storeSlug, productSlug, limit = 6 }: Props) {
  const [products, setProducts] = useState<RelatedProduct[]>([]);

  useEffect(() => {
    api
      .get<RelatedProduct[]>(`/ec/store/${storeSlug}/related/${productSlug}?limit=${limit}`)
      .then((r) => setProducts(r.data))
      .catch(() => {});
  }, [storeSlug, productSlug, limit]);

  if (products.length === 0) return null;

  return (
    <section className="mt-12">
      <h2 className="text-xl font-bold mb-4">Related Products</h2>
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6">
        {products.map((p) => (
          <Link
            key={p.server_id}
            href={`/products/${p.slug}`}
            className="card group block overflow-hidden hover:shadow-md transition-shadow"
          >
            <div className="aspect-square bg-slate-100 overflow-hidden relative">
              {p.primary_image ? (
                <img
                  src={p.primary_image}
                  alt={p.name}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-slate-300 text-3xl">📦</div>
              )}
              {p.is_low_stock && (
                <span className="absolute top-1 left-1 text-[10px] font-bold bg-amber-100 text-amber-700 px-1.5 py-0.5 rounded">
                  Low Stock
                </span>
              )}
            </div>
            <div className="p-2">
              <p className="text-sm font-medium line-clamp-2">{p.name}</p>
              <p className="text-sm font-bold text-indigo-600 mt-1">₹{Number(p.ec_selling_price).toLocaleString("en-IN")}</p>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}
