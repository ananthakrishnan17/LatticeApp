import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'

type ReportCategoryId = 'bill' | 'financial' | 'product' | 'stock' | 'ledger'

interface ReportItem {
  name: string
  slug?: string
  description: string
  status?: 'planned' | 'ready'
}

const REPORT_CATEGORIES: Array<{ id: ReportCategoryId; label: string; subtitle: string }> = [
  { id: 'bill', label: 'Bill Reports', subtitle: 'Billwise, hourly, cancelled and GST report views' },
  { id: 'financial', label: 'Financial Reports', subtitle: 'Cash flow, payment mode and profitability views' },
  { id: 'product', label: 'Product Reports', subtitle: 'Item, category, movement and wholesale trends' },
  { id: 'stock', label: 'Stock Reports', subtitle: 'Ledger and stock-sales visibility' },
  { id: 'ledger', label: 'Ledger / CRM Reports', subtitle: 'Customer credit, supplier balance and loyalty insights' },
]

const REPORTS_MAP: Record<ReportCategoryId, ReportItem[]> = {
  bill: [
    { name: 'Billwise Report', slug: 'billwise', description: 'Line-level bill listing with totals and customer details.', status: 'ready' },
    { name: 'Sales by Bill', slug: 'sales-by-bill', description: 'Daily summary grouped by bill date.', status: 'ready' },
    { name: 'Hourly Sales Report', slug: 'hourly-sales', description: 'Hour bucket performance for peak-hour analysis.', status: 'ready' },
    { name: 'Modified Bill Report', slug: 'modified-bills', description: 'Track bills edited after initial save.', status: 'ready' },
    { name: 'Cancelled Bill Report', slug: 'cancelled-bills', description: 'View cancelled transactions and local void markers.', status: 'ready' },
    { name: 'GST Report', slug: 'gst', description: 'Taxable value and GST split by bill/date.', status: 'ready' },
  ],
  financial: [
    { name: 'Day Book', slug: 'day-book', description: 'Daily transaction summary across billing and expenses.', status: 'ready' },
    { name: 'Cash Book', slug: 'cash-book', description: 'Cash receipts and payments with daily net visibility.', status: 'ready' },
    { name: 'Bank Book', slug: 'bank-book', description: 'Digital collections ledger across UPI, card, bank, and online.', status: 'ready' },
    { name: 'Cash in Hand', slug: 'cash-in-hand', description: 'Expected hand cash versus counts.', status: 'ready' },
    { name: 'Profit & Loss', slug: 'profit-loss', description: 'Revenue minus cost and expenses statement.', status: 'ready' },
    { name: 'Day-wise Profit', slug: 'daywise-profit', description: 'Profit trend by day and week.', status: 'ready' },
    { name: 'Payment Method-wise Report', slug: 'payment-methods', description: 'Mode split of collection and split payments.', status: 'ready' },
    { name: 'Cashier Sales Report', slug: 'cashier-sales', description: 'Placeholder summary for cashier-level tracking.', status: 'ready' },
    { name: 'Cashier Sessions Dashboard', slug: 'cashier-sessions', description: 'Day-wise session summary with opening, expected, and closing cash.', status: 'ready' },
  ],
  product: [
    { name: 'Item-wise Sales Report', slug: 'item-wise-sales', description: 'Sales quantity and value by item.', status: 'ready' },
    { name: 'Category Stock Report', slug: 'category-stock', description: 'Stock grouped by inferred category.', status: 'ready' },
    { name: 'Moving Products', slug: 'moving-products', description: 'Fast and slow movers with turnover.', status: 'ready' },
    { name: 'Product Stock History', slug: 'product-stock-history', description: 'Movement timeline per product.', status: 'ready' },
    { name: 'Wholesale/Retail Stock', slug: 'wholesale-retail-stock', description: 'Bag-to-retail conversion stock and sales breakdown.', status: 'ready' },
  ],
  stock: [
    { name: 'Stock Ledger', slug: 'stock-ledger', description: 'Inward/outward stock ledger.', status: 'ready' },
    { name: 'Product Stock & Sales', slug: 'product-stock-sales', description: 'Stock vs sales comparison snapshot.', status: 'ready' },
  ],
  ledger: [
    { name: 'Ledger Dashboard', slug: 'ledger-dashboard', description: 'P&L, balances, and trial balance health snapshot.', status: 'ready' },
    { name: 'Pending Dues & Credit', slug: 'pending-dues', description: 'Customers with pending dues and statement drilldown.', status: 'ready' },
    { name: 'Customer Credit Statement', slug: 'customer-credit-statement', description: 'Detailed customer Dr/Cr statement with running balance.', status: 'ready' },
    { name: 'Customer Balance Report', slug: 'customer-balance', description: 'Outstanding balance by customer.', status: 'ready' },
    { name: 'Customer Purchase History', slug: 'customer-purchase-history', description: 'Customer order and visit trends.', status: 'ready' },
    { name: 'CRM Points Report', slug: 'crm-points', description: 'Points earned and redeemed.', status: 'ready' },
    { name: 'Top Customers Report', slug: 'top-customers', description: 'Top customer ranking by revenue.', status: 'ready' },
    { name: 'Supplier Balance Report', slug: 'supplier-balance', description: 'Supplier payable summary and ageing.', status: 'ready' },
    { name: 'Purchase Report', slug: 'purchase-report', description: 'Purchase trend and vendor spend analysis.', status: 'ready' },
  ],
}

