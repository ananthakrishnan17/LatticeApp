import { generateUUID } from '../utils/uuid'
import { useCallback, useEffect, useMemo, useState } from 'react'
import Box from '@cloudscape-design/components/box'
import Button from '@cloudscape-design/components/button'
import Container from '@cloudscape-design/components/container'
import Header from '@cloudscape-design/components/header'
import SpaceBetween from '@cloudscape-design/components/space-between'
import type { TableProps } from '@cloudscape-design/components/table'
import { extractApiError } from '../api/client'
import EnterNavigableTable from '../components/EnterNavigableTable'
import BulkProductEntry from '../components/BulkProductEntry'
import { listProducts, upsertProduct } from '../api/products'
import Spinner from '../components/Spinner'
import { useAuth } from '../context/AuthContext'
import { useGridNavigation } from '../context/GridNavigationContext'
import { pushAuditEvent } from '../utils/auditLog'
import type { ProductResponse } from '../types'

const PRODUCT_META_KEY = 'nn_product_meta'

type ProductType = 'physical' | 'raw_material' | 'composite' | 'service'
type RateType = 'fixed' | 'open'

interface ProductMeta {
  productType: ProductType
  barcode: string
  hsnCode: string
  gstRate: string
  gstInclusive: boolean
  rateType: RateType
  wholesalePrice: string
  wholesaleQty: string
  imageUrl: string
  multiUoms: string
  bomRecipe: string
}

interface ProductFormState extends ProductMeta {
  clientRecordId?: string
  name: string
  unit: string
  sellingPrice: string
  purchasePrice: string
  stockQuantity: string
  version?: number
}

const emptyMeta: ProductMeta = {
  productType: 'physical',
  barcode: '',
  hsnCode: '',
  gstRate: '0',
  gstInclusive: false,
  rateType: 'fixed',
  wholesalePrice: '0',
  wholesaleQty: '0',
  imageUrl: '',
  multiUoms: '',
  bomRecipe: '',
}

const emptyForm: ProductFormState = {
  name: '',
  unit: 'pcs',
  sellingPrice: '0',
  purchasePrice: '0',
  stockQuantity: '0',
  ...emptyMeta,
}

const currency = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  maximumFractionDigits: 2,
})

function loadProductMeta(): Record<string, ProductMeta> {
  try {
    const raw = localStorage.getItem(PRODUCT_META_KEY)
    return raw ? (JSON.parse(raw) as Record<string, ProductMeta>) : {}
  } catch {
    return {}
  }
}

function saveProductMeta(meta: Record<string, ProductMeta>) {
  localStorage.setItem(PRODUCT_META_KEY, JSON.stringify(meta))
}

type ActiveTab = 'list' | 'bulk'

