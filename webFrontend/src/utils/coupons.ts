import type { CouponConfig } from '../types'

export const COUPONS_KEY = 'nn_coupons'
export const PAYMENT_METHODS_KEY = 'nn_payment_methods'
export const DEFAULT_PAYMENT_METHODS = ['cash', 'card', 'upi', 'bank-transfer']

export function loadCoupons(): CouponConfig[] {
  try {
    const raw = localStorage.getItem(COUPONS_KEY)
    return raw ? (JSON.parse(raw) as CouponConfig[]) : []
  } catch {
    return []
  }
}

export function saveCoupons(coupons: CouponConfig[]) {
  localStorage.setItem(COUPONS_KEY, JSON.stringify(coupons))
}

export function loadPaymentMethods(): string[] {
  try {
    const raw = localStorage.getItem(PAYMENT_METHODS_KEY)
    const parsed = raw ? (JSON.parse(raw) as string[]) : []
    return parsed.length ? parsed : DEFAULT_PAYMENT_METHODS
  } catch {
    return DEFAULT_PAYMENT_METHODS
  }
}

export function savePaymentMethods(methods: string[]) {
  localStorage.setItem(PAYMENT_METHODS_KEY, JSON.stringify(methods))
}
