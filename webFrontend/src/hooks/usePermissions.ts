import { useMemo } from 'react'
import { useAuth } from '../context/AuthContext'

export type PermissionKey =
  | 'canBill'
  | 'canViewReports'
  | 'canManageProducts'
  | 'canManageMasters'
  | 'canViewExpenses'
  | 'canManagePurchase'
  | 'canViewDashboard'

export const usePermissions = () => {
  const { isAdmin, user } = useAuth()

  return useMemo(() => ({
    has(permission?: PermissionKey) {
      if (!permission) return true
      if (isAdmin) return true
      return Boolean(user?.[permission])
    },
  }), [isAdmin, user])
}
