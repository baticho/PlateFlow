import apiClient from '../client'

export const recipesApi = {
  list: (params?: Record<string, unknown>) =>
    apiClient.get('/api/v1/admin/recipes', { params }),

  get: (id: string) =>
    apiClient.get(`/api/v1/admin/recipes/${id}/full`),

  create: (data: unknown) =>
    apiClient.post('/api/v1/admin/recipes', data),

  save: (id: string, data: unknown) =>
    apiClient.put(`/api/v1/admin/recipes/${id}`, data),

  tags: () =>
    apiClient.get('/api/v1/admin/tags'),

  update: (id: string, data: unknown) =>
    apiClient.patch(`/api/v1/admin/recipes/${id}`, data),

  delete: (id: string) =>
    apiClient.delete(`/api/v1/admin/recipes/${id}`),
}
