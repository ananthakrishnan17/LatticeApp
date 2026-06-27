import Alert from '@cloudscape-design/components/alert'
import Box from '@cloudscape-design/components/box'
import Container from '@cloudscape-design/components/container'
import Header from '@cloudscape-design/components/header'
import SpaceBetween from '@cloudscape-design/components/space-between'
import StatusIndicator from '@cloudscape-design/components/status-indicator'
import { useEffect, useMemo, useState } from 'react'
import { listBills } from '../../api/bills'
import { extractApiError } from '../../api/client'
import { listCustomers, listSuppliers } from '../../api/masters'
import { listProducts } from '../../api/products'
import { listPurchases } from '../../api/purchases'
import { listTransactions } from '../../api/transactions'
import Spinner from '../../components/Spinner'
import {
  DateRangePanel,
  MetricCards,
  ReportPageShell,
} from './reportCloudscape'
import { currencyFormatter, isBetween, startOfDayIso, toDateInput } from './reportCloudscapeUtils'

const today = new Date()
const firstDayOfMonth = new Date(today.getFullYear(), today.getMonth(), 1)
const defaultFrom = toDateInput(firstDayOfMonth)
const defaultTo = toDateInput(today)

interface PurchaseRow {
  total_amount?: number
  purchase_date?: string
  created_at?: string
}

function LedgerDashboardPage() {
  const [from, setFrom] = useState(defaultFrom)
  const [to, setTo] = useState(defaultTo)
  const [payload, setPayload] = useState<{
    bills: Awaited<ReturnType<typeof listBills>>
    transactions: Awaited<ReturnType<typeof listTransactions>>
    purchases: PurchaseRow[]
    products: Awaited<ReturnType<typeof listProducts>>
    customers: Awaited<ReturnType<typeof listCustomers>>
    suppliers: Awaited<ReturnType<typeof listSuppliers>>
  } | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      setLoading(true)
      setError('')
      try {
        const [bills, transactions, purchases, products, customers, suppliers] = await Promise.all([
          listBills({ since: startOfDayIso(from), limit: 5000 }),
          listTransactions({ since: startOfDayIso(from), limit: 5000 }),
          listPurchases({ since: startOfDayIso(from), limit: 5000 }) as Promise<PurchaseRow[]>,
          listProducts(),
          listCustomers(),
          listSuppliers(),
        ])
        if (!cancelled) {
          setPayload({ bills, transactions, purchases, products, customers, suppliers })
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
    return () => {
      cancelled = true
    }
  }, [from])

  const metrics = useMemo(() => {
    if (!payload) {
      return {
        income: 0,
        cogs: 0,
        expenses: 0,
        waste: 0,
        asset: 0,
        inventory: 0,
        liability: 0,
      }
    }

    const bills = payload.bills.filter((bill) => isBetween(bill.created_at, from, to))
    const purchases = payload.purchases.filter((purchase) => {
      const value = purchase.purchase_date ?? purchase.created_at ?? ''
      return value ? isBetween(value, from, to) : false
    })
    const expenses = payload.transactions
      .filter((transaction) => transaction.tx_type === 'expense' && isBetween(transaction.created_at, from, to))
      .reduce((sum, transaction) => sum + transaction.total_amount, 0)

    const productsByName = new Map(payload.products.map((product) => [product.name, product]))
    const cogs = bills.reduce((sum, bill) => (
      sum + bill.items.reduce((billSum, item) => {
        const purchasePrice = item.purchase_price ?? productsByName.get(item.product_name)?.purchasePrice ?? 0
        return billSum + purchasePrice * item.quantity
      }, 0)
    ), 0)

    const income = bills.reduce((sum, bill) => sum + bill.total_amount, 0)
    const purchaseInward = purchases.reduce((sum, purchase) => sum + Number(purchase.total_amount ?? 0), 0)
    const inventory = payload.products.reduce((sum, product) => sum + product.stockQuantity * product.purchasePrice, 0)
    const customerAsset = payload.customers.reduce((sum, customer) => sum + Math.max(0, customer.outstandingBalance), 0)
    const supplierLiability = payload.suppliers.reduce((sum, supplier) => sum + Math.max(0, supplier.outstandingBalance), 0)
    const asset = customerAsset + Math.max(0, income - expenses - purchaseInward)

    return {
      income,
      cogs,
      expenses,
      waste: 0,
      asset,
      inventory,
      liability: supplierLiability,
    }
  }, [from, payload, to])

  const grossProfit = metrics.income - metrics.cogs
  const netProfit = grossProfit - metrics.expenses - metrics.waste
  const trialDebits = metrics.asset + metrics.inventory + metrics.cogs + metrics.expenses + metrics.waste
  const trialCredits = metrics.income + metrics.liability
  const isBalanced = Math.abs(trialDebits - trialCredits) < 0.01

  if (loading) {
    return <Spinner label="Loading ledger dashboard..." />
  }

  return (
    <ReportPageShell
      title="Ledger Dashboard"
      description="Financial snapshot across revenue, cost, balances, and trial balance status."
    >
      {error ? <Alert type="error">{error}</Alert> : null}
      <DateRangePanel from={from} to={to} onFromChange={setFrom} onToChange={setTo} />
      <MetricCards
        items={[
          { label: 'Revenue', value: currencyFormatter.format(metrics.income) },
          { label: 'COGS', value: currencyFormatter.format(metrics.cogs) },
          { label: 'Expenses', value: currencyFormatter.format(metrics.expenses) },
          { label: 'Net profit', value: currencyFormatter.format(netProfit) },
        ]}
      />
      <MetricCards
        items={[
          { label: 'Assets', value: currencyFormatter.format(metrics.asset) },
          { label: 'Inventory', value: currencyFormatter.format(metrics.inventory) },
          { label: 'Liabilities', value: currencyFormatter.format(metrics.liability) },
          { label: 'Gross profit', value: currencyFormatter.format(grossProfit) },
        ]}
      />
      <Container header={<Header variant="h2">Trial balance</Header>}>
        <SpaceBetween size="s">
          <StatusIndicator type={isBalanced ? 'success' : 'error'}>
            {isBalanced ? 'Books are balanced' : 'Books are not balanced'}
          </StatusIndicator>
          <Box><b>Total debits:</b> {currencyFormatter.format(trialDebits)}</Box>
          <Box><b>Total credits:</b> {currencyFormatter.format(trialCredits)}</Box>
        </SpaceBetween>
      </Container>
    </ReportPageShell>
  )
}

export default LedgerDashboardPage
