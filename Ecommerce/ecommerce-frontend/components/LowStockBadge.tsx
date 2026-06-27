interface Props {
  stockQuantity: number;
  lowStockThreshold?: number;
}

export default function LowStockBadge({ stockQuantity, lowStockThreshold = 5 }: Props) {
  if (stockQuantity <= 0) {
    return (
      <span className="inline-flex items-center gap-1 text-xs font-semibold bg-red-100 text-red-600 px-2 py-0.5 rounded-full">
        <span className="h-1.5 w-1.5 rounded-full bg-red-500 inline-block" />
        Out of Stock
      </span>
    );
  }
  if (stockQuantity <= lowStockThreshold) {
    return (
      <span className="inline-flex items-center gap-1 text-xs font-semibold bg-amber-100 text-amber-700 px-2 py-0.5 rounded-full">
        <span className="h-1.5 w-1.5 rounded-full bg-amber-500 inline-block" />
        Only {stockQuantity} left
      </span>
    );
  }
  return null;
}
