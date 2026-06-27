import { apiClient } from './client'
import type {
  SaleReturnUpsertRequest,
  SaleReturnUpsertResponse,
} from '../types'

export const upsertSaleReturn = async (payload: SaleReturnUpsertRequest) => {
  const { data } = await apiClient.post<SaleReturnUpsertResponse>('/sale-returns/upsert', payload)
  return data
}

export const listSaleReturns = async (params?: { since?: string; limit?: number }) => {
  const { data } = await apiClient.get<{ saleReturns: unknown[] }>('/sale-returns', { params })
  return data.saleReturns
}
