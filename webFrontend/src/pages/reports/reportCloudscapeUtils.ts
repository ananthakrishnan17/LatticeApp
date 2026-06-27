export const currencyFormatter = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  maximumFractionDigits: 2,
})

export const toDateInput = (value: Date) => value.toISOString().slice(0, 10)
export const startOfDayIso = (value: string) => new Date(`${value}T00:00:00`).toISOString()
export const endOfDayTs = (value: string) => new Date(`${value}T23:59:59`).getTime()
export const startOfDayTs = (value: string) => new Date(`${value}T00:00:00`).getTime()

export function isBetween(value: string, from: string, to: string) {
  const ts = new Date(value).getTime()
  return ts >= startOfDayTs(from) && ts <= endOfDayTs(to)
}

export function formatDateTime(value?: string | null) {
  if (!value) return '—'
  const parsed = Date.parse(value)
  if (Number.isNaN(parsed)) return value
  return new Date(parsed).toLocaleString()
}

export function formatDate(value?: string | null) {
  if (!value) return '—'
  const parsed = Date.parse(value)
  if (Number.isNaN(parsed)) return value
  return new Date(parsed).toLocaleDateString()
}

export function downloadCsv(filename: string, headers: string[], rows: Array<Array<string | number>>) {
  const escaped = [headers, ...rows]
    .map((row) => row.map((cell) => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\n')
  const blob = new Blob([escaped], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = filename
  anchor.click()
  URL.revokeObjectURL(url)
}

export function parseSplitPayments(splitSummary?: string | null) {
  if (!splitSummary) return [] as Array<{ mode: string; amount: number }>
  try {
    const entries = JSON.parse(splitSummary) as Array<{ mode?: string; amount?: string | number }>
    return entries
      .map((entry) => ({ mode: String(entry.mode ?? '').toLowerCase(), amount: Number(entry.amount ?? 0) || 0 }))
      .filter((entry) => entry.mode && entry.amount > 0)
  } catch {
    return []
  }
}
