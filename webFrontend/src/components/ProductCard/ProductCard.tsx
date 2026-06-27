import type { ProductResponse } from '../../types'
import useTranslation from '../../hooks/useTranslation'

interface ProductCardProps {
  index?: number
  product: ProductResponse
  remainingStock: number
  shiftOpen: boolean
  onAddToCart: (product: ProductResponse) => void
}

const LOW_STOCK_THRESHOLD = 5

function ProductCard({ index, product, remainingStock, shiftOpen, onAddToCart }: ProductCardProps) {
  const { t } = useTranslation()
  const isOutOfStock = remainingStock <= 0
  const isLowStock = remainingStock > 0 && remainingStock <= LOW_STOCK_THRESHOLD

  return (
    <div className="pos-product-card">
      <div className="pos-product-name">{product.name}</div>
      <div className="pos-product-price">₹{product.sellingPrice.toFixed(2)}</div>
      
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem', color: 'var(--pos-text-muted)' }}>
        <span>{t.unit}: {product.unit}</span>
        <span>{t.purchasePrice}: ₹{product.purchasePrice.toFixed(2)}</span>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '4px' }}>
        {isOutOfStock ? (
          <span className="pos-badge pos-badge-error">{t.outOfStock}</span>
        ) : isLowStock ? (
          <span className="pos-badge pos-badge-warning">{t.lowStock}</span>
        ) : (
          <span className="pos-badge pos-badge-success">{t.inStock}</span>
        )}
        <span className="pos-badge pos-badge-info">{t.stockCount} {remainingStock}</span>
      </div>

      <button
        id={index !== undefined ? `pos-product-btn-${index}` : undefined}
        type="button"
        className="pos-btn pos-btn-primary"
        style={{ marginTop: '8px' }}
        onClick={() => {
          onAddToCart(product);
          // Wait for Cart to re-render, then focus the Qty box for this product
          setTimeout(() => {
            document.getElementById(`pos-qty-${product.clientRecordId}`)?.focus();
          }, 50);
        }}
        disabled={!shiftOpen || isOutOfStock}
      >
        {isOutOfStock ? t.outOfStock : shiftOpen ? t.addToBill : t.shiftClosed}
      </button>
    </div>
  )
}

export default ProductCard
