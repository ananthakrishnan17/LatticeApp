import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { listBills, type BillRecord } from '../api/bills'
import { STORAGE_KEYS, extractApiError } from '../api/client'
import Spinner from '../components/Spinner'
import type { PrinterSettings, ShopInfoSettings } from '../types'
import useTranslation from '../hooks/useTranslation'

const DEFAULT_PRINTER: PrinterSettings = {
  paperSize: '80mm',
  showGstin: true,
  headerText: '',
  footerText: 'Thank you for your purchase!',
}

const DEFAULT_SHOP: ShopInfoSettings = {
  shopName: 'NammaNanban POS',
  address: '',
  phone: '',
  email: '',
  gstin: '',
  footerNote: '',
}

const loadJson = <T,>(key: string, fallback: T): T => {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

interface LocalBillLike {
  billNumber?: string
  bill_number?: string
  customerName?: string
  customer_name?: string | null
  totalAmount?: number
  total_amount?: number
  discountAmount?: number
  discount_amount?: number
  couponDiscountAmount?: number
  coupon_discount_amount?: number
  gstTotal?: number
  gst_total?: number
  cgstTotal?: number
  cgst_total?: number
  sgstTotal?: number
  sgst_total?: number
  paymentMode?: string
  payment_mode?: string
  changeAmount?: number
  change_amount?: number | null
  createdAt?: string
  created_at?: string
  items?: Array<{
    productName?: string
    product_name?: string
    quantity: number
    unit: string
    unitPrice?: number
    unit_price?: number
    totalPrice?: number
    total_price?: number
  }>
}

function normalizeBill(source: BillRecord | LocalBillLike, billId: string): BillRecord {
  const local = source as LocalBillLike
  return {
    server_id: (source as BillRecord).server_id ?? billId,
    client_record_id: (source as BillRecord).client_record_id ?? billId,
    bill_number: (source as BillRecord).bill_number ?? local.billNumber ?? local.bill_number ?? billId,
    bill_type: (source as BillRecord).bill_type ?? 'retail',
    customer_name: (source as BillRecord).customer_name ?? local.customerName ?? local.customer_name ?? null,
    customer_address: (source as BillRecord).customer_address ?? null,
    customer_gstin: (source as BillRecord).customer_gstin ?? null,
    total_amount: (source as BillRecord).total_amount ?? local.totalAmount ?? local.total_amount ?? 0,
    total_profit: (source as BillRecord).total_profit ?? 0,
    discount_amount: (source as BillRecord).discount_amount ?? local.discountAmount ?? local.discount_amount ?? 0,
    gst_total: (source as BillRecord).gst_total ?? local.gstTotal ?? local.gst_total ?? 0,
    cgst_total: (source as BillRecord).cgst_total ?? local.cgstTotal ?? local.cgst_total ?? 0,
    sgst_total: (source as BillRecord).sgst_total ?? local.sgstTotal ?? local.sgst_total ?? 0,
    igst_total: (source as BillRecord).igst_total ?? 0,
    payment_mode: (source as BillRecord).payment_mode ?? local.paymentMode ?? local.payment_mode ?? 'cash',
    coupon_code: (source as BillRecord).coupon_code ?? null,
    coupon_discount_amount: (source as BillRecord).coupon_discount_amount ?? local.couponDiscountAmount ?? local.coupon_discount_amount ?? 0,
    cash_tendered: (source as BillRecord).cash_tendered ?? null,
    change_amount: (source as BillRecord).change_amount ?? local.changeAmount ?? local.change_amount ?? null,
    split_payment_summary: (source as BillRecord).split_payment_summary ?? null,
    created_at: (source as BillRecord).created_at ?? local.createdAt ?? local.created_at ?? new Date().toISOString(),
    updated_at: (source as BillRecord).updated_at ?? local.createdAt ?? local.created_at ?? new Date().toISOString(),
    items: ((source as BillRecord).items ?? local.items ?? []).map((entry) => {
      const item = entry as BillRecord['items'][number] & { productName?: string; unitPrice?: number; totalPrice?: number }
      return {
        product_name: item.product_name ?? item.productName ?? 'Item',
        unit: item.unit,
        quantity: item.quantity,
        unit_price: item.unit_price ?? item.unitPrice ?? 0,
        total_price: item.total_price ?? item.totalPrice ?? 0,
      product_sku: null,
      purchase_price: 0,
      gst_rate: 0,
      discount_amount: 0,
      item_discount_type: 'flat',
        item_discount_value: 0,
      }
    }),
  }
}

export default function BillViewPage() {
  const { billId = '' } = useParams()
  const navigate = useNavigate()
  const { t } = useTranslation()
  const [bill, setBill] = useState<BillRecord | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const printer = loadJson<PrinterSettings>(STORAGE_KEYS.printerSettings, DEFAULT_PRINTER)
  const shop = loadJson<ShopInfoSettings>(STORAGE_KEYS.shopInfo, DEFAULT_SHOP)
  const business = loadJson<{ shopLogoUrl?: string }>('nn_business_settings', {})

  useEffect(() => {
    let cancelled = false

    const loadBill = async () => {
      setLoading(true)
      setError('')
      try {
        const local = localStorage.getItem(`nn_last_bill_${billId}`)
        if (local) {
          const parsed = JSON.parse(local) as LocalBillLike
          if (!cancelled) {
            setBill(normalizeBill(parsed, billId))
            setLoading(false)
          }
          return
        }

        const bills = await listBills({ limit: 300 })
        const matched = bills.find((entry) => entry.client_record_id === billId || entry.bill_number === billId)
        if (!matched) {
          throw new Error('Bill not found.')
        }
        if (!cancelled) {
          setBill(matched)
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

    void loadBill()
    return () => {
      cancelled = true
    }
  }, [billId])

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Enter') {
        e.preventDefault()
        navigate('/pos')
      }
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [navigate])

  const subtotal = useMemo(() => bill?.items.reduce((sum, item) => sum + item.total_price, 0) ?? 0, [bill])
  const paperClass = printer.paperSize === 'A4' ? 'max-w-2xl' : printer.paperSize === '58mm' ? 'max-w-[22rem]' : 'max-w-[26rem]'

  if (loading) {
    return <Spinner label="Loading receipt..." />
  }

  if (error || !bill) {
    return (
      <div className="space-y-4 rounded-3xl border border-rose-200 bg-white p-6 shadow-sm">
        <h1 className="text-2xl font-bold text-slate-900">{t.receiptUnavailable}</h1>
        <p className="text-sm text-rose-700">{error || t.unableToLoadBill}</p>
        <button type="button" onClick={() => navigate(-1)} className="rounded-2xl border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700">{t.back}</button>
      </div>
    )
  }

  return (
    <div className="space-y-6 receipt-page">
      <style>{`
        @media print {
          body { background: white !important; }
          .receipt-actions, #top-navigation { display: none !important; }
          .receipt-page { padding: 0 !important; }
          .receipt-card { box-shadow: none !important; border: none !important; }
          .receipt-wrapper { max-width: ${printer.paperSize === 'A4' ? '210mm' : printer.paperSize === '58mm' ? '58mm' : '80mm'} !important; margin: 0 auto !important; }
        }
      `}</style>

      <div className="receipt-actions flex flex-wrap gap-3">
        <button type="button" onClick={() => window.print()} className="rounded-2xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700">{t.print}</button>
        <button type="button" onClick={() => navigate('/pos')} className="rounded-2xl border border-slate-300 px-4 py-2.5 text-sm font-semibold text-slate-700 hover:border-indigo-300 hover:text-indigo-700">{t.newBill}</button>
        <button type="button" onClick={() => navigate(-1)} className="rounded-2xl border border-slate-300 px-4 py-2.5 text-sm font-semibold text-slate-700">{t.back}</button>
      </div>

      <div className={`receipt-wrapper mx-auto ${paperClass}`}>
        <div className="receipt-card rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          {business.shopLogoUrl ? <img src={business.shopLogoUrl} alt={shop.shopName} className="mx-auto mb-3 h-16 w-16 rounded-xl object-cover" /> : null}
          <div className="text-center">
            <h1 className="text-2xl font-bold text-slate-900">{shop.shopName}</h1>
            {shop.address ? <p className="mt-1 text-xs text-slate-500">{shop.address}</p> : null}
            {shop.phone ? <p className="text-xs text-slate-500">{t.phone}: {shop.phone}</p> : null}
            {printer.showGstin && shop.gstin ? <p className="text-xs text-slate-500">{t.gstin}: {shop.gstin}</p> : null}
            {printer.headerText ? <p className="mt-2 text-xs text-slate-600">{printer.headerText}</p> : null}
          </div>

          <div className="mt-6 grid gap-2 rounded-2xl bg-slate-50 p-4 text-sm text-slate-700">
            <div className="flex justify-between"><span>{t.billNo}</span><span className="font-semibold text-slate-900">{bill.bill_number}</span></div>
            <div className="flex justify-between"><span>{t.date}</span><span>{new Date(bill.created_at).toLocaleString()}</span></div>
            <div className="flex justify-between"><span>{t.customer}</span><span>{bill.customer_name || t.walkInCustomer}</span></div>
            <div className="flex justify-between"><span>{t.payment}</span><span className="capitalize">{bill.payment_mode}</span></div>
          </div>

          <div className="mt-6 overflow-hidden rounded-2xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-slate-600">
                <tr>
                  {[t.item, t.qty, t.unit, t.price, t.total].map((heading) => (
                    <th key={heading} className="px-3 py-2 text-left font-semibold">{heading}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {bill.items.map((item, index) => (
                  <tr key={`${item.product_name}-${index}`} className="border-t border-slate-100">
                    <td className="px-3 py-2 text-slate-900">{item.product_name}</td>
                    <td className="px-3 py-2">{item.quantity}</td>
                    <td className="px-3 py-2">{item.unit}</td>
                    <td className="px-3 py-2">₹{item.unit_price.toFixed(2)}</td>
                    <td className="px-3 py-2 font-medium">₹{item.total_price.toFixed(2)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="mt-6 space-y-2 text-sm">
            <div className="flex justify-between"><span className="text-slate-500">{t.subtotal}</span><span className="font-medium text-slate-900">₹{subtotal.toFixed(2)}</span></div>
            <div className="flex justify-between"><span className="text-slate-500">{t.discountAmount}</span><span className="font-medium text-slate-900">₹{(bill.discount_amount + (bill.coupon_discount_amount ?? 0)).toFixed(2)}</span></div>
            <div className="flex justify-between"><span className="text-slate-500">{t.gstAmount}</span><span className="font-medium text-slate-900">₹{bill.gst_total.toFixed(2)}</span></div>
            {printer.showGstin ? (
              <div className="rounded-xl bg-slate-50 px-3 py-2 text-xs text-slate-600">
                <div className="flex justify-between"><span>{t.cgst}</span><span>₹{bill.cgst_total.toFixed(2)}</span></div>
                <div className="mt-1 flex justify-between"><span>{t.sgst}</span><span>₹{bill.sgst_total.toFixed(2)}</span></div>
              </div>
            ) : null}
            <div className="flex justify-between border-t border-slate-200 pt-3 text-base font-semibold text-slate-900"><span>{t.total}</span><span>₹{bill.total_amount.toFixed(2)}</span></div>
            {bill.change_amount !== null ? <div className="flex justify-between"><span className="text-slate-500">{t.change}</span><span className="font-medium text-slate-900">₹{Number(bill.change_amount).toFixed(2)}</span></div> : null}
          </div>

          <div className="mt-6 text-center text-xs text-slate-500">
            <p>{printer.footerText || shop.footerNote}</p>
          </div>
        </div>
      </div>
    </div>
  )
}
