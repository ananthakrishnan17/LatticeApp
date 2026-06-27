import { generateUUID } from '../utils/uuid'
import { useMemo, useState } from 'react'
import { listBills, type BillRecord } from '../api/bills'
import { extractApiError } from '../api/client'
import { upsertTransaction } from '../api/transactions'
import { useAuth } from '../context/AuthContext'
import { pushAuditEvent } from '../utils/auditLog'

const currency = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 })
const VOID_KEY = 'nn_voided_bill_ids'

const loadVoided = () => {
  try {
    const raw = localStorage.getItem(VOID_KEY)
    return raw ? (JSON.parse(raw) as string[]) : []
  } catch {
    return []
  }
}

function BillHistoryPage() {
  const { username } = useAuth()
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [bills, setBills] = useState<BillRecord[]>([])
  const [selected, setSelected] = useState<BillRecord | null>(null)
  const [voidReason, setVoidReason] = useState('')
  const [voidedIds, setVoidedIds] = useState<string[]>(() => loadVoided())

  const voidedSet = useMemo(() => new Set(voidedIds), [voidedIds])

  const search = async () => {
    setLoading(true)
    setError('')
    setNotice('')
    try {
      const result = await listBills(query.trim() ? { billNumber: query.trim(), limit: 100 } : { limit: 200 })
      setBills(result)
      setSelected(result[0] ?? null)
      if (!result.length) setNotice('No bills found.')
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setLoading(false)
    }
  }

  const reprint = (bill: BillRecord) => {
    const popup = window.open('', '_blank', 'width=420,height=640')
    if (!popup) return
    const rows = (bill.items ?? []).map((item) => `<tr><td>${item.product_name}</td><td>${item.quantity}</td><td>${item.unit_price}</td><td>${item.total_price}</td></tr>`).join('')
    popup.document.write(`<html><body><h3>Bill ${bill.bill_number}</h3><p>Customer: ${bill.customer_name ?? 'Walk-in'}</p><table border="1" cellspacing="0" cellpadding="4"><tr><th>Item</th><th>Qty</th><th>Price</th><th>Total</th></tr>${rows}</table><h4>Total: ${bill.total_amount}</h4></body></html>`)
    popup.document.close()
    popup.print()
    pushAuditEvent({ module: 'billing', action: 'reprint', detail: `Reprinted ${bill.bill_number}`, actor: username ?? 'unknown' })
  }

  const markVoid = async () => {
    if (!selected) return
    if (!voidReason.trim()) {
      setError('Enter a reason to void this bill.')
      return
    }
    try {
      await upsertTransaction({
        clientRecordId: generateUUID(),
        type: 'bill_void',
        totalAmount: selected.total_amount,
        tags: {
          bill_number: selected.bill_number,
          reason: voidReason.trim(),
          bill_server_id: selected.server_id,
        },
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
      const next = Array.from(new Set([selected.server_id, ...voidedIds]))
      setVoidedIds(next)
      localStorage.setItem(VOID_KEY, JSON.stringify(next))
      setNotice(`Bill ${selected.bill_number} marked as void.`)
      pushAuditEvent({ module: 'billing', action: 'void', detail: `Voided ${selected.bill_number}: ${voidReason.trim()}`, actor: username ?? 'unknown' })
      setVoidReason('')
    } catch (err) {
      setError(extractApiError(err))
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Bill History</h1>
        <p className="mt-1 text-sm text-slate-500">Search bills, reprint receipts, and void with reason.</p>
      </div>

      <div className="flex gap-3">
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search by bill number" className="flex-1 rounded-xl border border-slate-200 px-4 py-2.5 text-sm" />
        <button type="button" onClick={() => void search()} className="rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white">{loading ? 'Searching...' : 'Search'}</button>
      </div>

      {error ? <div className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      {notice ? <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      <div className="grid gap-6 lg:grid-cols-[1.1fr_1fr]">
        <section className="rounded-2xl bg-white p-4 ring-1 ring-slate-200 space-y-2 max-h-[520px] overflow-y-auto">
          {bills.length ? bills.map((bill) => (
            <button
              key={bill.server_id}
              type="button"
              onClick={() => setSelected(bill)}
              className={`w-full rounded-xl border px-4 py-3 text-left ${selected?.server_id === bill.server_id ? 'border-indigo-300 bg-indigo-50' : 'border-slate-200 bg-white'}`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-semibold text-slate-900">{bill.bill_number}</p>
                  <p className="text-xs text-slate-500">{bill.customer_name ?? 'Walk-in'} · {new Date(bill.created_at).toLocaleString()}</p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-bold text-slate-900">{currency.format(bill.total_amount)}</p>
                  {voidedSet.has(bill.server_id) ? <p className="text-xs font-semibold text-rose-600">VOID</p> : null}
                </div>
              </div>
            </button>
          )) : <p className="px-2 py-8 text-center text-sm text-slate-500">Search to load bills.</p>}
        </section>

        <section className="rounded-2xl bg-white p-5 ring-1 ring-slate-200">
          {selected ? (
            <div className="space-y-4">
              <div className="flex items-center justify-between gap-3">
                <h2 className="text-lg font-semibold text-slate-900">{selected.bill_number}</h2>
                <button type="button" onClick={() => reprint(selected)} className="rounded-xl border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700">Reprint</button>
              </div>
              <p className="text-sm text-slate-500">{selected.customer_name ?? 'Walk-in'} · {currency.format(selected.total_amount)} · {selected.payment_mode.toUpperCase()}</p>

              <div className="max-h-56 overflow-y-auto space-y-2">
                {(selected.items ?? []).map((item, idx) => (
                  <div key={`${item.product_name}-${idx}`} className="flex items-center justify-between rounded-xl bg-slate-50 px-3 py-2 text-sm">
                    <span>{item.product_name} × {item.quantity}</span>
                    <span className="font-semibold">{currency.format(item.total_price)}</span>
                  </div>
                ))}
              </div>

              <div className="space-y-2 border-t border-slate-100 pt-4">
                <label className="block text-sm font-medium text-slate-700">Void reason</label>
                <textarea value={voidReason} onChange={(e) => setVoidReason(e.target.value)} rows={2} className="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Explain why this bill is being voided" />
                <button type="button" onClick={() => void markVoid()} disabled={voidedSet.has(selected.server_id)} className="rounded-xl bg-rose-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">
                  {voidedSet.has(selected.server_id) ? 'Already voided' : 'Void bill'}
                </button>
              </div>
            </div>
          ) : <p className="text-sm text-slate-500">Choose a bill to view details.</p>}
        </section>
      </div>
    </div>
  )
}

export default BillHistoryPage
