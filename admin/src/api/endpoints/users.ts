import apiClient from '../client'

export const usersApi = {
  list: (params?: Record<string, unknown>) =>
    apiClient.get('/api/v1/admin/users', { params }),

  get: (id: string) =>
    apiClient.get(`/api/v1/admin/users/${id}`),

  create: (data: unknown) =>
    apiClient.post('/api/v1/admin/users', data),

  update: (id: string, data: unknown) =>
    apiClient.patch(`/api/v1/admin/users/${id}`, data),
}
