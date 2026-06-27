import axios, { AxiosError, type InternalAxiosRequestConfig } from 'axios'
import { appBasePath } from '../config/appBasePath'

export const STORAGE_KEYS = {
  token: 'nn_token',
  baseUrl: 'nn_baseUrl',
  legacyBaseUrl: 'baseUrl',
  tenantId: 'nn_tenantId',
  deviceId: 'nn_deviceId',
  role: 'nn_role',
  username: 'nn_username',
  shopInfo: 'nn_shopInfo',
  language: 'nn_language',
  printerSettings: 'nn_printerSettings',
  /** 'online' | 'offline' — determines which backend the app talks to */
  licenseMode: 'nn_licenseMode',
  /** Backend base URL used when licenseMode === 'offline' (e.g. http://localhost:8080) */
  offlineBaseUrl: 'nn_offlineBaseUrl',
  /** ISO-8601 timestamp of the last successful login — used for offline 3-day session */
  loginAt: 'nn_loginAt',
  /** JSON-serialized UserResponse cached at login time for offline session restore */
  cachedUser: 'nn_cachedUser',
} as const

export type LicenseMode = 'online' | 'offline'

export const OFFLINE_SESSION_DAYS = 3

export const normalizeBaseUrl = (value: string) => value.trim().replace(/\/+$/, '')
const LOCAL_DEV_BACKEND_BASE_URL = 'http://localhost:8080'
const normalizedAppBasePath = normalizeBaseUrl(appBasePath) || '/'

const isFrontendAppUrl = (value: string) => {
  const normalized = normalizeBaseUrl(value)
  if (!normalized) {
    return false
  }

  try {
    const url = new URL(normalized)
    if (url.origin !== window.location.origin) {
      return false
    }
    const normalizedPath = normalizeBaseUrl(url.pathname) || '/'
    return normalizedPath === normalizedAppBasePath
  } catch {
    return false
  }
}

const resolveDefaultBaseUrl = () => {
  const configuredBaseUrl = normalizeBaseUrl(import.meta.env.VITE_API_BASE_URL ?? '')
  if (configuredBaseUrl) {
    return configuredBaseUrl
  }

  return import.meta.env.DEV ? LOCAL_DEV_BACKEND_BASE_URL : window.location.origin
}

export const resolveRequestBaseUrl = (value: string) => normalizeBaseUrl(value)

/**
 * Returns the stored backend base URL.
 * Falls back to VITE_API_BASE_URL when provided and localhost during
 * Vite local development.
 */
export const getStoredBaseUrl = () => {
  const value = localStorage.getItem(STORAGE_KEYS.baseUrl) ?? localStorage.getItem(STORAGE_KEYS.legacyBaseUrl) ?? ''
  const normalized = normalizeBaseUrl(value)
  if (normalized && !isFrontendAppUrl(normalized)) {
    return normalized
  }

  const fallback = resolveDefaultBaseUrl()
  if (fallback && fallback !== normalized) {
    setStoredBaseUrl(fallback)
  }
  return fallback
}

export const setStoredBaseUrl = (value: string) => {
  const normalized = normalizeBaseUrl(value)
  localStorage.setItem(STORAGE_KEYS.baseUrl, normalized)
  localStorage.setItem(STORAGE_KEYS.legacyBaseUrl, normalized)
}

export const getStoredToken = () => localStorage.getItem(STORAGE_KEYS.token)
export const getStoredTenantId = () => localStorage.getItem(STORAGE_KEYS.tenantId)
export const getStoredDeviceId = () => localStorage.getItem(STORAGE_KEYS.deviceId)

export const getStoredLicenseMode = (): LicenseMode => {
  const raw = localStorage.getItem(STORAGE_KEYS.licenseMode)
  const normalized = raw?.trim().toLowerCase()
  return normalized === 'offline' ? 'offline' : 'online'
}

export const setStoredLicenseMode = (mode: LicenseMode) =>
  localStorage.setItem(STORAGE_KEYS.licenseMode, mode)

export const getStoredOfflineBaseUrl = () =>
  normalizeBaseUrl(localStorage.getItem(STORAGE_KEYS.offlineBaseUrl) ?? '')

export const setStoredOfflineBaseUrl = (value: string) =>
  localStorage.setItem(STORAGE_KEYS.offlineBaseUrl, normalizeBaseUrl(value))

/** Returns ms since last login, or Infinity if never recorded. */
export const getLoginAgeMsec = () => {
  const raw = localStorage.getItem(STORAGE_KEYS.loginAt)
  if (!raw) return Infinity
  const ts = Date.parse(raw)
  return isNaN(ts) ? Infinity : Date.now() - ts
}

export const recordLoginTimestamp = () =>
  localStorage.setItem(STORAGE_KEYS.loginAt, new Date().toISOString())

export const clearLoginTimestamp = () =>
  localStorage.removeItem(STORAGE_KEYS.loginAt)

/** Days remaining in the offline session (0 if expired). */
export const offlineSessionDaysLeft = () => {
  const ageDays = getLoginAgeMsec() / (1000 * 60 * 60 * 24)
  const remaining = OFFLINE_SESSION_DAYS - ageDays
  return remaining > 0 ? remaining : 0
}

/** Returns the effective base URL depending on license mode. */
export const getEffectiveBaseUrl = () => {
  if (getStoredLicenseMode() === 'offline') {
    const offlineUrl = getStoredOfflineBaseUrl()
    return offlineUrl || getStoredBaseUrl()
  }
  return getStoredBaseUrl()
}

export const apiClient = axios.create({
  headers: {
    Accept: 'application/json',
  },
})

apiClient.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const explicitBaseUrl = typeof config.baseURL === 'string' ? normalizeBaseUrl(config.baseURL) : ''
  // In offline mode, use the offline backend URL unless the caller explicitly overrides it
  const effectiveBaseUrl = explicitBaseUrl || getEffectiveBaseUrl()
  const resolvedBaseUrl = effectiveBaseUrl ? resolveRequestBaseUrl(effectiveBaseUrl) : ''
  if (resolvedBaseUrl) {
    config.baseURL = resolvedBaseUrl
  } else {
    delete config.baseURL
  }

  config.headers.set?.('Content-Type', 'application/json')

  const token = getStoredToken()
  if (token) {
    config.headers.set?.('Authorization', 'Bearer ' + token)
  } else {
    config.headers.delete?.('Authorization')
  }

  const tenantId = getStoredTenantId()
  if (tenantId) {
    config.headers.set?.('X-Tenant-Id', tenantId)
  } else {
    config.headers.delete?.('X-Tenant-Id')
  }

  const deviceId = getStoredDeviceId()
  if (deviceId) {
    config.headers.set?.('X-Device-Id', deviceId)
  } else {
    config.headers.delete?.('X-Device-Id')
  }

  return config
})

export function extractApiError(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const axiosError = error as AxiosError<unknown>
    const payload = axiosError.response?.data

    if (typeof payload === 'string') {
      return payload
    }

    if (payload && typeof payload === 'object') {
      const record = payload as Record<string, unknown>
      const message =
        record.message ??
        record.error ??
        record.detail ??
        record.title ??
        record.status

      if (typeof message === 'string' && message.trim()) {
        return message
      }
    }

    if (axiosError.message) {
      return axiosError.message
    }
  }

  if (error instanceof Error) {
    return error.message
  }

  return 'Something went wrong. Please try again.'
}
