import { ProductCard } from "@/components/ProductCard";

export default function CategoryPage({ params }: { params: { slug: string } }) {
  const products = [
    { slug: `${params.slug}-1`, name: `${params.slug} Essential Pack`, price: 199, category: params.slug },
    { slug: `${params.slug}-2`, name: `${params.slug} Premium Pack`, price: 299, category: params.slug },
    { slug: `${params.slug}-3`, name: `${params.slug} Family Pack`, price: 399, category: params.slug }
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold capitalize">{params.slug.replace(/-/g, " ")}</h1>
        <p className="mt-2 text-slate-500">Tenant storefront category grid powered by storefront-aware listings.</p>
      </div>
      <div className="grid gap-6 md:grid-cols-3">
        {products.map((product) => (
          <ProductCard key={product.slug} {...product} />
        ))}
      </div>
    </div>
  );
}
