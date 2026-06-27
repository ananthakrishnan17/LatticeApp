import { generateUUID } from './uuid'
import type { CashSessionRecord } from '../types'

const CASH_SESSION_STORAGE_KEY = 'nn_cashier_sessions_v1'

export const CASH_SESSION_DENOMINATIONS = [500, 200, 100, 50, 20, 10, 5, 1] as const

export type DenominationCounts = Record<number, number>

interface OpenCashSessionInput {
  cashierUsername: string
  openingAmount: number
  openingDenominationCounts?: DenominationCounts
}

interface CloseCashSessionInput {
  cashierUsername: string
  closingAmount: number
  closingDenominationCounts?: DenominationCounts
  closedBy: string
  notes?: string
}

const normalizeAmount = (value: number) => Number((Number.isFinite(value) ? value : 0).toFixed(2))

export function createEmptyDenominationCounts(): DenominationCounts {
  return CASH_SESSION_DENOMINATIONS.reduce<DenominationCounts>((acc, denomination) => {
    acc[denomination] = 0
    return acc
  }, {} as DenominationCounts)
}

function sanitizeDenominationCounts(counts?: DenominationCounts): Record<string, number> | null {
  if (!counts) return null

  const normalized = CASH_SESSION_DENOMINATIONS.reduce<Record<string, number>>((acc, denomination) => {
    const count = Math.max(0, Math.trunc(counts[denomination] ?? 0))
    acc[String(denomination)] = count
    return acc
  }, {})

  return Object.values(normalized).some((count) => count > 0) ? normalized : null
}

export function parseDenominationCounts(
  counts?: Record<string, number> | null,
): DenominationCounts {
  const normalized = createEmptyDenominationCounts()

  for (const denomination of CASH_SESSION_DENOMINATIONS) {
    normalized[denomination] = Math.max(0, Math.trunc(Number(counts?.[String(denomination)] ?? 0) || 0))
  }

  return normalized
}

export function sumDenominationCounts(counts?: DenominationCounts | Record<string, number> | null) {
  const normalizedCounts = counts as Record<string, number> | undefined | null
  return normalizeAmount(
    CASH_SESSION_DENOMINATIONS.reduce((total, denomination) => total + denomination * Math.max(0, Number(normalizedCounts?.[String(denomination)] ?? 0)), 0),
  )
}

function loadCashSessions() {
  try {
    const raw = localStorage.getItem(CASH_SESSION_STORAGE_KEY)
    const parsed = raw ? (JSON.parse(raw) as CashSessionRecord[]) : []
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

function saveCashSessions(sessions: CashSessionRecord[]) {
  localStorage.setItem(CASH_SESSION_STORAGE_KEY, JSON.stringify(sessions))
}

export function listCashSessions(cashierUsername?: string) {
  const sessions = loadCashSessions()
  if (!cashierUsername) {
    return sessions.sort((left, right) => right.openedAt.localeCompare(left.openedAt))
  }

  return sessions
    .filter((session) => session.cashierUsername === cashierUsername)
    .sort((left, right) => right.openedAt.localeCompare(left.openedAt))
}

export function getActiveCashSession(cashierUsername: string) {
  return listCashSessions(cashierUsername).find((session) => session.status === 'OPEN') ?? null
}

export function openCashSession({ cashierUsername, openingAmount, openingDenominationCounts }: OpenCashSessionInput) {
  const existing = getActiveCashSession(cashierUsername)
  if (existing) {
    return existing
  }

  const normalizedOpeningAmount = normalizeAmount(openingAmount)
  const now = new Date().toISOString()
  const session: CashSessionRecord = {
    id: generateUUID(),
    cashierUsername,
    status: 'OPEN',
    openingAmount: normalizedOpeningAmount,
    openingDenominations: sanitizeDenominationCounts(openingDenominationCounts),
    openedAt: now,
    totalCashCollected: 0,
    totalCashRefunded: 0,
    expectedClosing: normalizedOpeningAmount,
    closingAmount: null,
    closingDenominations: null,
    closedAt: null,
    difference: null,
    closedBy: null,
    notes: null,
  }

  saveCashSessions([session, ...loadCashSessions()])
  return session
}

export function addCashCollection(cashierUsername: string, amount: number) {
  const normalizedAmount = normalizeAmount(amount)
  if (normalizedAmount <= 0) {
    return getActiveCashSession(cashierUsername)
  }

  let updatedSession: CashSessionRecord | null = null
  const nextSessions = loadCashSessions().map((session) => {
    if (session.cashierUsername !== cashierUsername || session.status !== 'OPEN') {
      return session
    }

    const totalCashCollected = normalizeAmount(session.totalCashCollected + normalizedAmount)
    updatedSession = {
      ...session,
      totalCashCollected,
      expectedClosing: normalizeAmount(session.openingAmount + totalCashCollected - session.totalCashRefunded),
    }
    return updatedSession
  })

  if (!updatedSession) {
    throw new Error(`No active cashier session found for ${cashierUsername}.`)
  }

  saveCashSessions(nextSessions)
  return updatedSession
}

export function addCashRefund(cashierUsername: string, amount: number) {
  const normalizedAmount = normalizeAmount(amount)
  if (normalizedAmount <= 0) {
    return getActiveCashSession(cashierUsername)
  }

  let updatedSession: CashSessionRecord | null = null
  const nextSessions = loadCashSessions().map((session) => {
    if (session.cashierUsername !== cashierUsername || session.status !== 'OPEN') {
      return session
    }

    const totalCashRefunded = normalizeAmount(session.totalCashRefunded + normalizedAmount)
    updatedSession = {
      ...session,
      totalCashRefunded,
      expectedClosing: normalizeAmount(session.openingAmount + session.totalCashCollected - totalCashRefunded),
    }
    return updatedSession
  })

  if (!updatedSession) {
    throw new Error(`No active cashier session found for ${cashierUsername}.`)
  }

  saveCashSessions(nextSessions)
  return updatedSession
}

export function closeCashSession({
  cashierUsername,
  closingAmount,
  closingDenominationCounts,
  closedBy,
  notes,
}: CloseCashSessionInput) {
  const activeSession = getActiveCashSession(cashierUsername)
  if (!activeSession) {
    throw new Error(`No active cashier session found for ${cashierUsername}.`)
  }

  const normalizedClosingAmount = normalizeAmount(closingAmount)
  const difference = normalizeAmount(normalizedClosingAmount - activeSession.expectedClosing)
  const now = new Date().toISOString()

  const closedSession: CashSessionRecord = {
    ...activeSession,
    status: 'CLOSED',
    closingAmount: normalizedClosingAmount,
    closingDenominations: sanitizeDenominationCounts(closingDenominationCounts),
    closedAt: now,
    difference,
    closedBy,
    notes: notes?.trim() ? notes.trim() : null,
  }

  const nextSessions = loadCashSessions().map((session) => (session.id === activeSession.id ? closedSession : session))
  saveCashSessions(nextSessions)
  return closedSession
}
