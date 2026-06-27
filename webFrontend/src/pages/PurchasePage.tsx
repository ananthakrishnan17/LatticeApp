import { generateUUID } from '../utils/uuid'
import { useEffect, useState } from 'react'
import { extractApiError } from '../api/client'
import { listProducts } from '../api/products'
import { upsertPurchase } from '../api/purchases'
import type { ProductResponse, PurchaseItemRequest } from '../types'

interface CartItem {
  product: ProductResponse
  quantity: number
  unitCost: number
  gstRate: number
}

const paymentModes = ['cash', 'credit', 'bank-transfer', 'upi']

const currency = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  maximumFractionDigits: 2,
})

let purchaseCounter = 0
const genPurchaseNumber = () => {
  purchaseCounter++
  const now = new Date()
  const y = now.getFullYear()
  const m = String(now.getMonth() + 1).padStart(2, '0')
  const d = String(now.getDate()).padStart(2, '0')
  return `PUR-${y}${m}${d}-${String(purchaseCounter).padStart(3, '0')}`
}

function PurchasePage() {
  const [products, setProducts] = useState<ProductResponse[]>([])
  const [cart, setCart] = useState<CartItem[]>([])
  const [search, setSearch] = useState('')
  const [supplierName, setSupplierName] = useState('')
  const [invoiceNumber, setInvoiceNumber] = useState('')
  const [paymentMode, setPaymentMode] = useState(paymentModes[0])
  const [notes, setNotes] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [toast, setToast] = useState('')

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      try {
        const list = await listProducts()
        if (!cancelled) setProducts(list)
      } catch (err) {
        if (!cancelled) setError(extractApiError(err))
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    void load()
    return () => { cancelled = true }
  }, [])

  const filtered = products.filter((p) =>
    p.name.toLowerCase().includes(search.toLowerCase()),
  )

  const addToCart = (product: ProductResponse) => {
    setCart((prev) => {
      const idx = prev.findIndex((c) => c.product.clientRecordId === product.clientRecordId)
      if (idx >= 0) {
        const updated = [...prev]
        updated[idx] = { ...updated[idx], quantity: updated[idx].quantity + 1 }
        return updated
      }
      return [...prev, { product, quantity: 1, unitCost: product.purchasePrice ?? 0, gstRate: 0 }]
    })
  }

  const updateItem = (idx: number, field: 'quantity' | 'unitCost' | 'gstRate', value: number) => {
    setCart((prev) => {
      const updated = [...prev]
      updated[idx] = { ...updated[idx], [field]: value }
      return updated
    })
  }

  const removeItem = (idx: number) => setCart((prev) => prev.filter((_, i) => i !== idx))

  const gstAmount = (item: CartItem) => item.unitCost * item.quantity * item.gstRate / 100
  const itemTotal = (item: CartItem) => item.unitCost * item.quantity + gstAmount(item)
  const grandTotal = cart.reduce((s, c) => s + itemTotal(c), 0)

  const handleSave = async () => {
    if (cart.length === 0) { setError('Add at least one item'); return }
    setSaving(true)
    setError('')
    try {
      const clientRecordId = generateUUID()
      const purchaseNumber = genPurchaseNumber()
      const now = new Date().toISOString()
      const items: PurchaseItemRequest[] = cart.map((c) => ({
        productId: c.product.serverId,
        productName: c.product.name,
        quantity: c.quantity,
        unit: c.product.unit,
        unitCost: c.unitCost,
        gstRate: c.gstRate,
        gstAmount: gstAmount(c),
        totalCost: itemTotal(c),
      }))
      await upsertPurchase({
        clientRecordId,
        purchaseNumber,
        supplierName: supplierName.trim() || undefined,
        totalAmount: grandTotal,
        gstTotal: cart.reduce((s, c) => s + gstAmount(c), 0),
        paymentMode,
        invoiceNumber: invoiceNumber.trim() || undefined,
        notes: notes.trim() || undefined,
        items,
        createdAt: now,
        updatedAt: now,
      })
      setToast(`✅ Purchase ${purchaseNumber} saved!`)
      setCart([])
      setSupplierName('')
      setInvoiceNumber('')
      setNotes('')
      setTimeout(() => setToast(''), 3000)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-indigo-600 border-t-transparent" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Purchase Entry</h1>
        <p className="mt-1 text-sm text-slate-500">Record stock purchases from suppliers</p>
      </div>

      {toast && (
        <div className="rounded-xl bg-emerald-50 px-4 py-3 text-sm font-medium text-emerald-700 border border-emerald-200">
          {toast}
        </div>
      )}
      {error && (
        <div className="rounded-xl bg-red-50 px-4 py-3 text-sm font-medium text-red-700 border border-red-200">
          {error}
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Product picker */}
        <div className="rounded-2xl border border-slate-200 bg-white p-5">
          <h2 className="text-base font-semibold text-slate-800 mb-3">Select Products</h2>
          <input
            className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100 mb-3"
            placeholder="Search products…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <div className="max-h-64 overflow-y-auto space-y-2">
            {filtered.map((p) => (
              <button
                key={p.clientRecordId}
                type="button"
                onClick={() => addToCart(p)}
                className="flex w-full items-center justify-between rounded-xl border border-slate-100 bg-slate-50 px-4 py-3 text-left text-sm hover:border-indigo-300 hover:bg-indigo-50 transition"
              >
                <span className="font-medium text-slate-800">{p.name}</span>
                <span className="text-slate-500">{currency.format(p.purchasePrice ?? 0)}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Cart */}
        <div className="rounded-2xl border border-slate-200 bg-white p-5">
          <h2 className="text-base font-semibold text-slate-800 mb-3">Cart</h2>
          {cart.length === 0 ? (
            <p className="text-sm text-slate-400 text-center py-8">No items added yet</p>
          ) : (
            <div className="space-y-3 max-h-64 overflow-y-auto">
              {cart.map((item, idx) => (
                <div key={idx} className="rounded-xl border border-slate-100 p-3">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-semibold text-slate-800">{item.product.name}</span>
                    <button
                      type="button"
                      onClick={() => removeItem(idx)}
                      className="text-xs text-red-500 hover:text-red-700"
                    >
                      Remove
                    </button>
                  </div>
                  <div className="grid grid-cols-3 gap-2">
                    {(['quantity', 'unitCost', 'gstRate'] as const).map((field) => (
                      <div key={field}>
                        <label className="text-xs text-slate-500 capitalize">{field === 'unitCost' ? 'Unit Cost' : field === 'gstRate' ? 'GST %' : 'Qty'}</label>
                        <input
                          type="number"
                          min={0}
                          step={field === 'quantity' ? 1 : 0.01}
                          value={item[field]}
                          onChange={(e) => updateItem(idx, field, parseFloat(e.target.value) || 0)}
                          className="w-full rounded-lg border border-slate-200 px-2 py-1 text-sm outline-none focus:border-indigo-400"
                        />
                      </div>
                    ))}
                  </div>
                  <div className="mt-1 text-right text-xs text-slate-500">
                    Total: <span className="font-semibold text-slate-700">{currency.format(itemTotal(item))}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Purchase details */}
      <div className="rounded-2xl border border-slate-200 bg-white p-5">
        <h2 className="text-base font-semibold text-slate-800 mb-4">Purchase Details</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Supplier Name</label>
            <input
              className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100"
              placeholder="Optional"
              value={supplierName}
              onChange={(e) => setSupplierName(e.target.value)}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Invoice Number</label>
            <input
              className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100"
              placeholder="Optional"
              value={invoiceNumber}
              onChange={(e) => setInvoiceNumber(e.target.value)}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">Payment Mode</label>
            <select
              className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100"
              value={paymentMode}
              onChange={(e) => setPaymentMode(e.target.value)}
            >
              {paymentModes.map((m) => (
                <option key={m} value={m}>{m.charAt(0).toUpperCase() + m.slice(1)}</option>
              ))}
            </select>
          </div>
          <div className="sm:col-span-2">
            <label className="block text-sm font-medium text-slate-700 mb-1">Notes</label>
            <input
              className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100"
              placeholder="Optional"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>
        </div>
      </div>

      {/* Footer */}
      <div className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-6 py-4">
        <div>
          <p className="text-sm text-slate-500">Grand Total</p>
          <p className="text-2xl font-bold text-slate-900">{currency.format(grandTotal)}</p>
        </div>
        <button
          type="button"
          onClick={handleSave}
          disabled={saving || cart.length === 0}
          className="rounded-xl bg-indigo-600 px-8 py-3 text-sm font-semibold text-white shadow hover:bg-indigo-700 disabled:opacity-50 transition"
        >
          {saving ? 'Saving…' : 'Save Purchase'}
        </button>
      </div>
    </div>
  )
}

export default PurchasePage
