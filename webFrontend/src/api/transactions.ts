import { apiClient } from './client'
import type { TransactionUpsertRequest, TransactionUpsertResponse, TransactionRecord } from '../types'

export const upsertTransaction = async (payload: TransactionUpsertRequest) => {
  const { data } = await apiClient.post<TransactionUpsertResponse>('/transactions/upsert', payload)
  return data
}

export const listTransactions = async (params?: { types?: string; since?: string; limit?: number }) => {
  const { data } = await apiClient.get<{ transactions: TransactionRecord[] }>('/transactions', { params })
  return data.transactions
}
