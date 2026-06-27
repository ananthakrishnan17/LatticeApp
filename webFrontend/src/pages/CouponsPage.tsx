import { generateUUID } from '../utils/uuid'
import { useState } from 'react'
import { pushAuditEvent } from '../utils/auditLog'
import { STORAGE_KEYS } from '../api/client'
import type { CouponConfig, CouponDiscountType } from '../types'
import { loadCoupons, loadPaymentMethods, saveCoupons, savePaymentMethods } from '../utils/coupons'

interface CouponFormState {
  code: string
  discountType: CouponDiscountType
  discountValue: string
  minOrderAmount: string
}

const defaultCouponForm: CouponFormState = {
  code: '',
  discountType: 'flat',
  discountValue: '',
  minOrderAmount: '0',
}

type TabId = 'coupons' | 'payment-methods'

function CouponsPage() {
  const actor = localStorage.getItem(STORAGE_KEYS.username) ?? 'unknown'
  const [tab, setTab] = useState<TabId>('coupons')

  // ─── Coupons state ─────────────────────────────────────────────────────────
  const [coupons, setCoupons] = useState<CouponConfig[]>(() => loadCoupons())
  const [form, setForm] = useState<CouponFormState>(defaultCouponForm)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [couponError, setCouponError] = useState('')
  const [couponNotice, setCouponNotice] = useState('')

  // ─── Payment methods state ──────────────────────────────────────────────────
  const [paymentMethods, setPaymentMethods] = useState<string[]>(() => loadPaymentMethods())
  const [newMethod, setNewMethod] = useState('')
  const [pmError, setPmError] = useState('')
  const [pmNotice, setPmNotice] = useState('')

  // ─── Coupon handlers ────────────────────────────────────────────────────────

  const openCreate = () => {
    setEditingId(null)
    setForm(defaultCouponForm)
    setCouponError('')
    setIsModalOpen(true)
  }

  const openEdit = (coupon: CouponConfig) => {
    setEditingId(coupon.id)
    setForm({
      code: coupon.code,
      discountType: coupon.discountType,
      discountValue: String(coupon.discountValue),
      minOrderAmount: String(coupon.minOrderAmount),
    })
    setCouponError('')
    setIsModalOpen(true)
  }

  const handleSaveCoupon = (event: React.FormEvent) => {
    event.preventDefault()
    const code = form.code.trim().toUpperCase()
    if (!code) {
      setCouponError('Code is required.')
      return
    }

    const existing = coupons.find((c) => c.code === code && c.id !== editingId)
    if (existing) {
      setCouponError('Coupon code already exists.')
      return
    }

    const coupon: CouponConfig = {
      id: editingId ?? generateUUID(),
      code,
      discountType: form.discountType,
      discountValue: parseFloat(form.discountValue) || 0,
      minOrderAmount: parseFloat(form.minOrderAmount) || 0,
      active: true,
    }

    const next = editingId
      ? coupons.map((c) => (c.id === editingId ? coupon : c))
      : [...coupons, coupon]

    saveCoupons(next)
    setCoupons(next)
    pushAuditEvent({ module: 'coupons', action: editingId ? 'update' : 'create', detail: `${editingId ? 'Updated' : 'Created'} coupon ${code}`, actor })
    setCouponNotice(`Coupon ${editingId ? 'updated' : 'created'}.`)
    setIsModalOpen(false)
  }

  const handleToggleCoupon = (id: string) => {
    const next = coupons.map((c) => (c.id === id ? { ...c, active: !c.active } : c))
    saveCoupons(next)
    setCoupons(next)
    pushAuditEvent({ module: 'coupons', action: 'toggle', detail: `Toggled coupon ${id}`, actor })
  }

  const handleDeleteCoupon = (id: string) => {
    const coupon = coupons.find((c) => c.id === id)
    if (!window.confirm(`Delete coupon "${coupon?.code ?? id}"?`)) return
    const next = coupons.filter((c) => c.id !== id)
    saveCoupons(next)
    setCoupons(next)
    pushAuditEvent({ module: 'coupons', action: 'delete', detail: `Deleted coupon ${coupon?.code ?? id}`, actor })
    setCouponNotice('Coupon deleted.')
  }

  // ─── Payment method handlers ────────────────────────────────────────────────

  const handleAddPaymentMethod = (event: React.FormEvent) => {
    event.preventDefault()
    const name = newMethod.trim().toLowerCase()
    if (!name) return
    if (paymentMethods.includes(name)) {
      setPmError('Payment method already exists.')
      return
    }
    const next = [...paymentMethods, name]
    savePaymentMethods(next)
    setPaymentMethods(next)
    setNewMethod('')
    setPmNotice('Payment method added.')
    pushAuditEvent({ module: 'settings', action: 'create', detail: `Added payment method ${name}`, actor })
  }

  const handleDeletePaymentMethod = (method: string) => {
    if (!window.confirm(`Remove payment method "${method}"?`)) return
    const next = paymentMethods.filter((m) => m !== method)
    savePaymentMethods(next)
    setPaymentMethods(next)
    setPmNotice('Payment method removed.')
    pushAuditEvent({ module: 'settings', action: 'delete', detail: `Removed payment method ${method}`, actor })
  }

  const tabs: Array<{ id: TabId; label: string }> = [
    { id: 'coupons', label: 'Coupons' },
    { id: 'payment-methods', label: 'Payment Methods' },
  ]

  return (
    <div className="space-y-6">
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Promotions</p>
        <h1 className="mt-2 text-3xl font-bold text-slate-900">Coupons & Payment Methods</h1>
        <p className="mt-2 text-sm text-slate-500">Configure discount coupons and available payment modes for billing.</p>
      </div>

      <div className="flex gap-1 border-b border-slate-200">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setTab(t.id)}
            className={`rounded-t-xl px-5 py-3 text-sm font-semibold transition ${tab === t.id ? 'border-b-2 border-indigo-600 text-indigo-600' : 'text-slate-500 hover:text-slate-700'}`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* ─── Coupons tab ─────────────────────────────────────────────────────── */}
      {tab === 'coupons' && (
        <div className="space-y-5">
          <div className="flex justify-between items-center">
            <p className="text-sm text-slate-500">{coupons.length} coupon(s) configured</p>
            <button
              type="button"
              onClick={openCreate}
              className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700"
            >
              Add Coupon
            </button>
          </div>

          {couponError ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{couponError}</div> : null}
          {couponNotice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{couponNotice}</div> : null}

          <div className="overflow-hidden rounded-2xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-slate-50">
                <tr>
                  {['Code', 'Type', 'Value', 'Min Order', 'Status', 'Actions'].map((h) => (
                    <th key={h} className="px-4 py-3 text-left font-semibold text-slate-600">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {coupons.length ? coupons.map((coupon) => (
                  <tr key={coupon.id} className="border-t border-slate-100">
                    <td className="px-4 py-3 font-mono font-bold text-slate-800">{coupon.code}</td>
                    <td className="px-4 py-3 text-slate-600 capitalize">{coupon.discountType}</td>
                    <td className="px-4 py-3 text-slate-600">
                      {coupon.discountType === 'flat' ? `₹${coupon.discountValue}` : `${coupon.discountValue}%`}
                    </td>
                    <td className="px-4 py-3 text-slate-600">₹{coupon.minOrderAmount}</td>
                    <td className="px-4 py-3">
                      <button
                        type="button"
                        onClick={() => handleToggleCoupon(coupon.id)}
                        className={`rounded-full px-3 py-1 text-xs font-semibold ${coupon.active ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'}`}
                      >
                        {coupon.active ? 'Active' : 'Inactive'}
                      </button>
                    </td>
                    <td className="px-4 py-3">
                      <span className="flex gap-3">
                        <button type="button" onClick={() => openEdit(coupon)} className="text-xs font-medium text-indigo-600 hover:text-indigo-800">Edit</button>
                        <button type="button" onClick={() => handleDeleteCoupon(coupon.id)} className="text-xs font-medium text-rose-600 hover:text-rose-800">Delete</button>
                      </span>
                    </td>
                  </tr>
                )) : (
                  <tr>
                    <td colSpan={6} className="px-4 py-6 text-center text-slate-400">No coupons configured.</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ─── Payment methods tab ─────────────────────────────────────────────── */}
      {tab === 'payment-methods' && (
        <div className="space-y-5">
          <form onSubmit={handleAddPaymentMethod} className="flex flex-wrap gap-3 items-end">
            <div className="flex-1 min-w-[200px]">
              <label className="mb-2 block text-sm font-medium text-slate-700">New payment method name</label>
              <input
                required
                value={newMethod}
                onChange={(e) => setNewMethod(e.target.value)}
                placeholder="e.g. netbanking"
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
              />
            </div>
            <button
              type="submit"
              className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700"
            >
              Add
            </button>
          </form>

          {pmError ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{pmError}</div> : null}
          {pmNotice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{pmNotice}</div> : null}

          <div className="flex flex-wrap gap-3">
            {paymentMethods.map((method) => (
              <div key={method} className="flex items-center gap-2 rounded-2xl border border-slate-200 bg-white px-4 py-2.5">
                <span className="text-sm font-medium capitalize text-slate-700">{method}</span>
                <button
                  type="button"
                  onClick={() => handleDeletePaymentMethod(method)}
                  className="ml-1 text-slate-400 hover:text-rose-500"
                  aria-label={`Remove ${method}`}
                >
                  ✕
                </button>
              </div>
            ))}
          </div>
          <p className="text-xs text-slate-400">These payment methods will appear in the POS billing screen.</p>
        </div>
      )}

      {/* Coupon modal */}
      {isModalOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4">
          <div className="w-full max-w-md rounded-3xl bg-white p-6 shadow-2xl">
            <div className="flex items-start justify-between gap-4 mb-5">
              <h2 className="text-xl font-semibold text-slate-900">{editingId ? 'Edit Coupon' : 'Add Coupon'}</h2>
              <button type="button" onClick={() => setIsModalOpen(false)} className="rounded-full p-2 text-slate-400 hover:bg-slate-100">✕</button>
            </div>
            <form onSubmit={handleSaveCoupon} className="space-y-4">
              <label>
                <span className="mb-1 block text-sm font-medium text-slate-700">Coupon code *</span>
                <input
                  required
                  value={form.code}
                  onChange={(e) => setForm((f) => ({ ...f, code: e.target.value.toUpperCase() }))}
                  placeholder="e.g. SAVE10"
                  className="w-full rounded-2xl border border-slate-200 px-4 py-2.5 text-sm font-mono uppercase outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                />
              </label>

              <div>
                <span className="mb-2 block text-sm font-medium text-slate-700">Discount type</span>
                <div className="flex gap-3">
                  {(['flat', 'percent'] as CouponDiscountType[]).map((type) => (
                    <button
                      key={type}
                      type="button"
                      onClick={() => setForm((f) => ({ ...f, discountType: type }))}
                      className={`rounded-2xl px-4 py-2.5 text-sm font-semibold transition ${form.discountType === type ? 'bg-indigo-600 text-white' : 'border border-slate-200 text-slate-700 hover:border-indigo-300'}`}
                    >
                      {type === 'flat' ? 'Flat (₹)' : 'Percent (%)'}
                    </button>
                  ))}
                </div>
              </div>

              <label>
                <span className="mb-1 block text-sm font-medium text-slate-700">
                  Discount value {form.discountType === 'flat' ? '(₹)' : '(%)'}
                </span>
                <input
                  required
                  type="number"
                  min="0"
                  value={form.discountValue}
                  onChange={(e) => setForm((f) => ({ ...f, discountValue: e.target.value }))}
                  className="w-full rounded-2xl border border-slate-200 px-4 py-2.5 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                />
              </label>

              <label>
                <span className="mb-1 block text-sm font-medium text-slate-700">Minimum order amount (₹)</span>
                <input
                  type="number"
                  min="0"
                  value={form.minOrderAmount}
                  onChange={(e) => setForm((f) => ({ ...f, minOrderAmount: e.target.value }))}
                  className="w-full rounded-2xl border border-slate-200 px-4 py-2.5 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                />
              </label>

              {couponError ? <div className="text-sm text-rose-600">{couponError}</div> : null}

              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={() => setIsModalOpen(false)} className="rounded-2xl border border-slate-200 px-5 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50">
                  Cancel
                </button>
                <button type="submit" className="rounded-2xl bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700">
                  {editingId ? 'Save changes' : 'Add Coupon'}
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  )
}

export default CouponsPage
