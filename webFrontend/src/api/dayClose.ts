import { apiClient } from './client'
import type {
  DayCloseUpsertRequest,
  DayCloseUpsertResponse,
} from '../types'

export const upsertDayClose = async (payload: DayCloseUpsertRequest) => {
  const { data } = await apiClient.post<DayCloseUpsertResponse>('/day-close/upsert', payload)
  return data
}

export const listDayCloseRecords = async (params?: { since?: string; limit?: number }) => {
  const { data } = await apiClient.get<{ dayCloseRecords: unknown[] }>('/day-close', { params })
  return data.dayCloseRecords
}
