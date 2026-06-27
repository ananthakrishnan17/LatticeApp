import { generateUUID } from '../utils/uuid'
import { useEffect, useState } from 'react'
import {
  listCategories, upsertCategory,
  listBrands, upsertBrand,
  listCustomers, upsertCustomer,
  listSuppliers, upsertSupplier,
} from '../api/masters'
import { extractApiError } from '../api/client'
import { STORAGE_KEYS } from '../api/client'
import Spinner from '../components/Spinner'
import { pushAuditEvent } from '../utils/auditLog'
import type {
  BrandRecord,
  CategoryRecord,
  CustomerRecord,
  SupplierRecord,
  UnitRecord,
} from '../types'

// ─── Unit helpers (localStorage only) ────────────────────────────────────────

const UNITS_KEY = 'nn_units'
const TAX_SLABS_KEY = 'nn_tax_slabs'

function loadUnits(): UnitRecord[] {
  try {
    const raw = localStorage.getItem(UNITS_KEY)
    return raw ? (JSON.parse(raw) as UnitRecord[]) : defaultUnits()
  } catch {
    return defaultUnits()
  }
}

function defaultUnits(): UnitRecord[] {
  return [
    { clientRecordId: '1', name: 'piece' },
    { clientRecordId: '2', name: 'kg' },
    { clientRecordId: '3', name: 'g' },
    { clientRecordId: '4', name: 'litre' },
    { clientRecordId: '5', name: 'ml' },
    { clientRecordId: '6', name: 'box' },
    { clientRecordId: '7', name: 'pack' },
  ]
}

function saveUnits(units: UnitRecord[]) {
  localStorage.setItem(UNITS_KEY, JSON.stringify(units))
}

interface TaxSlabRecord {
  clientRecordId: string
  name: string
}

function loadTaxSlabs(): TaxSlabRecord[] {
  try {
    const raw = localStorage.getItem(TAX_SLABS_KEY)
    return raw
      ? (JSON.parse(raw) as TaxSlabRecord[])
      : [
          { clientRecordId: generateUUID(), name: 'GST 0%' },
          { clientRecordId: generateUUID(), name: 'GST 5%' },
          { clientRecordId: generateUUID(), name: 'GST 12%' },
          { clientRecordId: generateUUID(), name: 'GST 18%' },
        ]
  } catch {
    return []
  }
}

function saveTaxSlabs(slabs: TaxSlabRecord[]) {
  localStorage.setItem(TAX_SLABS_KEY, JSON.stringify(slabs))
}

// ─── Generic confirmation dialog ─────────────────────────────────────────────

type TabId = 'categories' | 'brands' | 'units' | 'taxSlabs' | 'customers' | 'suppliers'

interface NameRecord { serverId?: string; clientRecordId: string; name: string }

