import { apiClient } from './client'
import type { ActivateSubscriptionRequest, SubscriptionStatusResponse } from '../types'

export const getSubscriptionStatus = async () => {
  try {
    const { data } = await apiClient.get<SubscriptionStatusResponse>('/subscription')
    return data
  } catch {
    const { data } = await apiClient.get<SubscriptionStatusResponse>('/subscription/status')
    return data
  }
}

export const activateSubscription = async (payload: ActivateSubscriptionRequest) => {
  const { data } = await apiClient.post<SubscriptionStatusResponse>('/subscription/activate', payload)
  return data
}
