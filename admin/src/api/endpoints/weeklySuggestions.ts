import apiClient from '../client'

export const weeklySuggestionsApi = {
  list: (params?: Record<string, unknown>) => apiClient.get('/api/v1/weekly-suggestions', { params }),
  create: (data: unknown) => apiClient.post('/api/v1/admin/weekly-suggestions', data),
  update: (id: number, data: { position: number }) => apiClient.patch(`/api/v1/admin/weekly-suggestions/${id}`, data),
  delete: (id: number) => apiClient.delete(`/api/v1/admin/weekly-suggestions/${id}`),
  searchRecipes: (q?: string) => apiClient.get('/api/v1/admin/recipes', { params: { q: q || undefined, page_size: 50 } }),
}
