import { useCallback, useEffect, useMemo, useState } from 'react'
import { apiClient, extractApiError } from '../api/client'
import type { SubscriptionStatusResponse } from '../types'

const CACHE_KEY = 'nn_subscription_cache'
const TTL_MS = 60 * 60 * 1000

interface CachedSubscription {
  fetchedAt: number
  data: SubscriptionStatusResponse
}

const readCache = (): CachedSubscription | null => {
  try {
    const raw = localStorage.getItem(CACHE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as CachedSubscription
    if (!parsed?.data || typeof parsed.fetchedAt !== 'number') return null
    if (Date.now() - parsed.fetchedAt > TTL_MS) return null
    return parsed
  } catch {
    return null
  }
}

const writeCache = (data: SubscriptionStatusResponse) => {
  localStorage.setItem(CACHE_KEY, JSON.stringify({ fetchedAt: Date.now(), data }))
}

export function clearSubscriptionCache() {
  localStorage.removeItem(CACHE_KEY)
}

export default function useSubscription() {
  const [cached] = useState<CachedSubscription | null>(() => readCache())
  const [status, setStatus] = useState<SubscriptionStatusResponse | null>(cached?.data ?? null)
  const [loading, setLoading] = useState(!cached)
  const [error, setError] = useState('')

  const refresh = useCallback(async (force = false) => {
    const existing = !force ? readCache() : null
    if (existing) {
      setStatus(existing.data)
      setLoading(false)
      return existing.data
    }

    setLoading(true)
    setError('')
    try {
      const primary = await apiClient.get<SubscriptionStatusResponse>('/subscription')
      writeCache(primary.data)
      setStatus(primary.data)
      return primary.data
    } catch (firstError) {
      try {
        const fallback = await apiClient.get<SubscriptionStatusResponse>('/subscription/status')
        writeCache(fallback.data)
        setStatus(fallback.data)
        return fallback.data
      } catch (secondError) {
        const message = extractApiError(secondError ?? firstError)
        setError(message)
        throw secondError ?? firstError
      }
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    if (cached) {
      return undefined
    }

    const timer = window.setTimeout(() => {
      void refresh()
    }, 0)

    return () => window.clearTimeout(timer)
  }, [cached, refresh])

  return useMemo(() => ({
    status,
    loading,
    error,
    refresh,
    expired: Boolean(status?.expired),
  }), [error, loading, refresh, status])
}
