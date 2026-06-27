import { apiClient } from './client'
import type {
  PurchaseReturnUpsertRequest,
  PurchaseReturnUpsertResponse,
} from '../types'

export const upsertPurchaseReturn = async (payload: PurchaseReturnUpsertRequest) => {
  const { data } = await apiClient.post<PurchaseReturnUpsertResponse>('/purchase-returns/upsert', payload)
  return data
}

export const listPurchaseReturns = async (params?: { since?: string; limit?: number }) => {
  const { data } = await apiClient.get<{ purchaseReturns: unknown[] }>('/purchase-returns', { params })
  return data.purchaseReturns
}
