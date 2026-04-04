import { Outlet } from 'react-router-dom'

export function AuthLayout() {
  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'linear-gradient(135deg, #e8f5e9 0%, #c8e6c9 100%)',
    }}>
      <Outlet />
    </div>
  )
}