function ProductsPage() {
  const { username } = useAuth()
  const { keyboardEventKey, navigationKey } = useGridNavigation()
  const [activeTab, setActiveTab] = useState<ActiveTab>('list')
  const [products, setProducts] = useState<ProductResponse[]>([])
  const [productMeta, setProductMeta] = useState<Record<string, ProductMeta>>(() => loadProductMeta())
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [search, setSearch] = useState('')
  const [selectedItems, setSelectedItems] = useState<ReadonlyArray<ProductResponse>>([])
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [form, setForm] = useState<ProductFormState>(emptyForm)

  const loadProducts = useCallback(async () => {
    setLoading(true)
    setError('')

    try {
      const result = await listProducts()
      setProducts(result)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    let cancelled = false

    const bootstrapProducts = async () => {
      try {
        const result = await listProducts()
        if (!cancelled) {
          setProducts(result)
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

    void bootstrapProducts()

    return () => {
      cancelled = true
    }
  }, [])

  const activeProducts = useMemo(() => {
    const query = search.trim().toLowerCase()
    return products
      .filter((product) => product.deletedAt === null)
      .filter((product) => {
        const meta = productMeta[product.clientRecordId]
        return !query || [product.name, product.unit, meta?.barcode ?? '', meta?.hsnCode ?? ''].some((value) => value.toLowerCase().includes(query))
      })
  }, [products, productMeta, search])

  const columnDefinitions: ReadonlyArray<TableProps.ColumnDefinition<ProductResponse>> = [
    {
      id: 'name',
      header: 'Name',
      cell: (item) => <Box fontWeight="bold">{item.name}</Box>,
    },
    {
      id: 'unit',
      header: 'Unit',
      cell: (item) => item.unit,
    },
    {
      id: 'barcode',
      header: 'Barcode',
      cell: (item) => productMeta[item.clientRecordId]?.barcode || '—',
    },
    {
      id: 'gst',
      header: 'GST',
      cell: (item) => `${productMeta[item.clientRecordId]?.gstRate ?? '0'}%`,
    },
    {
      id: 'type',
      header: 'Type',
      cell: (item) => (productMeta[item.clientRecordId]?.productType ?? 'physical').replace('_', ' '),
    },
    {
      id: 'sellingPrice',
      header: 'Selling Price',
      cell: (item) => currency.format(item.sellingPrice),
    },
    {
      id: 'purchasePrice',
      header: 'Purchase Price',
      cell: (item) => currency.format(item.purchasePrice),
    },
    {
      id: 'stockQuantity',
      header: 'Stock Qty',
      cell: (item) => item.stockQuantity,
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: (item) => (
        <SpaceBetween size="xs" direction="horizontal">
          <Button onClick={() => openEditModal(item)}>Edit</Button>
          <Button variant="normal" onClick={() => void handleDelete(item)}>
            Delete
          </Button>
        </SpaceBetween>
      ),
    },
  ]

  const openAddModal = () => {
    setForm(emptyForm)
    setError('')
    setNotice('')
    setIsModalOpen(true)
  }

  const openEditModal = (product: ProductResponse) => {
    const meta = productMeta[product.clientRecordId] ?? emptyMeta
    setForm({
      clientRecordId: product.clientRecordId,
      name: product.name,
      unit: product.unit,
      sellingPrice: String(product.sellingPrice),
      purchasePrice: String(product.purchasePrice),
      stockQuantity: String(product.stockQuantity),
      version: product.version,
      ...meta,
    })
    setError('')
    setNotice('')
    setIsModalOpen(true)
  }

  const closeModal = () => {
    setIsModalOpen(false)
    setForm(emptyForm)
  }

  const handleChange = <K extends keyof ProductFormState>(field: K, value: ProductFormState[K]) => {
    setForm((current) => ({ ...current, [field]: value }))
  }

  const persistMeta = (clientRecordId: string, meta: ProductMeta) => {
    setProductMeta((current) => {
      const next = { ...current, [clientRecordId]: meta }
      saveProductMeta(next)
      return next
    })
  }

  const handleFormGridNavigation = (event: React.KeyboardEvent<HTMLFormElement>) => {
    if (event.key !== keyboardEventKey || event.shiftKey || event.altKey || event.metaKey || event.ctrlKey) {
      return
    }

    const target = event.target
    if (!(target instanceof HTMLElement) || target.tagName.toLowerCase() === 'textarea') {
      return
    }

    const formElement = event.currentTarget
    const focusableSelector = [
      'input:not([type="hidden"]):not([disabled])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      'button:not([disabled])',
      '[tabindex]:not([tabindex="-1"])',
    ].join(',')
    const focusableFields = Array.from(formElement.querySelectorAll<HTMLElement>(focusableSelector))
      .filter((element) => element.offsetParent !== null)
    const currentField = target.closest<HTMLElement>('input, select, textarea, button, [tabindex]')
    if (!currentField) {
      return
    }

    const currentIndex = focusableFields.indexOf(currentField)
    if (currentIndex < 0 || currentIndex >= focusableFields.length - 1) {
      return
    }

    event.preventDefault()
    const nextField = focusableFields[currentIndex + 1]
    nextField.focus()
    if (nextField instanceof HTMLInputElement && !['checkbox', 'radio', 'file'].includes(nextField.type)) {
      nextField.select()
    }
  }

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setSaving(true)
    setError('')
    setNotice('')

    const clientRecordId = form.clientRecordId ?? generateUUID()

    try {
      const saved = await upsertProduct({
        clientRecordId,
        name: form.name.trim(),
        unit: form.unit.trim() || 'pcs',
        sellingPrice: Number.parseFloat(form.sellingPrice) || 0,
        purchasePrice: Number.parseFloat(form.purchasePrice) || 0,
        stockQuantity: Number.parseFloat(form.stockQuantity) || 0,
        version: form.version,
        updatedAt: new Date().toISOString(),
      })

      persistMeta(clientRecordId, {
        productType: form.productType,
        barcode: form.barcode.trim(),
        hsnCode: form.hsnCode.trim(),
        gstRate: form.gstRate,
        gstInclusive: form.gstInclusive,
        rateType: form.rateType,
        wholesalePrice: form.wholesalePrice,
        wholesaleQty: form.wholesaleQty,
        imageUrl: form.imageUrl.trim(),
        multiUoms: form.multiUoms.trim(),
        bomRecipe: form.bomRecipe.trim(),
      })

      setProducts((prev) => {
        const exists = prev.some((p) => p.clientRecordId === saved.clientRecordId)
        return exists
          ? prev.map((p) => (p.clientRecordId === saved.clientRecordId ? saved : p))
          : [saved, ...prev]
      })

      pushAuditEvent({
        module: 'products',
        action: form.clientRecordId ? 'update' : 'create',
        detail: `${form.clientRecordId ? 'Updated' : 'Created'} product ${form.name.trim()}`,
        actor: username ?? 'unknown',
      })
      setNotice(form.clientRecordId ? 'Product updated successfully.' : 'Product created successfully.')
      closeModal()
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (product: ProductResponse) => {
    const shouldDelete = window.confirm(`Delete ${product.name}? This will mark the product as deleted.`)
    if (!shouldDelete) {
      return
    }

    setError('')
    setNotice('')

    try {
      await upsertProduct({
        clientRecordId: product.clientRecordId,
        name: product.name,
        unit: product.unit,
        sellingPrice: product.sellingPrice,
        purchasePrice: product.purchasePrice,
        stockQuantity: product.stockQuantity,
        version: product.version,
        updatedAt: new Date().toISOString(),
        deleted: true,
      })
      pushAuditEvent({
        module: 'products',
        action: 'delete',
        detail: `Deleted product ${product.name}`,
        actor: username ?? 'unknown',
      })
      setProducts((prev) => prev.filter((p) => p.clientRecordId !== product.clientRecordId))
      setNotice('Product deleted successfully.')
    } catch (err) {
      setError(extractApiError(err))
    }
  }

  const handleBulkSaveComplete = (refreshed: ProductResponse[]) => {
    setProducts(refreshed)
    setActiveTab('list')
    setNotice('Bulk products saved successfully.')
  }

  if (loading) {
    return <Spinner label="Loading products..." />
  }

  const tabBtnCls = (tab: ActiveTab) =>
    `px-4 py-2 text-sm font-semibold rounded-xl transition ${
      activeTab === tab
        ? 'bg-indigo-600 text-white'
        : 'border border-slate-200 text-slate-700 hover:bg-slate-50'
    }`

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Products</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-900">Product catalog</h1>
          <p className="mt-2 text-sm text-slate-500">Create products with GST, barcode, wholesale, UOM, and recipe metadata.</p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          {/* Tab switcher */}
          <div className="flex gap-2">
            <button type="button" className={tabBtnCls('list')} onClick={() => setActiveTab('list')}>
              Products
            </button>
            <button type="button" className={tabBtnCls('bulk')} onClick={() => setActiveTab('bulk')}>
              Bulk Add
            </button>
          </div>

          {activeTab === 'list' && (
            <>
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search products"
                className="rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
              />
              <button
                type="button"
                onClick={openAddModal}
                className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700"
              >
                Add Product
              </button>
            </>
          )}
        </div>
      </div>

      {error ? (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
          <div>{error}</div>
          <button
            type="button"
            onClick={() => void loadProducts()}
            className="mt-2 rounded-xl border border-rose-300 bg-white px-3 py-1.5 text-xs font-semibold text-rose-700 transition hover:bg-rose-100"
          >
            Retry loading products
          </button>
        </div>
      ) : null}
      {notice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      {activeTab === 'list' && (
        <Container>
          <EnterNavigableTable
            items={activeProducts}
            selectedItems={selectedItems}
            onSelectionChange={setSelectedItems}
            columnDefinitions={columnDefinitions}
            trackBy="clientRecordId"
            header={<Header description="Use the configured grid key to move selection row-by-row.">Products grid</Header>}
            empty={<Box color="text-body-secondary">No active products found.</Box>}
          />
        </Container>
      )}

      {activeTab === 'bulk' && (
        <Container>
          <div className="p-2">
            <BulkProductEntry onSaveComplete={handleBulkSaveComplete} />
          </div>
        </Container>
      )}

      {activeTab === 'list' && isModalOpen ? (
        <Container>
          <div className="space-y-5 rounded-3xl bg-white p-6 md:p-8">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="text-2xl font-semibold text-slate-900">{form.clientRecordId ? 'Edit product' : 'Add product'}</h2>
                <p className="mt-1 text-sm text-slate-500">Enter product details in grid format and press {navigationKey} to move to the next field.</p>
              </div>
              <button type="button" onClick={closeModal} className="rounded-full p-2 text-slate-400 transition hover:bg-slate-100 hover:text-slate-600">✕</button>
            </div>

            <form className="grid gap-4 md:grid-cols-2" onSubmit={handleSubmit} onKeyDown={handleFormGridNavigation}>
              <label className="md:col-span-2">
                <span className="mb-2 block text-sm font-medium text-slate-700">Name</span>
                <input required value={form.name} onChange={(event) => handleChange('name', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Product type</span>
                <select value={form.productType} onChange={(event) => handleChange('productType', event.target.value as ProductType)} className="w-full rounded-2xl border border-slate-200 px-4 py-3">
                  <option value="physical">Physical</option>
                  <option value="raw_material">Raw material</option>
                  <option value="composite">Composite recipe</option>
                  <option value="service">Service</option>
                </select>
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Rate type</span>
                <select value={form.rateType} onChange={(event) => handleChange('rateType', event.target.value as RateType)} className="w-full rounded-2xl border border-slate-200 px-4 py-3">
                  <option value="fixed">Fixed</option>
                  <option value="open">Open</option>
                </select>
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Unit</span>
                <input value={form.unit} onChange={(event) => handleChange('unit', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Multi-UOM list</span>
                <input value={form.multiUoms} onChange={(event) => handleChange('multiUoms', event.target.value)} placeholder="pcs, box, kg" className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Stock quantity</span>
                <input type="number" step="0.01" value={form.stockQuantity} onChange={(event) => handleChange('stockQuantity', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Barcode</span>
                <input value={form.barcode} onChange={(event) => handleChange('barcode', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">HSN code</span>
                <input value={form.hsnCode} onChange={(event) => handleChange('hsnCode', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">GST rate (%)</span>
                <input type="number" step="0.01" value={form.gstRate} onChange={(event) => handleChange('gstRate', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
                <input type="checkbox" checked={form.gstInclusive} onChange={(event) => handleChange('gstInclusive', event.target.checked)} />
                GST inclusive pricing
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Selling price</span>
                <input type="number" step="0.01" value={form.sellingPrice} onChange={(event) => handleChange('sellingPrice', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Purchase price</span>
                <input type="number" step="0.01" value={form.purchasePrice} onChange={(event) => handleChange('purchasePrice', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Wholesale price</span>
                <input type="number" step="0.01" value={form.wholesalePrice} onChange={(event) => handleChange('wholesalePrice', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">Wholesale-to-retail qty</span>
                <input type="number" step="0.01" value={form.wholesaleQty} onChange={(event) => handleChange('wholesaleQty', event.target.value)} className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <label className="md:col-span-2">
                <span className="mb-2 block text-sm font-medium text-slate-700">Product image</span>
                <div className="space-y-2">
                  <input
                    type="file"
                    accept="image/*"
                    className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm"
                    onChange={(event) => {
                      const file = event.target.files?.[0]
                      if (!file) return
                      const reader = new FileReader()
                      reader.onload = () => handleChange('imageUrl', reader.result as string)
                      reader.readAsDataURL(file)
                    }}
                  />
                  <input value={form.imageUrl} onChange={(event) => handleChange('imageUrl', event.target.value)} placeholder="Or paste image URL…" className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm" />
                  {form.imageUrl && (
                    <img src={form.imageUrl} alt="Preview" className="h-20 w-20 rounded-xl border border-slate-200 object-cover" onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }} />
                  )}
                </div>
              </label>

              <label className="md:col-span-2">
                <span className="mb-2 block text-sm font-medium text-slate-700">BOM / Recipe</span>
                <textarea rows={3} value={form.bomRecipe} onChange={(event) => handleChange('bomRecipe', event.target.value)} placeholder="Milk: 200ml, Sugar: 20g" className="w-full rounded-2xl border border-slate-200 px-4 py-3" />
              </label>

              <div className="md:col-span-2 flex justify-end gap-3 pt-2">
                <button type="button" onClick={closeModal} className="rounded-2xl border border-slate-200 px-5 py-3 text-sm font-semibold text-slate-700 transition hover:border-slate-300 hover:bg-slate-50">Cancel</button>
                <button type="submit" disabled={saving} className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300">
                  {saving ? 'Saving...' : form.clientRecordId ? 'Save changes' : 'Create product'}
                </button>
              </div>
            </form>
          </div>
        </Container>
      ) : null}
    </div>
  )
}

export default ProductsPage
