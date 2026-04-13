import apiClient from '../client'

export const categoriesApi = {
  list: () => apiClient.get('/api/v1/categories/'),
  create: (data: unknown) => apiClient.post('/api/v1/admin/categories', data),
  delete: (id: number) => apiClient.delete(`/api/v1/admin/categories/${id}`),
}
