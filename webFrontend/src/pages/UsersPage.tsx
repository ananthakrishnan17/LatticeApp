import { useCallback, useEffect, useMemo, useState } from 'react'
import Badge from '@cloudscape-design/components/badge'
import Box from '@cloudscape-design/components/box'
import Button from '@cloudscape-design/components/button'
import Container from '@cloudscape-design/components/container'
import Header from '@cloudscape-design/components/header'
import SpaceBetween from '@cloudscape-design/components/space-between'
import type { TableProps } from '@cloudscape-design/components/table'
import { createUser, deleteUser, listUsers, updateUser, updateUserPin } from '../api/users'
import { extractApiError } from '../api/client'
import EnterNavigableTable from '../components/EnterNavigableTable'
import Spinner from '../components/Spinner'
import { useAuth } from '../context/AuthContext'
import { pushAuditEvent } from '../utils/auditLog'
import type { CreateUserRequest, UpdateUserRequest, UserResponse, UserRole } from '../types'

interface UserFormState {
  username: string
  pin: string
  role: UserRole
  isActive: boolean
  canBill: boolean
  canViewReports: boolean
  canManageProducts: boolean
  canManageMasters: boolean
  canViewExpenses: boolean
  canManagePurchase: boolean
  canViewDashboard: boolean
}

const defaultUserForm: UserFormState = {
  username: '',
  pin: '',
  role: 'user',
  isActive: true,
  canBill: true,
  canViewReports: false,
  canManageProducts: false,
  canManageMasters: false,
  canViewExpenses: false,
  canManagePurchase: false,
  canViewDashboard: true,
}

const permissionFields: Array<{ key: keyof Omit<UserFormState, 'username' | 'pin' | 'role'>; label: string }> = [
  { key: 'isActive', label: 'Active account' },
  { key: 'canBill', label: 'Can bill' },
  { key: 'canViewReports', label: 'Can view reports' },
  { key: 'canManageProducts', label: 'Can manage products' },
  { key: 'canManageMasters', label: 'Can manage masters' },
  { key: 'canViewExpenses', label: 'Can view expenses' },
  { key: 'canManagePurchase', label: 'Can manage purchase' },
  { key: 'canViewDashboard', label: 'Can view dashboard' },
]

