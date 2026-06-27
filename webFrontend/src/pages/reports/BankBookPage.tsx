import Alert from '@cloudscape-design/components/alert'
import Box from '@cloudscape-design/components/box'
import FormField from '@cloudscape-design/components/form-field'
import Select from '@cloudscape-design/components/select'
import Table from '@cloudscape-design/components/table'
import type { SelectProps } from '@cloudscape-design/components/select'
import type { TableProps } from '@cloudscape-design/components/table'
import { useEffect, useMemo, useState } from 'react'
import { listBills, type BillRecord } from '../../api/bills'
import { extractApiError } from '../../api/client'
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

interface BankBookRow {
  date: string
  mode: string
  description: string
  amount: number
}

const today = new Date()
const firstDayOfMonth = new Date(today.getFullYear(), today.getMonth(), 1)
const defaultFrom = toDateInput(firstDayOfMonth)
const defaultTo = toDateInput(today)
const digitalModes = new Set(['upi', 'card', 'bank', 'online'])

const modeOptions: SelectProps.Option[] = [
  { value: 'all', label: 'All Digital' },
  { value: 'upi', label: 'UPI' },
  { value: 'card', label: 'Card' },
  { value: 'bank', label: 'Bank' },
  { value: 'online', label: 'Online' },
]

function BankBookPage() {
  const [from, setFrom] = useState(defaultFrom)
  const [to, setTo] = useState(defaultTo)
  const [mode, setMode] = useState<SelectProps.Option>(modeOptions[0])
  const [bills, setBills] = useState<BillRecord[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      setLoading(true)
      setError('')
      try {
        const rows = await listBills({ since: startOfDayIso(from), limit: 5000 })
        if (!cancelled) {
          setBills(rows)
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
    const selectedMode = mode.value ?? 'all'
    const output: BankBookRow[] = []

    for (const bill of bills) {
      if (!isBetween(bill.created_at, from, to)) continue

      const paymentMode = bill.payment_mode?.toLowerCase() ?? ''
      if (digitalModes.has(paymentMode) && (selectedMode === 'all' || selectedMode === paymentMode)) {
        output.push({
          date: bill.created_at,
          mode: paymentMode.toUpperCase(),
          description: `${paymentMode.toUpperCase()} Sale - Bill #${bill.bill_number}`,
          amount: bill.total_amount,
        })
      }

      for (const split of parseSplitPayments(bill.split_payment_summary)) {
        if (!digitalModes.has(split.mode)) continue
        if (selectedMode !== 'all' && selectedMode !== split.mode) continue
        output.push({
          date: bill.created_at,
          mode: split.mode.toUpperCase(),
          description: `${split.mode.toUpperCase()} Split - Bill #${bill.bill_number}`,
          amount: split.amount,
        })
      }
    }

    return output.sort((left, right) => left.date.localeCompare(right.date))
  }, [bills, from, mode.value, to])

  const total = useMemo(() => rows.reduce((sum, row) => sum + row.amount, 0), [rows])

  const columnDefinitions: ReadonlyArray<TableProps.ColumnDefinition<BankBookRow>> = [
    { id: 'date', header: 'Date', cell: (item) => formatDateTime(item.date) },
    { id: 'mode', header: 'Mode', cell: (item) => item.mode },
    { id: 'description', header: 'Description', cell: (item) => item.description },
    { id: 'amount', header: 'Amount', cell: (item) => currencyFormatter.format(item.amount) },
  ]

  if (loading) {
    return <Spinner label="Loading bank book..." />
  }

  return (
    <ReportPageShell
      title="Bank Book"
      description="Digital collections from bills and split payments."
      actions={(
        <CsvButton
          onClick={() => downloadCsv(
            `bank-book-${mode.value ?? 'all'}-${from}-to-${to}.csv`,
            ['Date', 'Mode', 'Description', 'Amount'],
            rows.map((row) => [formatDateTime(row.date), row.mode, row.description, row.amount.toFixed(2)]),
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
          <FormField label="Payment mode">
            <Select selectedOption={mode} onChange={({ detail }) => setMode(detail.selectedOption)} options={modeOptions} />
          </FormField>
        )}
      />
      <MetricCards
        items={[
          { label: 'Total digital inflow', value: currencyFormatter.format(total) },
          { label: 'Transactions', value: String(rows.length) },
          { label: 'Selected mode', value: mode.label ?? 'All Digital' },
          { label: 'Date range', value: `${from} → ${to}` },
        ]}
      />
      <Table
        items={rows}
        columnDefinitions={columnDefinitions}
        loadingText="Loading entries"
        empty={<Box color="text-body-secondary">No digital transactions found for selected filters.</Box>}
        header={<Box variant="h3">Bank book entries</Box>}
      />
    </ReportPageShell>
  )
}

export default BankBookPage
