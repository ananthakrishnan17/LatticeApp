"use client";

export type Variant = {
  id: string;
  label: string;
  price: number;
  stock?: number;
};

export function VariantSelector({
  variants,
  selected,
  onChange,
}: {
  variants: Variant[];
  selected?: string;
  onChange?: (id: string) => void;
}) {
  const active = selected ?? variants[0]?.id;

  return (
    <div className="space-y-3">
      <h3 className="font-semibold">Select variant</h3>
      <div className="flex flex-wrap gap-3">
        {variants.map((variant) => (
          <button
            key={variant.id}
            type="button"
            onClick={() => onChange?.(variant.id)}
            className={`rounded-xl border px-4 py-2 text-sm ${active === variant.id ? "border-brand bg-brand-light text-brand-dark" : "border-slate-200 bg-white"}`}
          >
            {variant.label} · ₹{variant.price}
            {variant.stock !== undefined ? ` · ${variant.stock > 0 ? `${variant.stock} left` : "Out of stock"}` : ""}
          </button>
        ))}
      </div>
    </div>
  );
}
