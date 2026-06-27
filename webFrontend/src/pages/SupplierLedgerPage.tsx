import { generateUUID } from '../utils/uuid'
import { useEffect, useMemo, useState } from 'react'
import { extractApiError } from '../api/client'
import { listSuppliers, upsertSupplier } from '../api/masters'
import { listPurchases } from '../api/purchases'
import { upsertTransaction } from '../api/transactions'
import type { SupplierRecord } from '../types'

const currency = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 })

interface PurchaseRow { supplier_name?: string | null; purchase_number?: string; total_amount?: number }

function SupplierLedgerPage() {
  const [purchases, setPurchases] = useState<PurchaseRow[]>([])
  const [suppliers, setSuppliers] = useState<SupplierRecord[]>([])
  const [pendingAmounts, setPendingAmounts] = useState<Record<string, string>>({})
  const [loading, setLoading] = useState(true)
  const [savingId, setSavingId] = useState('')
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  useEffect(() => {
    let cancelled = false

    const bootstrapLedger = async () => {
      setLoading(true)
      setError('')
      try {
        const [purchaseRows, supplierRows] = await Promise.all([listPurchases({ limit: 1000 }), listSuppliers()])
        if (!cancelled) {
          setPurchases(purchaseRows as PurchaseRow[])
          setSuppliers(supplierRows)
        }
      } catch (err) {
        if (!cancelled) {
          setError(extractApiError(err))
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    void bootstrapLedger()
    return () => { cancelled = true }
  }, [])

  const rows = useMemo(() => suppliers.map((supplier) => {
    const supplierPurchases = purchases.filter((purchase) => (purchase.supplier_name || 'Unknown Supplier') === supplier.name)
    const purchaseTotal = supplierPurchases.reduce((sum, purchase) => sum + Number(purchase.total_amount ?? 0), 0)
    return { supplier, purchaseTotal, invoiceCount: supplierPurchases.length }
  }).sort((a, b) => b.supplier.outstandingBalance - a.supplier.outstandingBalance), [purchases, suppliers])

  const markPaid = async (supplier: SupplierRecord) => {
    const amountPaid = Math.max(0, Number(pendingAmounts[supplier.clientRecordId] || 0))
    if (!amountPaid) {
      setError('Enter an amount paid before saving.')
      return
    }
    setSavingId(supplier.clientRecordId)
    setError('')
    setNotice('')
    try {
      const nextOutstanding = Math.max(supplier.outstandingBalance - amountPaid, 0)
      await upsertSupplier({
        clientRecordId: supplier.clientRecordId,
        name: supplier.name,
        phone: supplier.phone ?? undefined,
        address: supplier.address ?? undefined,
        gstNumber: supplier.gstNumber ?? undefined,
        outstandingBalance: nextOutstanding,
        version: supplier.version,
        updatedAt: new Date().toISOString(),
      })
      await upsertTransaction({
        clientRecordId: generateUUID(),
        type: 'supplier_payment',
        totalAmount: amountPaid,
        tags: { supplierName: supplier.name, clientRecordId: supplier.clientRecordId },
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
      setSuppliers((current) => current.map((entry) => entry.clientRecordId === supplier.clientRecordId ? { ...entry, outstandingBalance: nextOutstanding } : entry))
      setPendingAmounts((current) => ({ ...current, [supplier.clientRecordId]: '' }))
      setNotice(`Recorded payment for ${supplier.name}.`)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSavingId('')
    }
  }

  if (loading) {
    return <div className="rounded-2xl bg-white p-6 text-sm text-slate-500 shadow-sm">Loading supplier ledger...</div>
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Supplier Ledger</h1>
        <p className="mt-1 text-sm text-slate-500">Track supplier exposure and write supplier payment updates back to the backend.</p>
      </div>

      {error ? <div className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      {notice ? <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      <section className="rounded-2xl bg-white p-5 ring-1 ring-slate-200 space-y-3">
        {rows.map(({ supplier, purchaseTotal, invoiceCount }) => (
          <div key={supplier.clientRecordId} className="rounded-xl border border-slate-200 p-4">
            <div className="grid gap-3 md:grid-cols-[1.5fr_1fr_1fr_1fr_1fr] md:items-center">
              <div>
                <p className="font-semibold text-slate-900">{supplier.name}</p>
                <p className="text-xs text-slate-500">{invoiceCount} purchases · {supplier.phone ?? 'No phone'}</p>
              </div>
              <p className="text-sm">Purchased: <span className="font-semibold">{currency.format(purchaseTotal)}</span></p>
              <p className="text-sm">Outstanding: <span className="font-semibold text-indigo-700">{currency.format(supplier.outstandingBalance)}</span></p>
              <label className="text-sm">Amount Paid: <input type="number" min={0} step="0.01" value={pendingAmounts[supplier.clientRecordId] ?? ''} onChange={(e) => setPendingAmounts((current) => ({ ...current, [supplier.clientRecordId]: e.target.value }))} className="ml-2 w-28 rounded-md border border-slate-200 px-2 py-1" /></label>
              <button type="button" onClick={() => void markPaid(supplier)} disabled={savingId === supplier.clientRecordId} className="rounded-xl bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700 disabled:bg-slate-300">{savingId === supplier.clientRecordId ? 'Saving...' : 'Mark Paid'}</button>
            </div>
          </div>
        ))}
        {!rows.length ? <p className="text-sm text-slate-500">No supplier activity found.</p> : null}
      </section>
    </div>
  )
}

export default SupplierLedgerPage
