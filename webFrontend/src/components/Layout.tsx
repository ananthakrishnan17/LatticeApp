import { useMemo, useState, useEffect, useRef } from 'react'
import { Outlet, useLocation, useNavigate, Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { OFFLINE_SESSION_DAYS } from '../api/client'
import { usePermissions, type PermissionKey } from '../hooks/usePermissions'
import useTranslation from '../hooks/useTranslation'
import GridNavigationPreferences from './GridNavigationPreferences'
import '../styles/layoutTheme.css'

const navigation = [
  { href: '/dashboard', textKey: 'dashboard' },
  { href: '/owner-dashboard', text: 'Owner Dashboard', adminOnly: true },
  { href: '/pos', textKey: 'pos' },
  { href: '/held-bills', textKey: 'heldBills' },
  { href: '/reports', textKey: 'reports', permission: 'canViewReports' },
  { href: '/bill-history', textKey: 'billHistory', permission: 'canViewReports' },
  { href: '/expenses', textKey: 'expenses', permission: 'canViewExpenses' },
  { href: '/customers-loyalty', textKey: 'loyalty', permission: 'canViewReports' },
  { href: '/products', textKey: 'products', permission: 'canManageProducts' },
  { href: '/inventory-alerts', text: 'Inventory Alerts', permission: 'canManageProducts' },
  { href: '/purchase', textKey: 'purchase', permission: 'canManagePurchase' },
  { href: '/sale-return', text: 'Sale Return' },
  { href: '/purchase-return', text: 'Purchase Return', permission: 'canManagePurchase' },
  { href: '/supplier-ledger', text: 'Supplier Ledger', permission: 'canManagePurchase' },
  { href: '/day-close', text: 'Day Close' },
  { href: '/receipt-profiles', text: 'Receipt Profiles', adminOnly: true },
  { href: '/audit-log', text: 'Audit Log', adminOnly: true },
  { href: '/org', text: 'Org Management', adminOnly: true },
  { href: '/masters', text: 'Masters', permission: 'canManageMasters' },
  { href: '/coupons', text: 'Coupons & Payments', adminOnly: true },
  { href: '/users', text: 'Users', adminOnly: true },
  { href: '/subscription', textKey: 'subscription' },
  { href: '/settings', textKey: 'settings' },
] as Array<{ href: string; text?: string; textKey?: keyof ReturnType<typeof useTranslation>['t']; adminOnly?: boolean; permission?: PermissionKey }>

function Layout() {
  const { isAdmin, logout, role, username, licenseMode, offlineSessionDaysLeft } = useAuth()
  const permissions = usePermissions()
  const location = useLocation()
  const navigate = useNavigate()
  const [navigationOpen, setNavigationOpen] = useState(true)
  const [userMenuOpen, setUserMenuOpen] = useState(false)
  const { t } = useTranslation()
  const menuRef = useRef<HTMLDivElement>(null)

  const navItems = useMemo(() => navigation
    .filter((item) => (!item.adminOnly || isAdmin) && permissions.has(item.permission))
    .map((item) => ({ text: item.text ?? t[item.textKey ?? 'dashboard'], href: item.href })), [isAdmin, permissions, t])

  const offlineBannerColor = offlineSessionDaysLeft <= 1 ? '#FEF2F2' : '#FFFBEB'
  const offlineBannerBorder = offlineSessionDaysLeft <= 1 ? '#FECACA' : '#FDE68A'
  const offlineBannerText = offlineSessionDaysLeft <= 1 ? '#991B1B' : '#92400E'

  // Close dropdown on outside click
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setUserMenuOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  return (
    <div className="layout-app">
      {/* Sidebar */}
      <aside className={`layout-sidebar ${!navigationOpen ? 'closed' : ''}`}>
        <div className="layout-sidebar-header">
          NammaNanban
        </div>
        <div className="layout-sidebar-content">
          {navItems.map((item) => (
            <Link
              key={item.href}
              to={item.href}
              className={`layout-nav-link ${location.pathname === item.href ? 'active' : ''}`}
            >
              {item.text}
            </Link>
          ))}
          <GridNavigationPreferences />
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="layout-main">
        {/* Topbar */}
        <header className="layout-topbar">
          <div className="layout-topbar-left">
            <button className="layout-toggle-btn" onClick={() => setNavigationOpen(!navigationOpen)} title={t.toggleMenu}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="3" y1="12" x2="21" y2="12"></line>
                <line x1="3" y1="6" x2="21" y2="6"></line>
                <line x1="3" y1="18" x2="21" y2="18"></line>
              </svg>
            </button>
            <div style={{ fontWeight: 600, fontSize: '1.1rem' }}>{t.posSystem}</div>
          </div>

          <div className="layout-topbar-right">
            <div className="layout-user-menu" ref={menuRef}>
              <button className="layout-user-btn" onClick={() => setUserMenuOpen(!userMenuOpen)}>
                <div className="layout-user-avatar">{username?.charAt(0).toUpperCase() || 'U'}</div>
                <div className="layout-user-info">
                  <span className="layout-user-name">{username || 'User'}</span>
                  <span className="layout-user-role">{role || 'user'}</span>
                </div>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ marginLeft: 4 }}>
                  <polyline points="6 9 12 15 18 9"></polyline>
                </svg>
              </button>

              {userMenuOpen && (
                <div className="layout-dropdown">
                  <button 
                    className="layout-dropdown-item" 
                    onClick={() => {
                      logout()
                      navigate('/login', { replace: true })
                    }}
                  >
                    {t.logout}
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>

        {/* Offline Banner */}
        {licenseMode === 'offline' && (
          <div style={{
            background: offlineBannerColor,
            borderBottom: `1px solid ${offlineBannerBorder}`,
            color: offlineBannerText,
            fontSize: '13px',
            fontWeight: 500,
            padding: '6px 20px',
            textAlign: 'center',
          }}>
            {offlineSessionDaysLeft > 0
              ? `💾 Offline mode — session valid for ${Math.ceil(offlineSessionDaysLeft)} more day${Math.ceil(offlineSessionDaysLeft) !== 1 ? 's' : ''} (re-login requires internet after ${OFFLINE_SESSION_DAYS} days)`
              : '⚠ Offline session expired — please sign in again (internet required)'}
          </div>
        )}

        {/* Page Content */}
        <div className="layout-content-wrapper">
          <Outlet />
        </div>
      </main>
    </div>
  )
}

export default Layout
