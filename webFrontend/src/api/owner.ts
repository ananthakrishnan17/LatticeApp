import { apiClient } from './client'
import type { AssignUserRequest, OwnerBranchResponse, OwnerDashboardResponse, OwnerRoleResponse } from '../types'

export const getOwnerDashboard = async () => {
  const { data } = await apiClient.get<OwnerDashboardResponse>('/owner/dashboard')
  return data
}

export const listOwnerBranches = async () => {
  const { data } = await apiClient.get<OwnerBranchResponse[]>('/owner/branches')
  return data
}

export const createBranch = async (name: string) => {
  const { data } = await apiClient.post<OwnerBranchResponse>('/owner/branches', { name })
  return data
}

export const listOwnerRoles = async () => {
  const { data } = await apiClient.get<OwnerRoleResponse[]>('/owner/roles')
  return data
}

export const assignUserRole = async (username: string, payload: AssignUserRequest) => {
  const { data } = await apiClient.post<{ status: string }>(`/owner/users/${username}/assign`, payload)
  return data
}
