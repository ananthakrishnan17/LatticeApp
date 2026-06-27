import { useMemo } from 'react'
import type { ProductResponse } from '../../types'
import useTranslation from '../../hooks/useTranslation'

interface CartItem {
  product: ProductResponse
  quantity: number
  unit: string
  saleType: 'retail' | 'wholesale'
  itemDiscount: string
}

interface PaymentOption {
  label: string
  value: string
}

interface CartPanelProps {
  cart: CartItem[]
  availableUnits: string[]
  customerName: string
  customerCredit: string
  onCustomerNameChange: (value: string) => void
  onCustomerCreditChange: (value: string) => void
  discount: string
  discountMode: 'amount' | 'percent'
  onDiscountChange: (value: string) => void
  onDiscountModeChange: (value: 'amount' | 'percent') => void
  couponCode: string
  couponError: string
  couponAppliedCode?: string
  couponDiscountLabel?: string
  onCouponCodeChange: (value: string) => void
  onApplyCoupon: () => void
  onRemoveCoupon: () => void
  billSaleType: 'retail' | 'wholesale'
  onBillSaleTypeChange: (value: 'retail' | 'wholesale') => void
  paymentMode: string
  paymentModeOptions: PaymentOption[]
  onPaymentModeChange: (value: string) => void
  autoPrintReceipt: boolean
  onAutoPrintChange: (value: boolean) => void
  onOpenLedger: () => void
  onRemoveItem: (productId: string) => void
  onUpdateItem: (productId: string, update: Partial<CartItem>) => void
  onUpdateQuantity: (productId: string, nextValue: number | '') => void
  selectedCartProductId: string | null
  onSelectCartProductId: (productId: string | null) => void
  cartSubtotal: number
  itemDiscountTotal: number
  parsedDiscount: number
  couponDiscount: number
  gstRatePercent: number
  gstTotal: number
  total: number
  placingOrder: boolean
  shiftOpen: boolean
  onOpenSplit: () => void
  onPlaceOrder: () => void
  customerSuggestions: string[]
}

const formatCurrency = (value: number) => `₹${value.toFixed(2)}`

const paymentLabelMap: Record<string, string> = {
  cash: '💵 Cash',
  card: '💳 Card',
  upi: '📱 UPI',
  split: '🧾 Split',
}

