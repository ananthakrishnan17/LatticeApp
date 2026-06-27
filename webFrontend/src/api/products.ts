import { apiClient } from './client'
import type { ProductResponse, ProductUpsertRequest } from '../types'

export const listProducts = async () => {
  const { data } = await apiClient.get<ProductResponse[] | { products: ProductResponse[] }>('/products')
  return Array.isArray(data) ? data : data.products ?? []
}

export const upsertProduct = async (payload: ProductUpsertRequest) => {
  const { data } = await apiClient.post<ProductResponse>('/products/upsert', payload)
  return data
}
