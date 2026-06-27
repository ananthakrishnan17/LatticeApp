import { generateUUID } from './uuid'
import { upsertTransaction } from '../api/transactions'

export interface AuditEvent {
  id: string
  action: string
  module: string
  detail: string
  actor: string
  createdAt: string
  metadata?: Record<string, unknown>
}

const KEY = 'nn_audit_log_v1'

export const listAuditEvents = (): AuditEvent[] => {
  try {
    const raw = localStorage.getItem(KEY)
    const parsed = raw ? (JSON.parse(raw) as AuditEvent[]) : []
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

export const pushAuditEvent = (event: Omit<AuditEvent, 'id' | 'createdAt'>) => {
  const next: AuditEvent = {
    ...event,
    id: generateUUID(),
    createdAt: new Date().toISOString(),
  }

  const existing = listAuditEvents()
  localStorage.setItem(KEY, JSON.stringify([next, ...existing].slice(0, 1000)))

  void upsertTransaction({
    clientRecordId: generateUUID(),
    type: 'audit_event',
    totalAmount: 0,
    tags: {
      module: next.module,
      action: next.action,
      detail: next.detail,
      actor: next.actor,
      timestamp: next.createdAt,
      ...(next.metadata ?? {}),
    },
    createdAt: next.createdAt,
    updatedAt: next.createdAt,
  }).catch(() => undefined)

  return next
}
