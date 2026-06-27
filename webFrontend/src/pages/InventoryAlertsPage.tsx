import { useEffect, useMemo, useState } from 'react'
import { extractApiError } from '../api/client'
import { listProducts } from '../api/products'
import type { ProductResponse } from '../types'

const KEY = 'nn_reorder_thresholds'

const loadThresholds = () => {
  try {
    const raw = localStorage.getItem(KEY)
    return raw ? (JSON.parse(raw) as Record<string, number>) : {}
  } catch {
    return {}
  }
}

function InventoryAlertsPage() {
  const [products, setProducts] = useState<ProductResponse[]>([])
  const [thresholds, setThresholds] = useState<Record<string, number>>(() => loadThresholds())
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false

    const bootstrapProducts = async () => {
      setLoading(true)
      setError('')
      try {
        const result = await listProducts()
        if (!cancelled) {
          setProducts(result)
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

    void bootstrapProducts()

    return () => {
      cancelled = true
    }
  }, [])

  const active = useMemo(() => products.filter((p) => p.deletedAt === null), [products])

  const lowStock = useMemo(() => active
    .map((item) => ({ item, threshold: thresholds[item.clientRecordId] ?? 5 }))
    .filter(({ item, threshold }) => item.stockQuantity <= threshold)
    .sort((a, b) => a.item.stockQuantity - b.item.stockQuantity), [active, thresholds])

  const setThreshold = (productId: string, value: number) => {
    const next = { ...thresholds, [productId]: value }
    setThresholds(next)
    localStorage.setItem(KEY, JSON.stringify(next))
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Low-Stock & Reorder Alerts</h1>
        <p className="mt-1 text-sm text-slate-500">Set thresholds and generate purchase suggestions.</p>
      </div>

      {error ? <div className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}

      <section className="rounded-2xl bg-white p-5 ring-1 ring-slate-200">
        <h2 className="text-lg font-semibold text-slate-900">Critical products ({lowStock.length})</h2>
        {loading ? <p className="mt-3 text-sm text-slate-500">Loading...</p> : (
          <div className="mt-4 space-y-2 max-h-[420px] overflow-y-auto">
            {lowStock.map(({ item, threshold }) => {
              const suggestedQty = Math.max(threshold * 3 - item.stockQuantity, threshold)
              return (
                <div key={item.clientRecordId} className="rounded-xl border border-slate-200 p-3">
                  <div className="grid gap-3 md:grid-cols-[1.5fr_1fr_1fr_1fr] md:items-center">
                    <div>
                      <p className="font-semibold text-slate-900">{item.name}</p>
                      <p className="text-xs text-slate-500">Unit: {item.unit}</p>
                    </div>
                    <p className="text-sm">Current: <span className="font-semibold">{item.stockQuantity}</span></p>
                    <label className="text-sm">Threshold: <input type="number" value={threshold} onChange={(e) => setThreshold(item.clientRecordId, Number.parseFloat(e.target.value) || 0)} className="ml-2 w-20 rounded-md border border-slate-200 px-2 py-1" /></label>
                    <p className="text-sm font-semibold text-indigo-700">Suggested purchase: {suggestedQty}</p>
                  </div>
                </div>
              )
            })}
            {!lowStock.length ? <p className="text-sm text-slate-500">No low-stock alerts right now.</p> : null}
          </div>
        )}
      </section>
    </div>
  )
}

export default InventoryAlertsPage
