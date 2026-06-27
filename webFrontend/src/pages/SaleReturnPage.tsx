import { generateUUID } from '../utils/uuid'
import { useState } from 'react'
import { extractApiError } from '../api/client'
import { upsertSaleReturn } from '../api/saleReturns'
import { apiClient } from '../api/client'
import type { SaleReturnItemRequest } from '../types'

interface BillRow {
  server_id: string
  client_record_id: string
  bill_number: string
  customer_name: string | null
  total_amount: number
  payment_mode: string
  snapshot_json: { items?: BillItemSnap[] } | null
}

interface BillItemSnap {
  product_name: string
  unit: string
  quantity: number
  unit_price: number
  total_price: number
  product_server_id?: string
}

interface ReturnLineItem extends BillItemSnap {
  returnQty: number
}

const currency = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  maximumFractionDigits: 2,
})

const refundModes = ['cash', 'upi', 'bank-transfer']
const returnTypes = ['return', 'exchange']

function SaleReturnPage() {
  const [billNumber, setBillNumber] = useState('')
  const [bill, setBill] = useState<BillRow | null>(null)
  const [lineItems, setLineItems] = useState<ReturnLineItem[]>([])
  const [refundMode, setRefundMode] = useState(refundModes[0])
  const [returnType, setReturnType] = useState(returnTypes[0])
  const [reason, setReason] = useState('')
  const [searching, setSearching] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [toast, setToast] = useState('')

  const searchBill = async () => {
    if (!billNumber.trim()) return
    setSearching(true)
    setError('')
    setBill(null)
    setLineItems([])
    try {
      const { data } = await apiClient.get<{ bills: BillRow[] }>('/bills', {
        params: { billNumber: billNumber.trim() },
      })
      const found = (data.bills ?? [])[0]
      if (!found) { setError(`Bill "${billNumber}" not found`); return }
      setBill(found)
      setLineItems(
        (found.snapshot_json?.items ?? []).map((item) => ({ ...item, returnQty: 0 })),
      )
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

  const returnTotal = lineItems.reduce((s, i) => s + i.returnQty * i.unit_price, 0)

  const handleSave = async () => {
    if (!bill) return
    if (returnTotal <= 0) { setError('Select at least one item to return'); return }
    setSaving(true)
    setError('')
    try {
      const clientRecordId = generateUUID()
      const now = new Date().toISOString()
      const datePrefix = now.slice(0, 10).replace(/-/g, '')
      const returnNumber = `RET-${datePrefix}-${clientRecordId.slice(0, 12).toUpperCase()}`

      const items: SaleReturnItemRequest[] = lineItems
        .filter((i) => i.returnQty > 0)
        .map((i) => ({
          productId: i.product_server_id,
          productName: i.product_name,
          quantity: i.returnQty,
          unit: i.unit,
          unitPrice: i.unit_price,
          totalPrice: i.returnQty * i.unit_price,
        }))

      await upsertSaleReturn({
        clientRecordId,
        returnNumber,
        originalBillNumber: bill.bill_number,
        customerName: bill.customer_name ?? undefined,
        returnType,
        refundMode,
        reason: reason.trim() || undefined,
        totalReturnAmount: returnTotal,
        items,
        createdAt: now,
        updatedAt: now,
      })
      setToast(`✅ Return ${returnNumber} saved — refund ${currency.format(returnTotal)}`)
      setBill(null)
      setLineItems([])
      setBillNumber('')
      setReason('')
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
        <h1 className="text-2xl font-bold text-slate-900">Sale Return / Exchange</h1>
        <p className="mt-1 text-sm text-slate-500">Process a return or exchange for an existing bill</p>
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

      {/* Bill search */}
      <div className="rounded-2xl border border-slate-200 bg-white p-5">
        <h2 className="text-base font-semibold text-slate-800 mb-3">Find Original Bill</h2>
        <div className="flex gap-3">
          <input
            className="flex-1 rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100"
            placeholder="Enter bill number…"
            value={billNumber}
            onChange={(e) => setBillNumber(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && void searchBill()}
          />
          <button
            type="button"
            onClick={searchBill}
            disabled={searching}
            className="rounded-xl bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:opacity-50 transition"
          >
            {searching ? 'Searching…' : 'Find'}
          </button>
        </div>
      </div>

      {bill && (
        <>
          {/* Bill summary */}
          <div className="rounded-2xl border border-indigo-200 bg-indigo-50 px-5 py-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-indigo-800">{bill.bill_number}</p>
                {bill.customer_name && (
                  <p className="text-xs text-indigo-600">{bill.customer_name}</p>
                )}
              </div>
              <p className="text-lg font-bold text-indigo-800">{currency.format(bill.total_amount)}</p>
            </div>
          </div>

          {/* Return items */}
          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            <h2 className="text-base font-semibold text-slate-800 mb-3">Select Items to Return</h2>
            <div className="space-y-3">
              {lineItems.map((item, idx) => (
                <div key={idx} className="flex items-center gap-4 rounded-xl border border-slate-100 p-3">
                  <div className="flex-1">
                    <p className="text-sm font-semibold text-slate-800">{item.product_name}</p>
                    <p className="text-xs text-slate-500">
                      {item.unit} × {currency.format(item.unit_price)} — sold qty: {item.quantity}
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
                      −{currency.format(item.returnQty * item.unit_price)}
                    </p>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Return options */}
          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            <h2 className="text-base font-semibold text-slate-800 mb-4">Return Options</h2>
            <div className="grid gap-4 sm:grid-cols-3">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Return Type</label>
                <select
                  className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400"
                  value={returnType}
                  onChange={(e) => setReturnType(e.target.value)}
                >
                  {returnTypes.map((t) => (
                    <option key={t} value={t}>{t.charAt(0).toUpperCase() + t.slice(1)}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Refund Mode</label>
                <select
                  className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400"
                  value={refundMode}
                  onChange={(e) => setRefundMode(e.target.value)}
                >
                  {refundModes.map((m) => (
                    <option key={m} value={m}>{m.charAt(0).toUpperCase() + m.slice(1)}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Reason</label>
                <input
                  className="w-full rounded-xl border border-slate-200 px-4 py-2.5 text-sm outline-none focus:border-indigo-400"
                  placeholder="Optional"
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                />
              </div>
            </div>
          </div>

          {/* Footer */}
          <div className="flex items-center justify-between rounded-2xl border border-slate-200 bg-white px-6 py-4">
            <div>
              <p className="text-sm text-slate-500">Refund Amount</p>
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

export default SaleReturnPage
