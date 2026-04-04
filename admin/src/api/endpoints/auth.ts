import apiClient from '../client'

export interface LoginResponse {
  access_token: string
  refresh_token: string
  token_type: string
}

export const authApi = {
  login: (email: string, password: string) =>
    apiClient.post<LoginResponse>('/api/v1/auth/login', { email, password }),

  getMe: () =>
    apiClient.get('/api/v1/users/me'),
}
