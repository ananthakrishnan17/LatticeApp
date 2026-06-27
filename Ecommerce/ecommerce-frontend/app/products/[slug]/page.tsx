"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams } from "next/navigation";
import { ReviewCard } from "@/components/ReviewCard";
import { Variant, VariantSelector } from "@/components/VariantSelector";
import { WishlistButton } from "@/components/WishlistButton";
import LowStockBadge from "@/components/LowStockBadge";
import ProductQA from "@/components/ProductQA";
import RelatedProducts from "@/components/RelatedProducts";
import RecentlyViewed, { recordView } from "@/components/RecentlyViewed";
import { useCartStore } from "@/store/cartStore";
import api from "@/lib/api";
import { asNumber, readApiError, storeSlug, storefrontId } from "@/lib/ecommerce";

const FALLBACK_PRODUCT_IMAGE = "https://images.unsplash.com/photo-1514996937319-344454492b37?auto=format&fit=crop&w=1200&q=80";
const PINCODE_REGEX = /^\d{6}$/;

type ProductImage = {
  server_id: string;
  image_url: string;
  is_primary?: boolean;
};

type ProductReview = {
  server_id: string;
  customer_name: string;
  rating: number;
  title: string;
  body: string;
  created_at?: string;
  verified_purchase?: boolean;
  photos?: string[];
};

type ProductDetail = {
  server_id: string;
  tenant_id: string;
  storefront_id: string;
  seo_slug: string;
  name: string;
  ec_selling_price: number;
  ec_compare_price?: number;
  stock_quantity: number;
  low_stock_threshold?: number;
  unit?: string;
  category_name?: string;
  images: ProductImage[];
  variants: Array<{ server_id: string; variant_label: string; ec_price: number; stock_override?: number }>;
  reviews: ProductReview[];
};

type Suggestion = { server_id: string; seo_slug: string; name: string; ec_selling_price: number };
const MAX_SUBSTITUTE_FETCH = 4;
const MAX_SUBSTITUTE_DISPLAY = 3;

