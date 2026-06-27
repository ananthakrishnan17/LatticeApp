import { useCallback, useEffect, useState } from 'react'
import { assignUserRole, createBranch, getOwnerDashboard, listOwnerBranches, listOwnerRoles } from '../api/owner'
import { listUsers } from '../api/users'
import { extractApiError } from '../api/client'
import Spinner from '../components/Spinner'
import { useAuth } from '../context/AuthContext'
import { pushAuditEvent } from '../utils/auditLog'
import type { OwnerBranchResponse, OwnerDashboardResponse, OwnerRoleResponse, UserResponse } from '../types'

type TabId = 'dashboard' | 'branches' | 'roles'

function OrgManagementPage() {
  const { username: actor } = useAuth()
  const [tab, setTab] = useState<TabId>('dashboard')
  const [loadingDash, setLoadingDash] = useState(true)
  const [dashboard, setDashboard] = useState<OwnerDashboardResponse | null>(null)
  const [branches, setBranches] = useState<OwnerBranchResponse[]>([])
  const [roles, setRoles] = useState<OwnerRoleResponse[]>([])
  const [users, setUsers] = useState<UserResponse[]>([])
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [saving, setSaving] = useState(false)

  // Branch creation form
  const [newBranchName, setNewBranchName] = useState('')

  // Role assignment form
  const [assignUsername, setAssignUsername] = useState('')
  const [assignBranchId, setAssignBranchId] = useState('')
  const [assignRoleCode, setAssignRoleCode] = useState('')

  const loadAll = useCallback(async () => {
    setLoadingDash(true)
    setError('')

    const [dashResult, branchResult, roleResult, userResult] = await Promise.allSettled([
      getOwnerDashboard(),
      listOwnerBranches(),
      listOwnerRoles(),
      listUsers(),
    ])

    if (dashResult.status === 'fulfilled') setDashboard(dashResult.value)
    if (branchResult.status === 'fulfilled') setBranches(branchResult.value)
    if (roleResult.status === 'fulfilled') setRoles(roleResult.value)
    if (userResult.status === 'fulfilled') setUsers(userResult.value)
    if (dashResult.status === 'rejected') setError(extractApiError(dashResult.reason))

    setLoadingDash(false)
  }, [])

  useEffect(() => {
    let cancelled = false

    const init = async () => {
      const [dashResult, branchResult, roleResult, userResult] = await Promise.allSettled([
        getOwnerDashboard(),
        listOwnerBranches(),
        listOwnerRoles(),
        listUsers(),
      ])

      if (cancelled) return

      if (dashResult.status === 'fulfilled') setDashboard(dashResult.value)
      if (branchResult.status === 'fulfilled') setBranches(branchResult.value)
      if (roleResult.status === 'fulfilled') setRoles(roleResult.value)
      if (userResult.status === 'fulfilled') setUsers(userResult.value)
      if (dashResult.status === 'rejected') setError(extractApiError(dashResult.reason))

      setLoadingDash(false)
    }

    void init()
    return () => { cancelled = true }
  }, [])

  const handleCreateBranch = async (event: React.FormEvent) => {
    event.preventDefault()
    if (!newBranchName.trim()) return
    setSaving(true)
    setError('')
    setNotice('')

    try {
      await createBranch(newBranchName.trim())
      pushAuditEvent({ module: 'org', action: 'create_branch', detail: `Created branch ${newBranchName.trim()}`, actor: actor ?? 'unknown' })
      setNotice(`Branch "${newBranchName.trim()}" created.`)
      setNewBranchName('')
      const updated = await listOwnerBranches()
      setBranches(updated)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  const handleAssignRole = async (event: React.FormEvent) => {
    event.preventDefault()
    if (!assignUsername || !assignBranchId || !assignRoleCode) return
    setSaving(true)
    setError('')
    setNotice('')

    try {
      await assignUserRole(assignUsername, { branchId: assignBranchId, roleCode: assignRoleCode })
      pushAuditEvent({ module: 'org', action: 'assign_role', detail: `Assigned ${assignRoleCode} to ${assignUsername}`, actor: actor ?? 'unknown' })
      setNotice(`Role assigned to ${assignUsername}.`)
      setAssignUsername('')
      setAssignBranchId('')
      setAssignRoleCode('')
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  if (loadingDash) {
    return <Spinner label="Loading org management..." />
  }

  const tabs: Array<{ id: TabId; label: string }> = [
    { id: 'dashboard', label: 'Owner Dashboard' },
    { id: 'branches', label: 'Branch Management' },
    { id: 'roles', label: 'Role Assignment' },
  ]

  return (
    <div className="space-y-6">
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Organisation</p>
        <h1 className="mt-2 text-3xl font-bold text-slate-900">Org Management</h1>
        <p className="mt-2 text-sm text-slate-500">Owner dashboard, branches, and role assignments.</p>
      </div>

      {error ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      {notice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      {/* Tabs */}
      <div className="flex gap-2 border-b border-slate-200 pb-0">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setTab(t.id)}
            className={`rounded-t-xl px-5 py-3 text-sm font-semibold transition ${tab === t.id ? 'border-b-2 border-indigo-600 text-indigo-600' : 'text-slate-500 hover:text-slate-700'}`}
          >
            {t.label}
          </button>
        ))}
        <div className="ml-auto">
          <button
            type="button"
            onClick={() => void loadAll()}
            className="rounded-2xl border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
          >
            Refresh
          </button>
        </div>
      </div>

      {/* Dashboard tab */}
      {tab === 'dashboard' && (
        <div className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {[
              { label: 'Today Revenue', value: `₹${(dashboard?.todayRevenue ?? 0).toLocaleString('en-IN')}` },
              { label: 'Total Profit', value: `₹${(dashboard?.totalProfit ?? 0).toLocaleString('en-IN')}` },
              { label: 'Transactions', value: String(dashboard?.transactionCount ?? 0) },
              { label: 'Active Staff', value: String(dashboard?.activeStaffCount ?? 0) },
            ].map((stat) => (
              <div key={stat.label} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                <p className="text-xs font-semibold uppercase tracking-widest text-slate-500">{stat.label}</p>
                <p className="mt-2 text-2xl font-bold text-slate-900">{stat.value}</p>
              </div>
            ))}
          </div>

          <div>
            <h2 className="mb-4 text-lg font-semibold text-slate-800">Branch Overview</h2>
            {dashboard?.branches?.length ? (
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {dashboard.branches.map((b) => (
                  <div key={b.branchId} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                    <p className="font-semibold text-slate-800">{b.branchName}</p>
                    <p className="mt-1 text-sm text-slate-500">Staff: {b.activeStaffCount} · Txns: {b.transactionCount}</p>
                    <p className="mt-1 text-sm text-slate-500">Revenue: ₹{b.revenueAmount.toLocaleString('en-IN')}</p>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-slate-500">No branch data available.</p>
            )}
          </div>
        </div>
      )}

      {/* Branches tab */}
      {tab === 'branches' && (
        <div className="space-y-6">
          <form onSubmit={(e) => void handleCreateBranch(e)} className="flex flex-wrap gap-3 items-end">
            <div className="flex-1 min-w-[200px]">
              <label className="mb-2 block text-sm font-medium text-slate-700">New branch name</label>
              <input
                required
                value={newBranchName}
                onChange={(e) => setNewBranchName(e.target.value)}
                placeholder="e.g. Main Branch"
                className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
              />
            </div>
            <button
              type="submit"
              disabled={saving}
              className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300"
            >
              {saving ? 'Creating...' : 'Create Branch'}
            </button>
          </form>

          <div className="overflow-hidden rounded-2xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-slate-50">
                <tr>
                  <th className="px-4 py-3 text-left font-semibold text-slate-600">Branch Name</th>
                  <th className="px-4 py-3 text-left font-semibold text-slate-600">Default</th>
                  <th className="px-4 py-3 text-left font-semibold text-slate-600">Created At</th>
                </tr>
              </thead>
              <tbody>
                {branches.length ? branches.map((b) => (
                  <tr key={b.id} className="border-t border-slate-100">
                    <td className="px-4 py-3 font-medium text-slate-800">{b.name}</td>
                    <td className="px-4 py-3">
                      {b.isDefault ? (
                        <span className="rounded-full bg-indigo-100 px-2 py-1 text-xs font-semibold text-indigo-700">Default</span>
                      ) : '—'}
                    </td>
                    <td className="px-4 py-3 text-slate-500">{new Date(b.createdAt).toLocaleDateString()}</td>
                  </tr>
                )) : (
                  <tr>
                    <td colSpan={3} className="px-4 py-6 text-center text-slate-400">No branches found.</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Role assignment tab */}
      {tab === 'roles' && (
        <div className="space-y-6">
          <form onSubmit={(e) => void handleAssignRole(e)} className="rounded-2xl border border-slate-200 bg-white p-6 space-y-4">
            <h2 className="text-lg font-semibold text-slate-800">Assign Role to User</h2>

            <div className="grid gap-4 md:grid-cols-3">
              <div>
                <label className="mb-2 block text-sm font-medium text-slate-700">User</label>
                <select
                  required
                  value={assignUsername}
                  onChange={(e) => setAssignUsername(e.target.value)}
                  className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                >
                  <option value="">Select user...</option>
                  {users.map((u) => (
                    <option key={u.username} value={u.username}>{u.username}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="mb-2 block text-sm font-medium text-slate-700">Branch</label>
                <select
                  required
                  value={assignBranchId}
                  onChange={(e) => setAssignBranchId(e.target.value)}
                  className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                >
                  <option value="">Select branch...</option>
                  {branches.map((b) => (
                    <option key={b.id} value={b.id}>{b.name}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="mb-2 block text-sm font-medium text-slate-700">Role</label>
                <select
                  required
                  value={assignRoleCode}
                  onChange={(e) => setAssignRoleCode(e.target.value)}
                  className="w-full rounded-2xl border border-slate-200 px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                >
                  <option value="">Select role...</option>
                  {roles.map((r) => (
                    <option key={r.code} value={r.code}>{r.displayName} ({r.scope})</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="flex justify-end">
              <button
                type="submit"
                disabled={saving}
                className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300"
              >
                {saving ? 'Assigning...' : 'Assign Role'}
              </button>
            </div>
          </form>

          <div>
            <h2 className="mb-3 text-lg font-semibold text-slate-800">Available Roles</h2>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {roles.map((r) => (
                <div key={r.code} className="rounded-2xl border border-slate-200 bg-white p-4">
                  <p className="font-semibold text-slate-800">{r.displayName}</p>
                  <p className="mt-1 text-xs text-slate-500">Code: {r.code} · Scope: {r.scope}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default OrgManagementPage
