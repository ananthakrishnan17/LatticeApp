import Alert from '@cloudscape-design/components/alert'
import Box from '@cloudscape-design/components/box'
import Button from '@cloudscape-design/components/button'
import FormField from '@cloudscape-design/components/form-field'
import Input from '@cloudscape-design/components/input'
import SpaceBetween from '@cloudscape-design/components/space-between'
import Table from '@cloudscape-design/components/table'
import type { TableProps } from '@cloudscape-design/components/table'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { listBills } from '../../api/bills'
import { extractApiError } from '../../api/client'
import { listCustomers } from '../../api/masters'
import Spinner from '../../components/Spinner'
import { CsvButton, MetricCards, ReportPageShell } from './reportCloudscape'
import { currencyFormatter, downloadCsv, formatDateTime } from './reportCloudscapeUtils'

interface PendingDueRow {
  customerName: string
  phone: string
  outstanding: number
  lastTransaction: string
}

function PendingDuesPage() {
  const navigate = useNavigate()
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [rows, setRows] = useState<PendingDueRow[]>([])

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      setLoading(true)
      setError('')
      try {
        const [customers, bills] = await Promise.all([
          listCustomers(),
          listBills({ limit: 10000 }),
        ])
        const rowsData = customers
          .filter((customer) => customer.outstandingBalance > 0)
          .map<PendingDueRow>((customer) => {
            const latestBill = bills
              .filter((bill) => (bill.customer_name ?? '').toLowerCase() === customer.name.toLowerCase())
              .sort((left, right) => right.created_at.localeCompare(left.created_at))[0]
            return {
              customerName: customer.name,
              phone: customer.phone ?? '—',
              outstanding: customer.outstandingBalance,
              lastTransaction: latestBill?.created_at ?? '',
            }
          })
          .sort((left, right) => right.outstanding - left.outstanding)
        if (!cancelled) {
          setRows(rowsData)
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
  }, [])

  const filteredRows = useMemo(() => {
    const value = query.trim().toLowerCase()
    if (!value) return rows
    return rows.filter((row) => row.customerName.toLowerCase().includes(value) || row.phone.toLowerCase().includes(value))
  }, [query, rows])

  const totalOutstanding = useMemo(() => filteredRows.reduce((sum, row) => sum + row.outstanding, 0), [filteredRows])

  const columnDefinitions: ReadonlyArray<TableProps.ColumnDefinition<PendingDueRow>> = [
    { id: 'customer', header: 'Customer', cell: (item) => item.customerName },
    { id: 'phone', header: 'Phone', cell: (item) => item.phone },
    { id: 'outstanding', header: 'Outstanding', cell: (item) => currencyFormatter.format(item.outstanding) },
    { id: 'last', header: 'Last transaction', cell: (item) => formatDateTime(item.lastTransaction) },
    {
      id: 'statement',
      header: 'Statement',
      cell: (item) => (
        <Button
          variant="inline-link"
          onClick={() => navigate(`/reports/customer-credit-statement?customer=${encodeURIComponent(item.customerName)}`)}
        >
          Open statement
        </Button>
      ),
    },
  ]

  if (loading) {
    return <Spinner label="Loading pending dues..." />
  }

  return (
    <ReportPageShell
      title="Pending Dues & Credit Customers"
      description="Customers with outstanding balances and quick access to statements."
      actions={(
        <CsvButton
          onClick={() => downloadCsv(
            'pending-dues.csv',
            ['Customer', 'Phone', 'Outstanding', 'Last Transaction'],
            filteredRows.map((row) => [row.customerName, row.phone, row.outstanding.toFixed(2), formatDateTime(row.lastTransaction)]),
          )}
        />
      )}
    >
      {error ? <Alert type="error">{error}</Alert> : null}
      <MetricCards
        items={[
          { label: 'Customers in due', value: String(filteredRows.length) },
          { label: 'Total outstanding', value: currencyFormatter.format(totalOutstanding) },
          { label: 'Highest due', value: currencyFormatter.format(filteredRows[0]?.outstanding ?? 0) },
          { label: 'Search key', value: query || 'All' },
        ]}
      />
      <SpaceBetween size="s">
        <FormField label="Search customer">
          <Input value={query} onChange={({ detail }) => setQuery(detail.value)} placeholder="Search by name or phone" />
        </FormField>
        <Table
          items={filteredRows}
          columnDefinitions={columnDefinitions}
          loadingText="Loading dues"
          empty={<Box color="text-body-secondary">No pending dues found.</Box>}
          header={<Box variant="h3">Pending dues list</Box>}
        />
      </SpaceBetween>
    </ReportPageShell>
  )
}

export default PendingDuesPage
