import { FilterSidebar } from "@/components/FilterSidebar";
import { ProductCard } from "@/components/ProductCard";

type Product = {
  server_id: string;
  seo_slug: string;
  name: string;
  ec_selling_price: number;
  ec_compare_price?: number;
  category_name?: string;
};

async function fetchProducts(category?: string, brand?: string): Promise<Product[]> {
  const slug = process.env.NEXT_PUBLIC_STORE_SLUG ?? "default";
  const base = process.env.NEXT_PUBLIC_API_BASE ?? "";
  const params = new URLSearchParams({ size: "40" });
  if (category) params.set("category", category);
  if (brand) params.set("brand", brand);
  try {
    const res = await fetch(`${base}/ec/store/${slug}/products?${params}`, {
      next: { revalidate: 60 },
    });
    if (!res.ok) return [];
    const data = await res.json();
    return data.items ?? [];
  } catch {
    return [];
  }
}

export default async function ProductsPage({
  searchParams,
}: {
  searchParams: { category?: string; brand?: string };
}) {
  const products = await fetchProducts(searchParams.category, searchParams.brand);

  return (
    <div className="grid gap-8 lg:grid-cols-[280px_1fr]">
      <FilterSidebar activeCategory={searchParams.category} activeBrand={searchParams.brand} />
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold">Products</h1>
          <p className="mt-2 text-slate-500">Browse tenant storefront listings with filters, stock visibility, and pricing.</p>
        </div>
        {products.length === 0 && <p className="text-slate-500">No products available.</p>}
        <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
          {products.map((product) => (
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
      </div>
    </div>
  );
}
