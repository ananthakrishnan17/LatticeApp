import Alert from '@cloudscape-design/components/alert'
import Box from '@cloudscape-design/components/box'
import Button from '@cloudscape-design/components/button'
import StatusIndicator from '@cloudscape-design/components/status-indicator'
import Table from '@cloudscape-design/components/table'
import type { TableProps } from '@cloudscape-design/components/table'
import { useMemo, useState } from 'react'
import type { CashSessionRecord } from '../../types'
import { listCashSessions } from '../../utils/cashSession'
import {
  CsvButton,
  DatePanel,
  MetricCards,
  ReportPageShell,
} from './reportCloudscape'
import { currencyFormatter, downloadCsv, formatDateTime, toDateInput } from './reportCloudscapeUtils'

const today = toDateInput(new Date())

function CashierSessionsDashboardPage() {
  const [date, setDate] = useState(today)
  const [notice, setNotice] = useState('')

  const rows = useMemo(() => {
    const selectedDate = date
    return listCashSessions()
      .filter((session) => session.openedAt.slice(0, 10) === selectedDate)
  }, [date])

  const totals = useMemo(() => {
    return rows.reduce(
      (acc, row) => ({
        opening: acc.opening + row.openingAmount,
        expected: acc.expected + row.expectedClosing,
        actual: acc.actual + (row.closingAmount ?? 0),
        difference: acc.difference + (row.difference ?? 0),
        openCount: acc.openCount + (row.status === 'OPEN' ? 1 : 0),
      }),
      { opening: 0, expected: 0, actual: 0, difference: 0, openCount: 0 },
    )
  }, [rows])

  const columnDefinitions: ReadonlyArray<TableProps.ColumnDefinition<CashSessionRecord>> = [
    { id: 'cashier', header: 'Cashier', cell: (item) => item.cashierUsername },
    {
      id: 'status',
      header: 'Status',
      cell: (item) => (
        <StatusIndicator type={item.status === 'OPEN' ? 'warning' : 'success'}>
          {item.status}
        </StatusIndicator>
      ),
    },
    { id: 'opening', header: 'Opening', cell: (item) => currencyFormatter.format(item.openingAmount) },
    { id: 'cashSales', header: 'Cash sales', cell: (item) => currencyFormatter.format(item.totalCashCollected) },
    { id: 'refunds', header: 'Cash refunds', cell: (item) => currencyFormatter.format(item.totalCashRefunded) },
    { id: 'expected', header: 'Expected closing', cell: (item) => currencyFormatter.format(item.expectedClosing) },
    { id: 'actual', header: 'Actual closing', cell: (item) => currencyFormatter.format(item.closingAmount ?? 0) },
    { id: 'difference', header: 'Difference', cell: (item) => currencyFormatter.format(item.difference ?? 0) },
    { id: 'openedAt', header: 'Opened at', cell: (item) => formatDateTime(item.openedAt) },
    { id: 'closedAt', header: 'Closed at', cell: (item) => formatDateTime(item.closedAt) },
  ]

  return (
    <ReportPageShell
      title="Cashier Sessions Dashboard"
      description="Day-wise cashier shift summary from local web shift sessions."
      actions={(
        <CsvButton
          onClick={() => {
            downloadCsv(
              `cashier-sessions-${date}.csv`,
              ['Cashier', 'Status', 'Opening', 'Cash Sales', 'Cash Refunds', 'Expected', 'Actual', 'Difference', 'Opened At', 'Closed At'],
              rows.map((row) => [
                row.cashierUsername,
                row.status,
                row.openingAmount.toFixed(2),
                row.totalCashCollected.toFixed(2),
                row.totalCashRefunded.toFixed(2),
                row.expectedClosing.toFixed(2),
                (row.closingAmount ?? 0).toFixed(2),
                (row.difference ?? 0).toFixed(2),
                formatDateTime(row.openedAt),
                formatDateTime(row.closedAt),
              ]),
            )
          }}
        />
      )}
    >
      {notice ? <Alert type="success" dismissible onDismiss={() => setNotice('')}>{notice}</Alert> : null}
      <DatePanel
        date={date}
        onDateChange={setDate}
        extra={(
          <Box padding={{ top: 'xl' }}>
            <Button
              onClick={() => {
                setNotice('Session dashboard refreshed.')
              }}
            >
              Refresh
            </Button>
          </Box>
        )}
      />
      <MetricCards
        items={[
          { label: 'Sessions', value: String(rows.length) },
          { label: 'Open sessions', value: String(totals.openCount) },
          { label: 'Expected closing total', value: currencyFormatter.format(totals.expected) },
          { label: 'Difference total', value: currencyFormatter.format(totals.difference) },
        ]}
      />
      <Table
        items={rows}
        columnDefinitions={columnDefinitions}
        loadingText="Loading sessions"
        empty={<Box color="text-body-secondary">No sessions found for selected day.</Box>}
        header={<Box variant="h3">Cashier sessions</Box>}
      />
    </ReportPageShell>
  )
}

export default CashierSessionsDashboardPage
