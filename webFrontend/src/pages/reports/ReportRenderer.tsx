import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { listBills, type BillRecord } from '../../api/bills'
import { extractApiError } from '../../api/client'
import { listSuppliers, listCustomers } from '../../api/masters'
import { listPurchases } from '../../api/purchases'
import { listSaleReturns } from '../../api/saleReturns'
import { listTransactions } from '../../api/transactions'
import { listDayCloseRecords } from '../../api/dayClose'
import { listProducts } from '../../api/products'
import Spinner from '../../components/Spinner'
import type { CustomerRecord, ProductResponse, SupplierRecord, TransactionRecord } from '../../types'

const currency = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 })
const productMetaKey = 'nn_product_meta'

type ReportKey =
  | 'billwise'
  | 'hourly-sales'
  | 'gst'
  | 'cancelled-bills'
  | 'sales-by-bill'
  | 'modified-bills'
  | 'day-book'
  | 'profit-loss'
  | 'daywise-profit'
  | 'payment-methods'
  | 'cashier-sales'
  | 'cash-in-hand'
  | 'item-wise-sales'
  | 'category-stock'
  | 'product-stock-history'
  | 'moving-products'
  | 'stock-ledger'
  | 'product-stock-sales'
  | 'customer-balance'
  | 'top-customers'
  | 'supplier-balance'
  | 'purchase-report'
  | 'customer-purchase-history'
  | 'crm-points'

interface Props {
  reportKey: ReportKey
}

interface PurchaseRow {
  server_id?: string
  client_record_id?: string
  purchase_number?: string
  supplier_name?: string | null
  total_amount?: number
  gst_total?: number
  payment_mode?: string
  invoice_number?: string
  purchase_date?: string
  created_at?: string
  items?: Array<{ product_name?: string; quantity?: number; unit_cost?: number; total_cost?: number }>
}

interface SaleReturnRow {
  client_record_id?: string
  return_number?: string
  original_bill_number?: string
  customer_name?: string | null
  total_return_amount?: number
  refund_mode?: string
  reason?: string
  created_at?: string
  items?: Array<{ product_name?: string; quantity?: number; total_price?: number }>
}

interface DayCloseRecord {
  close_date?: string
  created_at?: string
  total_sales?: number
  total_expenses?: number
  cash_opening?: number
  cash_closing?: number
}

const today = new Date()
const toDateInput = (value: Date) => value.toISOString().slice(0, 10)
const addDays = (value: Date, days: number) => new Date(value.getTime() + days * 24 * 60 * 60 * 1000)
const defaultFrom = toDateInput(addDays(today, -29))
const defaultTo = toDateInput(today)
const defaultToday = toDateInput(today)
const ninetyDays = toDateInput(addDays(today, -89))

const startOfDayIso = (value: string) => new Date(`${value}T00:00:00`).toISOString()
const isBetween = (value: string, from: string, to: string) => {
  const date = new Date(value).getTime()
  return date >= new Date(`${from}T00:00:00`).getTime() && date <= new Date(`${to}T23:59:59`).getTime()
}

function loadProductMeta() {
  try {
    const raw = localStorage.getItem(productMetaKey)
    return raw ? (JSON.parse(raw) as Record<string, { productType?: string }>) : {}
  } catch {
    return {}
  }
}

function BackButton() {
  return <Link to="/reports" className="inline-flex rounded-2xl border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-700 hover:border-indigo-300 hover:text-indigo-700">← Back to Reports</Link>
}