function NameMasterTab<T extends NameRecord>({
  title,
  description,
  items,
  loading,
  error,
  notice,
  onAdd,
  onDelete,
}: {
  title: string
  description: string
  items: T[]
  loading: boolean
  error: string
  notice: string
  onAdd: (name: string) => Promise<void>
  onDelete: (item: T) => Promise<void>
}) {
  const [newName, setNewName] = useState('')
  const [saving, setSaving] = useState(false)
  const [localError, setLocalError] = useState('')

  const handleAdd = async (event: React.FormEvent) => {
    event.preventDefault()
    if (!newName.trim()) return
    setSaving(true)
    setLocalError('')
    try {
      await onAdd(newName.trim())
      setNewName('')
    } catch (err) {
      setLocalError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (item: T) => {
    if (!window.confirm(`Delete "${item.name}"?`)) return
    setSaving(true)
    setLocalError('')
    try {
      await onDelete(item)
    } catch (err) {
      setLocalError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }


  if (loading) return <Spinner label={`Loading ${title.toLowerCase()}...`} />

  return (
    <div className="space-y-5">
      <form onSubmit={(e) => void handleAdd(e)} className="flex flex-wrap gap-3 items-end">
        <div className="flex-1 min-w-[200px]">
          <label className="mb-2 block text-sm font-medium text-slate-700">New {title.replace(/s$/, '').toLowerCase()} name</label>
          <input
            required
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            placeholder={`e.g. ${description}`}
            className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
          />
        </div>
        <button
          type="submit"
          disabled={saving}
          className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300"
        >
          {saving ? 'Saving...' : `Add ${title.replace(/s$/, '')}`}
        </button>
      </form>

      {(localError || error) ? (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{localError || error}</div>
      ) : null}
      {notice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      <div className="overflow-hidden rounded-2xl border border-slate-200">
        <table className="w-full text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th className="px-4 py-3 text-left font-semibold text-slate-600">Name</th>
              <th className="px-4 py-3 text-right font-semibold text-slate-600">Actions</th>
            </tr>
          </thead>
          <tbody>
            {items.length ? items.map((item) => (
              <tr key={item.clientRecordId} className="border-t border-slate-100">
                <td className="px-4 py-3 text-slate-800">{item.name}</td>
                <td className="px-4 py-3 text-right">
                  <button
                    type="button"
                    onClick={() => void handleDelete(item)}
                    className="text-xs font-medium text-rose-600 hover:text-rose-800"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            )) : (
              <tr>
                <td colSpan={2} className="px-4 py-6 text-center text-slate-400">No {title.toLowerCase()} found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

// ─── Customer / Supplier table ────────────────────────────────────────────────

interface CustomerFormState {
  name: string
  phone: string
  address: string
  gstNumber: string
  creditLimit: string
  outstandingBalance: string
}

const defaultCustomerForm: CustomerFormState = {
  name: '',
  phone: '',
  address: '',
  gstNumber: '',
  creditLimit: '0',
  outstandingBalance: '0',
}

function CustomersTab({
  customers,
  loading,
  error,
  notice,
  onSave,
  onDelete,
}: {
  customers: CustomerRecord[]
  loading: boolean
  error: string
  notice: string
  onSave: (form: CustomerFormState, existing?: CustomerRecord) => Promise<void>
  onDelete: (item: CustomerRecord) => Promise<void>
}) {
  const [form, setForm] = useState<CustomerFormState>(defaultCustomerForm)
  const [editingItem, setEditingItem] = useState<CustomerRecord | null>(null)
  const [isOpen, setIsOpen] = useState(false)
  const [saving, setSaving] = useState(false)
  const [localError, setLocalError] = useState('')
  const [search, setSearch] = useState('')

  const filtered = customers.filter((c) =>
    !search.trim() || c.name.toLowerCase().includes(search.toLowerCase()) || (c.phone ?? '').includes(search)
  )

  const openCreate = () => {
    setEditingItem(null)
    setForm(defaultCustomerForm)
    setLocalError('')
    setIsOpen(true)
  }

  const openEdit = (item: CustomerRecord) => {
    setEditingItem(item)
    setForm({
      name: item.name,
      phone: item.phone ?? '',
      address: item.address ?? '',
      gstNumber: item.gstNumber ?? '',
      creditLimit: String(item.creditLimit ?? 0),
      outstandingBalance: String(item.outstandingBalance ?? 0),
    })
    setLocalError('')
    setIsOpen(true)
  }

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault()
    setSaving(true)
    setLocalError('')
    try {
      await onSave(form, editingItem ?? undefined)
      setIsOpen(false)
    } catch (err) {
      setLocalError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (item: CustomerRecord) => {
    if (!window.confirm(`Delete customer "${item.name}"?`)) return
    setSaving(true)
    try {
      await onDelete(item)
    } catch (err) {
      setLocalError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <Spinner label="Loading customers..." />

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap gap-3 items-center justify-between">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search customers..."
          className="rounded-2xl border border-slate-200 px-4 py-2 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
        />
        <button
          type="button"
          onClick={openCreate}
          className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700"
        >
          Add Customer
        </button>
      </div>

      {(localError || error) ? (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{localError || error}</div>
      ) : null}
      {notice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      <div className="overflow-x-auto rounded-2xl border border-slate-200">
        <table className="w-full text-sm">
          <thead className="bg-slate-50">
            <tr>
              {['Name', 'Phone', 'GST Number', 'Credit Limit', 'Outstanding', 'Actions'].map((h) => (
                <th key={h} className="px-4 py-3 text-left font-semibold text-slate-600">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.length ? filtered.map((c) => (
              <tr key={c.clientRecordId} className="border-t border-slate-100">
                <td className="px-4 py-3 font-medium text-slate-800">{c.name}</td>
                <td className="px-4 py-3 text-slate-600">{c.phone ?? '—'}</td>
                <td className="px-4 py-3 text-slate-600">{c.gstNumber ?? '—'}</td>
                <td className="px-4 py-3 text-slate-600">₹{(c.creditLimit ?? 0).toLocaleString('en-IN')}</td>
                <td className="px-4 py-3 text-slate-600">₹{(c.outstandingBalance ?? 0).toLocaleString('en-IN')}</td>
                <td className="px-4 py-3">
                  <span className="flex gap-3">
                    <button type="button" onClick={() => openEdit(c)} className="text-xs font-medium text-indigo-600 hover:text-indigo-800">Edit</button>
                    <button type="button" onClick={() => void handleDelete(c)} className="text-xs font-medium text-rose-600 hover:text-rose-800">Delete</button>
                  </span>
                </td>
              </tr>
            )) : (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-slate-400">No customers found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {isOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4">
          <div className="w-full max-w-xl rounded-3xl bg-white p-6 shadow-2xl">
            <div className="flex items-start justify-between gap-4 mb-5">
              <h2 className="text-xl font-semibold text-slate-900">{editingItem ? 'Edit Customer' : 'Add Customer'}</h2>
              <button type="button" onClick={() => setIsOpen(false)} className="rounded-full p-2 text-slate-400 hover:bg-slate-100">✕</button>
            </div>
            <form onSubmit={(e) => void handleSubmit(e)} className="space-y-4">
              {[
                { key: 'name' as const, label: 'Name *', required: true },
                { key: 'phone' as const, label: 'Phone' },
                { key: 'address' as const, label: 'Address' },
                { key: 'gstNumber' as const, label: 'GST Number' },
                { key: 'creditLimit' as const, label: 'Credit Limit (₹)', type: 'number' },
                { key: 'outstandingBalance' as const, label: 'Outstanding Balance (₹)', type: 'number' },
              ].map((field) => (
                <label key={field.key}>
                  <span className="mb-1 block text-sm font-medium text-slate-700">{field.label}</span>
                  <input
                    required={field.required}
                    type={field.type ?? 'text'}
                    value={form[field.key]}
                    onChange={(e) => setForm((f) => ({ ...f, [field.key]: e.target.value }))}
                    className="w-full rounded-2xl border border-slate-200 px-4 py-2.5 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                  />
                </label>
              ))}
              {localError ? <div className="text-sm text-rose-600">{localError}</div> : null}
              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={() => setIsOpen(false)} className="rounded-2xl border border-slate-200 px-5 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50">Cancel</button>
                <button type="submit" disabled={saving} className="rounded-2xl bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:bg-slate-300">
                  {saving ? 'Saving...' : editingItem ? 'Save changes' : 'Add Customer'}
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  )
}

function SuppliersTab({
  suppliers,
  loading,
  error,
  notice,
  onSave,
  onDelete,
}: {
  suppliers: SupplierRecord[]
  loading: boolean
  error: string
  notice: string
  onSave: (form: SupplierFormState, existing?: SupplierRecord) => Promise<void>
  onDelete: (item: SupplierRecord) => Promise<void>
}) {
  const [form, setForm] = useState<SupplierFormState>(defaultSupplierForm)
  const [editingItem, setEditingItem] = useState<SupplierRecord | null>(null)
  const [isOpen, setIsOpen] = useState(false)
  const [saving, setSaving] = useState(false)
  const [localError, setLocalError] = useState('')
  const [search, setSearch] = useState('')

  const filtered = suppliers.filter((s) =>
    !search.trim() || s.name.toLowerCase().includes(search.toLowerCase()) || (s.phone ?? '').includes(search)
  )

  const openCreate = () => {
    setEditingItem(null)
    setForm(defaultSupplierForm)
    setLocalError('')
    setIsOpen(true)
  }

  const openEdit = (item: SupplierRecord) => {
    setEditingItem(item)
    setForm({
      name: item.name,
      phone: item.phone ?? '',
      address: item.address ?? '',
      gstNumber: item.gstNumber ?? '',
      outstandingBalance: String(item.outstandingBalance ?? 0),
    })
    setLocalError('')
    setIsOpen(true)
  }

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault()
    setSaving(true)
    setLocalError('')
    try {
      await onSave(form, editingItem ?? undefined)
      setIsOpen(false)
    } catch (err) {
      setLocalError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (item: SupplierRecord) => {
    if (!window.confirm(`Delete supplier "${item.name}"?`)) return
    setSaving(true)
    try {
      await onDelete(item)
    } catch (err) {
      setLocalError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <Spinner label="Loading suppliers..." />

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap gap-3 items-center justify-between">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search suppliers..."
          className="rounded-2xl border border-slate-200 px-4 py-2 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
        />
        <button
          type="button"
          onClick={openCreate}
          className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700"
        >
          Add Supplier
        </button>
      </div>

      {(localError || error) ? (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{localError || error}</div>
      ) : null}
      {notice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      <div className="overflow-x-auto rounded-2xl border border-slate-200">
        <table className="w-full text-sm">
          <thead className="bg-slate-50">
            <tr>
              {['Name', 'Phone', 'GST Number', 'Outstanding', 'Actions'].map((h) => (
                <th key={h} className="px-4 py-3 text-left font-semibold text-slate-600">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.length ? filtered.map((s) => (
              <tr key={s.clientRecordId} className="border-t border-slate-100">
                <td className="px-4 py-3 font-medium text-slate-800">{s.name}</td>
                <td className="px-4 py-3 text-slate-600">{s.phone ?? '—'}</td>
                <td className="px-4 py-3 text-slate-600">{s.gstNumber ?? '—'}</td>
                <td className="px-4 py-3 text-slate-600">₹{(s.outstandingBalance ?? 0).toLocaleString('en-IN')}</td>
                <td className="px-4 py-3">
                  <span className="flex gap-3">
                    <button type="button" onClick={() => openEdit(s)} className="text-xs font-medium text-indigo-600 hover:text-indigo-800">Edit</button>
                    <button type="button" onClick={() => void handleDelete(s)} className="text-xs font-medium text-rose-600 hover:text-rose-800">Delete</button>
                  </span>
                </td>
              </tr>
            )) : (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-slate-400">No suppliers found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {isOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4">
          <div className="w-full max-w-xl rounded-3xl bg-white p-6 shadow-2xl">
            <div className="flex items-start justify-between gap-4 mb-5">
              <h2 className="text-xl font-semibold text-slate-900">{editingItem ? 'Edit Supplier' : 'Add Supplier'}</h2>
              <button type="button" onClick={() => setIsOpen(false)} className="rounded-full p-2 text-slate-400 hover:bg-slate-100">✕</button>
            </div>
            <form onSubmit={(e) => void handleSubmit(e)} className="space-y-4">
              {[
                { key: 'name' as const, label: 'Name *', required: true },
                { key: 'phone' as const, label: 'Phone' },
                { key: 'address' as const, label: 'Address' },
                { key: 'gstNumber' as const, label: 'GST Number' },
                { key: 'outstandingBalance' as const, label: 'Outstanding Balance (₹)', type: 'number' },
              ].map((field) => (
                <label key={field.key}>
                  <span className="mb-1 block text-sm font-medium text-slate-700">{field.label}</span>
                  <input
                    required={field.required}
                    type={field.type ?? 'text'}
                    value={form[field.key]}
                    onChange={(e) => setForm((f) => ({ ...f, [field.key]: e.target.value }))}
                    className="w-full rounded-2xl border border-slate-200 px-4 py-2.5 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                  />
                </label>
              ))}
              {localError ? <div className="text-sm text-rose-600">{localError}</div> : null}
              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={() => setIsOpen(false)} className="rounded-2xl border border-slate-200 px-5 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50">Cancel</button>
                <button type="submit" disabled={saving} className="rounded-2xl bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:bg-slate-300">
                  {saving ? 'Saving...' : editingItem ? 'Save changes' : 'Add Supplier'}
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  )
}

interface SupplierFormState {
  name: string
  phone: string
  address: string
  gstNumber: string
  outstandingBalance: string
}

const defaultSupplierForm: SupplierFormState = {
  name: '',
  phone: '',
  address: '',
  gstNumber: '',
  outstandingBalance: '0',
}

// ─── Main page ────────────────────────────────────────────────────────────────

function MastersPage() {
  const actor = localStorage.getItem(STORAGE_KEYS.username) ?? 'unknown'
  const [tab, setTab] = useState<TabId>('categories')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const [categories, setCategories] = useState<CategoryRecord[]>([])
  const [brands, setBrands] = useState<BrandRecord[]>([])
  const [customers, setCustomers] = useState<CustomerRecord[]>([])
  const [suppliers, setSuppliers] = useState<SupplierRecord[]>([])
  const [units, setUnits] = useState<UnitRecord[]>(() => loadUnits())
  const [taxSlabs, setTaxSlabs] = useState<TaxSlabRecord[]>(() => loadTaxSlabs())

  useEffect(() => {
    let cancelled = false
    const bootstrap = async () => {
      setLoading(true)
      setError('')
      setNotice('')
      try {
        if (tab === 'categories') {
          const result = await listCategories()
          if (!cancelled) setCategories(result)
        } else if (tab === 'brands') {
          const result = await listBrands()
          if (!cancelled) setBrands(result)
        } else if (tab === 'customers') {
          const result = await listCustomers()
          if (!cancelled) setCustomers(result)
        } else if (tab === 'suppliers') {
          const result = await listSuppliers()
          if (!cancelled) setSuppliers(result)
        }
      } catch (err) {
        if (!cancelled) setError(extractApiError(err))
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    void bootstrap()
    return () => {
      cancelled = true
    }
  }, [tab])

  // ─── Category handlers ───────────────────────────────────────────────────

  const handleAddCategory = async (name: string) => {
    await upsertCategory({ clientRecordId: generateUUID(), name })
    pushAuditEvent({ module: 'masters', action: 'create', detail: `Created category ${name}`, actor })
    setNotice('Category added.')
    setCategories(await listCategories())
  }

  const handleDeleteCategory = async (item: CategoryRecord) => {
    await upsertCategory({ clientRecordId: item.clientRecordId, name: item.name, deleted: true })
    pushAuditEvent({ module: 'masters', action: 'delete', detail: `Deleted category ${item.name}`, actor })
    setNotice('Category deleted.')
    setCategories(await listCategories())
  }

  // ─── Brand handlers ──────────────────────────────────────────────────────

  const handleAddBrand = async (name: string) => {
    await upsertBrand({ clientRecordId: generateUUID(), name })
    pushAuditEvent({ module: 'masters', action: 'create', detail: `Created brand ${name}`, actor })
    setNotice('Brand added.')
    setBrands(await listBrands())
  }

  const handleDeleteBrand = async (item: BrandRecord) => {
    await upsertBrand({ clientRecordId: item.clientRecordId, name: item.name, deleted: true })
    pushAuditEvent({ module: 'masters', action: 'delete', detail: `Deleted brand ${item.name}`, actor })
    setNotice('Brand deleted.')
    setBrands(await listBrands())
  }

  // ─── Unit handlers (localStorage) ───────────────────────────────────────

  const handleAddUnit = async (name: string) => {
    const next = [...units, { clientRecordId: generateUUID(), name }]
    saveUnits(next)
    setUnits(next)
    setNotice('Unit added.')
    pushAuditEvent({ module: 'masters', action: 'create', detail: `Created unit ${name}`, actor })
  }

  const handleDeleteUnit = async (item: UnitRecord) => {
    const next = units.filter((u) => u.clientRecordId !== item.clientRecordId)
    saveUnits(next)
    setUnits(next)
    setNotice('Unit deleted.')
    pushAuditEvent({ module: 'masters', action: 'delete', detail: `Deleted unit ${item.name}`, actor })
  }

  // ─── Tax slab handlers (localStorage) ────────────────────────────────────

  const handleAddTaxSlab = async (name: string) => {
    const next = [...taxSlabs, { clientRecordId: generateUUID(), name }]
    saveTaxSlabs(next)
    setTaxSlabs(next)
    setNotice('Tax slab added.')
    pushAuditEvent({ module: 'masters', action: 'create', detail: `Created tax slab ${name}`, actor })
  }

  const handleDeleteTaxSlab = async (item: TaxSlabRecord) => {
    const next = taxSlabs.filter((s) => s.clientRecordId !== item.clientRecordId)
    saveTaxSlabs(next)
    setTaxSlabs(next)
    setNotice('Tax slab deleted.')
    pushAuditEvent({ module: 'masters', action: 'delete', detail: `Deleted tax slab ${item.name}`, actor })
  }

  // ─── Customer handlers ───────────────────────────────────────────────────

  const handleSaveCustomer = async (form: CustomerFormState, existing?: CustomerRecord) => {
    const clientRecordId = existing?.clientRecordId ?? generateUUID()
    await upsertCustomer({
      clientRecordId,
      name: form.name,
      phone: form.phone || undefined,
      address: form.address || undefined,
      gstNumber: form.gstNumber || undefined,
      creditLimit: parseFloat(form.creditLimit) || 0,
      outstandingBalance: parseFloat(form.outstandingBalance) || 0,
    })
    pushAuditEvent({ module: 'masters', action: existing ? 'update' : 'create', detail: `${existing ? 'Updated' : 'Created'} customer ${form.name}`, actor })
    setNotice(`Customer ${existing ? 'updated' : 'added'}.`)
    setCustomers(await listCustomers())
  }

  const handleDeleteCustomer = async (item: CustomerRecord) => {
    await upsertCustomer({ clientRecordId: item.clientRecordId, name: item.name, deleted: true })
    pushAuditEvent({ module: 'masters', action: 'delete', detail: `Deleted customer ${item.name}`, actor })
    setNotice('Customer deleted.')
    setCustomers(await listCustomers())
  }

  // ─── Supplier handlers ───────────────────────────────────────────────────

  const handleSaveSupplier = async (form: SupplierFormState, existing?: SupplierRecord) => {
    const clientRecordId = existing?.clientRecordId ?? generateUUID()
    await upsertSupplier({
      clientRecordId,
      name: form.name,
      phone: form.phone || undefined,
      address: form.address || undefined,
      gstNumber: form.gstNumber || undefined,
      outstandingBalance: parseFloat(form.outstandingBalance) || 0,
    })
    pushAuditEvent({ module: 'masters', action: existing ? 'update' : 'create', detail: `${existing ? 'Updated' : 'Created'} supplier ${form.name}`, actor })
    setNotice(`Supplier ${existing ? 'updated' : 'added'}.`)
    setSuppliers(await listSuppliers())
  }

  const handleDeleteSupplier = async (item: SupplierRecord) => {
    await upsertSupplier({ clientRecordId: item.clientRecordId, name: item.name, deleted: true })
    pushAuditEvent({ module: 'masters', action: 'delete', detail: `Deleted supplier ${item.name}`, actor })
    setNotice('Supplier deleted.')
    setSuppliers(await listSuppliers())
  }

  const tabs: Array<{ id: TabId; label: string }> = [
    { id: 'categories', label: 'Categories' },
    { id: 'brands', label: 'Brands' },
    { id: 'units', label: 'Units' },
    { id: 'taxSlabs', label: 'Tax Slabs' },
    { id: 'customers', label: 'Customers' },
    { id: 'suppliers', label: 'Suppliers' },
  ]

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Masters</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-900">Master Data</h1>
          <p className="mt-2 text-sm text-slate-500">Manage categories, brands, units, customers, and suppliers.</p>
        </div>
      </div>

      {/* Tab bar */}
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

      {tab === 'categories' && (
        <NameMasterTab
          title="Categories"
          description="Electronics"
          items={categories}
          loading={loading}
          error={error}
          notice={notice}
          onAdd={handleAddCategory}
          onDelete={handleDeleteCategory}
        />
      )}

      {tab === 'brands' && (
        <NameMasterTab
          title="Brands"
          description="Samsung"
          items={brands}
          loading={loading}
          error={error}
          notice={notice}
          onAdd={handleAddBrand}
          onDelete={handleDeleteBrand}
        />
      )}

      {tab === 'units' && (
        <NameMasterTab
          title="Units"
          description="litre"
          items={units}
          loading={false}
          error={error}
          notice={notice}
          onAdd={handleAddUnit}
          onDelete={handleDeleteUnit}
        />
      )}

      {tab === 'taxSlabs' && (
        <NameMasterTab
          title="Tax Slabs"
          description="Manage GST rate slabs"
          items={taxSlabs}
          loading={false}
          error={error}
          notice={notice}
          onAdd={handleAddTaxSlab}
          onDelete={handleDeleteTaxSlab}
        />
      )}

      {tab === 'customers' && (
        <CustomersTab
          customers={customers}
          loading={loading}
          error={error}
          notice={notice}
          onSave={handleSaveCustomer}
          onDelete={handleDeleteCustomer}
        />
      )}

      {tab === 'suppliers' && (
        <SuppliersTab
          suppliers={suppliers}
          loading={loading}
          error={error}
          notice={notice}
          onSave={handleSaveSupplier}
          onDelete={handleDeleteSupplier}
        />
      )}
    </div>
  )
}

export default MastersPage
