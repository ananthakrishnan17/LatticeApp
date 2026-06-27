import { useState } from 'react'
import { useAuth } from '../context/AuthContext'
import { updateUserPin } from '../api/users'
import { STORAGE_KEYS, OFFLINE_SESSION_DAYS, apiClient, extractApiError, type LicenseMode } from '../api/client'
import { pushAuditEvent } from '../utils/auditLog'
import type { LanguageSettings, PrinterSettings, ShopInfoSettings } from '../types'

// ─── Default values ───────────────────────────────────────────────────────────

const DEFAULT_SHOP_INFO: ShopInfoSettings = {
  shopName: '',
  address: '',
  phone: '',
  email: '',
  gstin: '',
  footerNote: '',
}

const DEFAULT_LANGUAGE: LanguageSettings = {
  language: 'en',
  currencySymbol: '₹',
  dateFormat: 'DD/MM/YYYY',
}

const DEFAULT_PRINTER: PrinterSettings = {
  paperSize: '80mm',
  showGstin: true,
  headerText: '',
  footerText: 'Thank you for your purchase!',
}

// ─── Storage helpers ──────────────────────────────────────────────────────────

function loadJson<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

function saveJson<T>(key: string, value: T) {
  localStorage.setItem(key, JSON.stringify(value))
  pushAuditEvent({
    module: 'settings',
    action: 'update',
    detail: `Updated ${key}`,
    actor: localStorage.getItem(STORAGE_KEYS.username) ?? 'unknown',
  })
}

// ─── Tab list ─────────────────────────────────────────────────────────────────

type TabId = 'shop' | 'language' | 'printer' | 'business' | 'backup' | 'sync' | 'api' | 'security' | 'license'

interface Tab {
  id: TabId
  label: string
  adminOnly?: boolean
}

const TABS: Tab[] = [
  { id: 'shop', label: 'Shop Info', adminOnly: true },
  { id: 'language', label: 'Language' },
  { id: 'printer', label: 'Printer & Template', adminOnly: true },
  { id: 'business', label: 'Business & GST', adminOnly: true },
  { id: 'backup', label: 'Backup & Restore', adminOnly: true },
  { id: 'sync', label: 'Connection Monitor' },
  { id: 'api', label: 'Backend API', adminOnly: true },
  { id: 'license', label: 'License Mode', adminOnly: true },
  { id: 'security', label: 'Security' },
]

interface BusinessSettings {
  businessType: 'retail' | 'wholesale' | 'restaurant' | 'pharmacy'
  defaultGstRate: string
  gstPricingMode: 'inclusive' | 'exclusive'
  billTemplate: 'classic' | 'compact'
  languageLocale: string
  shopLogoUrl: string
  ownerCapital: string
  enableGoogleDriveBackup: boolean
}

const DEFAULT_BUSINESS_SETTINGS: BusinessSettings = {
  businessType: 'retail',
  defaultGstRate: '5',
  gstPricingMode: 'exclusive',
  billTemplate: 'classic',
  languageLocale: 'en-IN',
  shopLogoUrl: '',
  ownerCapital: '0',
  enableGoogleDriveBackup: false,
}

// ─── Shared UI helpers ────────────────────────────────────────────────────────

function SectionTitle({ title, subtitle }: { title: string; subtitle?: string }) {
  return (
    <div className="mb-6">
      <h2 className="text-xl font-semibold text-slate-900">{title}</h2>
      {subtitle ? <p className="mt-1 text-sm text-slate-500">{subtitle}</p> : null}
    </div>
  )
}

function FieldLabel({ children }: { children: React.ReactNode }) {
  return <span className="mb-2 block text-sm font-medium text-slate-700">{children}</span>
}

function TextInput({
  value,
  onChange,
  placeholder,
  disabled,
}: {
  value: string
  onChange: (v: string) => void
  placeholder?: string
  disabled?: boolean
}) {
  return (
    <input
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      disabled={disabled}
      className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100 disabled:bg-slate-100"
    />
  )
}

function TextArea({
  value,
  onChange,
  rows = 3,
  placeholder,
}: {
  value: string
  onChange: (v: string) => void
  rows?: number
  placeholder?: string
}) {
  return (
    <textarea
      rows={rows}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100 resize-none"
    />
  )
}

