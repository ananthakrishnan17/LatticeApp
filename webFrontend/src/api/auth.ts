import { apiClient, getStoredBaseUrl, normalizeBaseUrl } from './client'
import type { BootstrapRequest, BootstrapResponse, LoginRequest, LoginResponse } from '../types'

const buildRequestConfig = (baseUrl: string) => {
  const effective = normalizeBaseUrl(baseUrl) || getStoredBaseUrl()
  if (!effective) {
    return undefined
  }

  return { baseURL: effective }
}

export const login = async (baseUrl: string, payload: LoginRequest) => {
  const { data } = await apiClient.post<LoginResponse>('/auth/login', payload, buildRequestConfig(baseUrl))
  return data
}

export const bootstrap = async (baseUrl: string, payload: BootstrapRequest) => {
  const { data } = await apiClient.post<BootstrapResponse>('/auth/bootstrap', payload, buildRequestConfig(baseUrl))
  return data
}

export const health = async (baseUrl: string) => {
  const { data } = await apiClient.get<string>('/auth/health', buildRequestConfig(baseUrl))
  return data
}
