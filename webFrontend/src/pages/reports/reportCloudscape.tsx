import Box from '@cloudscape-design/components/box'
import Button from '@cloudscape-design/components/button'
import ColumnLayout from '@cloudscape-design/components/column-layout'
import Container from '@cloudscape-design/components/container'
import DatePicker from '@cloudscape-design/components/date-picker'
import FormField from '@cloudscape-design/components/form-field'
import Header from '@cloudscape-design/components/header'
import SpaceBetween from '@cloudscape-design/components/space-between'
import type { ReactNode } from 'react'

export function ReportPageShell({
  title,
  description,
  actions,
  children,
}: {
  title: string
  description: string
  actions?: ReactNode
  children: ReactNode
}) {
  return (
    <SpaceBetween size="l">
      <Header variant="h1" description={description} actions={actions}>
        {title}
      </Header>
      {children}
    </SpaceBetween>
  )
}

export function DateRangePanel({
  from,
  to,
  onFromChange,
  onToChange,
  extra,
}: {
  from: string
  to: string
  onFromChange: (value: string) => void
  onToChange: (value: string) => void
  extra?: ReactNode
}) {
  return (
    <Container>
      <ColumnLayout columns={extra ? 3 : 2}>
        <FormField label="From date">
          <DatePicker value={from} onChange={({ detail }) => onFromChange(detail.value ?? from)} />
        </FormField>
        <FormField label="To date">
          <DatePicker value={to} onChange={({ detail }) => onToChange(detail.value ?? to)} />
        </FormField>
        {extra ?? null}
      </ColumnLayout>
    </Container>
  )
}

export function DatePanel({
  date,
  onDateChange,
  extra,
}: {
  date: string
  onDateChange: (value: string) => void
  extra?: ReactNode
}) {
  return (
    <Container>
      <ColumnLayout columns={extra ? 2 : 1}>
        <FormField label="Date">
          <DatePicker value={date} onChange={({ detail }) => onDateChange(detail.value ?? date)} />
        </FormField>
        {extra ?? null}
      </ColumnLayout>
    </Container>
  )
}

export function MetricCards({ items }: { items: Array<{ label: string; value: string; description?: string }> }) {
  return (
    <ColumnLayout columns={4} variant="text-grid">
      {items.map((item) => (
        <Container
          key={item.label}
          header={<Header variant="h3">{item.label}</Header>}
        >
          <Box variant="h2">{item.value}</Box>
          {item.description ? <Box color="text-body-secondary">{item.description}</Box> : null}
        </Container>
      ))}
    </ColumnLayout>
  )
}

export function CsvButton({ onClick }: { onClick: () => void }) {
  return <Button iconName="download" onClick={onClick}>Export CSV</Button>
}