function ReportsPage() {
  const navigate = useNavigate()
  const [activeCategory, setActiveCategory] = useState<ReportCategoryId>('bill')
  const reports = useMemo(() => REPORTS_MAP[activeCategory], [activeCategory])

  return (
    <div className="space-y-6">
      <header className="rounded-3xl border border-indigo-100 bg-white p-6 shadow-sm">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Reports</p>
        <h1 className="mt-2 text-3xl font-bold text-slate-900">Reporting Hub</h1>
        <p className="mt-2 text-sm text-slate-500">Choose a report and open the live report page.</p>
      </header>

      <section className="grid gap-3 md:grid-cols-2 xl:grid-cols-5">
        {REPORT_CATEGORIES.map((category) => {
          const active = category.id === activeCategory
          return (
            <button
              key={category.id}
              type="button"
              onClick={() => setActiveCategory(category.id)}
              className={`rounded-2xl border p-4 text-left transition ${active ? 'border-indigo-500 bg-indigo-50 shadow-sm' : 'border-slate-200 bg-white hover:border-indigo-200 hover:bg-indigo-50/40'}`}
            >
              <p className={`text-sm font-semibold ${active ? 'text-indigo-700' : 'text-slate-800'}`}>{category.label}</p>
              <p className="mt-2 text-xs text-slate-500">{category.subtitle}</p>
            </button>
          )
        })}
      </section>

      <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-slate-900">{REPORT_CATEGORIES.find((c) => c.id === activeCategory)?.label}</h2>
          <span className="rounded-full bg-indigo-100 px-3 py-1 text-xs font-semibold text-indigo-700">Live report links</span>
        </div>
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {reports.map((report) => {
            const ready = report.status === 'ready' && report.slug
            return (
              <article key={report.name} className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
                <div className="flex items-start justify-between gap-3">
                  <h3 className="text-sm font-semibold text-slate-900">{report.name}</h3>
                  <span className={`rounded-full px-2.5 py-1 text-[11px] font-semibold ${ready ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'}`}>{ready ? '(available)' : '(coming soon)'}</span>
                </div>
                <p className="mt-2 text-xs leading-relaxed text-slate-600">{report.description}</p>
                <button
                  type="button"
                  disabled={!ready}
                  onClick={() => ready && navigate(`/reports/${report.slug}`)}
                  className="mt-4 rounded-xl border border-slate-300 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 transition hover:border-indigo-300 hover:text-indigo-700 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Open Report
                </button>
              </article>
            )
          })}
        </div>
      </section>
    </div>
  )
}

export default ReportsPage
