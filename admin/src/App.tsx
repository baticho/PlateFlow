import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { ConfigProvider, theme } from 'antd'
import { AuthProvider } from './contexts/AuthContext'
import { ProtectedRoute } from './components/guards/ProtectedRoute'
import { AdminLayout } from './layouts/AdminLayout'
import { AuthLayout } from './layouts/AuthLayout'
import { LoginPage } from './pages/Login/LoginPage'
import { DashboardPage } from './pages/Dashboard/DashboardPage'
import { UsersPage } from './pages/Users/UsersPage'
import { RecipesPage } from './pages/Recipes/RecipesPage'
import { RecipeFormPage } from './pages/Recipes/RecipeFormPage'
import { CategoriesPage } from './pages/Categories/CategoriesPage'
import { CuisinesPage } from './pages/Cuisines/CuisinesPage'
import { IngredientsPage } from './pages/Ingredients/IngredientsPage'
import { SubscriptionsPage } from './pages/Subscriptions/SubscriptionsPage'
import { WeeklySuggestionsPage } from './pages/WeeklySuggestions/WeeklySuggestionsPage'
import { SettingsPage } from './pages/Settings/SettingsPage'

const plateflowTheme = {
  token: {
    colorPrimary: '#2E7D32',
    colorLink: '#2E7D32',
    borderRadius: 8,
    fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
  },
  algorithm: theme.defaultAlgorithm,
}

export default function App() {
  return (
    <ConfigProvider theme={plateflowTheme}>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route element={<AuthLayout />}>
              <Route path="/login" element={<LoginPage />} />
            </Route>
            <Route element={<ProtectedRoute />}>
              <Route element={<AdminLayout />}>
                <Route path="/" element={<Navigate to="/dashboard" replace />} />
                <Route path="/dashboard" element={<DashboardPage />} />
                <Route path="/users" element={<UsersPage />} />
                <Route path="/recipes" element={<RecipesPage />} />
                <Route path="/recipes/new" element={<RecipeFormPage />} />
                <Route path="/recipes/:id/edit" element={<RecipeFormPage />} />
                <Route path="/categories" element={<CategoriesPage />} />
                <Route path="/cuisines" element={<CuisinesPage />} />
                <Route path="/ingredients" element={<IngredientsPage />} />
                <Route path="/subscriptions" element={<SubscriptionsPage />} />
                <Route path="/weekly-suggestions" element={<WeeklySuggestionsPage />} />
                <Route path="/settings" element={<SettingsPage />} />
              </Route>
            </Route>
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ConfigProvider>
  )
}
