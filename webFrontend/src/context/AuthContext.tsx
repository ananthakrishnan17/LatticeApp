import { generateUUID } from '../utils/uuid'
/* eslint-disable react-refresh/only-export-components */
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { getCurrentUser } from '../api/users'
import { login as loginRequest } from '../api/auth'
import {
  STORAGE_KEYS,
  OFFLINE_SESSION_DAYS,
  getStoredBaseUrl,
  normalizeBaseUrl,
  setStoredBaseUrl,
  getStoredLicenseMode,
  setStoredLicenseMode,
  getStoredOfflineBaseUrl,
  setStoredOfflineBaseUrl,
  getLoginAgeMsec,
  recordLoginTimestamp,
  clearLoginTimestamp,
  offlineSessionDaysLeft,
  type LicenseMode,
} from '../api/client'
import type { LoginResponse, UserResponse } from '../types'

interface LoginFormValues {
  baseUrl: string
  tenantCode: string
  username: string
  password: string
}

interface AuthContextValue {
  token: string | null
  user: UserResponse | null
  role: string | null
  username: string | null
  baseUrl: string
  tenantId: string | null
  deviceId: string
  isAuthenticated: boolean
  isAdmin: boolean
  loading: boolean
  licenseMode: LicenseMode
  offlineBaseUrl: string
  /** Days remaining in the offline session (only meaningful when licenseMode === 'offline') */
  offlineSessionDaysLeft: number
  login: (values: LoginFormValues) => Promise<void>
  logout: () => void
  refreshUser: () => Promise<UserResponse>
  setBaseUrl: (value: string) => void
  setUser: (value: UserResponse | null) => void
  setLicenseMode: (mode: LicenseMode) => void
  setOfflineBaseUrl: (value: string) => void
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

const ensureDeviceId = () => {
  const existing = localStorage.getItem(STORAGE_KEYS.deviceId)
  if (existing) {
    return existing
  }

  const nextValue = generateUUID()
  localStorage.setItem(STORAGE_KEYS.deviceId, nextValue)
  return nextValue
}

const persistLogin = (payload: LoginResponse, username: string) => {
  localStorage.setItem(STORAGE_KEYS.token, payload.accessToken)
  localStorage.setItem(STORAGE_KEYS.tenantId, payload.tenantId)
  localStorage.setItem(STORAGE_KEYS.deviceId, payload.deviceId)
  localStorage.setItem(STORAGE_KEYS.role, payload.role)
  localStorage.setItem(STORAGE_KEYS.username, username)
  recordLoginTimestamp()
}

const persistCachedUser = (user: UserResponse) => {
  try {
    localStorage.setItem(STORAGE_KEYS.cachedUser, JSON.stringify(user))
  } catch {
    // ignore storage errors
  }
}

const loadCachedUser = (): UserResponse | null => {
  try {
    const raw = localStorage.getItem(STORAGE_KEYS.cachedUser)
    return raw ? (JSON.parse(raw) as UserResponse) : null
  } catch {
    return null
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => localStorage.getItem(STORAGE_KEYS.token))
  const [role, setRole] = useState<string | null>(() => localStorage.getItem(STORAGE_KEYS.role))
  const [username, setUsername] = useState<string | null>(() => localStorage.getItem(STORAGE_KEYS.username))
  const [tenantId, setTenantId] = useState<string | null>(() => localStorage.getItem(STORAGE_KEYS.tenantId))
  const [deviceId] = useState<string>(() => ensureDeviceId())
  const [baseUrl, setBaseUrlState] = useState<string>(() => getStoredBaseUrl())
  const [user, setUser] = useState<UserResponse | null>(null)
  const [loading, setLoading] = useState<boolean>(Boolean(localStorage.getItem(STORAGE_KEYS.token)))
  const [licenseMode, setLicenseModeState] = useState<LicenseMode>(() => getStoredLicenseMode())
  const [offlineBaseUrl, setOfflineBaseUrlState] = useState<string>(() => getStoredOfflineBaseUrl())
  const [sessionDaysLeft, setSessionDaysLeft] = useState<number>(() => offlineSessionDaysLeft())

  const setBaseUrl = useCallback((value: string) => {
    const normalized = normalizeBaseUrl(value)
    setStoredBaseUrl(normalized)
    setBaseUrlState(normalized)
  }, [])

  const setLicenseMode = useCallback((mode: LicenseMode) => {
    setStoredLicenseMode(mode)
    setLicenseModeState(mode)
  }, [])

  const setOfflineBaseUrl = useCallback((value: string) => {
    setStoredOfflineBaseUrl(value)
    setOfflineBaseUrlState(normalizeBaseUrl(value))
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem(STORAGE_KEYS.token)
    localStorage.removeItem(STORAGE_KEYS.tenantId)
    localStorage.removeItem(STORAGE_KEYS.role)
    localStorage.removeItem(STORAGE_KEYS.username)
    clearLoginTimestamp()
    setToken(null)
    setTenantId(null)
    setRole(null)
    setUsername(null)
    setUser(null)
    setLoading(false)
    setSessionDaysLeft(0)
  }, [])

  const refreshUser = useCallback(async () => {
    const currentUser = await getCurrentUser()
    setUser(currentUser)
    persistCachedUser(currentUser)
    setRole(currentUser.role)
    setUsername(currentUser.username)
    localStorage.setItem(STORAGE_KEYS.role, currentUser.role)
    localStorage.setItem(STORAGE_KEYS.username, currentUser.username)
    return currentUser
  }, [])

  const login = useCallback(async (values: LoginFormValues) => {
    const normalizedBaseUrl = normalizeBaseUrl(values.baseUrl)
    setBaseUrl(normalizedBaseUrl)
    const isPhoneNumber = /^\d+$/.test(values.username.trim())
    const payload = await loginRequest(normalizedBaseUrl, {
      tenantCode: values.tenantCode,
      ...(isPhoneNumber ? { phoneNumber: values.username } : { username: values.username }),
      password: values.password,
      deviceId,
    })

    persistLogin(payload, values.username)
    setToken(payload.accessToken)
    setTenantId(payload.tenantId)
    setRole(payload.role)
    setUsername(values.username)
    setSessionDaysLeft(OFFLINE_SESSION_DAYS)
    setLoading(true)

    try {
      await refreshUser()
    } catch {
      setUser(null)
    } finally {
      setLoading(false)
    }
  }, [deviceId, refreshUser, setBaseUrl])

  useEffect(() => {
    if (!token) {
      return
    }

    let cancelled = false

    const bootstrapSession = async () => {
      const currentLicenseMode = getStoredLicenseMode()

      // ── Offline mode: use cached session within the 3-day window ──────────
      if (currentLicenseMode === 'offline') {
        const ageDays = getLoginAgeMsec() / (1000 * 60 * 60 * 24)

        if (ageDays > OFFLINE_SESSION_DAYS) {
          // Session expired — force re-login
          if (!cancelled) {
            logout()
          }
          return
        }

        // Session still valid — restore from cache, no network call needed
        const cached = loadCachedUser()
        if (cached && !cancelled) {
          setUser(cached)
          setRole(cached.role)
          setUsername(cached.username)
          localStorage.setItem(STORAGE_KEYS.role, cached.role)
          localStorage.setItem(STORAGE_KEYS.username, cached.username)
          setSessionDaysLeft(Math.max(0, OFFLINE_SESSION_DAYS - ageDays))
          setLoading(false)
        } else if (!cancelled) {
          // No cached user — try to fetch (may fail if truly offline)
          try {
            const currentUser = await getCurrentUser()
            if (!cancelled) {
              setUser(currentUser)
              persistCachedUser(currentUser)
              setRole(currentUser.role)
              setUsername(currentUser.username)
              localStorage.setItem(STORAGE_KEYS.role, currentUser.role)
              localStorage.setItem(STORAGE_KEYS.username, currentUser.username)
              setSessionDaysLeft(Math.max(0, OFFLINE_SESSION_DAYS - ageDays))
            }
          } catch {
            if (!cancelled) {
              logout()
            }
          } finally {
            if (!cancelled) {
              setLoading(false)
            }
          }
        }
        return
      }

      // ── Online mode: validate token against the server ─────────────────────
      try {
        const currentUser = await getCurrentUser()
        if (cancelled) {
          return
        }

        setUser(currentUser)
        persistCachedUser(currentUser)
        setRole(currentUser.role)
        setUsername(currentUser.username)
        localStorage.setItem(STORAGE_KEYS.role, currentUser.role)
        localStorage.setItem(STORAGE_KEYS.username, currentUser.username)
        setSessionDaysLeft(offlineSessionDaysLeft())
      } catch {
        if (!cancelled) {
          logout()
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    void bootstrapSession()

    return () => {
      cancelled = true
    }
  }, [logout, token])

  const value = useMemo<AuthContextValue>(() => ({
    token,
    user,
    role,
    username,
    baseUrl,
    tenantId,
    deviceId,
    isAuthenticated: Boolean(token),
    isAdmin: (user?.role ?? role) === 'admin',
    loading,
    licenseMode,
    offlineBaseUrl,
    offlineSessionDaysLeft: sessionDaysLeft,
    login,
    logout,
    refreshUser,
    setBaseUrl,
    setUser,
    setLicenseMode,
    setOfflineBaseUrl,
  }), [baseUrl, deviceId, loading, licenseMode, login, logout, offlineBaseUrl, refreshUser, role, sessionDaysLeft, tenantId, token, user, username, setBaseUrl, setLicenseMode, setOfflineBaseUrl])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth = () => {
  const context = useContext(AuthContext)

  if (!context) {
    throw new Error('useAuth must be used inside AuthProvider')
  }

  return context
}
