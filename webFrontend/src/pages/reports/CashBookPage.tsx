import Alert from '@cloudscape-design/components/alert'
import Box from '@cloudscape-design/components/box'
import Table from '@cloudscape-design/components/table'
import type { TableProps } from '@cloudscape-design/components/table'
import StatusIndicator from '@cloudscape-design/components/status-indicator'
import { useEffect, useMemo, useState } from 'react'
import { listBills, type BillRecord } from '../../api/bills'
import { extractApiError } from '../../api/client'
import { listTransactions } from '../../api/transactions'
import type { TransactionRecord } from '../../types'
import Spinner from '../../components/Spinner'
import {
  CsvButton,
  DateRangePanel,
  MetricCards,
  ReportPageShell,
} from './reportCloudscape'
import {
  currencyFormatter,
  downloadCsv,
  formatDateTime,
  isBetween,
  parseSplitPayments,
  startOfDayIso,
  toDateInput,
} from './reportCloudscapeUtils'

interface CashBookRow {
  date: string
  type: 'Receipt' | 'Payment'
  description: string
  amount: number
}

const today = new Date()
const firstDayOfMonth = new Date(today.getFullYear(), today.getMonth(), 1)
const defaultFrom = toDateInput(firstDayOfMonth)
const defaultTo = toDateInput(today)

function CashBookPage() {
  const [from, setFrom] = useState(defaultFrom)
  const [to, setTo] = useState(defaultTo)
  const [bills, setBills] = useState<BillRecord[]>([])
  const [transactions, setTransactions] = useState<TransactionRecord[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      setLoading(true)
      setError('')
      try {
        const [billData, expenseData] = await Promise.all([
          listBills({ since: startOfDayIso(from), limit: 5000 }),
          listTransactions({ types: 'expense', since: startOfDayIso(from), limit: 5000 }),
        ])
        if (!cancelled) {
          setBills(billData)
          setTransactions(expenseData)
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

  const rows = useMemo(() => {
    const output: CashBookRow[] = []

    for (const bill of bills) {
      if (!isBetween(bill.created_at, from, to)) continue

      if (bill.payment_mode?.toLowerCase() === 'cash') {
        output.push({
          date: bill.created_at,
          type: 'Receipt',
          description: `Cash Sale - Bill #${bill.bill_number}`,
          amount: bill.total_amount,
        })
      }

      for (const split of parseSplitPayments(bill.split_payment_summary)) {
        if (split.mode === 'cash') {
          output.push({
            date: bill.created_at,
            type: 'Receipt',
            description: `Cash Split - Bill #${bill.bill_number}`,
            amount: split.amount,
          })
        }
      }
    }

    for (const tx of transactions) {
      if (!isBetween(tx.created_at, from, to)) continue
      const tags = tx.tags_json as Record<string, unknown>
      output.push({
        date: tx.created_at,
        type: 'Payment',
        description: String(tags.description ?? tags.category ?? tags.ref ?? 'Expense'),
        amount: tx.total_amount,
      })
    }

    return output.sort((left, right) => left.date.localeCompare(right.date))
  }, [bills, from, to, transactions])

  const receiptTotal = useMemo(
    () => rows.filter((row) => row.type === 'Receipt').reduce((sum, row) => sum + row.amount, 0),
    [rows],
  )
  const paymentTotal = useMemo(
    () => rows.filter((row) => row.type === 'Payment').reduce((sum, row) => sum + row.amount, 0),
    [rows],
  )

  const columnDefinitions: ReadonlyArray<TableProps.ColumnDefinition<CashBookRow>> = [
    { id: 'date', header: 'Date', cell: (item) => formatDateTime(item.date) },
    {
      id: 'type',
      header: 'Type',
      cell: (item) => (
        <StatusIndicator type={item.type === 'Receipt' ? 'success' : 'warning'}>
          {item.type}
        </StatusIndicator>
      ),
    },
    { id: 'description', header: 'Description', cell: (item) => item.description },
    {
      id: 'amount',
      header: 'Amount',
      cell: (item) => currencyFormatter.format(item.amount),
    },
  ]

  if (loading) {
    return <Spinner label="Loading cash book..." />
  }

  return (
    <ReportPageShell
      title="Cash Book"
      description="Cash inflow and outflow from bills, split payments, and expenses."
      actions={(
        <CsvButton
          onClick={() => downloadCsv(
            `cash-book-${from}-to-${to}.csv`,
            ['Date', 'Type', 'Description', 'Amount'],
            rows.map((row) => [formatDateTime(row.date), row.type, row.description, row.amount.toFixed(2)]),
          )}
        />
      )}
    >
      {error ? <Alert type="error">{error}</Alert> : null}
      <DateRangePanel from={from} to={to} onFromChange={setFrom} onToChange={setTo} />
      <MetricCards
        items={[
          { label: 'Total receipts', value: currencyFormatter.format(receiptTotal) },
          { label: 'Total payments', value: currencyFormatter.format(paymentTotal) },
          { label: 'Net cash', value: currencyFormatter.format(receiptTotal - paymentTotal) },
          { label: 'Transactions', value: String(rows.length) },
        ]}
      />
      <Table
        items={rows}
        columnDefinitions={columnDefinitions}
        loadingText="Loading entries"
        empty={<Box color="text-body-secondary">No cash transactions found for selected period.</Box>}
        header={<Box variant="h3">Cash transactions</Box>}
      />
    </ReportPageShell>
  )
}

export default CashBookPage
