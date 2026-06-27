import { generateUUID } from '../utils/uuid'
import { useRef, useState } from 'react'
import { listProducts, upsertProduct } from '../api/products'
import { extractApiError } from '../api/client'
import { useAuth } from '../context/AuthContext'
import { pushAuditEvent } from '../utils/auditLog'
import type { ProductResponse } from '../types'

const PRODUCT_META_KEY = 'nn_product_meta'

type ProductType = 'physical' | 'raw_material' | 'composite' | 'service'
type RowStatus = 'idle' | 'saving' | 'success' | 'error'

interface BulkRow {
  id: string
  name: string
  unit: string
  barcode: string
  hsnCode: string
  gstRate: string
  sellingPrice: string
  purchasePrice: string
  wholesalePrice: string
  stockQuantity: string
  productType: ProductType
  status: RowStatus
  errorMsg: string
}

// Column indices matching the input order in each row
const COL_COUNT = 10 // name, unit, barcode, hsnCode, gstRate, sellingPrice, purchasePrice, wholesalePrice, stockQuantity, productType
const LAST_COL = COL_COUNT - 1

function makeRow(): BulkRow {
  return {
    id: generateUUID(),
    name: '',
    unit: 'pcs',
    barcode: '',
    hsnCode: '',
    gstRate: '0',
    sellingPrice: '0',
    purchasePrice: '0',
    wholesalePrice: '0',
    stockQuantity: '0',
    productType: 'physical',
    status: 'idle',
    errorMsg: '',
  }
}

function makeRows(count: number): BulkRow[] {
  return Array.from({ length: count }, makeRow)
}

interface BulkProductEntryProps {
  onSaveComplete: (products: ProductResponse[]) => void
}

