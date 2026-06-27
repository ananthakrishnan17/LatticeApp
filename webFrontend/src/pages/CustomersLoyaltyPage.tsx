import type { FormEvent } from 'react'
import { useEffect, useMemo, useState } from 'react'
import { extractApiError } from '../api/client'
import { listCustomers } from '../api/masters'
import { listTransactions } from '../api/transactions'
import Spinner from '../components/Spinner'
import type { CustomerRecord, TransactionRecord } from '../types'

const LOYALTY_KEY = 'nn_loyalty_rules'

interface LoyaltyRules {
  enabled: boolean
  pointsPerAmount: number
  amountThreshold: number
  redeemValue: number
  redeemPoints: number
}

const defaultRules: LoyaltyRules = {
  enabled: true,
  pointsPerAmount: 1,
  amountThreshold: 100,
  redeemValue: 1,
  redeemPoints: 10,
}

const loadRules = (): LoyaltyRules => {
  try {
    const raw = localStorage.getItem(LOYALTY_KEY)
    return raw ? { ...defaultRules, ...(JSON.parse(raw) as Partial<LoyaltyRules>) } : defaultRules
  } catch {
    return defaultRules
  }
}

function CustomersLoyaltyPage() {
  const [rules, setRules] = useState<LoyaltyRules>(() => loadRules())
  const [customers, setCustomers] = useState<CustomerRecord[]>([])
  const [transactions, setTransactions] = useState<TransactionRecord[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      setLoading(true)
      setError('')
      try {
        const [customerRows, loyaltyRows] = await Promise.all([
          listCustomers(),
          listTransactions({ types: 'loyalty_earn,loyalty_redeem', limit: 1000 }),
        ])
        if (!cancelled) {
          setCustomers(customerRows)
          setTransactions(loyaltyRows)
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

    void load()
    return () => { cancelled = true }
  }, [])

  const ledger = useMemo(() => {
    const map = new Map<string, { phone: string; earned: number; redeemed: number }>()
    customers.forEach((customer) => {
      map.set(customer.name, { phone: customer.phone ?? '—', earned: 0, redeemed: 0 })
    })
    transactions.forEach((transaction) => {
      const tags = (transaction.tags_json ?? {}) as Record<string, unknown>
      const customerName = String(tags.customerName ?? 'Unknown')
      const points = Number(tags.points ?? transaction.total_amount ?? 0)
      const row = map.get(customerName) ?? { phone: '—', earned: 0, redeemed: 0 }
      if (transaction.tx_type === 'loyalty_redeem') {
        row.redeemed += points
      } else {
        row.earned += points
      }
      map.set(customerName, row)
    })
    return Array.from(map.entries()).map(([customerName, value]) => ({ customerName, ...value, balance: value.earned - value.redeemed })).sort((a, b) => b.balance - a.balance)
  }, [customers, transactions])

  const totals = useMemo(() => ledger.reduce((acc, row) => ({ customers: acc.customers + (row.balance > 0 || row.earned > 0 || row.redeemed > 0 ? 1 : 0), issued: acc.issued + row.earned }), { customers: 0, issued: 0 }), [ledger])

  const saveRules = (event: FormEvent) => {
    event.preventDefault()
    localStorage.setItem(LOYALTY_KEY, JSON.stringify(rules))
    setNotice('Loyalty configuration saved.')
  }

  if (loading) {
    return <Spinner label="Loading loyalty data..." />
  }

  return (
    <div className="space-y-6">
      <header className="rounded-3xl border border-indigo-100 bg-white p-6 shadow-sm">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Customers</p>
        <h1 className="mt-2 text-3xl font-bold text-slate-900">Loyalty & Credit</h1>
        <p className="mt-2 text-sm text-slate-500">Configure loyalty rules and review customer points directly from backend transactions.</p>
      </header>

      {error ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      {notice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {[
          ['Total Customers Enrolled', totals.customers],
          ['Total Points Issued', totals.issued],
          ['Points Threshold', `${rules.pointsPerAmount} / ₹${rules.amountThreshold}`],
          ['Redemption', `${rules.redeemPoints} pts = ₹${rules.redeemValue}`],
        ].map(([label, value]) => (
          <article key={String(label)} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <p className="text-xs uppercase tracking-[0.2em] text-slate-500">{label}</p>
            <p className="mt-2 text-2xl font-bold text-slate-900">{value}</p>
          </article>
        ))}
      </section>

      <form onSubmit={saveRules} className="grid gap-6 xl:grid-cols-2">
        <article className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-slate-900">Loyalty Configuration</h2>
            <label className="flex items-center gap-2 text-sm font-medium text-slate-700"><input type="checkbox" checked={rules.enabled} onChange={(e) => setRules((current) => ({ ...current, enabled: e.target.checked }))} /> Enabled</label>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            <label className="text-sm font-medium text-slate-700">Points Earned<input type="number" min={1} value={rules.pointsPerAmount} onChange={(e) => setRules((current) => ({ ...current, pointsPerAmount: Math.max(1, Number(e.target.value) || 1) }))} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3" /></label>
            <label className="text-sm font-medium text-slate-700">For Every Amount (₹)<input type="number" min={1} value={rules.amountThreshold} onChange={(e) => setRules((current) => ({ ...current, amountThreshold: Math.max(1, Number(e.target.value) || 1) }))} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3" /></label>
            <label className="text-sm font-medium text-slate-700">Points to Redeem<input type="number" min={1} value={rules.redeemPoints} onChange={(e) => setRules((current) => ({ ...current, redeemPoints: Math.max(1, Number(e.target.value) || 1) }))} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3" /></label>
            <label className="text-sm font-medium text-slate-700">Discount Value (₹)<input type="number" min={1} value={rules.redeemValue} onChange={(e) => setRules((current) => ({ ...current, redeemValue: Math.max(1, Number(e.target.value) || 1) }))} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3" /></label>
          </div>
          <p className="rounded-xl bg-indigo-50 px-3 py-2 text-sm text-indigo-700">{rules.enabled ? `${rules.pointsPerAmount} point(s) for every ₹${rules.amountThreshold} billed.` : 'Automatic earning is disabled.'}</p>
          <div className="flex justify-end"><button type="submit" className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white hover:bg-indigo-700">Save configuration</button></div>
        </article>
      </form>

      <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-slate-900">Customer Points Ledger</h2>
        <div className="mt-4 overflow-x-auto rounded-2xl border border-slate-200">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>{['Customer Name', 'Phone', 'Points Earned', 'Points Redeemed', 'Net Points Balance'].map((heading) => <th key={heading} className="px-4 py-3 text-left font-semibold">{heading}</th>)}</tr>
            </thead>
            <tbody>
              {ledger.length ? ledger.map((row) => (
                <tr key={row.customerName} className="border-t border-slate-100 text-slate-700">
                  <td className="px-4 py-3 font-semibold text-slate-900">{row.customerName}</td>
                  <td className="px-4 py-3">{row.phone}</td>
                  <td className="px-4 py-3">{row.earned}</td>
                  <td className="px-4 py-3">{row.redeemed}</td>
                  <td className="px-4 py-3 font-semibold text-indigo-700">{row.balance}</td>
                </tr>
              )) : <tr><td colSpan={5} className="px-4 py-8 text-center text-slate-500">No loyalty activity found.</td></tr>}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  )
}

export default CustomersLoyaltyPage
