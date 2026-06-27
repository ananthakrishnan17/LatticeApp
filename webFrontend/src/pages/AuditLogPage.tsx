import { useEffect, useMemo, useState } from 'react'
import { extractApiError } from '../api/client'
import { listTransactions } from '../api/transactions'
import Spinner from '../components/Spinner'
import { listAuditEvents, type AuditEvent } from '../utils/auditLog'

interface AuditRow extends AuditEvent {
  source: 'local' | 'synced'
}

function AuditLogPage() {
  const [filter, setFilter] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [logs, setLogs] = useState<AuditRow[]>([])

  useEffect(() => {
    let cancelled = false

    const load = async () => {
      setLoading(true)
      setError('')
      try {
        const [transactions, local] = await Promise.all([
          listTransactions({ types: 'audit_event', limit: 200 }),
          Promise.resolve(listAuditEvents()),
        ])
        const synced: AuditRow[] = transactions.map((tx) => {
          const tags = (tx.tags_json ?? {}) as Record<string, unknown>
          return {
            id: tx.client_record_id,
            module: String(tags.module ?? 'general'),
            action: String(tags.action ?? tx.tx_type),
            detail: String(tags.detail ?? ''),
            actor: String(tags.actor ?? 'unknown'),
            createdAt: String(tags.timestamp ?? tx.created_at),
            metadata: tags,
            source: 'synced',
          }
        })
        const merged = new Map<string, AuditRow>()
        ;[...synced, ...local.map((event) => ({ ...event, source: 'local' as const }))].forEach((event) => {
          const key = `${event.module}::${event.action}::${event.createdAt}`
          if (!merged.has(key) || event.source === 'synced') {
            merged.set(key, event)
          }
        })
        if (!cancelled) {
          setLogs(Array.from(merged.values()).sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()))
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
  }, [])

  const filtered = useMemo(() => {
    const q = filter.trim().toLowerCase()
    if (!q) return logs
    return logs.filter((log) => [log.module, log.action, log.detail, log.actor].some((value) => value.toLowerCase().includes(q)))
  }, [filter, logs])

  if (loading) {
    return <Spinner label="Loading audit log..." />
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Operational Audit Log</h1>
        <p className="mt-1 text-sm text-slate-500">Review tracked actions on products, users, bills, and settings changes.</p>
      </div>

      <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="Filter by module/action/user" className="w-full max-w-md rounded-xl border border-slate-200 px-4 py-2.5 text-sm" />
      {error ? <div className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}

      <section className="overflow-x-auto rounded-2xl bg-white p-5 ring-1 ring-slate-200">
        <table className="w-full text-sm">
          <thead className="border-b border-slate-200 bg-slate-50 text-slate-600">
            <tr>
              {['Timestamp', 'Module', 'Action', 'Detail', 'Actor', 'Source'].map((heading) => (
                <th key={heading} className="px-4 py-3 text-left font-semibold">{heading}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map((event) => (
              <tr key={`${event.source}-${event.id}`} className="border-t border-slate-100 align-top">
                <td className="px-4 py-3 text-slate-500">{new Date(event.createdAt).toLocaleString()}</td>
                <td className="px-4 py-3 font-semibold text-slate-900">{event.module}</td>
                <td className="px-4 py-3 text-slate-700">{event.action}</td>
                <td className="px-4 py-3 text-slate-700">{event.detail}</td>
                <td className="px-4 py-3 text-slate-700">{event.actor}</td>
                <td className="px-4 py-3"><span className={`rounded-full px-3 py-1 text-xs font-semibold ${event.source === 'synced' ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'}`}>{event.source}</span></td>
              </tr>
            ))}
            {!filtered.length ? <tr><td colSpan={6} className="px-4 py-8 text-center text-slate-500">No audit events captured yet.</td></tr> : null}
          </tbody>
        </table>
      </section>
    </div>
  )
}

export default AuditLogPage
