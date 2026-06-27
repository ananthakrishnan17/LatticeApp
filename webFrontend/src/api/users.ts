import { apiClient } from './client'
import type { CreateUserRequest, UpdateUserPinRequest, UpdateUserRequest, UserResponse } from '../types'

export const listUsers = async () => {
  const { data } = await apiClient.get<UserResponse[]>('/users')
  return data
}

export const getCurrentUser = async () => {
  const { data } = await apiClient.get<UserResponse>('/users/me')
  return data
}

export const createUser = async (payload: CreateUserRequest) => {
  const { data } = await apiClient.post<UserResponse>('/users', payload)
  return data
}

export const updateUser = async (username: string, payload: UpdateUserRequest) => {
  const { data } = await apiClient.put<UserResponse>(`/users/${encodeURIComponent(username)}`, payload)
  return data
}

export const updateUserPin = async (username: string, payload: UpdateUserPinRequest) => {
  const { data } = await apiClient.put<{ status: 'ok' }>(`/users/${encodeURIComponent(username)}/pin`, payload)
  return data
}

export const deleteUser = async (username: string) => {
  const { data } = await apiClient.delete<{ status: 'ok' }>(`/users/${encodeURIComponent(username)}`)
  return data
}
