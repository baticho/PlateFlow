import apiClient from '../client'

export const usersApi = {
  list: (params?: Record<string, unknown>) =>
    apiClient.get('/api/v1/admin/users', { params }),

  get: (id: string) =>
    apiClient.get(`/api/v1/admin/users/${id}`),

  update: (id: string, data: unknown) =>
    apiClient.patch(`/api/v1/admin/users/${id}`, data),
}
