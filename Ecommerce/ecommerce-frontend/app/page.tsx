import Link from "next/link";
import { ProductCard } from "@/components/ProductCard";

type Product = {
  server_id: string;
  seo_slug: string;
  name: string;
  ec_selling_price: number;
  ec_compare_price?: number;
  category_name?: string;
};

type Banner = {
  server_id: string;
  cta_url?: string;
  image_url?: string;
};

async function fetchFeatured(): Promise<Product[]> {
  const slug = process.env.NEXT_PUBLIC_STORE_SLUG ?? "default";
  const base = process.env.NEXT_PUBLIC_API_BASE ?? "";
  try {
    const res = await fetch(`${base}/ec/store/${slug}/products?size=3`, {
      next: { revalidate: 120 },
    });
    if (!res.ok) return [];
    const data = await res.json();
    return data.items ?? [];
  } catch {
    return [];
  }
}

async function fetchBanners(): Promise<Banner[]> {
  const slug = process.env.NEXT_PUBLIC_STORE_SLUG ?? "default";
  const base = process.env.NEXT_PUBLIC_API_BASE ?? "";
  try {
    const res = await fetch(`${base}/ec/store/${slug}/banners`, {
      next: { revalidate: 120 },
    });
    if (!res.ok) return [];
    return res.json();
  } catch {
    return [];
  }
}

async function fetchCategories(): Promise<{ name: string }[]> {
  const slug = process.env.NEXT_PUBLIC_STORE_SLUG ?? "default";
  const base = process.env.NEXT_PUBLIC_API_BASE ?? "";
  try {
    const res = await fetch(`${base}/ec/store/${slug}/categories`, {
      next: { revalidate: 300 },
    });
    if (!res.ok) return [];
    return res.json();
  } catch {
    return [];
  }
}

export default async function HomePage() {
  const [featuredProducts, banners, categories] = await Promise.all([
    fetchFeatured(),
    fetchBanners(),
    fetchCategories(),
  ]);

  return (
    <div className="space-y-12">
      <section className="grid gap-8 rounded-3xl bg-gradient-to-r from-brand to-brand-dark p-10 text-white md:grid-cols-[1.5fr_1fr]">
        <div className="space-y-5">
          <p className="text-sm uppercase tracking-[0.3em] text-brand-light">Hero</p>
          <h1 className="text-4xl font-bold leading-tight">Launch your tenant-aware ecommerce storefront in minutes.</h1>
          <p className="max-w-2xl text-white/80">Browse products, manage carts, place orders, track shipments, and monitor analytics from a unified module.</p>
          <div className="flex gap-4">
            <Link href="/products" className="rounded-xl bg-white px-5 py-3 font-semibold text-brand">Shop now</Link>
            <Link href="/admin/analytics" className="rounded-xl border border-white/30 px-5 py-3 font-semibold">View analytics</Link>
          </div>
        </div>
        <div className="card flex items-center justify-center p-8 text-slate-900">
          <div>
            <p className="text-sm text-slate-500">Banners</p>
            <h2 className="mt-2 text-2xl font-bold">Festival sale live</h2>
            <p className="mt-3 text-slate-600">Configure hero banners, coupons, and seasonal campaigns from the admin panel.</p>
          </div>
        </div>
      </section>

      {featuredProducts.length > 0 && (
        <section className="space-y-6">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-bold">Featured Products</h2>
            <Link href="/products" className="text-sm font-semibold text-brand">View all</Link>
          </div>
          <div className="grid gap-6 md:grid-cols-3">
            {featuredProducts.map((product) => (
              <ProductCard
                key={product.server_id}
                slug={product.seo_slug}
                name={product.name}
                price={Number(product.ec_selling_price)}
                comparePrice={product.ec_compare_price ? Number(product.ec_compare_price) : undefined}
                category={product.category_name}
              />
            ))}
          </div>
        </section>
      )}

      {categories.length > 0 && (
        <section className="space-y-6">
          <h2 className="text-2xl font-bold">Categories</h2>
          <div className="grid gap-4 md:grid-cols-4">
            {categories.map((cat) => (
              <Link
                key={cat.name}
                href={`/categories/${cat.name.toLowerCase().replace(/\s+/g, "-")}`}
                className="card p-6 text-lg font-semibold"
              >
                {cat.name}
              </Link>
            ))}
          </div>
        </section>
      )}

      {banners.length > 0 && (
        <section className="space-y-6">
          <h2 className="text-2xl font-bold">Banners</h2>
          <div className="grid gap-6 md:grid-cols-2">
            {banners.map((banner) => (
              <Link
                key={banner.server_id}
                href={banner.cta_url ?? "#"}
                className="card rounded-3xl bg-slate-900 p-8 text-white"
              >
                <p className="text-sm uppercase tracking-wide text-brand-light">Campaign</p>
                {banner.image_url && (
                  <img src={banner.image_url} alt="Banner" className="mt-3 h-24 w-full rounded-xl object-cover" />
                )}
              </Link>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
