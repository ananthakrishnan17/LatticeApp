import { apiClient } from './client'
import type {
  PurchaseUpsertRequest,
  PurchaseUpsertResponse,
} from '../types'

export const upsertPurchase = async (payload: PurchaseUpsertRequest) => {
  const { data } = await apiClient.post<PurchaseUpsertResponse>('/purchases/upsert', payload)
  return data
}

export const listPurchases = async (params?: { since?: string; limit?: number }) => {
  const { data } = await apiClient.get<{ purchases: unknown[] }>('/purchases', { params })
  return data.purchases
}