function CartPanel({
  cart,
  availableUnits,
  customerName,
  customerCredit,
  onCustomerNameChange,
  onCustomerCreditChange,
  discount,
  discountMode,
  onDiscountChange,
  onDiscountModeChange,
  couponCode,
  couponError,
  couponAppliedCode,
  couponDiscountLabel,
  onCouponCodeChange,
  onApplyCoupon,
  onRemoveCoupon,
  billSaleType,
  onBillSaleTypeChange,
  paymentMode,
  paymentModeOptions,
  onPaymentModeChange,
  autoPrintReceipt,
  onAutoPrintChange,
  onOpenLedger,
  onRemoveItem,
  onUpdateItem,
  onUpdateQuantity,
  selectedCartProductId,
  onSelectCartProductId,
  cartSubtotal,
  itemDiscountTotal,
  parsedDiscount,
  couponDiscount,
  gstRatePercent,
  gstTotal,
  total,
  placingOrder,
  shiftOpen,
  onOpenSplit,
  onPlaceOrder,
  customerSuggestions,
}: CartPanelProps) {
  const { t } = useTranslation()
  
  // A helper function to manage Enter key logic globally across all inputs inside the POS
  const handleInputKeyDown = (e: React.KeyboardEvent<HTMLInputElement | HTMLSelectElement>, nextTargetId?: string) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      if (nextTargetId) {
        document.getElementById(nextTargetId)?.focus()
      }
    }
  }

  return (
    <div className="pos-glass-panel">
      <div className="pos-title">{t.currentBill}</div>
      <div className="pos-subtitle" style={{ marginBottom: '16px' }}>{cart.length} {t.itemsInBill}</div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' }}>
        <div className="pos-input-group">
          <label className="pos-label">{t.customerName}</label>
          <input
            id="pos-customer-name"
            type="text"
            className="pos-input"
            list="customer-suggestions"
            placeholder={t.walkInCustomer}
            value={customerName}
            onChange={(e) => onCustomerNameChange(e.target.value)}
            onKeyDown={(e) => handleInputKeyDown(e, 'pos-discount-input')}
          />
          <datalist id="customer-suggestions">
            {customerSuggestions.map((name) => (
              <option key={name} value={name} />
            ))}
          </datalist>
        </div>
        <div className="pos-input-group">
          <label className="pos-label">{t.customerCredit} (₹)</label>
          <input
            type="number"
            className="pos-input"
            value={customerCredit}
            onChange={(e) => onCustomerCreditChange(e.target.value)}
            placeholder="0"
          />
        </div>
      </div>

      <button type="button" className="pos-btn" style={{ width: '100%', marginBottom: '16px' }} onClick={onOpenLedger}>
        Open Customer Ledger
      </button>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px', marginBottom: '16px' }}>
        <div className="pos-input-group">
          <label className="pos-label">{t.saleType}</label>
          <select 
            className="pos-input" 
            value={billSaleType} 
            onChange={(e) => onBillSaleTypeChange(e.target.value as 'retail' | 'wholesale')}
          >
            <option value="retail">{t.retail.toUpperCase()}</option>
            <option value="wholesale">{t.wholesale.toUpperCase()}</option>
          </select>
        </div>
        <div className="pos-input-group">
          <label className="pos-label">{t.paymentMode}</label>
          <select 
            id="pos-payment-mode"
            className="pos-input" 
            value={paymentMode} 
            onChange={(e) => onPaymentModeChange(e.target.value)}
            onKeyDown={(e) => handleInputKeyDown(e, 'pos-place-order-btn')}
          >
            {paymentModeOptions.map(opt => (
              <option key={opt.value} value={opt.value}>{paymentLabelMap[opt.value] || opt.label}</option>
            ))}
          </select>
        </div>
        <div className="pos-input-group" style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'flex-end', paddingTop: '22px' }}>
          <button 
            type="button" 
            className={`pos-btn ${autoPrintReceipt ? 'pos-btn-primary' : ''}`}
            onClick={() => onAutoPrintChange(!autoPrintReceipt)}
            style={{ width: '100%' }}
          >
            {autoPrintReceipt ? 'Auto Print ON' : 'Auto Print OFF'}
          </button>
        </div>
      </div>

      <div style={{ marginBottom: '16px', overflowX: 'auto' }}>
        {cart.length > 0 ? (
          <table className="pos-cart-table">
            <thead>
              <tr>
                <th>Item</th>
                <th>UOM</th>
                <th style={{ textAlign: 'center' }}>{t.qty}</th>
                <th style={{ textAlign: 'right' }}>{t.total}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {cart.map((item, index) => {
                const isSelected = selectedCartProductId === item.product.clientRecordId
                return (
                  <tr key={item.product.clientRecordId} className="pos-cart-row" style={isSelected ? { background: 'rgba(99, 102, 241, 0.05)' } : {}}>
                    <td style={{ fontWeight: '500' }}>{item.product.name}</td>
                    <td>
                      <select 
                        style={{ border: 'none', background: 'transparent', outline: 'none', cursor: 'pointer' }}
                        value={item.unit}
                        onChange={(e) => onUpdateItem(item.product.clientRecordId, { unit: e.target.value })}
                      >
                        {[...new Set([item.product.unit, ...availableUnits])].map(unit => (
                          <option key={unit} value={unit}>{unit}</option>
                        ))}
                      </select>
                    </td>
                    <td>
                      <div className="pos-cart-qty" style={{ justifyContent: 'center' }}>
                        <button type="button" className="pos-btn" style={{ padding: '4px 8px' }} onClick={() => onUpdateQuantity(item.product.clientRecordId, (typeof item.quantity === 'number' ? item.quantity : 0) - 1)}>-</button>
                        <input 
                          id={`pos-qty-${item.product.clientRecordId}`}
                          type="number" 
                          className="pos-input" 
                          style={{ padding: '4px' }} 
                          value={item.quantity} 
                          onFocus={(e) => {
                            onSelectCartProductId(item.product.clientRecordId);
                            e.target.select();
                          }}
                          onChange={(e) => {
                            if (e.target.value === '') {
                              onUpdateQuantity(item.product.clientRecordId, '');
                            } else {
                              const val = parseInt(e.target.value, 10);
                              if (!isNaN(val)) onUpdateQuantity(item.product.clientRecordId, val);
                            }
                          }}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                              e.preventDefault();
                              document.getElementById('pos-search-input')?.focus();
                            }
                          }}
                        />
                        <button type="button" className="pos-btn" style={{ padding: '4px 8px' }} onClick={() => onUpdateQuantity(item.product.clientRecordId, (typeof item.quantity === 'number' ? item.quantity : 0) + 1)}>+</button>
                      </div>
                    </td>
                    <td style={{ textAlign: 'right', fontWeight: '600' }}>
                      {formatCurrency((item.quantity || 0) * item.product.sellingPrice)}
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <button type="button" className="pos-btn pos-btn-danger" style={{ padding: '6px' }} onClick={() => onRemoveItem(item.product.clientRecordId)}>✕</button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        ) : (
          <div style={{ padding: '32px', textAlign: 'center', color: 'var(--pos-text-muted)', background: 'rgba(0,0,0,0.02)', borderRadius: 'var(--pos-radius-md)' }}>
            {t.emptyCart}
          </div>
        )}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' }}>
        <div className="pos-input-group">
          <label className="pos-label">{t.discountAmount}</label>
          <div style={{ display: 'flex', gap: '8px' }}>
            <div className="pos-segment" style={{ flexShrink: 0 }}>
              <button type="button" className={discountMode === 'amount' ? 'active' : ''} onClick={() => onDiscountModeChange('amount')}>₹</button>
              <button type="button" className={discountMode === 'percent' ? 'active' : ''} onClick={() => onDiscountModeChange('percent')}>%</button>
            </div>
            <input 
              id="pos-discount-input"
              type="number" 
              className="pos-input" 
              value={discount} 
              onChange={(e) => onDiscountChange(e.target.value)} 
              onKeyDown={(e) => handleInputKeyDown(e, 'pos-payment-mode')}
            />
          </div>
        </div>
        <div className="pos-input-group">
          <label className="pos-label">
            {t.couponCode}
            {couponAppliedCode && couponDiscountLabel && <span style={{ color: 'var(--pos-success)' }}>Saved {couponDiscountLabel}</span>}
          </label>
          <div style={{ display: 'flex', gap: '8px' }}>
            <input 
              type="text" 
              className="pos-input" 
              placeholder="CODE"
              value={couponCode}
              onChange={(e) => onCouponCodeChange(e.target.value.toUpperCase())}
              disabled={!!couponAppliedCode}
            />
            {couponAppliedCode ? (
              <button type="button" className="pos-btn pos-btn-danger" onClick={onRemoveCoupon}>{t.remove}</button>
            ) : (
              <button type="button" className="pos-btn" onClick={onApplyCoupon}>{t.apply}</button>
            )}
          </div>
          {couponError && <div style={{ color: 'var(--pos-danger)', fontSize: '0.8rem', marginTop: '4px' }}>{couponError}</div>}
        </div>
      </div>

      <div className="pos-totals">
        <div className="pos-total-row">
          <span>{t.subtotal}</span>
          <span>{formatCurrency(cartSubtotal)}</span>
        </div>
        {itemDiscountTotal > 0 && (
          <div className="pos-total-row">
            <span>Item Discounts</span>
            <span>-{formatCurrency(itemDiscountTotal)}</span>
          </div>
        )}
        {parsedDiscount > 0 && (
          <div className="pos-total-row">
            <span>{t.billDiscount}</span>
            <span>-{formatCurrency(parsedDiscount)}</span>
          </div>
        )}
        {couponDiscount > 0 && (
          <div className="pos-total-row">
            <span>Coupon Discount</span>
            <span>-{formatCurrency(couponDiscount)}</span>
          </div>
        )}
        <div className="pos-total-row">
          <span>{t.gstAmount} ({gstRatePercent}%)</span>
          <span>{formatCurrency(gstTotal)}</span>
        </div>
        <div className="pos-total-row pos-total-grand">
          <span>{t.grandTotal}</span>
          <span>{formatCurrency(total)}</span>
        </div>
      </div>

      <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
        <button type="button" className="pos-btn" onClick={onOpenSplit} disabled={!cart.length || placingOrder}>
          Split Payment
        </button>
        <button 
          id="pos-place-order-btn"
          type="button" 
          className="pos-btn pos-btn-primary" 
          style={{ flex: 1, fontSize: '1.1rem' }}
          onClick={onPlaceOrder}
          disabled={!cart.length || placingOrder || !shiftOpen}
        >
          {placingOrder ? 'Placing order...' : `${t.placeOrder} (F10)`}
        </button>
      </div>

    </div>
  )
}

export default CartPanel
