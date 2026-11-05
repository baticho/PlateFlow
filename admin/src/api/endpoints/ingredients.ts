import apiClient from '../client'

export const ingredientsApi = {
  list: (params?: Record<string, unknown>) => apiClient.get('/api/v1/ingredients/', { params }),
  create: (data: unknown) => apiClient.post('/api/v1/admin/ingredients', data),
  update: (id: number, data: unknown) => apiClient.patch(`/api/v1/admin/ingredients/${id}`, data),
  delete: (id: number) => apiClient.delete(`/api/v1/admin/ingredients/${id}`),
}
