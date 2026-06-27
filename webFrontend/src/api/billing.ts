import { apiClient } from './client'
import type { BillUpsertRequest, BillUpsertResponse } from '../types'

export const upsertBill = async (payload: BillUpsertRequest) => {
  const { data } = await apiClient.post<BillUpsertResponse>('/bills/upsert', payload)
  return data
}
