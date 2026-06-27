import { apiClient } from './client'
import type {
  BrandRecord,
  BrandUpsertRequest,
  CategoryRecord,
  CategoryUpsertRequest,
  CustomerRecord,
  CustomerUpsertRequest,
  SupplierRecord,
  SupplierUpsertRequest,
} from '../types'

export const listCategories = async () => {
  const { data } = await apiClient.get<CategoryRecord[] | { categories: CategoryRecord[] }>('/categories')
  return Array.isArray(data) ? data : data.categories ?? []
}

export const upsertCategory = async (payload: CategoryUpsertRequest) => {
  const { data } = await apiClient.post<{ status: string; clientRecordId: string }>('/categories/upsert', payload)
  return data
}

export const listBrands = async () => {
  const { data } = await apiClient.get<BrandRecord[] | { brands: BrandRecord[] }>('/brands')
  return Array.isArray(data) ? data : data.brands ?? []
}

export const upsertBrand = async (payload: BrandUpsertRequest) => {
  const { data } = await apiClient.post<{ status: string; clientRecordId: string }>('/brands/upsert', payload)
  return data
}

export const listCustomers = async () => {
  const { data } = await apiClient.get<CustomerRecord[] | { customers: CustomerRecord[] }>('/customers')
  return Array.isArray(data) ? data : data.customers ?? []
}

export const upsertCustomer = async (payload: CustomerUpsertRequest) => {
  const { data } = await apiClient.post<{ status: string; clientRecordId: string }>('/customers/upsert', payload)
  return data
}

export const listSuppliers = async () => {
  const { data } = await apiClient.get<SupplierRecord[] | { suppliers: SupplierRecord[] }>('/suppliers')
  return Array.isArray(data) ? data : data.suppliers ?? []
}

export const upsertSupplier = async (payload: SupplierUpsertRequest) => {
  const { data } = await apiClient.post<{ status: string; clientRecordId: string }>('/suppliers/upsert', payload)
  return data
}
