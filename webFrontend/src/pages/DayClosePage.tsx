import { generateUUID } from '../utils/uuid'
import { useEffect, useMemo, useState } from 'react'
import { listBills } from '../api/bills'
import { extractApiError } from '../api/client'
import { listDayCloseRecords, upsertDayClose } from '../api/dayClose'
import { listPurchases } from '../api/purchases'
import { listSaleReturns } from '../api/saleReturns'
import { listTransactions } from '../api/transactions'
import Spinner from '../components/Spinner'
import { useAuth } from '../context/AuthContext'
import { getActiveCashSession, listCashSessions, parseDenominationCounts, sumDenominationCounts } from '../utils/cashSession'

const DENOMINATIONS = [500, 200, 100, 50, 20, 10]
const today = new Date().toISOString().slice(0, 10)

interface PurchaseRow { total_amount?: number; purchase_date?: string; created_at?: string }
interface SaleReturnRow { total_return_amount?: number; created_at?: string }
interface DayCloseRecord { close_date?: string; cash_opening?: number; total_sales?: number; total_expenses?: number; cash_closing?: number }

const isToday = (value?: string | null) => Boolean(value?.slice(0, 10) === today)

function DayClosePage() {
  const { username } = useAuth()
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [alreadyClosed, setAlreadyClosed] = useState(false)
  const [openingCash, setOpeningCash] = useState(0)
  const [notes, setNotes] = useState('')
  const [counts, setCounts] = useState<Record<number, number>>(() => DENOMINATIONS.reduce<Record<number, number>>((acc, note) => ({ ...acc, [note]: 0 }), {}))
  const [computed, setComputed] = useState({ totalSales: 0, billCount: 0, cashSales: 0, digitalSales: 0, totalExpenses: 0, totalReturns: 0, totalPurchases: 0 })

  useEffect(() => {
    let cancelled = false

    const bootstrap = async () => {
      setLoading(true)
      setError('')
      try {
        const [bills, expenses, saleReturns, purchases, dayCloseRecords] = await Promise.all([
          listBills({ limit: 500 }),
          listTransactions({ types: 'expense', limit: 500 }),
          listSaleReturns({ limit: 500 }),
          listPurchases({ limit: 500 }),
          listDayCloseRecords({ limit: 50 }),
        ])

        if (cancelled) {
          return
        }

        const todaysBills = bills.filter((bill) => isToday(bill.created_at))
        const todaysExpenses = expenses.filter((tx) => isToday(tx.created_at))
        const todaysReturns = (saleReturns as SaleReturnRow[]).filter((entry) => isToday(entry.created_at))
        const todaysPurchases = (purchases as PurchaseRow[]).filter((entry) => isToday(entry.purchase_date ?? entry.created_at))
        const todaysDayClose = (dayCloseRecords as DayCloseRecord[]).find((entry) => isToday(entry.close_date))
        const todaysCashSessions = (username ? listCashSessions(username) : []).filter((session) => isToday(session.openedAt) || isToday(session.closedAt))
        const todaysCashSession = username ? getActiveCashSession(username) ?? todaysCashSessions[0] ?? null : null

        setAlreadyClosed(Boolean(todaysDayClose))
        setOpeningCash(Number(todaysCashSession?.openingAmount ?? todaysDayClose?.cash_opening ?? 0))
        if (todaysCashSession?.closingDenominations) {
          setCounts(parseDenominationCounts(todaysCashSession.closingDenominations))
        } else {
          setCounts(DENOMINATIONS.reduce<Record<number, number>>((acc, note) => ({ ...acc, [note]: 0 }), {}))
        }
        setNotes(todaysCashSession?.notes ?? '')
        const { totalSales, cashSales, digitalSales } = todaysBills.reduce(
          (acc, bill) => {
            const isCash = bill.payment_mode.toLowerCase() === 'cash'
            return {
              totalSales: acc.totalSales + bill.total_amount,
              cashSales: acc.cashSales + (isCash ? bill.total_amount : 0),
              digitalSales: acc.digitalSales + (isCash ? 0 : bill.total_amount),
            }
          },
          { totalSales: 0, cashSales: 0, digitalSales: 0 },
        )
        setComputed({
          totalSales,
          billCount: todaysBills.length,
          cashSales,
          digitalSales,
          totalExpenses: todaysExpenses.reduce((sum, tx) => sum + tx.total_amount, 0),
          totalReturns: todaysReturns.reduce((sum, entry) => sum + Number(entry.total_return_amount ?? 0), 0),
          totalPurchases: todaysPurchases.reduce((sum, entry) => sum + Number(entry.total_amount ?? 0), 0),
        })
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

    void bootstrap()
    return () => { cancelled = true }
  }, [username])

  const countedCash = useMemo(() => sumDenominationCounts(counts), [counts])
  const expectedCash = openingCash + computed.cashSales - computed.totalExpenses - computed.totalReturns
  const variance = countedCash - expectedCash

  const handleSubmit = async () => {
    setSaving(true)
    setError('')
    setNotice('')
    try {
      await upsertDayClose({
        clientRecordId: generateUUID(),
        closeDate: `${today}T23:59:59`,
        cashOpening: openingCash,
        cashClosing: countedCash,
        cashVariance: variance,
        totalSales: computed.totalSales,
        totalExpenses: computed.totalExpenses,
        totalReturns: computed.totalReturns,
        totalPurchases: computed.totalPurchases,
        cashSales: computed.cashSales,
        digitalSales: computed.digitalSales,
        billCount: computed.billCount,
        notes,
        closedBy: username ?? 'unknown',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
      setAlreadyClosed(true)
      setNotice('Day close saved successfully.')
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return <Spinner label="Loading day close..." />
  }

  return (
    <div className="space-y-6">
      <header className="rounded-3xl border border-indigo-100 bg-white p-6 shadow-sm">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">End Of Day</p>
        <h1 className="mt-2 text-3xl font-bold text-slate-900">Cashier Shift Close</h1>
        <p className="mt-2 text-sm text-slate-500">Review today’s billing summary, count denominations, and close the day against backend data.</p>
      </header>

      {error ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      {notice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}
      {alreadyClosed ? <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-700">Today’s shift is already closed. The form is read-only.</div> : null}

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {[
          ['Total Sales', computed.totalSales],
          ['Bill Count', computed.billCount],
          ['Cash Sales', computed.cashSales],
          ['Digital Sales', computed.digitalSales],
          ['Expenses', computed.totalExpenses],
          ['Sale Returns', computed.totalReturns],
          ['Purchases', computed.totalPurchases],
          ['Opening Cash', openingCash],
        ].map(([label, value]) => (
          <article key={String(label)} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <p className="text-xs uppercase tracking-[0.2em] text-slate-500">{label}</p>
            <p className="mt-2 text-2xl font-bold text-slate-900">{typeof value === 'number' ? (label === 'Bill Count' ? value : `₹${Number(value).toLocaleString('en-IN')}`) : value}</p>
          </article>
        ))}
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.6fr,1fr]">
        <article className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm space-y-4">
          <div>
            <h2 className="text-lg font-semibold text-slate-900">Cash denomination count</h2>
            <p className="mt-1 text-sm text-slate-500">Opening cash and denomination counts are captured from the cashier closing workflow.</p>
          </div>

          <label className="block max-w-sm text-sm font-medium text-slate-700">
            Opening Cash
            <input type="number" min={0} value={openingCash} disabled={alreadyClosed} onChange={(e) => setOpeningCash(Math.max(0, Number(e.target.value) || 0))} className="mt-2 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-900 disabled:bg-slate-100" />
          </label>

          <div className="grid gap-3 md:grid-cols-2">
            {DENOMINATIONS.map((note) => (
              <label key={note} className="rounded-xl border border-slate-200 p-3 text-sm font-medium text-slate-700">
                ₹{note} notes
                <input
                  type="number"
                  min={0}
                  disabled={alreadyClosed}
                  value={counts[note] ?? 0}
                  onChange={(e) => setCounts((prev) => ({ ...prev, [note]: Math.max(0, Number(e.target.value) || 0) }))}
                  className="mt-2 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm disabled:bg-slate-100"
                />
              </label>
            ))}
          </div>

          <label className="block text-sm font-medium text-slate-700">
            Notes
            <textarea value={notes} disabled={alreadyClosed} onChange={(e) => setNotes(e.target.value)} rows={3} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm disabled:bg-slate-100" placeholder="Optional day close notes" />
          </label>
        </article>

        <article className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-slate-900">Close summary</h2>
          <dl className="mt-4 space-y-2 text-sm">
            <div className="flex justify-between"><dt className="text-slate-600">Expected Cash</dt><dd className="font-semibold text-slate-900">₹{expectedCash.toLocaleString('en-IN')}</dd></div>
            <div className="flex justify-between"><dt className="text-slate-600">Counted Cash</dt><dd className="font-semibold text-slate-900">₹{countedCash.toLocaleString('en-IN')}</dd></div>
            <div className="flex justify-between"><dt className="text-slate-600">Variance</dt><dd className={`font-semibold ${variance === 0 ? 'text-emerald-700' : 'text-rose-700'}`}>₹{variance.toLocaleString('en-IN')}</dd></div>
          </dl>

          <div className="mt-5 space-y-2">
            <button type="button" disabled={alreadyClosed || saving} onClick={() => void handleSubmit()} className="w-full rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300">{saving ? 'Saving...' : 'Close Cashier Shift'}</button>
            <button type="button" onClick={() => window.print()} className="w-full rounded-xl border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-700 hover:border-indigo-300 hover:text-indigo-700">Print Day Close Report</button>
          </div>
        </article>
      </section>
    </div>
  )
}

export default DayClosePage