function UsersPage() {
  const { username: actor } = useAuth()
  const [users, setUsers] = useState<UserResponse[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [search, setSearch] = useState('')
  const [selectedItems, setSelectedItems] = useState<ReadonlyArray<UserResponse>>([])
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [isPinModalOpen, setIsPinModalOpen] = useState(false)
  const [editingUser, setEditingUser] = useState<UserResponse | null>(null)
  const [form, setForm] = useState<UserFormState>(defaultUserForm)
  const [pinForm, setPinForm] = useState({ username: '', pin: '' })

  const loadUsers = useCallback(async () => {
    setLoading(true)
    setError('')

    try {
      const result = await listUsers()
      setUsers(result)
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    let cancelled = false

    const bootstrapUsers = async () => {
      try {
        const result = await listUsers()
        if (!cancelled) {
          setUsers(result)
        }
      } catch (err) {
        if (!cancelled) {
          setError(extractApiError(err))
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    void bootstrapUsers()

    return () => {
      cancelled = true
    }
  }, [])

  const filteredUsers = useMemo(() => {
    const query = search.trim().toLowerCase()
    return users.filter((user) => !query || user.username.toLowerCase().includes(query) || user.role.toLowerCase().includes(query))
  }, [search, users])

  const columnDefinitions: ReadonlyArray<TableProps.ColumnDefinition<UserResponse>> = [
    {
      id: 'username',
      header: 'Username',
      cell: (item) => <Box fontWeight="bold">{item.username}</Box>,
    },
    {
      id: 'role',
      header: 'Role',
      cell: (item) => item.role,
    },
    {
      id: 'status',
      header: 'Status',
      cell: (item) => <Badge color={item.isActive ? 'green' : 'grey'}>{item.isActive ? 'Active' : 'Inactive'}</Badge>,
    },
    {
      id: 'permissions',
      header: 'Permissions',
      cell: (item) => (
        <SpaceBetween size="xxs" direction="horizontal">
          {[
            { label: 'Bill', enabled: item.canBill },
            { label: 'Reports', enabled: item.canViewReports },
            { label: 'Products', enabled: item.canManageProducts },
            { label: 'Masters', enabled: item.canManageMasters },
            { label: 'Expenses', enabled: item.canViewExpenses },
            { label: 'Purchase', enabled: item.canManagePurchase },
            { label: 'Dashboard', enabled: item.canViewDashboard },
          ].map(({ label, enabled }) => (
            <Badge key={label} color={enabled ? 'blue' : 'grey'}>
              {label}
            </Badge>
          ))}
        </SpaceBetween>
      ),
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: (item) => (
        <SpaceBetween direction="horizontal" size="xxs">
          <Button onClick={() => openEditModal(item)}>Edit</Button>
          <Button onClick={() => openPinModal(item)}>Change PIN</Button>
          <Button onClick={() => void handleDelete(item)}>Delete</Button>
        </SpaceBetween>
      ),
    },
  ]

  const openCreateModal = () => {
    setEditingUser(null)
    setForm(defaultUserForm)
    setError('')
    setNotice('')
    setIsModalOpen(true)
  }

  const openEditModal = (user: UserResponse) => {
    setEditingUser(user)
    setForm({
      username: user.username,
      pin: '',
      role: user.role,
      isActive: user.isActive,
      canBill: user.canBill,
      canViewReports: user.canViewReports,
      canManageProducts: user.canManageProducts,
      canManageMasters: user.canManageMasters,
      canViewExpenses: user.canViewExpenses,
      canManagePurchase: user.canManagePurchase,
      canViewDashboard: user.canViewDashboard,
    })
    setError('')
    setNotice('')
    setIsModalOpen(true)
  }

  const closeModal = () => {
    setIsModalOpen(false)
    setEditingUser(null)
    setForm(defaultUserForm)
  }

  const openPinModal = (user: UserResponse) => {
    setPinForm({ username: user.username, pin: '' })
    setError('')
    setNotice('')
    setIsPinModalOpen(true)
  }

  const closePinModal = () => {
    setIsPinModalOpen(false)
    setPinForm({ username: '', pin: '' })
  }

  const handleTextChange = (field: 'username' | 'pin', value: string) => {
    setForm((current) => ({ ...current, [field]: value }))
  }

  const handleRoleChange = (role: UserRole) => {
    setForm((current) => ({
      ...current,
      role,
      ...(role === 'admin'
        ? {
            canBill: true,
            canViewReports: true,
            canManageProducts: true,
            canManageMasters: true,
            canViewExpenses: true,
            canManagePurchase: true,
            canViewDashboard: true,
          }
        : {}),
    }))
  }

  const handleToggle = (field: keyof Omit<UserFormState, 'username' | 'pin' | 'role'>, checked: boolean) => {
    setForm((current) => ({ ...current, [field]: checked }))
  }

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setSaving(true)
    setError('')
    setNotice('')

    try {
      if (editingUser) {
        const payload: UpdateUserRequest = {
          role: form.role,
          isActive: form.isActive,
          canBill: form.canBill,
          canViewReports: form.canViewReports,
          canManageProducts: form.canManageProducts,
          canManageMasters: form.canManageMasters,
          canViewExpenses: form.canViewExpenses,
          canManagePurchase: form.canManagePurchase,
          canViewDashboard: form.canViewDashboard,
        }
        await updateUser(editingUser.username, payload)
        pushAuditEvent({
          module: 'users',
          action: 'update',
          detail: `Updated user ${editingUser.username}`,
          actor: actor ?? 'unknown',
        })
        setNotice('User updated successfully.')
      } else {
        const payload: CreateUserRequest = {
          username: form.username.trim(),
          pin: form.pin,
          role: form.role,
          isActive: form.isActive,
          canBill: form.canBill,
          canViewReports: form.canViewReports,
          canManageProducts: form.canManageProducts,
          canManageMasters: form.canManageMasters,
          canViewExpenses: form.canViewExpenses,
          canManagePurchase: form.canManagePurchase,
          canViewDashboard: form.canViewDashboard,
        }
        await createUser(payload)
        pushAuditEvent({
          module: 'users',
          action: 'create',
          detail: `Created user ${payload.username}`,
          actor: actor ?? 'unknown',
        })
        setNotice('User created successfully.')
      }

      closeModal()
      await loadUsers()
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (user: UserResponse) => {
    const shouldDelete = window.confirm(`Delete user ${user.username}?`)
    if (!shouldDelete) {
      return
    }

    setError('')
    setNotice('')

    try {
      await deleteUser(user.username)
      pushAuditEvent({
        module: 'users',
        action: 'delete',
        detail: `Deleted user ${user.username}`,
        actor: actor ?? 'unknown',
      })
      setNotice('User deleted successfully.')
      await loadUsers()
    } catch (err) {
      setError(extractApiError(err))
    }
  }

  const handlePinUpdate = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setSaving(true)
    setError('')
    setNotice('')

    try {
      await updateUserPin(pinForm.username, { pin: pinForm.pin })
      pushAuditEvent({
        module: 'users',
        action: 'pin_change',
        detail: `Updated PIN for ${pinForm.username}`,
        actor: actor ?? 'unknown',
      })
      setNotice('PIN updated successfully.')
      closePinModal()
    } catch (err) {
      setError(extractApiError(err))
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return <Spinner label="Loading users..." />
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Users</p>
          <h1 className="mt-2 text-3xl font-bold text-slate-900">Team access control</h1>
          <p className="mt-2 text-sm text-slate-500">Create cashier accounts, update permissions, and manage PIN access.</p>
        </div>
        <div className="flex flex-wrap gap-3">
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search users"
            className="rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
          />
          <button
            type="button"
            onClick={openCreateModal}
            className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700"
          >
            Add User
          </button>
        </div>
      </div>

      {error ? <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div> : null}
      {notice ? <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{notice}</div> : null}

      <Container>
        <EnterNavigableTable
          items={filteredUsers}
          selectedItems={selectedItems}
          onSelectionChange={setSelectedItems}
          columnDefinitions={columnDefinitions}
          trackBy="username"
          header={<Header description="Use the configured grid key to move selection row-by-row.">Users grid</Header>}
          empty={<Box color="text-body-secondary">No users found.</Box>}
        />
      </Container>

      {isModalOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4">
          <div className="w-full max-w-3xl rounded-3xl bg-white p-6 shadow-2xl md:p-8">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="text-2xl font-semibold text-slate-900">{editingUser ? 'Edit user' : 'Add user'}</h2>
                <p className="mt-1 text-sm text-slate-500">Set the role and feature access for this team member.</p>
              </div>
              <button type="button" onClick={closeModal} className="rounded-full p-2 text-slate-400 transition hover:bg-slate-100 hover:text-slate-600">✕</button>
            </div>

            <form className="mt-6 space-y-6" onSubmit={handleSubmit}>
              <div className="grid gap-4 md:grid-cols-2">
                <label>
                  <span className="mb-2 block text-sm font-medium text-slate-700">Username</span>
                  <input
                    required
                    disabled={Boolean(editingUser)}
                    value={form.username}
                    onChange={(event) => handleTextChange('username', event.target.value)}
                    className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100 disabled:bg-slate-100"
                  />
                </label>
                {!editingUser ? (
                  <label>
                    <span className="mb-2 block text-sm font-medium text-slate-700">PIN</span>
                    <input
                      required
                      pattern="\d{4}"
                      maxLength={4}
                      value={form.pin}
                      onChange={(event) => handleTextChange('pin', event.target.value.replace(/\D/g, '').slice(0, 4))}
                      className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                    />
                  </label>
                ) : null}
              </div>

              <div>
                <span className="mb-2 block text-sm font-medium text-slate-700">Role</span>
                <div className="flex flex-wrap gap-3">
                  {(['admin', 'user'] as UserRole[]).map((role) => (
                    <button
                      key={role}
                      type="button"
                      onClick={() => handleRoleChange(role)}
                      className={`rounded-2xl px-4 py-3 text-sm font-semibold transition ${form.role === role ? 'bg-indigo-600 text-white' : 'border border-slate-200 text-slate-700 hover:border-indigo-300 hover:text-indigo-600'}`}
                    >
                      {role}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <span className="mb-3 block text-sm font-medium text-slate-700">Permissions</span>
                <div className="grid gap-3 sm:grid-cols-2">
                  {permissionFields.map((field) => (
                    <label key={field.key} className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
                      <input
                        type="checkbox"
                        checked={form[field.key]}
                        onChange={(event) => handleToggle(field.key, event.target.checked)}
                        className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                      />
                      <span className="text-sm font-medium text-slate-700">{field.label}</span>
                    </label>
                  ))}
                </div>
              </div>

              <div className="flex justify-end gap-3">
                <button
                  type="button"
                  onClick={closeModal}
                  className="rounded-2xl border border-slate-200 px-5 py-3 text-sm font-semibold text-slate-700 transition hover:border-slate-300 hover:bg-slate-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300"
                >
                  {saving ? 'Saving...' : editingUser ? 'Save changes' : 'Create user'}
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {isPinModalOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4">
          <div className="w-full max-w-md rounded-3xl bg-white p-6 shadow-2xl md:p-8">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="text-2xl font-semibold text-slate-900">Change PIN</h2>
                <p className="mt-1 text-sm text-slate-500">Update the 4-digit PIN for {pinForm.username}.</p>
              </div>
              <button type="button" onClick={closePinModal} className="rounded-full p-2 text-slate-400 transition hover:bg-slate-100 hover:text-slate-600">✕</button>
            </div>

            <form className="mt-6 space-y-5" onSubmit={handlePinUpdate}>
              <label>
                <span className="mb-2 block text-sm font-medium text-slate-700">New PIN</span>
                <input
                  required
                  pattern="\d{4}"
                  maxLength={4}
                  value={pinForm.pin}
                  onChange={(event) => setPinForm((current) => ({ ...current, pin: event.target.value.replace(/\D/g, '').slice(0, 4) }))}
                  className="w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none transition focus:border-indigo-500 focus:ring-4 focus:ring-indigo-100"
                />
              </label>
              <div className="flex justify-end gap-3">
                <button
                  type="button"
                  onClick={closePinModal}
                  className="rounded-2xl border border-slate-200 px-5 py-3 text-sm font-semibold text-slate-700 transition hover:border-slate-300 hover:bg-slate-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving || pinForm.pin.length !== 4}
                  className="rounded-2xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-indigo-700 disabled:cursor-not-allowed disabled:bg-slate-300"
                >
                  {saving ? 'Updating...' : 'Update PIN'}
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  )
}

export default UsersPage