function SaveButton({ saving }: { saving: boolean }) {
  return (
    <button
      type="submit"
      disabled={saving}
      className="rounded-2xl bg-indigo-600 px-6 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300"
    >
      {saving ? 'Saving…' : 'Save changes'}
    </button>
  )
}

function Notice({ text, type }: { text: string; type: 'success' | 'error' }) {
  const style =
    type === 'success'
      ? 'border-emerald-200 bg-emerald-50 text-emerald-700'
      : 'border-rose-200 bg-rose-50 text-rose-700'
  return <div className={`rounded-2xl border px-4 py-3 text-sm ${style}`}>{text}</div>
}

// ─── Shop Info tab ────────────────────────────────────────────────────────────

function ShopInfoTab() {
  const [form, setForm] = useState<ShopInfoSettings>(() =>
    loadJson(STORAGE_KEYS.shopInfo, DEFAULT_SHOP_INFO),
  )
  const [notice, setNotice] = useState('')

  const set = (field: keyof ShopInfoSettings) => (value: string) =>
    setForm((f) => ({ ...f, [field]: value }))

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    const gstin = form.gstin.trim()
    // Format: 2-digit state code + 5-letter PAN + 4-digit entity number + 1-letter entity type + 1 digit/letter + Z + 1 checksum
    if (gstin && !/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/.test(gstin)) {
      setNotice('Invalid GSTIN format. Expected format: 22AAAAA0000A1Z5')
      return
    }
    saveJson(STORAGE_KEYS.shopInfo, form)
    setNotice('Shop info saved.')
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5 max-w-2xl">
      <SectionTitle
        title="Shop Information"
        subtitle="This info is printed on receipts and used across the app."
      />
      {notice ? <Notice text={notice} type={notice.startsWith('Invalid') ? 'error' : 'success'} /> : null}
      <div className="grid gap-4 md:grid-cols-2">
        <label>
          <FieldLabel>Shop name</FieldLabel>
          <TextInput value={form.shopName} onChange={set('shopName')} placeholder="My Store" />
        </label>
        <label>
          <FieldLabel>Phone</FieldLabel>
          <TextInput value={form.phone} onChange={set('phone')} placeholder="+91 98765 43210" />
        </label>
        <label>
          <FieldLabel>Email</FieldLabel>
          <TextInput value={form.email} onChange={set('email')} placeholder="shop@example.com" />
        </label>
        <label>
          <FieldLabel>GSTIN</FieldLabel>
          <TextInput value={form.gstin} onChange={set('gstin')} placeholder="22AAAAA0000A1Z5" />
        </label>
      </div>
      <label>
        <FieldLabel>Address</FieldLabel>
        <TextArea value={form.address} onChange={set('address')} placeholder="123, Main Street, City - 600001" />
      </label>
      <label>
        <FieldLabel>Receipt footer note</FieldLabel>
        <TextInput
          value={form.footerNote}
          onChange={set('footerNote')}
          placeholder="Thank you for shopping with us!"
        />
      </label>
      <div className="flex justify-end">
        <SaveButton saving={false} />
      </div>
    </form>
  )
}

// ─── Language tab ─────────────────────────────────────────────────────────────

