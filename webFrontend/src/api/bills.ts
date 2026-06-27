import { apiClient } from './client'

export interface BillItemRecord {
  product_name: string
  product_sku?: string | null
  unit: string
  quantity: number
  unit_price: number
  purchase_price?: number
  total_price: number
  gst_rate?: number
  discount_amount?: number
  item_discount_type?: string
  item_discount_value?: number
}

export interface BillRecord {
  server_id: string
  client_record_id: string
  bill_number: string
  bill_type: string
  customer_name: string | null
  customer_address: string | null
  customer_gstin: string | null
  total_amount: number
  total_profit: number
  discount_amount: number
  gst_total: number
  cgst_total: number
  sgst_total: number
  igst_total: number
  payment_mode: string
  coupon_code: string | null
  coupon_discount_amount: number
  cash_tendered: number | null
  change_amount: number | null
  split_payment_summary: string | null
  created_at: string
  updated_at: string
  items: BillItemRecord[]
}

export const listBills = async (params?: { since?: string; limit?: number; billNumber?: string }) => {
  const { data } = await apiClient.get<{ bills: BillRecord[] }>('/bills', { params })
  return data.bills ?? []
}
