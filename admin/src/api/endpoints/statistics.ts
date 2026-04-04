import apiClient from '../client'

export const statisticsApi = {
  dashboard: () =>
    apiClient.get('/api/v1/admin/statistics/dashboard'),
}
