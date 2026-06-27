import { generateUUID } from '../utils/uuid'
import { useCallback, useEffect, useMemo, useRef, useState, type Dispatch, type SetStateAction } from 'react'
import { useNavigate } from 'react-router-dom'

import { upsertBill } from '../api/billing'
import { extractApiError } from '../api/client'
import { listProducts } from '../api/products'
import CartPanel from '../components/CartPanel/CartPanel'
import ProductCard from '../components/ProductCard/ProductCard'
import Spinner from '../components/Spinner'
import { useAuth } from '../context/AuthContext'
import type { CashSessionRecord, CouponConfig, ProductResponse } from '../types'
import {
  closeCashSession,
  createEmptyDenominationCounts,
  getActiveCashSession,
  openCashSession,
  sumDenominationCounts,
  CASH_SESSION_DENOMINATIONS,
  addCashCollection,
} from '../utils/cashSession'
import { loadPaymentMethods } from '../utils/coupons'
import useTranslation from '../hooks/useTranslation'
import '../styles/posTheme.css'

interface CartItem {
  product: ProductResponse
  quantity: number | ''
  unit: string
  saleType: 'retail' | 'wholesale'
  itemDiscount: string
}

interface HeldBill {
  id: string
  label: string
  cart: CartItem[]
  customerName: string
  discount: string
  billSaleType: 'retail' | 'wholesale'
  savedAt: string
}

interface SplitEntry {
  mode: string
  amount: string
}

type DenominationCounts = Record<number, number>

const currency = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  maximumFractionDigits: 2,
})

const HELD_BILLS_KEY = 'nn_held_bills'
const COUPONS_KEY = 'nn_coupons'
const UNITS_KEY = 'nn_units'
const BUSINESS_SETTINGS_KEY = 'nn_business_settings'
const APP_MODE_KEY = 'nn_app_mode'
const DEFAULT_GST_RATE_PERCENT = 5

const formatCurrency = (value: number) => currency.format(Number.isFinite(value) ? value : 0)

const formatSessionTimestamp = (value?: string | null) =>
  value
    ? new Date(value).toLocaleString('en-IN', {
      dateStyle: 'medium',
      timeStyle: 'short',
    })
    : '—'

function buildCashDifferenceMessage(difference: number) {
  if (Math.abs(difference) < 0.01) {
    return 'Shift closed successfully.'
  }

  return difference > 0 ? `Shift closed with excess cash of ${formatCurrency(difference)}.` : `Shift closed with cash shortage of ${formatCurrency(Math.abs(difference))}.`
}

function calculateCashCollected(paymentModeValue: string, billTotal: number, splitSummary?: string) {
  if (paymentModeValue === 'cash') {
    return Number(billTotal.toFixed(2))
  }

  if (paymentModeValue !== 'split' || !splitSummary) {
    return 0
  }

  try {
    const entries = JSON.parse(splitSummary) as Array<{ mode?: string; amount?: string | number }>
    return Number(
      entries
        .filter((entry) => entry.mode?.toLowerCase() === 'cash')
        .reduce((sum, entry) => sum + (Number(entry.amount) || 0), 0)
        .toFixed(2),
    )
  } catch {
    return 0
  }
}

function loadHeldBills(): HeldBill[] {
  try {
    const raw = localStorage.getItem(HELD_BILLS_KEY)
    return raw ? (JSON.parse(raw) as HeldBill[]) : []
  } catch {
    return []
  }
}

function saveHeldBills(bills: HeldBill[]) {
  localStorage.setItem(HELD_BILLS_KEY, JSON.stringify(bills))
}

function loadCoupons(): CouponConfig[] {
  try {
    const raw = localStorage.getItem(COUPONS_KEY)
    return raw ? (JSON.parse(raw) as CouponConfig[]) : []
  } catch {
    return []
  }
}

function loadUnits(): string[] {
  try {
    const raw = localStorage.getItem(UNITS_KEY)
    const parsed = raw ? (JSON.parse(raw) as Array<{ name: string }>) : []
    const units = parsed.map((x) => x.name).filter(Boolean)
    return units.length ? units : ['piece', 'kg', 'litre', 'box', 'pack']
  } catch {
    return ['piece', 'kg', 'litre', 'box', 'pack']
  }
}

function loadDefaultGstRatePercent(): number {
  try {
    const raw = localStorage.getItem(BUSINESS_SETTINGS_KEY)
    if (!raw) return DEFAULT_GST_RATE_PERCENT
    const parsed = JSON.parse(raw) as { defaultGstRate?: string }
    const value = Number.parseFloat(parsed.defaultGstRate ?? '')
    if (Number.isNaN(value) || value < 0) return DEFAULT_GST_RATE_PERCENT
    return value
  } catch {
    return DEFAULT_GST_RATE_PERCENT
  }
}

function categoryFor(product: ProductResponse): 'grocery' | 'beverage' | 'dairy' | 'snack' | 'other' {
  const text = `${product.name} ${product.unit}`.toLowerCase()
  if (/milk|curd|paneer|butter|dairy/.test(text)) return 'dairy'
  if (/drink|juice|tea|coffee|soda|beverage/.test(text)) return 'beverage'
  if (/chips|snack|biscuit/.test(text)) return 'snack'
  if (/rice|dal|oil|flour|grocery/.test(text)) return 'grocery'
  return 'other'
}

