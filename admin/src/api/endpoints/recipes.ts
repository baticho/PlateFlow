import apiClient from '../client'

export const recipesApi = {
  list: (params?: Record<string, unknown>) =>
    apiClient.get('/api/v1/admin/recipes', { params }),

  get: (id: string) =>
    apiClient.get(`/api/v1/recipes/${id}`),

  create: (data: unknown) =>
    apiClient.post('/api/v1/recipes', data),

  update: (id: string, data: unknown) =>
    apiClient.patch(`/api/v1/admin/recipes/${id}`, data),

  delete: (id: string) =>
    apiClient.delete(`/api/v1/admin/recipes/${id}`),
}