export default function ProductDetailPage() {
  const params = useParams<{ slug: string }>();
  const slug = params?.slug;
  const { sessionToken, syncFromServer } = useCartStore();
  const [product, setProduct] = useState<ProductDetail | null>(null);
  const [selectedVariant, setSelectedVariant] = useState<string | undefined>(undefined);
  const [selectedImage, setSelectedImage] = useState<string | undefined>(undefined);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [adding, setAdding] = useState(false);
  const [reviewFilter, setReviewFilter] = useState<"all" | "verified" | "withPhotos">("all");
  const [substitutes, setSubstitutes] = useState<Suggestion[]>([]);

  useEffect(() => {
    if (!slug) return;
    setLoading(true);
    setError("");
    api
      .get(`/ec/store/${storeSlug}/products/${slug}`)
      .then((res) => {
        const data = res.data as ProductDetail;
        setProduct(data);
        const primary = data.images?.find((img) => img.is_primary)?.image_url ?? data.images?.[0]?.image_url;
        setSelectedImage(primary);
        setSelectedVariant(data.variants?.[0]?.server_id ? String(data.variants[0].server_id) : undefined);
        recordView({
          slug: data.seo_slug,
          name: data.name,
          ec_selling_price: asNumber(data.ec_selling_price),
          primary_image: primary,
        });
        if (storefrontId) {
          void api
            .post("/ec/events", {
              storefrontId,
              eventType: "view",
              listingId: data.server_id,
              sessionToken,
              meta: {},
            })
            .catch(() => {});
        }
      })
      .catch((err: unknown) => setError(readApiError(err, "Failed to load product detail.")))
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [slug]);

  useEffect(() => {
    if (!product || product.stock_quantity > 0) {
      setSubstitutes([]);
      return;
    }
    api
      .get(`/ec/store/${storeSlug}/products`, { params: { q: product.category_name ?? product.name, limit: MAX_SUBSTITUTE_FETCH } })
      .then((res) => {
        const items = Array.isArray(res.data?.items) ? res.data.items : Array.isArray(res.data) ? res.data : [];
        const mapped = items
          .filter((item: Record<string, unknown>) => String(item.seo_slug) !== product.seo_slug)
          .slice(0, MAX_SUBSTITUTE_DISPLAY)
          .map((item: Record<string, unknown>) => ({
            server_id: String(item.server_id),
            seo_slug: String(item.seo_slug),
            name: String(item.name),
            ec_selling_price: asNumber(item.ec_selling_price),
          }));
        setSubstitutes(mapped);
      })
      .catch(() => setSubstitutes([]));
  }, [product]);

  const variants: Variant[] = useMemo(() => {
    if (!product) return [];
    return (product.variants ?? []).map((item) => ({
      id: String(item.server_id),
      label: String(item.variant_label),
      price: asNumber(item.ec_price),
      stock: item.stock_override !== undefined ? asNumber(item.stock_override) : undefined,
    }));
  }, [product]);

  const activeVariant = useMemo(
    () => variants.find((entry) => entry.id === selectedVariant) ?? variants[0],
    [variants, selectedVariant]
  );

  const filteredReviews = useMemo(() => {
    const reviews = product?.reviews ?? [];
    if (reviewFilter === "verified") return reviews.filter((entry) => entry.verified_purchase);
    if (reviewFilter === "withPhotos") return reviews.filter((entry) => (entry.photos?.length ?? 0) > 0);
    return reviews;
  }, [product?.reviews, reviewFilter]);

  const ratingSummary = useMemo(() => {
    const reviews = product?.reviews ?? [];
    if (!reviews.length) return { average: 0, total: 0, histogram: [0, 0, 0, 0, 0] };
    const histogram = [0, 0, 0, 0, 0];
    let sum = 0;
    reviews.forEach((entry) => {
      const rating = Math.min(5, Math.max(1, Math.round(asNumber(entry.rating, 0))));
      histogram[rating - 1] += 1;
      sum += rating;
    });
    return { average: sum / reviews.length, total: reviews.length, histogram };
  }, [product?.reviews]);

  const displayPrice = activeVariant?.price ?? asNumber(product?.ec_selling_price);
  const displayStock = activeVariant?.stock ?? asNumber(product?.stock_quantity);
  const lowStockThreshold = product?.low_stock_threshold ?? 5;

  const addToCart = async () => {
    if (!product) return;
    if (!storefrontId) {
      setError("Storefront ID is not configured.");
      return;
    }
    try {
      setAdding(true);
      setError("");
      const { data } = await api.post("/ec/cart/items", {
        storefrontId,
        sessionToken,
        listingId: product.server_id,
        variantId: selectedVariant ?? null,
        quantity: 1,
      });
      syncFromServer(data);
      void api
        .post("/ec/events", {
          storefrontId,
          eventType: "cart_add",
          listingId: product.server_id,
          sessionToken,
          meta: {},
        })
        .catch(() => {});
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to add item to cart."));
    } finally {
      setAdding(false);
    }
  };

  if (loading) return <p className="text-slate-500">Loading product…</p>;
  if (error && !product) return <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>;
  if (!product) return <p className="text-slate-500">Product not found.</p>;

  return (
    <div>
      <div className="grid gap-8 lg:grid-cols-[1.2fr_1fr]">
        <div className="space-y-3">
          <div className="card overflow-hidden">
            <img
              src={selectedImage ?? product.images?.[0]?.image_url ?? FALLBACK_PRODUCT_IMAGE}
              alt={product.name}
              className="h-full w-full object-cover"
            />
          </div>
          {product.images?.length > 1 && (
            <div className="grid grid-cols-4 gap-2">
              {product.images.map((image) => (
                <button key={image.server_id} type="button" className="overflow-hidden rounded-xl border border-slate-200" onClick={() => setSelectedImage(image.image_url)}>
                  <img src={image.image_url} alt={product.name} className="h-20 w-full object-cover" />
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="space-y-6">
          <div className="space-y-3">
            <p className="text-sm uppercase tracking-wide text-brand">{product.category_name ?? "Product detail"}</p>
            <h1 className="text-3xl font-bold">{product.name}</h1>
            <div className="flex items-center gap-2">
              <p className="text-slate-600">Unit: {product.unit ?? "piece"}</p>
              <LowStockBadge stockQuantity={displayStock} lowStockThreshold={lowStockThreshold} />
            </div>
            <div className="flex items-center gap-3">
              <span className="text-3xl font-bold">₹{displayPrice.toFixed(2)}</span>
              {product.ec_compare_price ? <span className="text-slate-400 line-through">₹{asNumber(product.ec_compare_price).toFixed(2)}</span> : null}
            </div>
          </div>
          <DeliveryPincodeChecker storeSlug={storeSlug} />
          {variants.length > 0 && <VariantSelector variants={variants} selected={selectedVariant} onChange={setSelectedVariant} />}
          <div className="flex flex-wrap gap-3">
            <button type="button" className="btn-primary disabled:opacity-60" onClick={() => void addToCart()} disabled={adding || displayStock <= 0}>
              {adding ? "Adding…" : displayStock <= 0 ? "Out of Stock" : "Add to cart"}
            </button>
            <WishlistButton listingId={product.server_id} />
          </div>
          {displayStock <= 0 && <StockAlertForm listingId={product.server_id} substitutes={substitutes} />}
          {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>}
        </div>

        <section className="space-y-4 lg:col-span-2">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h2 className="text-2xl font-bold">Customer reviews</h2>
            <div className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm">
              <p className="font-semibold">{ratingSummary.average.toFixed(1)} / 5</p>
              <p className="text-slate-500">{ratingSummary.total} reviews</p>
            </div>
          </div>
          <div className="grid gap-2 text-xs text-slate-500 sm:grid-cols-5">
            {ratingSummary.histogram.map((count, index) => (
              <div key={`rating-${index}`} className="rounded-xl border border-slate-200 px-3 py-2 text-center">
                {index + 1}★ · {count}
              </div>
            ))}
          </div>
          <div className="flex gap-2 text-sm">
            <button className="btn-secondary" onClick={() => setReviewFilter("all")}>All</button>
            <button className="btn-secondary" onClick={() => setReviewFilter("verified")}>Verified only</button>
            <button className="btn-secondary" onClick={() => setReviewFilter("withPhotos")}>Photo reviews</button>
          </div>
          {filteredReviews.length === 0 ? (
            <p className="text-slate-500">No reviews for this filter.</p>
          ) : (
            <div className="grid gap-4 md:grid-cols-2">
              {filteredReviews.map((review) => (
                <ReviewCard
                  key={review.server_id}
                  name={review.customer_name}
                  rating={asNumber(review.rating)}
                  title={review.title ?? "Review"}
                  body={review.body ?? ""}
                  verified={Boolean(review.verified_purchase)}
                  photos={review.photos ?? []}
                  createdAt={review.created_at}
                />
              ))}
            </div>
          )}
        </section>

        <div className="lg:col-span-2">
          <ProductQA listingId={product.server_id} />
        </div>
      </div>

      <RelatedProducts storeSlug={storeSlug} productSlug={product.seo_slug} />
      <RecentlyViewed excludeSlug={product.seo_slug} />
    </div>
  );
}

function StockAlertForm({ listingId, substitutes }: { listingId: string; substitutes: Suggestion[] }) {
  const [email, setEmail] = useState("");
  const [priority, setPriority] = useState<"normal" | "urgent">("normal");
  const [sent, setSent] = useState(false);
  const [err, setErr] = useState("");

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErr("");
    try {
      await api.post("/ec/stock-alerts", { listingId, email, priority });
      setSent(true);
    } catch (error) {
      setErr(readApiError(error, "An error occurred"));
    }
  };

  return (
    <div className="space-y-4">
      {sent ? <p className="text-sm text-green-600">✓ We&apos;ll notify you when it&apos;s back in stock.</p> : null}
      {!sent && (
        <form onSubmit={submit} className="space-y-2">
          <div className="flex gap-2 items-center">
            <input
              type="email"
              className="input flex-1 text-sm"
              placeholder="Your email for restock alert"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
            <select className="rounded-xl border border-slate-300 px-3 py-2 text-sm" value={priority} onChange={(e) => setPriority(e.target.value as "normal" | "urgent")}>
              <option value="normal">Normal waitlist</option>
              <option value="urgent">Priority waitlist</option>
            </select>
            <button type="submit" className="btn-secondary text-sm">Notify Me</button>
          </div>
          {err && <p className="text-xs text-red-500">{err}</p>}
        </form>
      )}
      {substitutes.length > 0 && (
        <div className="rounded-xl border border-slate-200 bg-slate-50 p-3 text-sm">
          <p className="font-medium">Try substitutes</p>
          <ul className="mt-2 space-y-1 text-slate-600">
            {substitutes.map((item) => (
              <li key={item.server_id}>• {item.name} · ₹{item.ec_selling_price.toFixed(2)}</li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

function DeliveryPincodeChecker({ storeSlug }: { storeSlug: string }) {
  const [pincode, setPincode] = useState("");
  const [checking, setChecking] = useState(false);
  const [result, setResult] = useState<{ serviceable: boolean; extraShippingCharge: number } | null>(null);
  const [error, setError] = useState("");

  const checkServiceability = async () => {
    const normalized = pincode.trim();
    if (!PINCODE_REGEX.test(normalized)) {
      setError("Enter a valid 6-digit pincode.");
      setResult(null);
      return;
    }
    setChecking(true);
    setError("");
    try {
      const { data } = await api.get(`/ec/store/${storeSlug}/pincode/${encodeURIComponent(normalized)}/check`);
      setResult({
        serviceable: Boolean(data?.serviceable),
        extraShippingCharge: asNumber(data?.extraShippingCharge),
      });
    } catch (err: unknown) {
      setError(readApiError(err, "Unable to verify delivery for this pincode. Please try again."));
      setResult(null);
    } finally {
      setChecking(false);
    }
  };

  return (
    <div className="card space-y-3 p-4">
      <p className="text-sm font-semibold">Check delivery availability</p>
      <div className="space-y-2">
        <label htmlFor="delivery-pincode" className="text-xs text-slate-600">Enter your delivery pincode</label>
        <div className="flex gap-2">
          <input
            id="delivery-pincode"
            type="text"
            inputMode="numeric"
            pattern="\d*"
            maxLength={6}
            placeholder="Enter pincode"
            value={pincode}
            onChange={(event) => setPincode(event.target.value.replace(/\D/g, ""))}
            aria-invalid={Boolean(error)}
            aria-describedby={error ? "delivery-pincode-error" : undefined}
            className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
          />
          <button type="button" className="btn-secondary whitespace-nowrap" onClick={() => void checkServiceability()} disabled={checking} aria-busy={checking} aria-label="Check delivery availability for pincode">
            {checking ? "Checking…" : "Check"}
          </button>
        </div>
      </div>
      {result && (
        <p className={`text-sm ${result.serviceable ? "text-emerald-700" : "text-red-600"}`}>
          {result.serviceable
            ? result.extraShippingCharge > 0
              ? `Delivery available. Extra shipping: ₹${result.extraShippingCharge.toFixed(2)}`
              : "Delivery available with no extra charge."
            : "Delivery unavailable for this pincode."}
        </p>
      )}
      {error && <p id="delivery-pincode-error" className="text-sm text-red-600">{error}</p>}
    </div>
  );
}
