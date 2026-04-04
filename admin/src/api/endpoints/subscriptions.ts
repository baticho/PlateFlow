import apiClient from '../client'

export const subscriptionsApi = {
  list: () => apiClient.get('/api/v1/admin/subscription-plans'),
  create: (data: unknown) => apiClient.post('/api/v1/admin/subscription-plans', data),
  update: (id: number, data: unknown) => apiClient.patch(`/api/v1/admin/subscription-plans/${id}`, data),
}
