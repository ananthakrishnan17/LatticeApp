import { type ReactNode } from 'react'
import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import useSubscription from '../hooks/useSubscription'
import { usePermissions, type PermissionKey } from '../hooks/usePermissions'
import Spinner from './Spinner'

interface ProtectedRouteProps {
  adminOnly?: boolean
  requiredPermission?: PermissionKey
  redirectTo?: string
  children?: ReactNode
}

const ALLOWED_EXPIRED_PATHS = new Set(['/subscription', '/subscription-expired'])

function ProtectedRoute({ adminOnly = false, requiredPermission, redirectTo = '/pos', children }: ProtectedRouteProps) {
  const { isAdmin, isAuthenticated, loading } = useAuth()
  const permissions = usePermissions()
  const location = useLocation()
  const { loading: subscriptionLoading, expired } = useSubscription()

  const isOnAllowedExpiredPath = ALLOWED_EXPIRED_PATHS.has(location.pathname)
  const shouldShowLoadingSpinner = loading || (isAuthenticated && !isOnAllowedExpiredPath && subscriptionLoading)

  if (shouldShowLoadingSpinner) {
    return <Spinner fullScreen label="Checking session..." />
  }

  if (!isAuthenticated) {
    return <Navigate replace to="/login" />
  }

  if (expired && !isOnAllowedExpiredPath) {
    return <Navigate replace to="/subscription-expired" />
  }

  if (adminOnly && !isAdmin) {
    return <Navigate replace to={redirectTo} />
  }

  if (!permissions.has(requiredPermission)) {
    return <Navigate replace to={redirectTo} />
  }

  return children ? <>{children}</> : <Outlet />
}

export default ProtectedRoute
