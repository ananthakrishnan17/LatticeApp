import Alert from '@cloudscape-design/components/alert'
import Box from '@cloudscape-design/components/box'
import FormField from '@cloudscape-design/components/form-field'
import Select from '@cloudscape-design/components/select'
import SpaceBetween from '@cloudscape-design/components/space-between'
import Table from '@cloudscape-design/components/table'
import type { SelectProps } from '@cloudscape-design/components/select'
import type { TableProps } from '@cloudscape-design/components/table'
import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { listBills } from '../../api/bills'
import { extractApiError } from '../../api/client'
import { listCustomers } from '../../api/masters'
import { listSaleReturns } from '../../api/saleReturns'
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
  startOfDayIso,
  toDateInput,
} from './reportCloudscapeUtils'

interface StatementRow {
  date: string
  description: string
  debit: number
  credit: number
  balance: number
}

const today = new Date()
const firstDayOfMonth = new Date(today.getFullYear(), today.getMonth(), 1)
const defaultFrom = toDateInput(firstDayOfMonth)
const defaultTo = toDateInput(today)

interface SaleReturnRow {
  customer_name?: string | null
  created_at?: string
  return_number?: string
  original_bill_number?: string
  total_return_amount?: number
}

function CustomerCreditStatementPage() {
  const [searchParams] = useSearchParams()
  const [from, setFrom] = useState(defaultFrom)
  const [to, setTo] = useState(defaultTo)
  const [selectedCustomer, setSelectedCustomer] = useState<SelectProps.Option | null>(null)
  const [customers, setCustomers] = useState<Awaited<ReturnType<typeof listCustomers>>>([])
  const [bills, setBills] = useState<Awaited<ReturnType<typeof listBills>>>([])
  const [returns, setReturns] = useState<SaleReturnRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      setLoading(true)
      setError('')
      try {
        const [customerRows, billRows, returnRows] = await Promise.all([
          listCustomers(),
          listBills({ since: startOfDayIso(from), limit: 10000 }),
          listSaleReturns({ since: startOfDayIso(from), limit: 5000 }) as Promise<SaleReturnRow[]>,
        ])
        if (cancelled) return
        setCustomers(customerRows)
        setBills(billRows)
        setReturns(returnRows)

        const fromQuery = searchParams.get('customer') ?? ''
        const selected = customerRows.find((customer) => customer.name.toLowerCase() === fromQuery.toLowerCase())
        if (selected) {
          setSelectedCustomer({ label: selected.name, value: selected.name })
        } else if (customerRows[0]) {
          setSelectedCustomer((current) => current ?? { label: customerRows[0].name, value: customerRows[0].name })
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
  }, [from, searchParams])

  const customerName = selectedCustomer?.value ?? ''
  const customer = customers.find((entry) => entry.name === customerName)
  const openingBalance = customer?.outstandingBalance ?? 0

  const statementRows = useMemo(() => {
    if (!customerName) return [] as StatementRow[]
    const entries: Array<{ date: string; description: string; debit: number; credit: number }> = []

    for (const bill of bills) {
      if ((bill.customer_name ?? '') !== customerName || !isBetween(bill.created_at, from, to)) continue
      entries.push({
        date: bill.created_at,
        description: `Invoice #${bill.bill_number}`,
        debit: bill.total_amount,
        credit: 0,
      })
    }

    for (const saleReturn of returns) {
      if ((saleReturn.customer_name ?? '') !== customerName) continue
      if (!saleReturn.created_at || !isBetween(saleReturn.created_at, from, to)) continue
      entries.push({
        date: saleReturn.created_at,
        description: `Return #${saleReturn.return_number ?? saleReturn.original_bill_number ?? 'N/A'}`,
        debit: 0,
        credit: Number(saleReturn.total_return_amount ?? 0),
      })
    }

    const sorted = entries.sort((left, right) => left.date.localeCompare(right.date))
    let running = openingBalance
    return sorted.map((entry) => {
      running += entry.debit - entry.credit
      return { ...entry, balance: running }
    })
  }, [bills, customerName, from, openingBalance, returns, to])

  const closingBalance = statementRows.at(-1)?.balance ?? openingBalance

  const customerOptions: SelectProps.Option[] = customers.map((entry) => ({ label: entry.name, value: entry.name }))
  const columnDefinitions: ReadonlyArray<TableProps.ColumnDefinition<StatementRow>> = [
    { id: 'date', header: 'Date', cell: (item) => formatDateTime(item.date) },
    { id: 'description', header: 'Description', cell: (item) => item.description },
    { id: 'debit', header: 'Debit', cell: (item) => currencyFormatter.format(item.debit) },
    { id: 'credit', header: 'Credit', cell: (item) => currencyFormatter.format(item.credit) },
    { id: 'balance', header: 'Running balance', cell: (item) => currencyFormatter.format(item.balance) },
  ]

  if (loading) {
    return <Spinner label="Loading customer statement..." />
  }

  return (
    <ReportPageShell
      title="Customer Credit Statement"
      description="Dr/Cr statement with running balance for selected customer."
      actions={(
        <CsvButton
          onClick={() => downloadCsv(
            `customer-credit-statement-${customerName || 'customer'}.csv`,
            ['Date', 'Description', 'Debit', 'Credit', 'Running Balance'],
            statementRows.map((row) => [formatDateTime(row.date), row.description, row.debit.toFixed(2), row.credit.toFixed(2), row.balance.toFixed(2)]),
          )}
        />
      )}
    >
      {error ? <Alert type="error">{error}</Alert> : null}
      <DateRangePanel
        from={from}
        to={to}
        onFromChange={setFrom}
        onToChange={setTo}
        extra={(
          <FormField label="Customer">
            <Select selectedOption={selectedCustomer} onChange={({ detail }) => setSelectedCustomer(detail.selectedOption)} options={customerOptions} />
          </FormField>
        )}
      />
      <MetricCards
        items={[
          { label: 'Opening balance', value: currencyFormatter.format(openingBalance) },
          { label: 'Closing balance', value: currencyFormatter.format(closingBalance) },
          { label: 'Transactions', value: String(statementRows.length) },
          { label: 'Customer', value: customerName || '—' },
        ]}
      />
      <SpaceBetween size="s">
        <Table
          items={statementRows}
          columnDefinitions={columnDefinitions}
          loadingText="Loading statement"
          empty={<Box color="text-body-secondary">No statement entries found.</Box>}
          header={<Box variant="h3">Statement entries</Box>}
        />
      </SpaceBetween>
    </ReportPageShell>
  )
}

export default CustomerCreditStatementPage
