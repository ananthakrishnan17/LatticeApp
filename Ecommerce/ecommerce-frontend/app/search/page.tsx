"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { ProductCard } from "@/components/ProductCard";
import { storeSlug } from "@/lib/ecommerce";
import api from "@/lib/api";

type SearchProduct = {
  server_id: string;
  seo_slug: string;
  name: string;
  ec_selling_price: number;
  primary_image?: string;
  stock_quantity?: number;
  rating?: number;
};

const MAX_FUZZY_MISSES = 1;

const normalize = (value: string) => value.trim().toLowerCase();

const fuzzyMatch = (text: string, query: string) => {
  const source = normalize(text);
  const target = normalize(query);
  if (!target) return true;
  if (source.includes(target)) return true;
  let misses = 0;
  let sourceIndex = 0;
  for (const char of target) {
    const nextIndex = source.indexOf(char, sourceIndex);
    if (nextIndex < 0) {
      misses += 1;
      continue;
    }
    sourceIndex = nextIndex + 1;
  }
  return misses <= MAX_FUZZY_MISSES;
};

export default function SearchPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const query = searchParams.get("q")?.trim() ?? "";
  const [draftQuery, setDraftQuery] = useState(query);
  const [allItems, setAllItems] = useState<SearchProduct[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [sortBy, setSortBy] = useState<"relevance" | "priceAsc" | "priceDesc" | "rating">("relevance");
  const [inStockOnly, setInStockOnly] = useState(false);
  const [priceMin, setPriceMin] = useState("");
  const [priceMax, setPriceMax] = useState("");
  const [minRating, setMinRating] = useState("");

  const loadResults = useCallback(async (term: string) => {
    if (!term.trim()) {
      setAllItems([]);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const [searchRes, fallbackRes] = await Promise.all([
        api.get(`/ec/store/${storeSlug}/search`, { params: { q: term } }).catch(() => ({ data: [] })),
        api.get(`/ec/store/${storeSlug}/products`, { params: { q: term, limit: 60 } }).catch(() => ({ data: [] })),
      ]);
      const mergedRaw = [
        ...(Array.isArray(searchRes.data) ? searchRes.data : []),
        ...(Array.isArray(fallbackRes.data?.items) ? fallbackRes.data.items : Array.isArray(fallbackRes.data) ? fallbackRes.data : []),
      ];
      const deduped = new Map<string, SearchProduct>();
      mergedRaw.forEach((item: Record<string, unknown>) => {
        const id = String(item.server_id ?? item.listing_id ?? "");
        if (!id) return;
        deduped.set(id, {
          server_id: id,
          seo_slug: String(item.seo_slug ?? ""),
          name: String(item.name ?? item.product_name ?? "Product"),
          ec_selling_price: Number(item.ec_selling_price ?? item.unit_price ?? 0),
          primary_image: item.primary_image ? String(item.primary_image) : item.image_url ? String(item.image_url) : undefined,
          stock_quantity: Number(item.stock_quantity ?? 0),
          rating: Number(item.rating ?? 0),
        });
      });
      setAllItems(Array.from(deduped.values()));
    } catch {
      setError("Search failed. Please try again.");
      setAllItems([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    setDraftQuery(query);
    void loadResults(query);
  }, [query, loadResults]);

  const suggestions = useMemo(() => {
    const seen = new Set<string>();
    return allItems
      .filter((item) => fuzzyMatch(item.name, draftQuery || query))
      .map((item) => item.name)
      .filter((name) => {
        const token = normalize(name);
        if (seen.has(token)) return false;
        seen.add(token);
        return true;
      })
      .slice(0, 6);
  }, [allItems, draftQuery, query]);

  const filteredItems = useMemo(() => {
    const min = priceMin ? Number(priceMin) : 0;
    const max = priceMax ? Number(priceMax) : Number.POSITIVE_INFINITY;
    const ratingCutoff = minRating ? Number(minRating) : 0;

    const filtered = allItems.filter((item) => {
      const price = Number(item.ec_selling_price ?? 0);
      const stock = Number(item.stock_quantity ?? 0);
      const rating = Number(item.rating ?? 0);
      const textMatch = fuzzyMatch(item.name, query);
      if (!textMatch) return false;
      if (inStockOnly && stock <= 0) return false;
      if (price < min || price > max) return false;
      if (rating < ratingCutoff) return false;
      return true;
    });

    if (sortBy === "priceAsc") return filtered.sort((a, b) => a.ec_selling_price - b.ec_selling_price);
    if (sortBy === "priceDesc") return filtered.sort((a, b) => b.ec_selling_price - a.ec_selling_price);
    if (sortBy === "rating") return filtered.sort((a, b) => Number(b.rating ?? 0) - Number(a.rating ?? 0));
    return filtered;
  }, [allItems, inStockOnly, minRating, priceMax, priceMin, query, sortBy]);

  const noResultSuggestions = useMemo(() => {
    if (filteredItems.length > 0 || !query) return [];
    const fallback = ["Try fewer words", "Check spelling", "Try category keywords", "Use broader terms"];
    return [...fallback, ...suggestions.slice(0, 2)];
  }, [filteredItems.length, query, suggestions]);

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <h1 className="text-3xl font-bold">Search results</h1>
        <p className="text-slate-500">Autosuggest, typo-tolerant search, and smart recovery suggestions.</p>
      </div>

      <form
        className="card space-y-3 p-4"
        onSubmit={(event) => {
          event.preventDefault();
          router.push(`/search?q=${encodeURIComponent(draftQuery.trim())}`);
        }}
      >
        <input
          className="w-full rounded-xl border border-slate-300 px-3 py-2"
          value={draftQuery}
          onChange={(event) => setDraftQuery(event.target.value)}
          placeholder="Search for products"
        />
        {draftQuery && suggestions.length > 0 && (
          <div className="flex flex-wrap gap-2 text-xs">
            {suggestions.map((suggestion) => (
              <button key={suggestion} type="button" className="rounded-full border border-slate-300 px-3 py-1" onClick={() => setDraftQuery(suggestion)}>
                {suggestion}
              </button>
            ))}
          </div>
        )}
        <div className="grid gap-2 md:grid-cols-5">
          <select className="rounded-xl border border-slate-300 px-3 py-2 text-sm" value={sortBy} onChange={(event) => setSortBy(event.target.value as typeof sortBy)}>
            <option value="relevance">Sort: relevance</option>
            <option value="priceAsc">Price: low to high</option>
            <option value="priceDesc">Price: high to low</option>
            <option value="rating">Rating</option>
          </select>
          <input className="rounded-xl border border-slate-300 px-3 py-2 text-sm" type="number" placeholder="Min ₹" value={priceMin} onChange={(event) => setPriceMin(event.target.value)} />
          <input className="rounded-xl border border-slate-300 px-3 py-2 text-sm" type="number" placeholder="Max ₹" value={priceMax} onChange={(event) => setPriceMax(event.target.value)} />
          <input className="rounded-xl border border-slate-300 px-3 py-2 text-sm" type="number" min={0} max={5} placeholder="Min rating" value={minRating} onChange={(event) => setMinRating(event.target.value)} />
          <label className="flex items-center gap-2 rounded-xl border border-slate-300 px-3 py-2 text-sm">
            <input type="checkbox" checked={inStockOnly} onChange={(event) => setInStockOnly(event.target.checked)} /> In stock only
          </label>
        </div>
      </form>

      {loading && <p className="text-slate-500">Searching…</p>}
      {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>}
      {!loading && query && filteredItems.length === 0 && (
        <div className="card space-y-2 p-4 text-sm">
          <p className="font-medium">No products found for “{query}”.</p>
          <ul className="list-disc pl-4 text-slate-600">
            {noResultSuggestions.map((tip) => (
              <li key={tip}>{tip}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {filteredItems.map((product) => (
          <ProductCard
            key={product.server_id}
            slug={product.seo_slug}
            name={product.name}
            price={Number(product.ec_selling_price)}
            imageUrl={product.primary_image}
            category="Search"
          />
        ))}
      </div>
    </div>
  );
}