function LanguageTab() {
  const [form, setForm] = useState<LanguageSettings>(() =>
    loadJson(STORAGE_KEYS.language, DEFAULT_LANGUAGE),
  )
  const [notice, setNotice] = useState('')

  const set =
    <K extends keyof LanguageSettings>(field: K) =>
    (value: LanguageSettings[K]) =>
      setForm((f) => ({ ...f, [field]: value }))

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    saveJson(STORAGE_KEYS.language, form)
    setNotice('Language preferences saved.')
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5 max-w-2xl">
      <SectionTitle title="Language & Display" subtitle="Customize locale, currency, and date formatting." />
      {notice ? <Notice text={notice} type="success" /> : null}

      <div>
        <FieldLabel>Interface language</FieldLabel>
        <div className="flex flex-wrap gap-3">
          {(['en', 'ta', 'te', 'hi', 'kn', 'ml'] as const).map((lang) => {
            const labels: Record<string, string> = {
              en: 'English',
              ta: 'தமிழ் (Tamil)',
              te: 'తెలుగు (Telugu)',
              hi: 'हिंदी (Hindi)',
              kn: 'ಕನ್ನಡ (Kannada)',
              ml: 'മലയാളം (Malayalam)',
            }
            return (
              <button
                key={lang}
                type="button"
                onClick={() => set('language')(lang)}
                className={`rounded-2xl px-5 py-3 text-sm font-semibold transition ${form.language === lang ? 'bg-indigo-600 text-white' : 'border border-slate-200 text-slate-700 hover:border-indigo-300 hover:text-indigo-600'}`}
              >
                {labels[lang]}
              </button>
            )
          })}
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <label>
          <FieldLabel>Currency symbol</FieldLabel>
          <TextInput value={form.currencySymbol} onChange={set('currencySymbol')} placeholder="₹" />
        </label>
        <div>
          <FieldLabel>Date format</FieldLabel>
          <select
            value={form.dateFormat}
            onChange={(e) => set('dateFormat')(e.target.value as LanguageSettings['dateFormat'])}
            className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
          >
            <option value="DD/MM/YYYY">DD/MM/YYYY</option>
            <option value="MM/DD/YYYY">MM/DD/YYYY</option>
            <option value="YYYY-MM-DD">YYYY-MM-DD</option>
          </select>
        </div>
      </div>

      <div className="flex justify-end">
        <SaveButton saving={false} />
      </div>
    </form>
  )
}

// ─── Printer / Template tab ───────────────────────────────────────────────────

function PrinterTab() {
  const [form, setForm] = useState<PrinterSettings>(() =>
    loadJson(STORAGE_KEYS.printerSettings, DEFAULT_PRINTER),
  )
  const [notice, setNotice] = useState('')

  const set =
    <K extends keyof PrinterSettings>(field: K) =>
    (value: PrinterSettings[K]) =>
      setForm((f) => ({ ...f, [field]: value }))

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    saveJson(STORAGE_KEYS.printerSettings, form)
    setNotice('Printer settings saved.')
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5 max-w-2xl">
      <SectionTitle title="Printer & Receipt Template" subtitle="Configure receipt size and content layout." />
      {notice ? <Notice text={notice} type="success" /> : null}

      <div>
        <FieldLabel>Paper size</FieldLabel>
        <div className="flex flex-wrap gap-3">
          {(['58mm', '80mm', 'A4'] as const).map((size) => (
            <button
              key={size}
              type="button"
              onClick={() => set('paperSize')(size)}
              className={`rounded-2xl px-5 py-3 text-sm font-semibold transition ${form.paperSize === size ? 'bg-indigo-600 text-white' : 'border border-slate-200 text-slate-700 hover:border-indigo-300 hover:text-indigo-600'}`}
            >
              {size}
            </button>
          ))}
        </div>
      </div>

      <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
        <input
          type="checkbox"
          checked={form.showGstin}
          onChange={(e) => set('showGstin')(e.target.checked)}
          className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
        />
        <span className="text-sm font-medium text-slate-700">Show GSTIN on receipt</span>
      </label>

      <label>
        <FieldLabel>Receipt header text</FieldLabel>
        <TextArea value={form.headerText} onChange={(v) => set('headerText')(v)} placeholder="Optional text printed below the shop name" />
      </label>
      <label>
        <FieldLabel>Receipt footer text</FieldLabel>
        <TextArea value={form.footerText} onChange={(v) => set('footerText')(v)} placeholder="Thank you for your purchase!" />
      </label>

      <div className="flex justify-end">
        <SaveButton saving={false} />
      </div>
    </form>
  )
}