function Shell({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return (
    <div className="space-y-6">
      <BackButton />
      <header className="rounded-3xl border border-indigo-100 bg-white p-6 shadow-sm">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Reports</p>
        <h1 className="mt-2 text-3xl font-bold text-slate-900">{title}</h1>
        <p className="mt-2 text-sm text-slate-500">{subtitle}</p>
      </header>
      {children}
    </div>
  )
}

function SummaryCards({ cards }: { cards: Array<{ label: string; value: string; hint?: string }> }) {
  return (
    <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      {cards.map((card) => (
        <article key={card.label} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <p className="text-xs uppercase tracking-[0.2em] text-slate-500">{card.label}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{card.value}</p>
          {card.hint ? <p className="mt-1 text-xs text-slate-500">{card.hint}</p> : null}
        </article>
      ))}
    </section>
  )
}

function Table({ headers, rows, footer }: { headers: string[]; rows: React.ReactNode[][]; footer?: React.ReactNode[] }) {
  return (
    <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
      <table className="w-full text-sm">
        <thead className="bg-slate-50 text-slate-600">
          <tr>{headers.map((header) => <th key={header} className="px-4 py-3 text-left font-semibold">{header}</th>)}</tr>
        </thead>
        <tbody>
          {rows.length ? rows.map((row, index) => (
            <tr key={index} className="border-t border-slate-100 text-slate-700">{row.map((cell, cellIndex) => <td key={cellIndex} className="px-4 py-3 align-top">{cell}</td>)}</tr>
          )) : (
            <tr><td colSpan={headers.length} className="px-4 py-8 text-center text-slate-500">No data found for the selected filters.</td></tr>
          )}
        </tbody>
        {footer ? <tfoot className="border-t border-slate-200 bg-slate-50 font-semibold text-slate-900"><tr>{footer.map((cell, idx) => <td key={idx} className="px-4 py-3">{cell}</td>)}</tr></tfoot> : null}
      </table>
    </div>
  )
}

function PlaceholderCard({ title, message }: { title: string; message: string }) {
  return (
    <div className="rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
      <div className="rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-8 text-center">
        <h2 className="text-xl font-semibold text-slate-900">{title}</h2>
        <p className="mt-3 text-sm text-slate-500">{message}</p>
      </div>
    </div>
  )
}

function RangeFilters({ from, to, setFrom, setTo }: { from: string; to: string; setFrom: (v: string) => void; setTo: (v: string) => void }) {
  return (
    <section className="grid gap-4 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm md:grid-cols-2 xl:grid-cols-4">
      <label className="text-sm font-medium text-slate-700">Date Range From<input type="date" value={from} onChange={(event) => setFrom(event.target.value)} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3" /></label>
      <label className="text-sm font-medium text-slate-700">Date Range To<input type="date" value={to} onChange={(event) => setTo(event.target.value)} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3" /></label>
    </section>
  )
}

function SingleDateFilter({ date, setDate }: { date: string; setDate: (v: string) => void }) {
  return (
    <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
      <label className="block max-w-xs text-sm font-medium text-slate-700">Date<input type="date" value={date} onChange={(event) => setDate(event.target.value)} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3" /></label>
    </section>
  )
}

export default function ReportRenderer({ reportKey }: Props) {
  const [from, setFrom] = useState(reportKey === 'top-customers' ? ninetyDays : defaultFrom)
  const [to, setTo] = useState(defaultTo)
  const [date, setDate] = useState(defaultToday)
  const [selectedProduct, setSelectedProduct] = useState('')
  const [selectedCustomer, setSelectedCustomer] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [payload, setPayload] = useState<Record<string, unknown>>({})

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      setLoading(true)
      setError('')
      try {
        let nextPayload: Record<string, unknown> = {}
        switch (reportKey) {
          case 'billwise':
          case 'hourly-sales':
          case 'gst':
          case 'sales-by-bill':
          case 'modified-bills':
          case 'payment-methods':
          case 'cashier-sales':
          case 'item-wise-sales':
          case 'moving-products':
          case 'top-customers':
          case 'customer-purchase-history': {
            nextPayload = { bills: await listBills({ since: startOfDayIso(from), limit: 1000 }) }
            break
          }
          case 'stock-ledger':
          case 'product-stock-sales': {
            const [bills, purchases, products] = await Promise.all([
              listBills({ since: startOfDayIso(from), limit: 1000 }),
              listPurchases({ since: startOfDayIso(from), limit: 1000 }),
              listProducts(),
            ])
            nextPayload = { bills, purchases, products }
            break
          }
          case 'cancelled-bills': {
            const [bills, transactions] = await Promise.all([
              listBills({ since: startOfDayIso(from), limit: 1000 }),
              listTransactions({ types: 'void,bill_void', since: startOfDayIso(from), limit: 500 }),
            ])
            nextPayload = { bills, transactions }
            break
          }
          case 'day-book': {
            const [bills, transactions, returns] = await Promise.all([
              listBills({ since: startOfDayIso(date), limit: 1000 }),
              listTransactions({ since: startOfDayIso(date), limit: 500 }),
              listSaleReturns({ since: startOfDayIso(date), limit: 500 }),
            ])
            nextPayload = { bills, transactions, returns }
            break
          }
          case 'profit-loss':
          case 'daywise-profit': {
            const [bills, purchases, expenses] = await Promise.all([
              listBills({ since: startOfDayIso(from), limit: 1000 }),
              listPurchases({ since: startOfDayIso(from), limit: 1000 }),
              listTransactions({ types: 'expense', since: startOfDayIso(from), limit: 500 }),
            ])
            nextPayload = { bills, purchases, expenses }
            break
          }
          case 'cash-in-hand': {
            nextPayload = { dayClose: await listDayCloseRecords({ limit: 30 }) }
            break
          }
          case 'category-stock': {
            nextPayload = { products: await listProducts() }
            break
          }
          case 'product-stock-history': {
            const [bills, purchases, products] = await Promise.all([
              listBills({ since: startOfDayIso(from), limit: 1000 }),
              listPurchases({ since: startOfDayIso(from), limit: 1000 }),
              listProducts(),
            ])
            nextPayload = { bills, purchases, products }
            break
          }
          case 'customer-balance': {
            nextPayload = { customers: await listCustomers() }
            break
          }
          case 'supplier-balance': {
            const [suppliers, purchases] = await Promise.all([listSuppliers(), listPurchases({ since: startOfDayIso(from), limit: 1000 })])
            nextPayload = { suppliers, purchases }
            break
          }
          case 'purchase-report': {
            nextPayload = { purchases: await listPurchases({ since: startOfDayIso(from), limit: 1000 }) }
            break
          }
          case 'crm-points': {
            const [transactions, customers] = await Promise.all([
              listTransactions({ types: 'loyalty_earn,loyalty_redeem', since: startOfDayIso(from), limit: 1000 }),
              listCustomers(),
            ])
            nextPayload = { transactions, customers }
            break
          }
        }

        if (!cancelled) {
          setPayload(nextPayload)
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
  }, [date, from, reportKey])

  const isSingleDayReport = reportKey === 'hourly-sales' || reportKey === 'day-book'
  const billDateFrom = isSingleDayReport ? date : from
  const billDateTo = isSingleDayReport ? date : to
  const txDateFrom = reportKey === 'day-book' ? date : from
  const txDateTo = reportKey === 'day-book' ? date : to

  const filteredBills = useMemo(
    () => ((payload.bills as BillRecord[] | undefined) ?? []).filter((bill) => isBetween(bill.created_at, billDateFrom, billDateTo)),
    [billDateFrom, billDateTo, payload.bills],
  )
  const filteredPurchases = useMemo(() => ((payload.purchases as PurchaseRow[] | undefined) ?? []).filter((purchase) => {
    const value = purchase.purchase_date ?? purchase.created_at ?? ''
    return value ? isBetween(value, from, to) : true
  }), [from, payload.purchases, to])
  const filteredTransactions = useMemo(
    () => ((payload.transactions as TransactionRecord[] | undefined) ?? []).filter((transaction) => isBetween(transaction.created_at, txDateFrom, txDateTo)),
    [payload.transactions, txDateFrom, txDateTo],
  )
  const filteredReturns = useMemo(
    () => ((payload.returns as SaleReturnRow[] | undefined) ?? []).filter((entry) => entry.created_at ? isBetween(entry.created_at, txDateFrom, txDateTo) : true),
    [payload.returns, txDateFrom, txDateTo],
  )

  if (loading) {
    return <Spinner label="Loading report..." />
  }

  if (error) {
    return <Shell title="Report error" subtitle="The report could not be loaded."><div className="rounded-3xl border border-rose-200 bg-rose-50 p-6 text-sm text-rose-700">{error}</div></Shell>
  }

  if (reportKey === 'billwise') {
    const totalRevenue = filteredBills.reduce((sum, bill) => sum + bill.total_amount, 0)
    return <Shell title="Billwise Report" subtitle="Detailed bill register for the selected date range."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><SummaryCards cards={[{ label: 'Total bills', value: String(filteredBills.length) }, { label: 'Total revenue', value: currency.format(totalRevenue) }]} /><Table headers={['Date', 'Bill#', 'Customer', 'Items count', 'Payment Mode', 'Total']} rows={filteredBills.map((bill) => [new Date(bill.created_at).toLocaleString(), bill.bill_number, bill.customer_name ?? 'Walk-in', String(bill.items.length), bill.payment_mode, currency.format(bill.total_amount)])} /></Shell>
  }

  if (reportKey === 'hourly-sales') {
    const hourly = Array.from({ length: 24 }, (_, hour) => {
      const bills = filteredBills.filter((bill) => new Date(bill.created_at).getHours() === hour)
      const revenue = bills.reduce((sum, bill) => sum + bill.total_amount, 0)
      return { hour, count: bills.length, revenue }
    })
    const maxRevenue = Math.max(...hourly.map((item) => item.revenue), 1)
    return <Shell title="Hourly Sales Report" subtitle="Sales bucketed by hour for the selected day."><SingleDateFilter date={date} setDate={setDate} /><div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm space-y-3">{hourly.map((item) => <div key={item.hour} className="grid items-center gap-3 md:grid-cols-[90px_1fr_120px_140px]"><div className="text-sm font-medium text-slate-700">{item.hour.toString().padStart(2, '0')}:00</div><div className="h-4 rounded-full bg-slate-100"><div className="h-4 rounded-full bg-indigo-500" style={{ width: `${(item.revenue / maxRevenue) * 100}%` }} /></div><div className="text-sm text-slate-600">{item.count} bills</div><div className="text-sm font-semibold text-slate-900">{currency.format(item.revenue)}</div></div>)}</div></Shell>
  }

  if (reportKey === 'gst') {
    const footer = filteredBills.reduce((acc, bill) => ({ taxable: acc.taxable + (bill.total_amount - bill.gst_total), gst: acc.gst + bill.gst_total, cgst: acc.cgst + bill.cgst_total, sgst: acc.sgst + bill.sgst_total, total: acc.total + bill.total_amount }), { taxable: 0, gst: 0, cgst: 0, sgst: 0, total: 0 })
    return <Shell title="GST Report" subtitle="Taxable sales and GST breakup by bill."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Bill#', 'Date', 'Taxable Amount', 'GST Total', 'CGST', 'SGST', 'Grand Total']} rows={filteredBills.map((bill) => [bill.bill_number, new Date(bill.created_at).toLocaleString(), currency.format(bill.total_amount - bill.gst_total), currency.format(bill.gst_total), currency.format(bill.cgst_total), currency.format(bill.sgst_total), currency.format(bill.total_amount)])} footer={['Totals', '', currency.format(footer.taxable), currency.format(footer.gst), currency.format(footer.cgst), currency.format(footer.sgst), currency.format(footer.total)]} /></Shell>
  }

  if (reportKey === 'cancelled-bills') {
    const bills = payload.bills as BillRecord[] | undefined ?? []
    const voidedIds = new Set<string>(JSON.parse(localStorage.getItem('nn_voided_bill_ids') ?? '[]') as string[])
    const rows = filteredTransactions.map((transaction) => {
      const tags = (transaction.tags_json ?? {}) as Record<string, unknown>
      const bill = bills.find((entry) => entry.bill_number === tags.bill_number || entry.server_id === tags.bill_server_id)
      return {
        createdAt: transaction.created_at,
        billNumber: String(tags.bill_number ?? bill?.bill_number ?? 'Unknown'),
        reason: String(tags.reason ?? 'No reason captured'),
        amount: transaction.total_amount || bill?.total_amount || 0,
        voidedBy: String(tags.actor ?? 'Unknown'),
        localFlag: bill ? voidedIds.has(bill.server_id) : false,
      }
    })
    return <Shell title="Cancelled Bill Report" subtitle="Voided bills captured from audit transactions and local markers."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Date', 'Bill#', 'Reason', 'Amount', 'Voided By']} rows={rows.map((row) => [<div><div>{new Date(row.createdAt).toLocaleString()}</div>{row.localFlag ? <div className="text-xs text-amber-600">Marked in browser</div> : null}</div>, row.billNumber, row.reason, currency.format(row.amount), row.voidedBy])} /></Shell>
  }

  if (reportKey === 'sales-by-bill') {
    const grouped = Array.from(filteredBills.reduce((map, bill) => {
      const key = bill.created_at.slice(0, 10)
      const current = map.get(key) ?? { bills: 0, revenue: 0 }
      current.bills += 1
      current.revenue += bill.total_amount
      map.set(key, current)
      return map
    }, new Map<string, { bills: number; revenue: number }>()).entries()).sort((a, b) => a[0].localeCompare(b[0]))
    return <Shell title="Sales By Bill" subtitle="Daily sales summary grouped by bill date."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Date', '# Bills', 'Revenue', 'Avg Bill Value']} rows={grouped.map(([day, value]) => [new Date(`${day}T00:00:00`).toLocaleDateString(), String(value.bills), currency.format(value.revenue), currency.format(value.revenue / value.bills || 0)])} /></Shell>
  }

  if (reportKey === 'modified-bills') {
    const modified = filteredBills.filter((bill) => Math.abs(new Date(bill.updated_at).getTime() - new Date(bill.created_at).getTime()) > 60000)
    return <Shell title="Modified Bill Report" subtitle="Bills updated more than one minute after creation."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Bill#', 'Customer', 'Original Time', 'Modified Time', 'Total']} rows={modified.map((bill) => [bill.bill_number, bill.customer_name ?? 'Walk-in', new Date(bill.created_at).toLocaleString(), new Date(bill.updated_at).toLocaleString(), currency.format(bill.total_amount)])} /></Shell>
  }

  if (reportKey === 'day-book') {
    const rows = [
      ...filteredBills.map((bill) => ({ time: bill.created_at, type: 'Sale', ref: bill.bill_number, paymentMode: bill.payment_mode, amount: bill.total_amount })),
      ...filteredTransactions.map((tx) => ({ time: tx.created_at, type: tx.tx_type === 'expense' ? 'Expense' : tx.tx_type, ref: String((tx.tags_json as Record<string, unknown>)?.ref ?? tx.client_record_id), paymentMode: String((tx.tags_json as Record<string, unknown>)?.paymentMode ?? '—'), amount: tx.tx_type === 'expense' ? -tx.total_amount : tx.total_amount })),
      ...filteredReturns.map((entry) => ({ time: entry.created_at ?? new Date().toISOString(), type: 'Return', ref: entry.return_number ?? entry.original_bill_number ?? 'Return', paymentMode: entry.refund_mode ?? '—', amount: -(entry.total_return_amount ?? 0) })),
    ].sort((a, b) => a.time.localeCompare(b.time))
    const netCash = rows.reduce((sum, row) => sum + row.amount, 0)
    return <Shell title="Day Book" subtitle="Daily inflow and outflow register for a single date."><SingleDateFilter date={date} setDate={setDate} /><Table headers={['Time', 'Type', 'Ref#', 'Payment Mode', 'Amount']} rows={rows.map((row) => [new Date(row.time).toLocaleTimeString(), row.type, row.ref, row.paymentMode, <span className={row.amount >= 0 ? 'text-emerald-700 font-semibold' : 'text-rose-700 font-semibold'}>{currency.format(row.amount)}</span>])} footer={['', '', '', 'Net Cash', <span className={netCash >= 0 ? 'text-emerald-700' : 'text-rose-700'}>{currency.format(netCash)}</span>]} /></Shell>
  }

  if (reportKey === 'profit-loss' || reportKey === 'daywise-profit') {
    const dayBuckets = new Map<string, { revenue: number; cost: number; expenses: number }>()
    filteredBills.forEach((bill) => {
      const key = bill.created_at.slice(0, 10)
      const bucket = dayBuckets.get(key) ?? { revenue: 0, cost: 0, expenses: 0 }
      bucket.revenue += bill.total_amount
      bucket.cost += bill.total_amount - bill.total_profit
      dayBuckets.set(key, bucket)
    })
    filteredPurchases.forEach((purchase) => {
      const key = (purchase.purchase_date ?? purchase.created_at ?? '').slice(0, 10)
      if (!key) return
      const bucket = dayBuckets.get(key) ?? { revenue: 0, cost: 0, expenses: 0 }
      bucket.cost += Number(purchase.total_amount ?? 0)
      dayBuckets.set(key, bucket)
    })
    filteredTransactions.forEach((tx) => {
      const key = tx.created_at.slice(0, 10)
      const bucket = dayBuckets.get(key) ?? { revenue: 0, cost: 0, expenses: 0 }
      bucket.expenses += tx.total_amount
      dayBuckets.set(key, bucket)
    })
    const rows = Array.from(dayBuckets.entries()).sort((a, b) => a[0].localeCompare(b[0]))
    const totals = rows.reduce((acc, [, value]) => ({ revenue: acc.revenue + value.revenue, cost: acc.cost + value.cost, expenses: acc.expenses + value.expenses }), { revenue: 0, cost: 0, expenses: 0 })
    if (reportKey === 'profit-loss') {
      const gross = totals.revenue - totals.cost
      const net = gross - totals.expenses
      return <Shell title="Profit & Loss" subtitle="Revenue, cost and expense summary for the selected period."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><SummaryCards cards={[{ label: 'Revenue', value: currency.format(totals.revenue) }, { label: 'CoGS', value: currency.format(totals.cost) }, { label: 'Gross Profit', value: currency.format(gross) }, { label: 'Expenses', value: currency.format(totals.expenses), hint: `Net ${currency.format(net)}` }]} /></Shell>
    }
    return <Shell title="Day Wise Profit" subtitle="Daily profit and loss breakdown across the selected date range."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Date', 'Revenue', 'Cost', 'Gross Profit', 'Expenses', 'Net Profit']} rows={rows.map(([day, value]) => [new Date(`${day}T00:00:00`).toLocaleDateString(), currency.format(value.revenue), currency.format(value.cost), currency.format(value.revenue - value.cost), currency.format(value.expenses), currency.format(value.revenue - value.cost - value.expenses)])} /></Shell>
  }

  if (reportKey === 'payment-methods') {
    const grouped = filteredBills.reduce((map, bill) => {
      const row = map.get(bill.payment_mode) ?? { count: 0, revenue: 0, split: 0 }
      row.count += 1
      row.revenue += bill.total_amount
      if (bill.split_payment_summary) row.split += 1
      map.set(bill.payment_mode, row)
      return map
    }, new Map<string, { count: number; revenue: number; split: number }>())
    const totalRevenue = filteredBills.reduce((sum, bill) => sum + bill.total_amount, 0)
    return <Shell title="Payment Method Wise" subtitle="Collection split by payment mode including split payments."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Payment Method', '# Bills', 'Total Revenue', '% Share', 'Split Payment Bills']} rows={Array.from(grouped.entries()).map(([mode, value]) => [mode, String(value.count), currency.format(value.revenue), `${((value.revenue / totalRevenue) * 100 || 0).toFixed(1)}%`, String(value.split)])} /></Shell>
  }

  if (reportKey === 'cashier-sales') {
    const grouped = filteredBills.reduce((map, bill) => {
      const key = bill.payment_mode || 'Unknown'
      const row = map.get(key) ?? { bills: 0, revenue: 0 }
      row.bills += 1
      row.revenue += bill.total_amount
      map.set(key, row)
      return map
    }, new Map<string, { bills: number; revenue: number }>())
    return <Shell title="Cashier Sales Report" subtitle="Cashier tracking is not available in the web app; this view groups sales by an available billing field."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><PlaceholderCard title="Cashier tracking not available in web version" message="Detailed cashier session tracking is unavailable in the current web frontend. The summary below groups bills by payment mode as the closest available operational split." /><Table headers={['Available Group', '# Bills', 'Revenue']} rows={Array.from(grouped.entries()).map(([key, value]) => [key, String(value.bills), currency.format(value.revenue)])} /></Shell>
  }

  if (reportKey === 'cash-in-hand') {
    const records = ((payload.dayClose as DayCloseRecord[] | undefined) ?? []).sort((a, b) => (b.close_date ?? b.created_at ?? '').localeCompare(a.close_date ?? a.created_at ?? ''))
    const latest = records[0]
    const expected = Number(latest?.total_sales ?? 0) - Number(latest?.total_expenses ?? 0) + Number(latest?.cash_opening ?? 0)
    const counted = Number(latest?.cash_closing ?? 0)
    return <Shell title="Cash In Hand" subtitle="Latest expected versus counted cash from day-close records."><SummaryCards cards={[{ label: 'Expected Cash', value: currency.format(expected) }, { label: 'Counted Cash', value: currency.format(counted) }, { label: 'Variance', value: currency.format(counted - expected) }, { label: 'Date', value: latest?.close_date ? new Date(latest.close_date).toLocaleDateString() : '—' }]} /></Shell>
  }

  if (reportKey === 'item-wise-sales') {
    const items = filteredBills.flatMap((bill) => bill.items)
    const grouped = items.reduce((map, item) => {
      const row = map.get(item.product_name) ?? { qty: 0, revenue: 0 }
      row.qty += item.quantity
      row.revenue += item.total_price
      map.set(item.product_name, row)
      return map
    }, new Map<string, { qty: number; revenue: number }>())
    const rows = Array.from(grouped.entries()).map(([product, value]) => ({ product, ...value, avgPrice: value.revenue / value.qty || 0 })).sort((a, b) => b.revenue - a.revenue)
    return <Shell title="Item Wise Sales" subtitle="Sales contribution grouped by product for the chosen date range."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Product', 'Total Qty Sold', 'Revenue', 'Avg Price']} rows={rows.map((row) => [row.product, row.qty.toFixed(2), currency.format(row.revenue), currency.format(row.avgPrice)])} /></Shell>
  }

  if (reportKey === 'category-stock') {
    const meta = loadProductMeta()
    const products = (payload.products as ProductResponse[] | undefined) ?? []
    const grouped = products.reduce((map, product) => {
      const category = meta[product.clientRecordId]?.productType || product.name.split(/[\s/-]+/)[0] || 'General'
      const row = map.get(category) ?? { count: 0, value: 0 }
      row.count += 1
      row.value += product.stockQuantity * product.purchasePrice
      map.set(category, row)
      return map
    }, new Map<string, { count: number; value: number }>())
    return <Shell title="Category Stock" subtitle="Current stock grouped using product metadata or name prefix."><Table headers={['Category', 'Product Count', 'Total Stock Value']} rows={Array.from(grouped.entries()).map(([category, value]) => [category, String(value.count), currency.format(value.value)])} /></Shell>
  }

  if (reportKey === 'product-stock-history') {
    const products = (payload.products as ProductResponse[] | undefined) ?? []
    const productOptions = products.map((product) => product.name)
    const selected = selectedProduct || productOptions[0] || ''
    const billLines = ((payload.bills as BillRecord[] | undefined) ?? []).flatMap((bill) => bill.items.filter((item) => item.product_name === selected).map((item) => ({ date: bill.created_at, ref: bill.bill_number, qty: -item.quantity, unitPrice: item.unit_price, type: 'Sale' })))
    const purchaseLines = ((payload.purchases as PurchaseRow[] | undefined) ?? []).flatMap((purchase) => (purchase.items ?? []).filter((item) => item.product_name === selected).map((item) => ({ date: purchase.purchase_date ?? purchase.created_at ?? new Date().toISOString(), ref: purchase.purchase_number ?? 'Purchase', qty: Number(item.quantity ?? 0), unitPrice: Number(item.unit_cost ?? 0), type: 'Purchase' })))
    const merged = [...purchaseLines, ...billLines]
      .sort((a, b) => a.date.localeCompare(b.date))
      .reduce<Array<{ date: string; ref: string; qty: number; unitPrice: number; type: string; running: number }>>((rows, entry) => {
        const running = (rows.at(-1)?.running ?? 0) + entry.qty
        rows.push({ ...entry, running })
        return rows
      }, [])
    return <Shell title="Product Stock History" subtitle="Movement trail for a selected product across sales and purchases."><section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"><label className="block max-w-md text-sm font-medium text-slate-700">Product<select value={selected} onChange={(event) => setSelectedProduct(event.target.value)} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3">{productOptions.map((option) => <option key={option} value={option}>{option}</option>)}</select></label></section><Table headers={['Date', 'Ref#', 'Type', 'Qty Change', 'Unit Price', 'Running Stock Change']} rows={merged.map((row) => [new Date(row.date).toLocaleString(), row.ref, row.type, row.qty.toFixed(2), currency.format(row.unitPrice), row.running.toFixed(2)])} /></Shell>
  }

  if (reportKey === 'moving-products') {
    const items = filteredBills.flatMap((bill) => bill.items)
    const grouped = Array.from(items.reduce((map, item) => {
      map.set(item.product_name, (map.get(item.product_name) ?? 0) + item.quantity)
      return map
    }, new Map<string, number>()).entries()).map(([product, quantity]) => ({ product, quantity }))
    const fast = [...grouped].sort((a, b) => b.quantity - a.quantity).slice(0, 20)
    const slow = [...grouped].sort((a, b) => a.quantity - b.quantity).slice(0, 20)
    return <Shell title="Moving Products" subtitle="Fast and slow movers over the last 30 days."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><div className="grid gap-6 xl:grid-cols-2"><Table headers={['Fast Movers', 'Qty Sold']} rows={fast.map((row) => [row.product, row.quantity.toFixed(2)])} /><Table headers={['Slow Movers', 'Qty Sold']} rows={slow.map((row) => [row.product, row.quantity.toFixed(2)])} /></div></Shell>
  }

  if (reportKey === 'stock-ledger') {
    const products = (payload.products as ProductResponse[] | undefined) ?? []
    const rows = products.map((product) => {
      const sales = filteredBills.flatMap((bill) => bill.items).filter((item) => item.product_name === product.name).reduce((sum, item) => sum + item.quantity, 0)
      const inward = filteredPurchases.flatMap((purchase) => purchase.items ?? []).filter((item) => item.product_name === product.name).reduce((sum, item) => sum + Number(item.quantity ?? 0), 0)
      const opening = product.stockQuantity - inward + sales
      return [product.name, opening.toFixed(2), inward.toFixed(2), sales.toFixed(2), product.stockQuantity.toFixed(2)]
    })
    return <Shell title="Stock Ledger" subtitle="Opening, inward, outward and current stock snapshot for each product."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Product', 'Opening Stock', 'Purchases', 'Sales', 'Current Stock']} rows={rows} /></Shell>
  }

  if (reportKey === 'product-stock-sales') {
    const products = (payload.products as ProductResponse[] | undefined) ?? []
    const rows = products.map((product) => {
      const totalSold = filteredBills.flatMap((bill) => bill.items).filter((item) => item.product_name === product.name).reduce((sum, item) => sum + item.quantity, 0)
      return [product.name, product.stockQuantity.toFixed(2), totalSold.toFixed(2), currency.format(product.stockQuantity * product.purchasePrice), currency.format(totalSold * product.sellingPrice)]
    })
    return <Shell title="Product Stock & Sales" subtitle="Current stock position versus the last 30 days of sales."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Product', 'Current Stock', 'Total Sold', 'Stock Value', 'Sales Value']} rows={rows} /></Shell>
  }

  if (reportKey === 'customer-balance') {
    const customers = (payload.customers as CustomerRecord[] | undefined) ?? []
    const customerRows = customers.map((customer) => [
      <Link className="text-indigo-700 hover:underline" to={`/reports/customer-purchase-history?customer=${encodeURIComponent(customer.name)}`}>{customer.name}</Link>,
      customer.phone ?? '—',
      currency.format(customer.creditLimit),
      currency.format(customer.outstandingBalance),
      <span className={customer.outstandingBalance > 0 ? 'font-semibold text-amber-700' : 'text-emerald-700'}>{customer.outstandingBalance > 0 ? 'Overdue' : 'Clear'}</span>,
    ])
    return <Shell title="Customer Balance" subtitle="Outstanding balances and customer credit visibility."><Table headers={['Customer Name', 'Phone', 'Credit Limit', 'Outstanding Balance', 'Status']} rows={customerRows} /></Shell>
  }

  if (reportKey === 'top-customers') {
    const grouped = Array.from(filteredBills.reduce((map, bill) => {
      const key = bill.customer_name || 'Walk-in'
      const row = map.get(key) ?? { bills: 0, spend: 0 }
      row.bills += 1
      row.spend += bill.total_amount
      map.set(key, row)
      return map
    }, new Map<string, { bills: number; spend: number }>()).entries()).map(([customer, value]) => ({ customer, ...value })).sort((a, b) => b.spend - a.spend)
    return <Shell title="Top Customers" subtitle="Rank customers by bill count and total spend."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Rank', 'Customer', '# Bills', 'Total Spend']} rows={grouped.map((row, index) => [String(index + 1), row.customer, String(row.bills), currency.format(row.spend)])} /></Shell>
  }

  if (reportKey === 'supplier-balance') {
    const suppliers = (payload.suppliers as SupplierRecord[] | undefined) ?? []
    const purchaseCounts = filteredPurchases.reduce((map, purchase) => {
      const name = purchase.supplier_name || 'Unknown Supplier'
      map.set(name, (map.get(name) ?? 0) + 1)
      return map
    }, new Map<string, number>())
    return <Shell title="Supplier Balance" subtitle="Outstanding supplier dues and purchase frequency."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Supplier', 'Phone', 'Outstanding Balance', '# Purchases', 'Status']} rows={suppliers.map((supplier) => [supplier.name, supplier.phone ?? '—', currency.format(supplier.outstandingBalance), String(purchaseCounts.get(supplier.name) ?? 0), <span className={supplier.outstandingBalance > 0 ? 'font-semibold text-amber-700' : 'text-emerald-700'}>{supplier.outstandingBalance > 0 ? 'Overdue' : 'Clear'}</span>])} /></Shell>
  }

  if (reportKey === 'purchase-report') {
    const totalSpend = filteredPurchases.reduce((sum, purchase) => sum + Number(purchase.total_amount ?? 0), 0)
    return <Shell title="Purchase Report" subtitle="Purchase register and supplier spend summary."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><SummaryCards cards={[{ label: 'Total spend', value: currency.format(totalSpend) }, { label: '# Purchases', value: String(filteredPurchases.length) }]} /><Table headers={['Date', 'Purchase#', 'Supplier', 'Invoice#', 'Payment Mode', 'Amount']} rows={filteredPurchases.map((purchase) => [new Date(purchase.purchase_date ?? purchase.created_at ?? '').toLocaleDateString(), purchase.purchase_number ?? '—', purchase.supplier_name ?? 'Unknown Supplier', purchase.invoice_number ?? '—', purchase.payment_mode ?? '—', currency.format(Number(purchase.total_amount ?? 0))])} /></Shell>
  }

  if (reportKey === 'customer-purchase-history') {
    const customers = Array.from(new Set(filteredBills.map((bill) => bill.customer_name).filter(Boolean))) as string[]
    const current = selectedCustomer || new URLSearchParams(window.location.search).get('customer') || customers[0] || ''
    const rows = filteredBills.filter((bill) => (bill.customer_name || '') === current)
    return <Shell title="Customer Purchase History" subtitle="Review all bills and items for a selected customer."><section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"><label className="block max-w-md text-sm font-medium text-slate-700">Customer<select value={current} onChange={(event) => setSelectedCustomer(event.target.value)} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3">{customers.map((customer) => <option key={customer} value={customer}>{customer}</option>)}</select></label></section><Table headers={['Bill#', 'Date', 'Items', 'Total']} rows={rows.map((bill) => [bill.bill_number, new Date(bill.created_at).toLocaleString(), <div className="space-y-1">{bill.items.map((item, index) => <div key={index}>{item.product_name} × {item.quantity}</div>)}</div>, currency.format(bill.total_amount)])} /></Shell>
  }

  if (reportKey === 'crm-points') {
    const rows = filteredTransactions
      .sort((a, b) => a.created_at.localeCompare(b.created_at))
      .reduce<Array<[string, string, string, string, string]>>((acc, tx) => {
        const tags = (tx.tags_json ?? {}) as Record<string, unknown>
        const points = Number(tags.points ?? tx.total_amount ?? 0)
        const running = Number(acc.at(-1)?.[4] ?? 0) + (tx.tx_type === 'loyalty_redeem' ? -points : points)
        acc.push([new Date(tx.created_at).toLocaleString(), String(tags.customerName ?? 'Unknown'), tx.tx_type.replace('loyalty_', ''), points.toFixed(0), running.toFixed(0)])
        return acc
      }, [])
    return <Shell title="CRM Points" subtitle="Loyalty earn and redeem transactions with running balance."><RangeFilters from={from} to={to} setFrom={setFrom} setTo={setTo} /><Table headers={['Date', 'Customer', 'Type', 'Points', 'Balance running total']} rows={rows} /></Shell>
  }

  return <Shell title="Report" subtitle="Report configuration unavailable."><PlaceholderCard title="Unavailable" message="This report is not yet configured." /></Shell>
}

