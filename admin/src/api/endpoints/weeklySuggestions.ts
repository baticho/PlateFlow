import apiClient from '../client'

export const weeklySuggestionsApi = {
  list: (params?: Record<string, unknown>) => apiClient.get('/api/v1/weekly-suggestions', { params }),
  create: (data: unknown) => apiClient.post('/api/v1/admin/weekly-suggestions', data),
  delete: (id: number) => apiClient.delete(`/api/v1/admin/weekly-suggestions/${id}`),
}
