import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { bootstrap, health } from '../api/auth'
import { extractApiError } from '../api/client'
import { useAuth } from '../context/AuthContext'

function BootstrapPage() {
  const { baseUrl, deviceId, setBaseUrl } = useAuth()
  const navigate = useNavigate()
  const [form, setForm] = useState({
    baseUrl,
    tenantCode: '',
    username: '',
    password: '',
  })
  const [error, setError] = useState('')
  const [status, setStatus] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [checkingHealth, setCheckingHealth] = useState(false)


  const canSubmit = useMemo(() => Object.values(form).every((value) => value.trim()), [form])

  const handleChange = (field: keyof typeof form, value: string) => {
    setForm((current) => ({ ...current, [field]: value }))
  }

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setSubmitting(true)
    setError('')
    setStatus('')

    try {
      setBaseUrl(form.baseUrl)
      const isPhoneNumber = /^\d+$/.test(form.username.trim())
      const result = await bootstrap(form.baseUrl, {
        tenantCode: form.tenantCode,
        ...(isPhoneNumber ? { phoneNumber: form.username } : { username: form.username }),
        password: form.password,
        deviceId,
      })
      setStatus(`Bootstrap completed: ${result.status}. You can sign in now.`)
      navigate('/login', { replace: true })
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSubmitting(false)
    }
  }

  const handleHealthCheck = async () => {
    setCheckingHealth(true)
    setError('')
    setStatus('')

    try {
      const result = await health(form.baseUrl)
      setStatus(`API health: ${result}`)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setCheckingHealth(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-100 px-4 py-10">
      <div className="w-full max-w-3xl rounded-3xl bg-white p-8 shadow-xl shadow-slate-200/70 md:p-10">
        <p className="text-sm font-semibold uppercase tracking-[0.35em] text-indigo-600">First-time setup</p>
        <h1 className="mt-3 text-3xl font-bold text-slate-900">Bootstrap the first admin account</h1>
        <p className="mt-2 text-sm text-slate-500">Use this once to initialize the tenant and create the first admin credentials.</p>

        <form className="mt-8 grid gap-5 md:grid-cols-2" onSubmit={handleSubmit}>
          <label className="md:col-span-2">
            <span className="mb-2 block text-sm font-medium text-slate-700">Base URL</span>
            <input
              value={form.baseUrl}
              onChange={(event) => handleChange('baseUrl', event.target.value)}
              placeholder="http://localhost:8080"
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
            />
            <span className="mt-2 block text-xs text-slate-500">
              Enter backend root URL (example: http://api.example.com:8080). Do not use the frontend URL or paths like /webapp.
            </span>
          </label>
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">Tenant code</span>
            <input
              value={form.tenantCode}
              onChange={(event) => handleChange('tenantCode', event.target.value)}
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
            />
          </label>
          <label>
            <span className="mb-2 block text-sm font-medium text-slate-700">Admin username</span>
            <input
              value={form.username}
              onChange={(event) => handleChange('username', event.target.value)}
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
            />
          </label>
          <label className="md:col-span-2">
            <span className="mb-2 block text-sm font-medium text-slate-700">Admin password</span>
            <input
              type="password"
              value={form.password}
              onChange={(event) => handleChange('password', event.target.value)}
              className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
            />
          </label>

          <div className="md:col-span-2 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-600">
            Device ID for this browser: <span className="font-semibold text-slate-900">{deviceId}</span>
          </div>

          {error ? <div className="md:col-span-2 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
          {status ? <div className="md:col-span-2 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{status}</div> : null}

          <div className="md:col-span-2 flex flex-col gap-3 sm:flex-row">
            <button
              type="submit"
              disabled={!canSubmit || submitting}
              className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300"
            >
              {submitting ? 'Bootstrapping...' : 'Bootstrap admin'}
            </button>
            <button
              type="button"
              onClick={handleHealthCheck}
              disabled={!form.baseUrl.trim() || checkingHealth}
              className="rounded-2xl border border-slate-200 px-5 py-3 text-sm font-semibold text-slate-700 transition hover:border-indigo-300 hover:text-indigo-600 disabled:cursor-not-allowed disabled:text-slate-400"
            >
              {checkingHealth ? 'Checking...' : 'Check API'}
            </button>
            <Link
              to="/login"
              className="rounded-2xl border border-slate-200 px-5 py-3 text-center text-sm font-semibold text-slate-700 transition hover:border-indigo-300 hover:text-indigo-600"
            >
              Back to login
            </Link>
          </div>
        </form>
      </div>
    </div>
  )
}

export default BootstrapPage