function BusinessGstTab() {
  const [form, setForm] = useState<BusinessSettings>(() =>
    loadJson('nn_business_settings', DEFAULT_BUSINESS_SETTINGS),
  )
  const [notice, setNotice] = useState('')

  const set =
    <K extends keyof BusinessSettings>(field: K) =>
    (value: BusinessSettings[K]) =>
      setForm((f) => ({ ...f, [field]: value }))

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    saveJson('nn_business_settings', form)
    setNotice('Business & GST settings saved.')
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5 max-w-2xl">
      <SectionTitle title="Business & GST Setup" subtitle="Configure GST defaults, business mode, owner capital, and backup preferences." />
      {notice ? <Notice text={notice} type="success" /> : null}

      <div className="grid gap-4 md:grid-cols-2">
        <label>
          <FieldLabel>Business type</FieldLabel>
          <select value={form.businessType} onChange={(e) => set('businessType')(e.target.value as BusinessSettings['businessType'])} className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100">
            <option value="retail">Retail</option>
            <option value="wholesale">Wholesale</option>
            <option value="restaurant">Restaurant</option>
            <option value="pharmacy">Pharmacy</option>
          </select>
        </label>
        <label>
          <FieldLabel>Default GST rate (%)</FieldLabel>
          <TextInput value={form.defaultGstRate} onChange={(v) => set('defaultGstRate')(v)} placeholder="5" />
        </label>
        <label>
          <FieldLabel>GST mode</FieldLabel>
          <select value={form.gstPricingMode} onChange={(e) => set('gstPricingMode')(e.target.value as BusinessSettings['gstPricingMode'])} className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100">
            <option value="exclusive">Tax exclusive</option>
            <option value="inclusive">Tax inclusive</option>
          </select>
        </label>
        <label>
          <FieldLabel>Receipt template</FieldLabel>
          <select value={form.billTemplate} onChange={(e) => set('billTemplate')(e.target.value as BusinessSettings['billTemplate'])} className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100">
            <option value="classic">Classic</option>
            <option value="compact">Compact</option>
          </select>
        </label>
        <label>
          <FieldLabel>Locale</FieldLabel>
          <TextInput value={form.languageLocale} onChange={(v) => set('languageLocale')(v)} placeholder="en-IN" />
        </label>
        <label>
          <FieldLabel>Owner capital (₹)</FieldLabel>
          <TextInput value={form.ownerCapital} onChange={(v) => set('ownerCapital')(v)} placeholder="0" />
        </label>
      </div>

      <label>
        <FieldLabel>Shop logo URL</FieldLabel>
        <TextInput value={form.shopLogoUrl} onChange={(v) => set('shopLogoUrl')(v)} placeholder="https://..." />
      </label>

      <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
        <input type="checkbox" checked={form.enableGoogleDriveBackup} onChange={(e) => set('enableGoogleDriveBackup')(e.target.checked)} className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
        <span className="text-sm font-medium text-slate-700">Enable Google Drive backup integration</span>
      </label>

      <div className="flex justify-end">
        <SaveButton saving={false} />
      </div>
    </form>
  )
}

// ─── Backup & Restore tab ─────────────────────────────────────────────────────

const BACKUP_KEYS: string[] = [
  STORAGE_KEYS.shopInfo,
  STORAGE_KEYS.language,
  STORAGE_KEYS.printerSettings,
  STORAGE_KEYS.baseUrl,
]

