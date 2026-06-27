import { useNavigate } from 'react-router-dom'
import useSubscription from '../hooks/useSubscription'
import Spinner from '../components/Spinner'

function formatExpiry(value: string | null) {
  return value ? new Date(value).toLocaleDateString() : '—'
}

export default function SubscriptionLockPage() {
  const navigate = useNavigate()
  const { status, loading, error } = useSubscription()

  if (loading) {
    return <Spinner fullScreen label="Checking subscription..." />
  }

  return (
    <div className="min-h-screen bg-slate-100 px-4 py-10">
      <div className="mx-auto flex min-h-[80vh] max-w-3xl items-center justify-center">
        <div className="w-full rounded-3xl border border-rose-200 bg-white p-8 shadow-xl">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-rose-600">Access restricted</p>
          <h1 className="mt-3 text-4xl font-bold text-slate-900">Subscription Expired</h1>
          <p className="mt-3 text-sm text-slate-500">
            {error || 'Your subscription needs renewal before the POS workspace can be used.'}
          </p>

          <div className="mt-8 grid gap-4 md:grid-cols-2">
            <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Plan</p>
              <p className="mt-2 text-xl font-semibold text-slate-900">{status?.planCode || '—'}</p>
              <p className="mt-2 text-sm text-slate-500">Company: {status?.companyName || '—'}</p>
            </div>
            <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Days overdue</p>
              <p className="mt-2 text-xl font-semibold text-rose-700">{status?.daysLeft ?? 0}</p>
              <p className="mt-2 text-sm text-slate-500">Expiry: {formatExpiry(status?.expiresAt ?? null)}</p>
            </div>
          </div>

          <div className="mt-8 rounded-2xl border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
            <div className="flex justify-between"><span>License</span><span className="font-medium text-slate-900">{status?.licenseKey || '—'}</span></div>
            <div className="mt-2 flex justify-between"><span>Users allowed</span><span className="font-medium text-slate-900">{status?.maxUsers ?? '—'}</span></div>
          </div>

          <div className="mt-8 flex gap-3">
            <button
              type="button"
              onClick={() => navigate('/subscription')}
              className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700"
            >
              Renew Subscription
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