function BulkProductEntry({ onSaveComplete }: BulkProductEntryProps) {
  const { username } = useAuth()
  const [rows, setRows] = useState<BulkRow[]>(() => makeRows(10))
  const [saving, setSaving] = useState(false)
  const cellRefs = useRef<(HTMLElement | null)[][]>([])

  const setRef = (rowIdx: number, colIdx: number) => (el: HTMLElement | null) => {
    if (!cellRefs.current[rowIdx]) {
      cellRefs.current[rowIdx] = Array<HTMLElement | null>(COL_COUNT).fill(null)
    }
    cellRefs.current[rowIdx][colIdx] = el
  }

  const focusCell = (rowIdx: number, colIdx: number) => {
    const cell = cellRefs.current[rowIdx]?.[colIdx]
    if (cell) {
      cell.focus()
      if (cell instanceof HTMLInputElement && !['checkbox', 'radio', 'file'].includes(cell.type)) {
        cell.select()
      }
    }
  }

  const handleKeyDown = (event: React.KeyboardEvent, rowIdx: number, colIdx: number) => {
    if (event.key !== 'Enter' && event.key !== 'Tab') return
    if (event.shiftKey) return

    event.preventDefault()

    if (colIdx < LAST_COL) {
      focusCell(rowIdx, colIdx + 1)
    } else if (rowIdx < rows.length - 1) {
      focusCell(rowIdx + 1, 0)
    }
  }

  const updateRow = (rowIdx: number, field: keyof BulkRow, value: string) => {
    setRows((prev) =>
      prev.map((row, i) =>
        i === rowIdx
          ? { ...row, [field]: value, status: row.status === 'error' ? 'idle' : row.status, errorMsg: '' }
          : row
      )
    )
  }

  const addRows = () => {
    setRows((prev) => [...prev, ...makeRows(10)])
  }

  const handleSaveAll = async () => {
    const filledRows = rows.filter((r) => r.name.trim())
    if (!filledRows.length) return

    setSaving(true)

    setRows((prev) => prev.map((r) => (r.name.trim() ? { ...r, status: 'saving' as RowStatus } : r)))

    for (const row of filledRows) {
      const clientRecordId = generateUUID()
      try {
        await upsertProduct({
          clientRecordId,
          name: row.name.trim(),
          unit: row.unit.trim() || 'pcs',
          sellingPrice: Number.parseFloat(row.sellingPrice) || 0,
          purchasePrice: Number.parseFloat(row.purchasePrice) || 0,
          stockQuantity: Number.parseFloat(row.stockQuantity) || 0,
          updatedAt: new Date().toISOString(),
        })

        const existing = (() => {
          try {
            return JSON.parse(localStorage.getItem(PRODUCT_META_KEY) ?? '{}') as Record<string, unknown>
          } catch {
            return {}
          }
        })()
        localStorage.setItem(
          PRODUCT_META_KEY,
          JSON.stringify({
            ...existing,
            [clientRecordId]: {
              productType: row.productType,
              barcode: row.barcode.trim(),
              hsnCode: row.hsnCode.trim(),
              gstRate: row.gstRate,
              gstInclusive: false,
              rateType: 'fixed',
              wholesalePrice: row.wholesalePrice,
              wholesaleQty: '0',
              imageUrl: '',
              multiUoms: '',
              bomRecipe: '',
            },
          })
        )

        pushAuditEvent({
          module: 'products',
          action: 'create',
          detail: `Bulk created product ${row.name.trim()}`,
          actor: username ?? 'unknown',
        })

        setRows((prev) => prev.map((r) => (r.id === row.id ? { ...r, status: 'success' as RowStatus } : r)))
      } catch (err) {
        setRows((prev) =>
          prev.map((r) =>
            r.id === row.id ? { ...r, status: 'error' as RowStatus, errorMsg: extractApiError(err) } : r
          )
        )
      }
    }

    setSaving(false)

    try {
      const refreshed = await listProducts()
      onSaveComplete(refreshed)
    } catch {
      // best-effort refresh
    }
  }

  const filledCount = rows.filter((r) => r.name.trim()).length
  const hasErrors = rows.some((r) => r.status === 'error')

  const inputCls =
    'w-full rounded-lg border border-slate-200 px-2 py-1.5 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100 disabled:bg-slate-100 disabled:cursor-not-allowed'

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-slate-500">
          Fill rows then click <strong>Save All</strong>. Rows with empty Name are ignored. Press{' '}
          <kbd className="rounded border border-slate-300 bg-slate-100 px-1 py-0.5 text-xs">Enter</kbd> or{' '}
          <kbd className="rounded border border-slate-300 bg-slate-100 px-1 py-0.5 text-xs">Tab</kbd> to move between
          cells.
        </p>
        <div className="flex gap-3">
          <button
            type="button"
            onClick={addRows}
            disabled={saving}
            className="rounded-2xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
          >
            + Add 10 more rows
          </button>
          <button
            type="button"
            onClick={() => void handleSaveAll()}
            disabled={saving || filledCount === 0}
            className="rounded-2xl bg-indigo-600 px-5 py-2 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300"
          >
            {saving ? 'Saving…' : `Save All (${filledCount})`}
          </button>
        </div>
      </div>

      <div className="overflow-x-auto rounded-2xl border border-slate-200">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50">
              <th className="w-8 px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">#</th>
              <th className="min-w-[160px] px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Name *
              </th>
              <th className="w-20 px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Unit</th>
              <th className="w-28 px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Barcode</th>
              <th className="w-24 px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">HSN</th>
              <th className="w-16 px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">GST %</th>
              <th className="w-28 px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Selling ₹</th>
              <th className="w-28 px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Purchase ₹
              </th>
              <th className="w-28 px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Wholesale ₹
              </th>
              <th className="w-20 px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Stock</th>
              <th className="w-28 px-2 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Type</th>
              <th className="w-10 px-2 py-2 text-center text-xs font-semibold uppercase tracking-wide text-slate-500">St.</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, rowIdx) => {
              const locked = row.status === 'saving' || row.status === 'success'
              const rowCls = [
                'border-b border-slate-100',
                row.status === 'success' ? 'bg-emerald-50' : row.status === 'error' ? 'bg-rose-50' : rowIdx % 2 === 0 ? 'bg-white' : 'bg-slate-50/50',
              ].join(' ')

              return (
                <tr key={row.id} className={rowCls}>
                  <td className="px-3 py-1 text-xs text-slate-400">{rowIdx + 1}</td>

                  {/* 0: Name */}
                  <td className="px-2 py-1">
                    <input
                      ref={setRef(rowIdx, 0) as React.RefCallback<HTMLInputElement>}
                      value={row.name}
                      onChange={(e) => updateRow(rowIdx, 'name', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 0)}
                      disabled={locked}
                      placeholder="Product name"
                      className={inputCls}
                    />
                  </td>

                  {/* 1: Unit */}
                  <td className="px-2 py-1">
                    <input
                      ref={setRef(rowIdx, 1) as React.RefCallback<HTMLInputElement>}
                      value={row.unit}
                      onChange={(e) => updateRow(rowIdx, 'unit', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 1)}
                      disabled={locked}
                      className={inputCls}
                    />
                  </td>

                  {/* 2: Barcode */}
                  <td className="px-2 py-1">
                    <input
                      ref={setRef(rowIdx, 2) as React.RefCallback<HTMLInputElement>}
                      value={row.barcode}
                      onChange={(e) => updateRow(rowIdx, 'barcode', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 2)}
                      disabled={locked}
                      className={inputCls}
                    />
                  </td>

                  {/* 3: HSN */}
                  <td className="px-2 py-1">
                    <input
                      ref={setRef(rowIdx, 3) as React.RefCallback<HTMLInputElement>}
                      value={row.hsnCode}
                      onChange={(e) => updateRow(rowIdx, 'hsnCode', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 3)}
                      disabled={locked}
                      className={inputCls}
                    />
                  </td>

                  {/* 4: GST % */}
                  <td className="px-2 py-1">
                    <input
                      ref={setRef(rowIdx, 4) as React.RefCallback<HTMLInputElement>}
                      type="number"
                      step="0.01"
                      value={row.gstRate}
                      onChange={(e) => updateRow(rowIdx, 'gstRate', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 4)}
                      disabled={locked}
                      className={inputCls}
                    />
                  </td>

                  {/* 5: Selling Price */}
                  <td className="px-2 py-1">
                    <input
                      ref={setRef(rowIdx, 5) as React.RefCallback<HTMLInputElement>}
                      type="number"
                      step="0.01"
                      value={row.sellingPrice}
                      onChange={(e) => updateRow(rowIdx, 'sellingPrice', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 5)}
                      disabled={locked}
                      className={inputCls}
                    />
                  </td>

                  {/* 6: Purchase Price */}
                  <td className="px-2 py-1">
                    <input
                      ref={setRef(rowIdx, 6) as React.RefCallback<HTMLInputElement>}
                      type="number"
                      step="0.01"
                      value={row.purchasePrice}
                      onChange={(e) => updateRow(rowIdx, 'purchasePrice', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 6)}
                      disabled={locked}
                      className={inputCls}
                    />
                  </td>

                  {/* 7: Wholesale Price */}
                  <td className="px-2 py-1">
                    <input
                      ref={setRef(rowIdx, 7) as React.RefCallback<HTMLInputElement>}
                      type="number"
                      step="0.01"
                      value={row.wholesalePrice}
                      onChange={(e) => updateRow(rowIdx, 'wholesalePrice', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 7)}
                      disabled={locked}
                      className={inputCls}
                    />
                  </td>

                  {/* 8: Stock Qty */}
                  <td className="px-2 py-1">
                    <input
                      ref={setRef(rowIdx, 8) as React.RefCallback<HTMLInputElement>}
                      type="number"
                      step="0.01"
                      value={row.stockQuantity}
                      onChange={(e) => updateRow(rowIdx, 'stockQuantity', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 8)}
                      disabled={locked}
                      className={inputCls}
                    />
                  </td>

                  {/* 9: Type (select — last col, Enter goes to next row col 0) */}
                  <td className="px-2 py-1">
                    <select
                      ref={setRef(rowIdx, 9) as React.RefCallback<HTMLSelectElement>}
                      value={row.productType}
                      onChange={(e) => updateRow(rowIdx, 'productType', e.target.value)}
                      onKeyDown={(e) => handleKeyDown(e, rowIdx, 9)}
                      disabled={locked}
                      className={inputCls}
                    >
                      <option value="physical">Physical</option>
                      <option value="raw_material">Raw material</option>
                      <option value="composite">Composite</option>
                      <option value="service">Service</option>
                    </select>
                  </td>

                  {/* Status indicator */}
                  <td className="px-2 py-1 text-center">
                    {row.status === 'saving' && (
                      <span className="text-slate-400" title="Saving…">
                        ⋯
                      </span>
                    )}
                    {row.status === 'success' && (
                      <span className="text-emerald-600" title="Saved successfully">
                        ✓
                      </span>
                    )}
                    {row.status === 'error' && (
                      <span className="text-rose-600" title={row.errorMsg}>
                        ✗
                      </span>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {hasErrors && (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
          Some rows failed to save (marked in red). Fix the data and click <strong>Save All</strong> again — only failed
          rows will be retried.
        </div>
      )}
    </div>
  )
}

export default BulkProductEntry
