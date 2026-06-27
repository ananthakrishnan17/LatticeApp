import Link from "next/link";

export type ProductCardProps = {
  slug: string;
  name: string;
  price: number;
  comparePrice?: number;
  imageUrl?: string;
  category?: string;
};

export function ProductCard({ slug, name, price, comparePrice, imageUrl, category }: ProductCardProps) {
  return (
    <Link href={`/products/${slug}`} className="card overflow-hidden transition hover:-translate-y-1">
      <div className="aspect-square bg-slate-100">
        <img src={imageUrl ?? "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=800&q=80"} alt={name} className="h-full w-full object-cover" />
      </div>
      <div className="space-y-2 p-4">
        <p className="text-xs uppercase tracking-wide text-brand">{category ?? "Featured"}</p>
        <h3 className="font-semibold text-slate-900">{name}</h3>
        <div className="flex items-center gap-2">
          <span className="text-lg font-bold">₹{price.toFixed(2)}</span>
          {comparePrice ? <span className="text-sm text-slate-400 line-through">₹{comparePrice.toFixed(2)}</span> : null}
        </div>
      </div>
    </Link>
  );
}