function BackupTab() {
  const [notice, setNotice] = useState('')
  const [noticeType, setNoticeType] = useState<'success' | 'error'>('success')

  const handleExport = () => {
    const snapshot: Record<string, unknown> = {}
    for (const key of BACKUP_KEYS) {
      const value = localStorage.getItem(key)
      if (value !== null) {
        snapshot[key] = value
      }
    }
    const blob = new Blob([JSON.stringify(snapshot, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `nammananban-settings-${new Date().toISOString().slice(0, 10)}.json`
    a.click()
    URL.revokeObjectURL(url)
    setNoticeType('success')
    setNotice('Settings exported successfully.')
  }

  const handleImport = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) {
      return
    }
    const reader = new FileReader()
    reader.onload = (event) => {
      try {
        const raw = event.target?.result as string
        const snapshot = JSON.parse(raw) as Record<string, unknown>
        for (const key of BACKUP_KEYS) {
          if (Object.prototype.hasOwnProperty.call(snapshot, key) && typeof snapshot[key] === 'string') {
            localStorage.setItem(key, snapshot[key] as string)
          }
        }
        setNoticeType('success')
        setNotice('Settings restored successfully. Refresh the page to apply all changes.')
      } catch {
        setNoticeType('error')
        setNotice('Invalid backup file. Please use a file exported from this app.')
      }
    }
    reader.readAsText(file)
    e.target.value = ''
  }

  return (
    <div className="space-y-5 max-w-2xl">
      <SectionTitle
        title="Backup & Restore"
        subtitle="Export your settings as a JSON file or restore from a previous backup."
      />
      {notice ? <Notice text={notice} type={noticeType} /> : null}

      <div className="rounded-3xl border border-slate-200 bg-slate-50 p-6 space-y-4">
        <div>
          <p className="font-semibold text-slate-900 text-sm">Export settings</p>
          <p className="mt-1 text-xs text-slate-500">Downloads a JSON file with shop info, language, printer, and API settings.</p>
          <button
            type="button"
            onClick={handleExport}
            className="mt-4 rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700"
          >
            Export settings
          </button>
        </div>

        <hr className="border-slate-200" />

        <div>
          <p className="font-semibold text-slate-900 text-sm">Restore from backup</p>
          <p className="mt-1 text-xs text-slate-500">Select a previously exported JSON file to restore settings.</p>
          <label className="mt-4 inline-flex cursor-pointer items-center gap-2 rounded-2xl border border-slate-300 bg-white px-5 py-3 text-sm font-semibold text-slate-700 transition hover:border-indigo-300 hover:text-indigo-600">
            <input type="file" accept="application/json" className="sr-only" onChange={handleImport} />
            Choose backup file
          </label>
        </div>
      </div>
    </div>
  )
}

// ─── Connection Monitor tab ───────────────────────────────────────────────────

function SyncMonitorTab() {
  const { tenantId, deviceId, baseUrl, role, username } = useAuth()

  const rows: Array<{ label: string; value: string }> = [
    { label: 'Device ID', value: deviceId },
    { label: 'Tenant ID', value: tenantId ?? '—' },
    { label: 'Backend URL', value: baseUrl || '(not set)' },
    { label: 'Signed-in user', value: username ?? '—' },
    { label: 'Role', value: role ?? '—' },
  ]

  return (
    <div className="space-y-5 max-w-2xl">
      <SectionTitle
        title="Connection Monitor"
        subtitle="Current device identity and connection details."
      />
      <dl className="divide-y divide-slate-100 rounded-3xl bg-white ring-1 ring-slate-200 overflow-hidden">
        {rows.map(({ label, value }) => (
          <div key={label} className="flex items-start gap-4 px-6 py-4">
            <dt className="w-40 shrink-0 text-sm text-slate-500">{label}</dt>
            <dd className="break-all text-sm font-medium text-slate-900">{value}</dd>
          </div>
        ))}
      </dl>
      <p className="text-xs text-slate-400">
        The app now uses direct online writes. This panel reflects the current session context.
      </p>
    </div>
  )
}

// ─── Backend API tab ──────────────────────────────────────────────────────────

function BackendApiTab() {
  const { baseUrl, setBaseUrl } = useAuth()
  const [url, setUrl] = useState(baseUrl)
  const [testing, setTesting] = useState(false)
  const [notice, setNotice] = useState('')
  const [noticeType, setNoticeType] = useState<'success' | 'error'>('success')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setBaseUrl(url.trim())
    setNoticeType('success')
    setNotice('Backend API URL saved.')
  }

  const handleTest = async () => {
    setTesting(true)
    setNotice('')
    try {
      await apiClient.get('/users/me', { baseURL: url.trim().replace(/\/+$/, '') })
      setNoticeType('success')
      setNotice('Connection successful — API is reachable.')
    } catch (err) {
      setNoticeType('error')
      setNotice(`Connection failed: ${extractApiError(err)}`)
    } finally {
      setTesting(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5 max-w-2xl">
      <SectionTitle
        title="Backend API Settings"
        subtitle="Configure the base URL for the NammaNanban Java backend."
      />
      {notice ? <Notice text={notice} type={noticeType} /> : null}

      <label>
        <FieldLabel>Backend base URL</FieldLabel>
        <TextInput
          value={url}
          onChange={setUrl}
          placeholder="http://192.168.1.10:8080/webapp"
        />
        <p className="mt-2 text-xs text-slate-400">
          Enter the full URL including the context path, without a trailing slash. Example: <code className="rounded bg-slate-100 px-1">http://server:8080/webapp</code>
        </p>
      </label>

      <div className="flex flex-wrap gap-3">
        <SaveButton saving={false} />
        <button
          type="button"
          disabled={testing || !url.trim()}
          onClick={handleTest}
          className="rounded-2xl border border-slate-200 px-6 py-3 text-sm font-semibold text-slate-700 transition hover:border-indigo-300 hover:text-indigo-600 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {testing ? 'Testing…' : 'Test connection'}
        </button>
      </div>
    </form>
  )
}

// ─── Security tab ─────────────────────────────────────────────────────────────

function SecurityTab() {
  const { username, logout } = useAuth()
  const [pin, setPin] = useState('')
  const [confirmPin, setConfirmPin] = useState('')
  const [saving, setSaving] = useState(false)
  const [notice, setNotice] = useState('')
  const [noticeType, setNoticeType] = useState<'success' | 'error'>('success')

  const handlePinChange = async (e: React.FormEvent) => {
    e.preventDefault()
    if (pin !== confirmPin) {
      setNoticeType('error')
      setNotice('PINs do not match.')
      return
    }
    if (pin.length !== 4) {
      setNoticeType('error')
      setNotice('PIN must be exactly 4 digits.')
      return
    }
    setSaving(true)
    setNotice('')
    try {
      await updateUserPin(username ?? '', { pin })
      setNoticeType('success')
      setNotice('PIN updated successfully.')
      setPin('')
      setConfirmPin('')
    } catch (err) {
      setNoticeType('error')
      setNotice(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  const handleLogout = () => {
    if (window.confirm('Are you sure you want to sign out?')) {
      logout()
    }
  }

  return (
    <div className="space-y-8 max-w-2xl">
      <SectionTitle title="Security" subtitle="Update your login PIN and manage your session." />

      <section className="rounded-3xl bg-white p-6 ring-1 ring-slate-200 space-y-4">
        <div>
          <h3 className="font-semibold text-slate-900">Change your PIN</h3>
          <p className="mt-1 text-sm text-slate-500">Your 4-digit PIN is used to sign in to the POS terminal.</p>
        </div>
        {notice ? <Notice text={notice} type={noticeType} /> : null}
        <form onSubmit={handlePinChange} className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <label>
              <FieldLabel>New PIN</FieldLabel>
              <input
                required
                type="password"
                inputMode="numeric"
                pattern="\d{4}"
                maxLength={4}
                value={pin}
                onChange={(e) => setPin(e.target.value.replace(/\D/g, '').slice(0, 4))}
                placeholder="••••"
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
              />
            </label>
            <label>
              <FieldLabel>Confirm new PIN</FieldLabel>
              <input
                required
                type="password"
                inputMode="numeric"
                pattern="\d{4}"
                maxLength={4}
                value={confirmPin}
                onChange={(e) => setConfirmPin(e.target.value.replace(/\D/g, '').slice(0, 4))}
                placeholder="••••"
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
              />
            </label>
          </div>
          <div className="flex justify-end">
            <button
              type="submit"
              disabled={saving || pin.length !== 4 || confirmPin.length !== 4}
              className="rounded-2xl bg-indigo-600 px-6 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300"
            >
              {saving ? 'Updating…' : 'Update PIN'}
            </button>
          </div>
        </form>
      </section>

      <section className="rounded-3xl bg-white p-6 ring-1 ring-rose-200 space-y-4">
        <div>
          <h3 className="font-semibold text-slate-900">Sign out</h3>
          <p className="mt-1 text-sm text-slate-500">This will clear your session from this browser. You will need to sign in again.</p>
        </div>
        <button
          type="button"
          onClick={handleLogout}
          className="rounded-2xl border border-rose-300 bg-rose-50 px-5 py-3 text-sm font-semibold text-rose-700 transition hover:bg-rose-100"
        >
          Sign out
        </button>
      </section>
    </div>
  )
}

// ─── License Mode tab ─────────────────────────────────────────────────────────

function LicenseTab() {
  const { licenseMode, offlineBaseUrl, offlineSessionDaysLeft: daysLeft, setLicenseMode, setOfflineBaseUrl } = useAuth()
  const [pendingMode, setPendingMode] = useState<LicenseMode>(licenseMode)
  const [pendingOfflineUrl, setPendingOfflineUrl] = useState(offlineBaseUrl)
  const [notice, setNotice] = useState('')

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault()
    setLicenseMode(pendingMode)
    setOfflineBaseUrl(pendingOfflineUrl)
    setNotice('License settings saved.')
    pushAuditEvent({
      module: 'settings',
      action: 'update',
      detail: `License mode changed to ${pendingMode}`,
      actor: localStorage.getItem(STORAGE_KEYS.username) ?? 'unknown',
    })
  }

  const isOffline = pendingMode === 'offline'

  return (
    <form onSubmit={handleSave} className="space-y-6 max-w-2xl">
      <SectionTitle
        title="License Mode"
        subtitle="Choose whether the POS operates in online (cloud) or offline (local database) mode."
      />
      {notice ? <Notice text={notice} type="success" /> : null}

      <div>
        <FieldLabel>Operating mode</FieldLabel>
        <div className="flex flex-wrap gap-3">
          {(['online', 'offline'] as const).map((mode) => (
            <button
              key={mode}
              type="button"
              onClick={() => setPendingMode(mode)}
              className={`rounded-2xl px-5 py-3 text-sm font-semibold transition ${pendingMode === mode ? 'bg-indigo-600 text-white' : 'border border-slate-200 text-slate-700 hover:border-indigo-300 hover:text-indigo-600'}`}
            >
              {mode === 'online' ? '🌐 Online' : '💾 Offline'}
            </button>
          ))}
        </div>
        <p className="mt-2 text-xs text-slate-400">
          {isOffline
            ? `Offline mode: data loads from your local backend (PostgreSQL). Login requires internet; session is valid for ${OFFLINE_SESSION_DAYS} days without reconnecting.`
            : 'Online mode: all data is loaded from the remote cloud backend.'}
        </p>
      </div>

      {isOffline && (
        <div className="space-y-4">
          <label>
            <FieldLabel>Local backend URL</FieldLabel>
            <TextInput
              value={pendingOfflineUrl}
              onChange={setPendingOfflineUrl}
              placeholder="http://localhost:8080"
            />
            <p className="mt-1 text-xs text-slate-400">
              URL of the local backend server that connects to your local PostgreSQL database.
            </p>
          </label>

          {licenseMode === 'offline' && (
            <div className={`rounded-2xl border px-4 py-3 text-sm ${daysLeft > 0 ? 'border-amber-200 bg-amber-50 text-amber-800' : 'border-rose-200 bg-rose-50 text-rose-700'}`}>
              {daysLeft > 0
                ? `⏱ Offline session: ${Math.ceil(daysLeft)} day${Math.ceil(daysLeft) !== 1 ? 's' : ''} remaining before re-login is required.`
                : '⚠ Offline session expired. Please log in again (internet required).'}
            </div>
          )}
        </div>
      )}

      <div className="flex justify-end">
        <SaveButton saving={false} />
      </div>
    </form>
  )
}

// ─── Main Settings page ───────────────────────────────────────────────────────

function SettingsPage() {
  const { isAdmin } = useAuth()
  const visibleTabs = TABS.filter((t) => !t.adminOnly || isAdmin)
  const [activeTab, setActiveTab] = useState<TabId>(visibleTabs[0]?.id ?? 'security')

  return (
    <div className="space-y-6">
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Settings</p>
        <h1 className="mt-2 text-3xl font-bold text-slate-900">App configuration</h1>
        <p className="mt-2 text-sm text-slate-500">Manage shop info, display preferences, printer templates, connectivity, and security.</p>
      </div>

      <div className="flex gap-6 flex-col lg:flex-row">
        {/* Sidebar nav */}
        <nav className="flex lg:flex-col gap-1 flex-wrap lg:w-52 shrink-0">
          {visibleTabs.map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id)}
              className={`rounded-xl px-4 py-2.5 text-sm font-medium text-left transition ${activeTab === tab.id ? 'bg-indigo-600 text-white' : 'text-slate-600 hover:bg-slate-200 hover:text-slate-900'}`}
            >
              {tab.label}
            </button>
          ))}
        </nav>

        {/* Content panel */}
        <div className="flex-1 rounded-3xl bg-white p-6 shadow-sm ring-1 ring-slate-200 min-h-[400px]">
          {activeTab === 'shop' && isAdmin && <ShopInfoTab />}
          {activeTab === 'language' && <LanguageTab />}
          {activeTab === 'printer' && isAdmin && <PrinterTab />}
          {activeTab === 'business' && isAdmin && <BusinessGstTab />}
          {activeTab === 'backup' && isAdmin && <BackupTab />}
          {activeTab === 'sync' && <SyncMonitorTab />}
          {activeTab === 'api' && isAdmin && <BackendApiTab />}
          {activeTab === 'license' && isAdmin && <LicenseTab />}
          {activeTab === 'security' && <SecurityTab />}
        </div>
      </div>
    </div>
  )
}

export default SettingsPage