function shouldUseApiProducts() {
  const configuredMode = localStorage.getItem(APP_MODE_KEY)?.trim().toLowerCase()
  if (configuredMode === 'offline') return false
  return true
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

const CATEGORY_FILTERS = [
  { id: 'all', label: 'All', icon: '🧾' },
  { id: 'grocery', label: 'Grocery', icon: '🛒' },
  { id: 'beverage', label: 'Beverage', icon: '🥤' },
  { id: 'dairy', label: 'Dairy', icon: '🥛' },
  { id: 'snack', label: 'Snack', icon: '🍪' },
  { id: 'other', label: 'Other', icon: '📦' },
] as const

function POSPage() {
  const navigate = useNavigate()
  const { username } = useAuth()
  const { t } = useTranslation()
  const [products, setProducts] = useState<ProductResponse[]>([])
  const [cart, setCart] = useState<CartItem[]>([])
  const [search, setSearch] = useState('')
  const [scanInput, setScanInput] = useState('')
  const [discount, setDiscount] = useState('0')
  const [discountMode, setDiscountMode] = useState<'amount' | 'percent'>('amount')
  const [couponCode, setCouponCode] = useState('')
  const [couponApplied, setCouponApplied] = useState<CouponConfig | null>(null)
  const [couponError, setCouponError] = useState('')
  const [paymentMode, setPaymentMode] = useState(loadPaymentMethods()[0] ?? 'cash')
  const [customerName, setCustomerName] = useState('')
  const [customerCredit, setCustomerCredit] = useState('0')
  const [loading, setLoading] = useState(true)
  const [placingOrder, setPlacingOrder] = useState(false)
  const [error, setError] = useState('')
  const [toast, setToast] = useState('')
  const [heldBills, setHeldBills] = useState<HeldBill[]>(() => loadHeldBills())
  const [showHeldBills, setShowHeldBills] = useState(false)
  const [billSaleType, setBillSaleType] = useState<'retail' | 'wholesale'>('retail')
  const [autoPrintReceipt, setAutoPrintReceipt] = useState(false)
  const [categoryFilter, setCategoryFilter] = useState<(typeof CATEGORY_FILTERS)[number]['id']>('all')
  const [, setSessionVersion] = useState(0)
  const [showOpenShiftModal, setShowOpenShiftModal] = useState(false)
  const [showCloseShiftModal, setShowCloseShiftModal] = useState(false)
  const [sessionSubmitting, setSessionSubmitting] = useState(false)
  const [openingAmount, setOpeningAmount] = useState('0')
  const [openingCounts, setOpeningCounts] = useState<DenominationCounts>(() => createEmptyDenominationCounts())
  const [closingCounts, setClosingCounts] = useState<DenominationCounts>(() => createEmptyDenominationCounts())
  const [closingNotes, setClosingNotes] = useState('')

  const [showSplitModal, setShowSplitModal] = useState(false)
  const [splitEntries, setSplitEntries] = useState<SplitEntry[]>([])
  const [selectedCartProductId, setSelectedCartProductId] = useState<string | null>(null)

  const searchInputRef = useRef<HTMLInputElement | null>(null)
  const scannerInputRef = useRef<HTMLInputElement | null>(null)

  const paymentModes = useMemo(() => loadPaymentMethods(), [])
  const paymentModeOptions = useMemo(() => paymentModes.map((mode: string) => ({ label: mode.toUpperCase(), value: mode })), [paymentModes])
  const availableUnits = useMemo(() => loadUnits(), [])
  const gstRatePercent = useMemo(() => loadDefaultGstRatePercent(), [])

  const loadProductsData = useCallback(async () => {
    setLoading(true)
    setError('')
    if (!shouldUseApiProducts()) {
      setProducts([])
      setError('Offline mode is enabled. Switch to online mode to fetch products from API.')
      setLoading(false)
      return
    }

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
    const bootstrap = async () => {
      if (!shouldUseApiProducts()) {
        if (!cancelled) {
          setProducts([])
          setError('Offline mode is enabled. Switch to online mode to fetch products from API.')
          setLoading(false)
        }
        return
      }

      try {
        const result = await listProducts()
        if (!cancelled) {
          setProducts(result)
          setError('')
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

    void bootstrap()
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    if (!toast) return undefined
    const timeout = window.setTimeout(() => setToast(''), 3500)
    return () => window.clearTimeout(timeout)
  }, [toast])

  const activeSession: CashSessionRecord | null = username ? getActiveCashSession(username) : null
  const activeProducts = useMemo(() => products.filter((product) => product.deletedAt === null), [products])
  const shiftOpen = Boolean(activeSession)
  const openingCountedTotal = useMemo(() => sumDenominationCounts(openingCounts), [openingCounts])
  const closingCountedTotal = useMemo(() => sumDenominationCounts(closingCounts), [closingCounts])
  const closingVariance = useMemo(() => Number((closingCountedTotal - (activeSession?.expectedClosing ?? 0)).toFixed(2)), [activeSession?.expectedClosing, closingCountedTotal])
  const filteredProducts = useMemo(() => {
    const query = search.trim().toLowerCase()
    return activeProducts
      .filter((product) => categoryFilter === 'all' || categoryFor(product) === categoryFilter)
      .filter((product) => !query || [product.name, product.unit].some((value) => value.toLowerCase().includes(query)))
  }, [activeProducts, categoryFilter, search])

  const categoryCounts = useMemo(
    () =>
      CATEGORY_FILTERS.reduce<Record<string, number>>((acc, filter) => {
        acc[filter.id] = filter.id === 'all'
          ? activeProducts.length
          : activeProducts.filter((product) => categoryFor(product) === filter.id).length
        return acc
      }, {}),
    [activeProducts],
  )

  const customerSuggestions = useMemo(
    () =>
      [...new Set(heldBills.map((bill) => bill.customerName.trim()).filter(Boolean))]
        .sort((left, right) => left.localeCompare(right)),
    [heldBills],
  )

  const focusSearchInput = useCallback(() => {
    searchInputRef.current?.focus()
  }, [])

  const focusScannerInput = useCallback(() => {
    scannerInputRef.current?.focus()
  }, [])


  const resolveScannedProduct = (rawValue: string) => {
    const normalized = rawValue.trim().toLowerCase()
    if (!normalized) return undefined
    try {
      const decoded = JSON.parse(rawValue) as { productId?: string; code?: string }
      const parsedCode = decoded.productId ?? decoded.code
      if (parsedCode) {
        return activeProducts.find((product) => [product.serverId, product.clientRecordId, product.name].some((value) => value.toLowerCase() === parsedCode.toLowerCase()))
      }
    } catch {
      // ignore
    }
    return activeProducts.find((product) => [product.serverId, product.clientRecordId, product.name, product.unit].some((value) => value.toLowerCase() === normalized))
  }

  const cartSubtotal = useMemo(
    () => cart.reduce((total, item) => total + (item.quantity || 0) * item.product.sellingPrice, 0),
    [cart],
  )
  const itemDiscountTotal = useMemo(() => cart.reduce((sum, item) => sum + (Number.parseFloat(item.itemDiscount) || 0), 0), [cart])
  const discountValue = Number.parseFloat(discount) || 0
  const parsedDiscount = useMemo(
    () =>
      discountMode === 'percent'
        ? Number(((cartSubtotal * Math.min(Math.max(discountValue, 0), 100)) / 100).toFixed(2))
        : discountValue,
    [cartSubtotal, discountMode, discountValue],
  )
  const couponDiscount = useMemo(() => {
    if (!couponApplied) return 0
    if (couponApplied.discountType === 'flat') return couponApplied.discountValue
    return Math.round((cartSubtotal * couponApplied.discountValue) / 100 * 100) / 100
  }, [couponApplied, cartSubtotal])

  const taxable = Math.max(cartSubtotal - itemDiscountTotal - parsedDiscount - couponDiscount, 0)
  const gstTotal = Number((taxable * (gstRatePercent / 100)).toFixed(2))
  const total = Number((taxable + gstTotal).toFixed(2))

  const addToCart = (product: ProductResponse) => {
    if (!shiftOpen) {
      setError('Open cashier shift to start billing.')
      return
    }
    if (product.stockQuantity <= 0) {
      setError(`${product.name} is out of stock.`)
      return
    }

    setError('')
    setSearch('')
    setSelectedCartProductId(product.clientRecordId)
    setCart((current) => {
      const existing = current.find((item) => item.product.clientRecordId === product.clientRecordId)
      if (!existing) {
        return [...current, { product, quantity: 1, unit: product.unit, saleType: billSaleType, itemDiscount: '0' }]
      }
      return current.map((item) => {
        if (item.product.clientRecordId !== product.clientRecordId) return item
        const currentQty = typeof item.quantity === 'number' ? item.quantity : 0
        const nextQuantity = Math.min(currentQty + 1, product.stockQuantity)
        return { ...item, quantity: nextQuantity }
      })
    })
  }

  const updateItem = (productId: string, update: Partial<CartItem>) => {
    setCart((current) => current.map((item) => (item.product.clientRecordId === productId ? { ...item, ...update } : item)))
  }

  const updateQuantity = (productId: string, nextValue: number | '') => {
    setSelectedCartProductId(productId)
    setCart((current) =>
      current.map((item) => {
        if (item.product.clientRecordId !== productId) return item
        if (nextValue === '') return { ...item, quantity: '' }
        const maxQuantity = Math.max(item.product.stockQuantity, 1)
        const safeQuantity = Math.min(Math.max(nextValue, 0), maxQuantity)
        return { ...item, quantity: safeQuantity }
      }),
    )
  }

  const removeItem = (productId: string) => {
    if (selectedCartProductId === productId) {
      setSelectedCartProductId(null)
    }
    setCart((current) => current.filter((item) => item.product.clientRecordId !== productId))
  }

  const resetCart = () => {
    setCart([])
    setSelectedCartProductId(null)
    setDiscount('0')
    setDiscountMode('amount')
    setCustomerName('')
    setCustomerCredit('0')
    setCouponCode('')
    setCouponApplied(null)
    setCouponError('')
    setError('')
    setBillSaleType('retail')
  }

  const updateDenominationCount = (
    setCounts: Dispatch<SetStateAction<DenominationCounts>>,
    denomination: number,
    value: string,
  ) => {
    setCounts((current) => ({
      ...current,
      [denomination]: Math.max(0, Number.parseInt(value, 10) || 0),
    }))
  }

  const handleOpenShift = () => {
    setError('')
    if (!username) {
      setError('Login again to open a cashier shift.')
      return
    }
    if (activeSession) {
      setToast('Cashier shift is already open.')
      return
    }

    setOpeningAmount('0')
    setOpeningCounts(createEmptyDenominationCounts())
    setShowOpenShiftModal(true)
  }

  const handleConfirmOpenShift = () => {
    if (!username) {
      setError('Login again to open a cashier shift.')
      return
    }

    const parsedAmount = Number.parseFloat(openingAmount)
    if (Number.isNaN(parsedAmount) || parsedAmount < 0) {
      setError('Enter a valid opening amount.')
      return
    }

    setSessionSubmitting(true)
    try {
      const session = openCashSession({
        cashierUsername: username,
        openingAmount: parsedAmount,
        openingDenominationCounts: openingCounts,
      })
      setSessionVersion((current) => current + 1)
      setShowOpenShiftModal(false)
      setToast(`Cashier shift opened with ${formatCurrency(session.openingAmount)}.`)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSessionSubmitting(false)
    }
  }

  const handleStartCloseShift = () => {
    setError('')
    if (!activeSession) {
      setError('Open cashier shift before closing it.')
      return
    }
    if (cart.length) {
      setError('Finish, hold, or clear the current bill before closing shift.')
      return
    }

    setClosingCounts(createEmptyDenominationCounts())
    setClosingNotes('')
    setShowCloseShiftModal(true)
  }

  const handleConfirmCloseShift = () => {
    if (!username || !activeSession) {
      setError('No active cashier shift found.')
      return
    }

    setSessionSubmitting(true)
    try {
      const closedSession = closeCashSession({
        cashierUsername: username,
        closingAmount: closingCountedTotal,
        closingDenominationCounts: closingCounts,
        closedBy: username,
        notes: closingNotes,
      })
      setSessionVersion((current) => current + 1)
      setShowCloseShiftModal(false)
      setClosingNotes('')
      setClosingCounts(createEmptyDenominationCounts())
      setToast(buildCashDifferenceMessage(closedSession.difference ?? 0))
      resetCart()
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSessionSubmitting(false)
    }
  }

  const handleScanAdd = () => {
    const found = resolveScannedProduct(scanInput)
    if (!found) {
      setError(`No product matched scanner input: "${scanInput}"`)
      return
    }
    addToCart(found)
    setScanInput('')
  }

  const applyCoupon = () => {
    const code = couponCode.trim().toUpperCase()
    if (!code) {
      setCouponError('Enter a coupon code.')
      return
    }

    const coupons = loadCoupons()
    const found = coupons.find((c) => c.code === code && c.active)
    if (!found) {
      setCouponError('Invalid or inactive coupon code.')
      return
    }

    if (cartSubtotal < found.minOrderAmount) {
      setCouponError(`Minimum order amount ₹${found.minOrderAmount} required.`)
      return
    }

    setCouponApplied(found)
    setCouponError('')
  }

  const holdBill = () => {
    if (!cart.length) {
      setError('Nothing in cart to hold.')
      return
    }

    const held: HeldBill = {
      id: generateUUID(),
      label: customerName.trim() || `Bill ${new Date().toLocaleTimeString()}`,
      cart,
      customerName,
      discount,
      billSaleType,
      savedAt: new Date().toISOString(),
    }

    const next = [...heldBills, held]
    saveHeldBills(next)
    setHeldBills(next)
    resetCart()
    setToast('Bill held. Resume it from the held bills panel.')
  }

  const resumeBill = (held: HeldBill) => {
    setCart(held.cart)
    setCustomerName(held.customerName)
    setDiscount(held.discount)
    setBillSaleType(held.billSaleType)
    const next = heldBills.filter((b) => b.id !== held.id)
    saveHeldBills(next)
    setHeldBills(next)
    setShowHeldBills(false)
    setToast(`Resumed bill for ${held.label}.`)
  }

  const removeCoupon = () => {
    setCouponApplied(null)
    setCouponCode('')
    setCouponError('')
  }

  const splitTotal = useMemo(() => splitEntries.reduce((sum, e) => sum + (parseFloat(e.amount) || 0), 0), [splitEntries])

  const openSplitModal = () => {
    setSplitEntries([
      { mode: paymentModes[0] ?? 'cash', amount: String(total) },
      { mode: paymentModes[1] ?? 'upi', amount: '0' },
    ])
    setShowSplitModal(true)
  }

  const maybePrintReceipt = (billNumber: string) => {
    if (!autoPrintReceipt) return
    const printWindow = window.open('', '_blank', 'width=380,height=640')
    if (!printWindow) return
    const safeBillNumber = escapeHtml(billNumber)
    const safeCustomer = escapeHtml(customerName || 'Walk-in')
    const safeTotal = escapeHtml(currency.format(total))
    printWindow.document.write(`<html><body><h3>Receipt ${safeBillNumber}</h3><p>Customer: ${safeCustomer}</p><p>Total: ${safeTotal}</p></body></html>`)
    printWindow.document.close()
    printWindow.print()
  }

  const handlePlaceOrder = async (overridePaymentMode?: string, splitSummary?: string) => {
    if (!shiftOpen) {
      setError('Open cashier shift before placing order.')
      return
    }
    if (!cart.length) {
      setError('Add at least one product to place an order.')
      return
    }

    setPlacingOrder(true)
    setError('')

    const clientRecordId = generateUUID()
    const billNumber = `BIL-${clientRecordId.slice(0, 8).toUpperCase()}`

    try {
      const effectivePaymentMode = overridePaymentMode ?? paymentMode
      const response = await upsertBill({
        clientRecordId,
        billNumber,
        billType: billSaleType,
        customerName: customerName.trim() || undefined,
        totalAmount: Number(total.toFixed(2)),
        discountAmount: Number((parsedDiscount + itemDiscountTotal).toFixed(2)),
        couponCode: couponApplied?.code,
        couponDiscountAmount: couponDiscount ? Number(couponDiscount.toFixed(2)) : undefined,
        gstTotal,
        cgstTotal: Number((gstTotal / 2).toFixed(2)),
        sgstTotal: Number((gstTotal / 2).toFixed(2)),
        paymentMode: effectivePaymentMode,
        splitPaymentSummary: splitSummary,
        items: cart.map((item) => ({
          productId: item.product.serverId,
          productName: item.product.name,
          unit: item.unit,
          quantity: item.quantity,
          unitPrice: item.product.sellingPrice,
          totalPrice: Number((item.quantity * item.product.sellingPrice).toFixed(2)),
          itemDiscountType: 'flat',
          itemDiscountValue: Number(item.itemDiscount || '0'),
          discountAmount: Number(item.itemDiscount || '0'),
          gstRate: gstRatePercent,
        })),
        version: 1,
        updatedAt: new Date().toISOString(),
      })

      if (username) {
        const cashCollected = calculateCashCollected(effectivePaymentMode, total, splitSummary)
        if (cashCollected > 0) {
          addCashCollection(username, cashCollected)
          setSessionVersion((current) => current + 1)
        }
      }

      setToast(response.status === 'duplicate' ? `Bill already recorded (${response.clientRecordId}).` : `Order placed successfully. Bill number: ${billNumber}`)
      maybePrintReceipt(billNumber)

      // Save bill data for BillViewPage and navigate there
      const billSnapshot = {
        clientRecordId,
        billNumber,
        customerName: customerName.trim() || undefined,
        totalAmount: Number(total.toFixed(2)),
        discountAmount: Number((parsedDiscount + itemDiscountTotal).toFixed(2)),
        couponCode: couponApplied?.code,
        couponDiscountAmount: couponDiscount ? Number(couponDiscount.toFixed(2)) : undefined,
        gstTotal,
        cgstTotal: Number((gstTotal / 2).toFixed(2)),
        sgstTotal: Number((gstTotal / 2).toFixed(2)),
        paymentMode: effectivePaymentMode,
        createdAt: new Date().toISOString(),
        items: cart.map((item) => ({
          productName: item.product.name,
          quantity: item.quantity,
          unit: item.unit,
          unitPrice: item.product.sellingPrice,
          totalPrice: Number((item.quantity * item.product.sellingPrice).toFixed(2)),
          discountAmount: Number(item.itemDiscount || '0'),
        })),
      }
      localStorage.setItem(`nn_last_bill_${clientRecordId}`, JSON.stringify(billSnapshot))
      setProducts((current) =>
        current.map((product) => {
          const cartItem = cart.find((item) => item.product.clientRecordId === product.clientRecordId)
          if (!cartItem) return product
          return { ...product, stockQuantity: Math.max(product.stockQuantity - cartItem.quantity, 0) }
        }),
      )
      resetCart()
      navigate(`/bill-view/${clientRecordId}`)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setPlacingOrder(false)
    }
  }

  useEffect(() => {
    const handleKeyboardShortcut = (event: KeyboardEvent) => {
      if (event.key === 'F2') {
        event.preventDefault()
        focusSearchInput()
        return
      }

      if (event.key === 'F3') {
        event.preventDefault()
        focusScannerInput()
        return
      }

      if (event.key === 'F10') {
        event.preventDefault()
        if (!placingOrder) {
          void handlePlaceOrder()
        }
        return
      }

      if (event.key === 'Escape') {
        event.preventDefault()
        if (showSplitModal) {
          setShowSplitModal(false)
          return
        }
        if (showHeldBills) {
          setShowHeldBills(false)
          return
        }
        if (showOpenShiftModal) {
          setShowOpenShiftModal(false)
          return
        }
        if (showCloseShiftModal) {
          setShowCloseShiftModal(false)
          return
        }
        resetCart()
        return
      }

      if ((event.key === '+' || event.key === '=') && selectedCartProductId) {
        event.preventDefault()
        const item = cart.find((entry) => entry.product.clientRecordId === selectedCartProductId)
        if (item) {
          updateQuantity(selectedCartProductId, item.quantity + 1)
        }
      }

      if ((event.key === '-' || event.key === '_') && selectedCartProductId) {
        event.preventDefault()
        const item = cart.find((entry) => entry.product.clientRecordId === selectedCartProductId)
        if (item) {
          updateQuantity(selectedCartProductId, item.quantity - 1)
        }
      }
    }

    window.addEventListener('keydown', handleKeyboardShortcut)
    return () => window.removeEventListener('keydown', handleKeyboardShortcut)
  }, [
    cart,
    focusScannerInput,
    focusSearchInput,
    handlePlaceOrder,
    placingOrder,
    selectedCartProductId,
    showCloseShiftModal,
    showHeldBills,
    showOpenShiftModal,
    showSplitModal,
  ])

  if (loading) return <Spinner label="Loading products..." />

  return (
    <div className="pos-page-wrapper" style={{ minHeight: '100vh', background: 'linear-gradient(135deg, #e0e7ff 0%, #f3e8ff 100%)', padding: '16px' }}>
      <div className="pos-layout">
        
        {/* Left Column: Header, Filters, Scanner, Products */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          <div className="pos-glass-panel">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
              <div>
                <h1 className="pos-title">Billing Console</h1>
                <div className="pos-subtitle">
                  {shiftOpen ? 'Browse products, manage cart, and complete billing quickly.' : 'Open cashier shift before billing.'}
                </div>
              </div>
              <div className={`pos-badge ${shiftOpen ? 'pos-badge-success' : 'pos-badge-error'}`}>
                {shiftOpen ? 'Shift Open' : 'Shift Closed'}
              </div>
            </div>

            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              <button type="button" className={`pos-btn ${shiftOpen ? 'pos-btn-danger' : 'pos-btn-primary'}`} onClick={shiftOpen ? handleStartCloseShift : handleOpenShift}>
                {shiftOpen ? 'Close Shift' : 'Open Shift'}
              </button>
              <button type="button" className="pos-btn" onClick={resetCart}>New Bill</button>
              <button type="button" className="pos-btn" onClick={holdBill} disabled={!cart.length}>{t.holdBill.replace(' (F7)', '')}</button>
              <button type="button" className="pos-btn" onClick={() => void loadProductsData()}>Refresh</button>
              <button type="button" className="pos-btn" onClick={handleScanAdd} aria-label="Add by scan">Scan (F3)</button>
              {heldBills.length > 0 && (
                <button type="button" className="pos-btn pos-btn-primary" onClick={() => setShowHeldBills(true)}>
                  Resume Held ({heldBills.length})
                </button>
              )}
            </div>
            
            {!shiftOpen && (
              <div style={{ marginTop: '16px', padding: '12px', background: 'rgba(239, 68, 68, 0.1)', color: 'var(--pos-danger)', borderRadius: 'var(--pos-radius-sm)', fontSize: '0.9rem' }}>
                No active cashier shift. Open shift with opening denomination counts to start billing.
              </div>
            )}
            {shiftOpen && activeSession && (
              <div style={{ marginTop: '16px', padding: '12px', background: 'rgba(16, 185, 129, 0.1)', color: 'var(--pos-success)', borderRadius: 'var(--pos-radius-sm)', fontSize: '0.9rem' }}>
                Cashier session active. Opened {formatSessionTimestamp(activeSession.openedAt)}
              </div>
            )}
          </div>

          <div className="pos-glass-panel">
            <h2 className="pos-section-title">Category Filter</h2>
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              {CATEGORY_FILTERS.map(filter => (
                <button
                  key={filter.id}
                  type="button"
                  className={`pos-btn ${categoryFilter === filter.id ? 'pos-btn-primary' : ''}`}
                  onClick={() => setCategoryFilter(filter.id)}
                  style={{ flex: 1, padding: '8px' }}
                >
                  {filter.label} ({categoryCounts[filter.id] ?? 0})
                </button>
              ))}
            </div>
          </div>

          <div className="pos-glass-panel">
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
              <div className="pos-input-group">
                <label className="pos-label">
                  <span>Scan barcode</span>
                  <span className="pos-shortcut">F3</span>
                </label>
                <input
                  ref={scannerInputRef}
                  className="pos-input"
                  value={scanInput}
                  onChange={e => setScanInput(e.target.value)}
                  onKeyDown={e => {
                    if (e.key === 'Enter') {
                      e.preventDefault()
                      if (!scanInput.trim()) {
                        document.getElementById('pos-customer-name')?.focus()
                      } else {
                        handleScanAdd()
                      }
                    }
                  }}
                  placeholder="Scan or type barcode (F3)"
                />
              </div>
              <div className="pos-input-group">
                <label className="pos-label">
                  <span>Search products</span>
                  <span className="pos-shortcut">F2</span>
                </label>
                <input
                  id="pos-search-input"
                  ref={searchInputRef}
                  className="pos-input"
                  value={search}
                  onChange={e => setSearch(e.target.value)}
                  onKeyDown={e => {
                    if (e.key === 'Enter') {
                      e.preventDefault()
                      if (!search.trim()) {
                        document.getElementById('pos-customer-name')?.focus()
                      } else {
                        document.getElementById('pos-product-btn-0')?.focus()
                      }
                    }
                  }}
                  placeholder={t.searchProducts}
                />
              </div>
            </div>
          </div>

          {error && <div style={{ padding: '12px', background: 'rgba(239, 68, 68, 0.1)', color: 'var(--pos-danger)', borderRadius: 'var(--pos-radius-md)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>{error}</div>}
          {toast && <div style={{ padding: '12px', background: 'rgba(16, 185, 129, 0.1)', color: 'var(--pos-success)', borderRadius: 'var(--pos-radius-md)', border: '1px solid rgba(16, 185, 129, 0.3)' }}>{toast}</div>}

          <div className="pos-glass-panel">
            <h2 className="pos-section-title">Products <span style={{ fontSize: '0.8rem', color: 'var(--pos-text-muted)', fontWeight: 'normal', marginLeft: 'auto' }}>{activeProducts.length} active products</span></h2>
            
            {filteredProducts.length ? (
              <div className="pos-product-grid">
                {filteredProducts.map((item, index) => {
                  const cartQuantity = cart.find(cartItem => cartItem.product.clientRecordId === item.clientRecordId)?.quantity ?? 0
                  const remainingStock = Math.max(item.stockQuantity - cartQuantity, 0)
                  return (
                    <ProductCard
                      key={item.clientRecordId}
                      index={index}
                      product={item}
                      remainingStock={remainingStock}
                      shiftOpen={shiftOpen}
                      onAddToCart={addToCart}
                    />
                  )
                })}
              </div>
            ) : (
              <div style={{ padding: '32px', textAlign: 'center', color: 'var(--pos-text-muted)', background: 'rgba(0,0,0,0.02)', borderRadius: 'var(--pos-radius-md)' }}>
                No products found.
              </div>
            )}
          </div>

        </div>

        {/* Right Column: Cart Panel */}
        <div>
          <CartPanel
            cart={cart}
            availableUnits={availableUnits}
            customerName={customerName}
            customerCredit={customerCredit}
            onCustomerNameChange={setCustomerName}
            onCustomerCreditChange={setCustomerCredit}
            discount={discount}
            discountMode={discountMode}
            onDiscountChange={setDiscount}
            onDiscountModeChange={setDiscountMode}
            couponCode={couponCode}
            couponError={couponError}
            couponAppliedCode={couponApplied?.code}
            couponDiscountLabel={couponDiscount ? currency.format(couponDiscount) : undefined}
            onCouponCodeChange={setCouponCode}
            onApplyCoupon={applyCoupon}
            onRemoveCoupon={removeCoupon}
            billSaleType={billSaleType}
            onBillSaleTypeChange={setBillSaleType}
            paymentMode={paymentMode}
            paymentModeOptions={paymentModeOptions}
            onPaymentModeChange={setPaymentMode}
            autoPrintReceipt={autoPrintReceipt}
            onAutoPrintChange={setAutoPrintReceipt}
            onOpenLedger={() => setToast(`Ledger for ${customerName || 'walk-in'} will open in customer ledger module.`)}
            onRemoveItem={removeItem}
            onUpdateItem={updateItem}
            onUpdateQuantity={updateQuantity}
            selectedCartProductId={selectedCartProductId}
            onSelectCartProductId={setSelectedCartProductId}
            cartSubtotal={cartSubtotal}
            itemDiscountTotal={itemDiscountTotal}
            parsedDiscount={parsedDiscount}
            couponDiscount={couponDiscount}
            gstRatePercent={gstRatePercent}
            gstTotal={gstTotal}
            total={total}
            placingOrder={placingOrder}
            shiftOpen={shiftOpen}
            onOpenSplit={openSplitModal}
            onPlaceOrder={() => void handlePlaceOrder()}
            customerSuggestions={customerSuggestions}
          />
        </div>
      </div>

      {/* Modals */}
      {showOpenShiftModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4" style={{ backdropFilter: 'blur(4px)' }}>
          <div className="w-full max-w-2xl rounded-3xl bg-white p-6 shadow-2xl">
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 className="text-xl font-semibold text-slate-900">Open Cashier Shift</h2>
                <p className="mt-1 text-sm text-slate-500">Capture opening cash and denomination count before billing starts.</p>
              </div>
              <button type="button" onClick={() => setShowOpenShiftModal(false)} className="rounded-full p-2 text-slate-400 hover:bg-slate-100">✕</button>
            </div>

            <div className="space-y-4">
              <label className="block text-sm font-medium text-slate-700">
                Opening Amount
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={openingAmount}
                  onChange={(e) => setOpeningAmount(e.target.value)}
                  className="mt-2 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-900 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </label>

              <div>
                <div className="mb-2 flex items-center justify-between">
                  <p className="text-sm font-medium text-slate-700">Opening denominations</p>
                  <button type="button" onClick={() => setOpeningAmount(String(openingCountedTotal))} className="text-sm font-semibold text-indigo-600 hover:text-indigo-700">Use counted total {formatCurrency(openingCountedTotal)}</button>
                </div>
                <div className="grid gap-3 md:grid-cols-2">
                  {CASH_SESSION_DENOMINATIONS.map((denomination) => (
                    <label key={denomination} className="rounded-xl border border-slate-200 p-3 text-sm font-medium text-slate-700">
                      ₹{denomination}
                      <input
                        type="number"
                        min="0"
                        value={openingCounts[denomination] ?? 0}
                        onChange={(e) => updateDenominationCount(setOpeningCounts, denomination, e.target.value)}
                        className="mt-2 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      />
                    </label>
                  ))}
                </div>
              </div>
            </div>

            <div className="mt-5 flex justify-between text-sm text-slate-500 border-t pt-4">
              <span>Counted total: {formatCurrency(openingCountedTotal)}</span>
              <span>Entered opening: {formatCurrency(Number.parseFloat(openingAmount) || 0)}</span>
            </div>
            <div className="mt-5 flex justify-end gap-3">
              <button type="button" onClick={() => setShowOpenShiftModal(false)} className="rounded-2xl border border-slate-200 px-5 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50">Cancel</button>
              <button type="button" disabled={sessionSubmitting} onClick={handleConfirmOpenShift} className="rounded-2xl bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:bg-slate-300">{sessionSubmitting ? 'Opening...' : 'Start Shift'}</button>
            </div>
          </div>
        </div>
      )}

      {showCloseShiftModal && activeSession && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4" style={{ backdropFilter: 'blur(4px)' }}>
          <div className="w-full max-w-2xl rounded-3xl bg-white p-6 shadow-2xl">
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 className="text-xl font-semibold text-slate-900">Close Cashier Shift</h2>
                <p className="mt-1 text-sm text-slate-500">Count closing cash and compare it with the expected amount.</p>
              </div>
              <button type="button" onClick={() => setShowCloseShiftModal(false)} className="rounded-full p-2 text-slate-400 hover:bg-slate-100">✕</button>
            </div>

            <div className="grid gap-3 rounded-2xl border border-slate-200 bg-slate-50 p-4 md:grid-cols-3">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Opening</p>
                <p className="mt-1 text-lg font-semibold text-slate-900">{formatCurrency(activeSession.openingAmount)}</p>
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Cash collected</p>
                <p className="mt-1 text-lg font-semibold text-slate-900">{formatCurrency(activeSession.totalCashCollected)}</p>
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Expected closing</p>
                <p className="mt-1 text-lg font-semibold text-slate-900">{formatCurrency(activeSession.expectedClosing)}</p>
              </div>
            </div>

            <div className="mt-4 grid gap-3 md:grid-cols-2">
              {CASH_SESSION_DENOMINATIONS.map((denomination) => (
                <label key={denomination} className="rounded-xl border border-slate-200 p-3 text-sm font-medium text-slate-700">
                  ₹{denomination}
                  <input
                    type="number"
                    min="0"
                    value={closingCounts[denomination] ?? 0}
                    onChange={(e) => updateDenominationCount(setClosingCounts, denomination, e.target.value)}
                    className="mt-2 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  />
                </label>
              ))}
            </div>

            <label className="mt-4 block text-sm font-medium text-slate-700">
              Closing notes
              <textarea value={closingNotes} onChange={(e) => setClosingNotes(e.target.value)} rows={3} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500" placeholder="Optional closing notes" />
            </label>

            <div className="mt-5 grid gap-3 rounded-2xl border border-slate-200 bg-slate-50 p-4 md:grid-cols-3">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Counted cash</p>
                <p className="mt-1 text-lg font-semibold text-slate-900">{formatCurrency(closingCountedTotal)}</p>
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Variance</p>
                <p className={`mt-1 text-lg font-semibold ${Math.abs(closingVariance) < 0.01 ? 'text-emerald-700' : 'text-rose-700'}`}>{formatCurrency(closingVariance)}</p>
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Opened at</p>
                <p className="mt-1 text-sm font-semibold text-slate-900">{formatSessionTimestamp(activeSession.openedAt)}</p>
              </div>
            </div>

            <div className="mt-5 flex justify-end gap-3 border-t pt-4">
              <button type="button" onClick={() => setShowCloseShiftModal(false)} className="rounded-2xl border border-slate-200 px-5 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50">Cancel</button>
              <button type="button" disabled={sessionSubmitting} onClick={handleConfirmCloseShift} className="rounded-2xl bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:bg-slate-300">{sessionSubmitting ? 'Closing...' : 'Close Shift'}</button>
            </div>
          </div>
        </div>
      )}

      {showHeldBills && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4" style={{ backdropFilter: 'blur(4px)' }}>
          <div className="w-full max-w-lg rounded-3xl bg-white p-6 shadow-2xl">
            <div className="mb-5 flex items-start justify-between gap-4">
              <h2 className="text-xl font-semibold text-slate-900">Held Bills</h2>
              <button type="button" onClick={() => setShowHeldBills(false)} className="rounded-full p-2 text-slate-400 hover:bg-slate-100">✕</button>
            </div>
            {heldBills.length ? heldBills.map((held) => (
              <div key={held.id} className="mb-3 flex items-center justify-between gap-3 rounded-2xl border border-slate-200 p-4 hover:border-indigo-200 transition-colors">
                <div>
                  <p className="font-semibold text-slate-800">{held.label}</p>
                  <p className="text-xs text-slate-500">{held.cart.length} item(s) · {held.billSaleType}</p>
                </div>
                <div className="flex gap-2">
                  <button type="button" onClick={() => resumeBill(held)} className="rounded-xl bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700">Resume</button>
                </div>
              </div>
            )) : <p className="text-sm text-slate-500 text-center py-4">No held bills.</p>}
          </div>
        </div>
      )}

      {showSplitModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4" style={{ backdropFilter: 'blur(4px)' }}>
          <div className="w-full max-w-md rounded-3xl bg-white p-6 shadow-2xl">
            <div className="mb-5 flex items-start justify-between gap-4">
              <h2 className="text-xl font-semibold text-slate-900">Split Payment</h2>
              <button type="button" onClick={() => setShowSplitModal(false)} className="rounded-full p-2 text-slate-400 hover:bg-slate-100">✕</button>
            </div>
            <div className="space-y-3">
              {splitEntries.map((entry, index) => (
                <div key={index} className="flex items-center gap-3">
                  <select 
                    value={entry.mode} 
                    onChange={(e) => setSplitEntries(splitEntries.map((s, i) => (i === index ? { ...s, mode: e.target.value } : s)))} 
                    className="flex-1 rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-indigo-500 focus:outline-none"
                  >
                    {paymentModes.map((m: string) => <option key={m} value={m}>{m.toUpperCase()}</option>)}
                  </select>
                  <input 
                    type="number" 
                    min="0" 
                    value={entry.amount} 
                    onChange={(e) => setSplitEntries(splitEntries.map((s, i) => (i === index ? { ...s, amount: e.target.value } : s)))} 
                    className="w-28 rounded-xl border border-slate-200 px-3 py-2.5 text-sm focus:border-indigo-500 focus:outline-none" 
                  />
                </div>
              ))}
            </div>
            <div className="mt-4 flex justify-between text-sm bg-slate-50 p-3 rounded-xl border border-slate-100">
              <span className="font-medium text-slate-700">Split total: {currency.format(splitTotal)}</span>
              {Math.abs(splitTotal - total) > 0.01 && (
                <span className="font-semibold text-rose-600">Remaining: {currency.format(total - splitTotal)}</span>
              )}
            </div>
            <div className="mt-5 flex justify-end gap-3">
              <button type="button" onClick={() => setShowSplitModal(false)} className="rounded-2xl border border-slate-200 px-5 py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50">Cancel</button>
              <button 
                type="button" 
                disabled={placingOrder || Math.abs(splitTotal - total) > 0.01} 
                onClick={() => { 
                  setShowSplitModal(false); 
                  void handlePlaceOrder('split', JSON.stringify(splitEntries.filter((e) => (parseFloat(e.amount) || 0) > 0))) 
                }} 
                className="rounded-2xl bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700 disabled:bg-slate-300"
              >
                {placingOrder ? 'Placing...' : 'Confirm & Place'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default POSPage
