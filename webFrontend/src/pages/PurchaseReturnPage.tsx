import { generateUUID } from '../utils/uuid'
import { useState } from 'react'
import { extractApiError } from '../api/client'
import { upsertPurchaseReturn } from '../api/purchaseReturns'
import { apiClient } from '../api/client'

interface PurchaseRow {
  server_id: string
  client_record_id: string
  purchase_number: string
  supplier_name: string | null
  total_amount: number
  payment_mode: string
}

interface PurchaseItemRow {
  product_name: string
  unit: string
  quantity: number
  unit_cost: number
  total_cost: number
}

interface ReturnLineItem extends PurchaseItemRow {
  returnQty: number
}

const currency = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  maximumFractionDigits: 2,
})

function PurchaseReturnPage() {
  const [purchaseNumber, setPurchaseNumber] = useState('')
  const [purchase, setPurchase] = useState<PurchaseRow | null>(null)
  const [lineItems, setLineItems] = useState<ReturnLineItem[]>([])
  const [notes, setNotes] = useState('')
  const [searching, setSearching] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [toast, setToast] = useState('')

  const searchPurchase = async () => {
    if (!purchaseNumber.trim()) return
    setSearching(true)
    setError('')
    setPurchase(null)
    setLineItems([])
    try {
      const { data } = await apiClient.get<{ purchases: PurchaseRow[] }>('/purchases', {
        params: { purchaseNumber: purchaseNumber.trim() },
      })
      const found = (data.purchases ?? [])[0]
      if (!found) { setError(`Purchase "${purchaseNumber}" not found`); return }

      // Fetch purchase items
      const { data: itemsData } = await apiClient.get<{ items: PurchaseItemRow[] }>(
        `/purchases/${found.server_id}/items`,
      ).catch(() => ({ data: { items: [] } }))

      setPurchase(found)
      setLineItems((itemsData.items ?? []).map((item) => ({ ...item, returnQty: 0 })))
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSearching(false)
    }
  }

  const updateReturnQty = (idx: number, qty: number) => {
    setLineItems((prev) => {
      const updated = [...prev]
      updated[idx] = { ...updated[idx], returnQty: Math.max(0, Math.min(qty, updated[idx].quantity)) }
      return updated
    })
  }

  const returnTotal = lineItems.reduce((s, i) => s + i.returnQty * i.unit_cost, 0)

  const handleSave = async () => {
    if (!purchase) return
    if (returnTotal <= 0) { setError('Select at least one item to return'); return }
    setSaving(true)
    setError('')
    try {
      const clientRecordId = generateUUID()
      const now = new Date().toISOString()
      const datePrefix = now.slice(0, 10).replace(/-/g, '')
      const returnNumber = `PRET-${datePrefix}-${clientRecordId.slice(0, 8).toUpperCase()}`

      await upsertPurchaseReturn({
        clientRecordId,
        returnNumber,
        originalPurchaseNumber: purchase.purchase_number,
        supplierName: purchase.supplier_name ?? undefined,
        totalReturnAmount: returnTotal,
        notes: notes.trim() || undefined,
        createdAt: now,
        updatedAt: now,
      })
      setToast(`✅ Purchase return ${returnNumber} saved — ${currency.format(returnTotal)}`)
      setPurchase(null)
      setLineItems([])
      setPurchaseNumber('')
      setNotes('')
      setTimeout(() => setToast(''), 4000)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Purchase Return</h1>
        <p className="mt-1 text-sm text-slate-500">Return goods to supplier against a purchase</p>
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

      {/* Purchase search */}
      <div className="rounded-2xl border border-slate-200 bg-white p-5">
        <h2 className="text-base font-semibold text-slate-800 mb-3">Find Purchase</h2>
        <div className="flex gap-3">
          <input
            className="flex-1 rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100"
            placeholder="Enter purchase number (e.g. PUR-20240101-001)…"
            value={purchaseNumber}
            onChange={(e) => setPurchaseNumber(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && void searchPurchase()}
          />
          <button
            type="button"
            onClick={searchPurchase}
            disabled={searching}
            className="rounded-xl bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:opacity-50 transition"
          >
            {searching ? 'Searching…' : 'Find'}
          </button>
        </div>
      </div>

      {purchase && (
        <>
          {/* Purchase summary */}
          <div className="rounded-2xl border border-amber-200 bg-amber-50 px-5 py-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-amber-800">{purchase.purchase_number}</p>
                {purchase.supplier_name && (
                  <p className="text-xs text-amber-600">{purchase.supplier_name}</p>
                )}
              </div>
              <p className="text-lg font-bold text-amber-800">{currency.format(purchase.total_amount)}</p>
            </div>
          </div>

          {lineItems.length > 0 ? (
            <div className="rounded-2xl border border-slate-200 bg-white p-5">
              <h2 className="text-base font-semibold text-slate-800 mb-3">Select Items to Return</h2>
              <div className="space-y-3">
                {lineItems.map((item, idx) => (
                  <div key={idx} className="flex items-center gap-4 rounded-xl border border-slate-100 p-3">
                    <div className="flex-1">
                      <p className="text-sm font-semibold text-slate-800">{item.product_name}</p>
                      <p className="text-xs text-slate-500">
                        {item.unit} × {currency.format(item.unit_cost)} — purchased qty: {item.quantity}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <label className="text-xs text-slate-500">Return qty</label>
                      <input
                        type="number"
                        min={0}
                        max={item.quantity}
                        step={1}
                        value={item.returnQty}
                        onChange={(e) => updateReturnQty(idx, parseFloat(e.target.value) || 0)}
                        className="w-20 rounded-lg border border-slate-200 px-2 py-1 text-sm text-center outline-none focus:border-indigo-400"
                      />
                    </div>
                    {item.returnQty > 0 && (
                      <p className="text-sm font-semibold text-red-600 w-24 text-right">
                        −{currency.format(item.returnQty * item.unit_cost)}
                      </p>
                    )}
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="rounded-2xl border border-slate-200 bg-white p-5 text-center text-sm text-slate-400">
              No item details found for this purchase. Enter a return total manually.
              <div className="mt-4 flex justify-center">
                <div className="w-48">
                  <label className="block text-sm font-medium text-slate-700 mb-1">Return Amount</label>
                  <input
                    type="number"
                    min={0}
                    step={0.01}
                    placeholder="0.00"
                    className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400"
                    onChange={(e) => {
                      const val = parseFloat(e.target.value) || 0
                      setLineItems((prev) => {
                        const existing = prev.find((i) => i.product_name === 'Manual return')
                        if (existing) {
                          return prev.map((i) =>
                            i.product_name === 'Manual return'
                              ? { ...i, unit_cost: val, total_cost: val }
                              : i,
                          )
                        }
                        return [{
                          product_name: 'Manual return',
                          unit: 'piece',
                          quantity: 1,
                          unit_cost: val,
                          total_cost: val,
                          returnQty: 1,
                        }]
                      })
                    }}
                  />
                </div>
              </div>
            </div>
          )}

          {/* Notes */}
          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            <label className="block text-sm font-medium text-slate-700 mb-1">Notes (optional)</label>
            <input
              className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100"
              placeholder="Reason for return…"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>

          {/* Footer */}
          <div className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-6 py-4">
            <div>
              <p className="text-sm text-slate-500">Return Total</p>
              <p className="text-2xl font-bold text-red-600">{currency.format(returnTotal)}</p>
            </div>
            <button
              type="button"
              onClick={handleSave}
              disabled={saving || returnTotal <= 0}
              className="rounded-xl bg-red-600 px-8 py-3 text-sm font-semibold text-white shadow hover:bg-red-700 disabled:opacity-50 transition"
            >
              {saving ? 'Saving…' : 'Confirm Return'}
            </button>
          </div>
        </>
      )}
    </div>
  )
}

export default PurchaseReturnPage
