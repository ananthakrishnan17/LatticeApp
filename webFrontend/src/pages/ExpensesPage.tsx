import { generateUUID } from '../utils/uuid'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { extractApiError } from '../api/client'
import { listTransactions, upsertTransaction } from '../api/transactions'
import { useAuth } from '../context/AuthContext'
import { pushAuditEvent } from '../utils/auditLog'

const currency = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 })
const APPROVAL_KEY = 'nn_expense_approval_log'

interface ApprovalMap { [key: string]: { approvedBy: string; approvedAt: string } }

const loadApproval = () => {
  try {
    const raw = localStorage.getItem(APPROVAL_KEY)
    return raw ? (JSON.parse(raw) as ApprovalMap) : {}
  } catch {
    return {}
  }
}

function ExpensesPage() {
  const { username, isAdmin } = useAuth()
  const [category, setCategory] = useState('general')
  const [amount, setAmount] = useState('')
  const [note, setNote] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [expenses, setExpenses] = useState<Array<{ client_record_id: string; total_amount: number; created_at: string; tags_json: Record<string, unknown> }>>([])
  const [approvals, setApprovals] = useState<ApprovalMap>(() => loadApproval())

  const fetchExpenses = useCallback(async () => {
    const txs = await listTransactions({ types: 'expense', limit: 500 })
    return txs.filter((tx) => tx.tx_type === 'expense')
  }, [])

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      setExpenses(await fetchExpenses())
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setLoading(false)
    }
  }, [fetchExpenses])

  useEffect(() => {
    let cancelled = false

    const bootstrapExpenses = async () => {
      setLoading(true)
      setError('')
      try {
        const txs = await fetchExpenses()
        if (!cancelled) {
          setExpenses(txs)
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

    void bootstrapExpenses()

    return () => {
      cancelled = true
    }
  }, [fetchExpenses])

  const submit = async (event: React.FormEvent) => {
    event.preventDefault()
    const parsed = Number.parseFloat(amount)
    if (!parsed || parsed <= 0) {
      setError('Enter a valid expense amount.')
      return
    }

    setSaving(true)
    setError('')
    try {
      const id = generateUUID()
      await upsertTransaction({
        clientRecordId: id,
        type: 'expense',
        totalAmount: parsed,
        tags: {
          category,
          note: note.trim() || undefined,
          created_by: username,
        },
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
      setNotice('Expense saved successfully.')
      setAmount('')
      setNote('')
      pushAuditEvent({ module: 'expenses', action: 'create', detail: `Expense ${parsed} in ${category}`, actor: username ?? 'unknown' })
      await load()
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  const approve = (id: string) => {
    if (!isAdmin) return
    const next = { ...approvals, [id]: { approvedBy: username ?? 'admin', approvedAt: new Date().toISOString() } }
    setApprovals(next)
    localStorage.setItem(APPROVAL_KEY, JSON.stringify(next))
    pushAuditEvent({ module: 'expenses', action: 'approve', detail: `Approved expense ${id}`, actor: username ?? 'unknown' })
  }

  const totals = useMemo(() => ({
    month: expenses.filter((e) => new Date(e.created_at) >= new Date(new Date().getFullYear(), new Date().getMonth(), 1)).reduce((sum, e) => sum + Number(e.total_amount), 0),
    all: expenses.reduce((sum, e) => sum + Number(e.total_amount), 0),
  }), [expenses])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Expense Management</h1>
        <p className="mt-1 text-sm text-slate-500">Track expenses with categories and lightweight approval trail.</p>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="rounded-2xl bg-white p-4 ring-1 ring-slate-200">
          <p className="text-xs uppercase tracking-wide text-slate-500">This month</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{currency.format(totals.month)}</p>
        </div>
        <div className="rounded-2xl bg-white p-4 ring-1 ring-slate-200">
          <p className="text-xs uppercase tracking-wide text-slate-500">Total expenses</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{currency.format(totals.all)}</p>
        </div>
      </div>

      <form onSubmit={submit} className="rounded-2xl bg-white p-5 ring-1 ring-slate-200 space-y-4">
        <div className="grid gap-4 md:grid-cols-3">
          <label>
            <p className="mb-1 text-sm font-medium text-slate-700">Category</p>
            <select value={category} onChange={(e) => setCategory(e.target.value)} className="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm">
              {['general', 'salary', 'rent', 'transport', 'maintenance', 'marketing'].map((item) => <option key={item} value={item}>{item.toUpperCase()}</option>)}
            </select>
          </label>
          <label>
            <p className="mb-1 text-sm font-medium text-slate-700">Amount</p>
            <input value={amount} onChange={(e) => setAmount(e.target.value)} type="number" min={0} step="0.01" className="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" />
          </label>
          <label>
            <p className="mb-1 text-sm font-medium text-slate-700">Note</p>
            <input value={note} onChange={(e) => setNote(e.target.value)} className="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" />
          </label>
        </div>
        <button type="submit" disabled={saving} className="rounded-xl bg-indigo-600 px-4 py-2 text-sm font-semibold text-white">{saving ? 'Saving...' : 'Add expense'}</button>
      </form>

      {error ? <div className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      {notice ? <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      <section className="rounded-2xl bg-white p-5 ring-1 ring-slate-200">
        <h2 className="text-lg font-semibold text-slate-900">Expense log</h2>
        {loading ? <p className="mt-4 text-sm text-slate-500">Loading...</p> : (
          <div className="mt-4 space-y-2 max-h-[440px] overflow-y-auto">
            {expenses.map((item) => (
              <div key={item.client_record_id} className="rounded-xl border border-slate-200 px-3 py-2 text-sm">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="font-semibold text-slate-900">{currency.format(item.total_amount)} · {String(item.tags_json.category ?? 'GENERAL').toUpperCase()}</p>
                    <p className="text-xs text-slate-500">{new Date(item.created_at).toLocaleString()} · {String(item.tags_json.note ?? 'No note')}</p>
                  </div>
                  <div className="text-right">
                    {approvals[item.client_record_id] ? (
                      <p className="text-xs font-semibold text-emerald-700">Approved by {approvals[item.client_record_id].approvedBy}</p>
                    ) : isAdmin ? (
                      <button type="button" onClick={() => approve(item.client_record_id)} className="rounded-lg border border-slate-200 px-2 py-1 text-xs font-semibold text-slate-700">Approve</button>
                    ) : <p className="text-xs text-amber-600">Pending approval</p>}
                  </div>
                </div>
              </div>
            ))}
            {!expenses.length ? <p className="text-sm text-slate-500">No expense records yet.</p> : null}
          </div>
        )}
      </section>
    </div>
  )
}

export default ExpensesPage
