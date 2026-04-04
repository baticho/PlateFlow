import apiClient from '../client'

export const cuisinesApi = {
  list: (params?: Record<string, unknown>) => apiClient.get('/api/v1/cuisines', { params }),
  create: (data: unknown) => apiClient.post('/api/v1/admin/cuisines', data),
}
