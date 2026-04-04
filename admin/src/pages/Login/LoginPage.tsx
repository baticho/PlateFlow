import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Form, Input, Button, Card, Typography, Alert } from 'antd'
import { UserOutlined, LockOutlined } from '@ant-design/icons'
import { useAuth } from '../../contexts/AuthContext'

const { Title, Text } = Typography

export function LoginPage() {
  const navigate = useNavigate()
  const { login } = useAuth()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const onFinish = async (values: { email: string; password: string }) => {
    setLoading(true)
    setError(null)
    try {
      await login(values.email, values.password)
      navigate('/dashboard')
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { detail?: string } }; message?: string })
        ?.response?.data?.detail || (e as { message?: string })?.message || 'Login failed'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Card style={{ width: 400, boxShadow: '0 8px 32px rgba(0,0,0,0.12)', borderRadius: 16 }}>
      <div style={{ textAlign: 'center', marginBottom: 32 }}>
        <Title level={2} style={{ color: '#2E7D32', fontFamily: 'Poppins, sans-serif', marginBottom: 4 }}>
          🌿 PlateFlow
        </Title>
        <Text type="secondary">Admin Panel</Text>
      </div>

      {error && <Alert message={error} type="error" style={{ marginBottom: 16 }} showIcon />}

      <Form layout="vertical" onFinish={onFinish}>
        <Form.Item name="email" rules={[{ required: true, type: 'email', message: 'Valid email required' }]}>
          <Input prefix={<UserOutlined />} placeholder="Email" size="large" />
        </Form.Item>
        <Form.Item name="password" rules={[{ required: true, message: 'Password required' }]}>
          <Input.Password prefix={<LockOutlined />} placeholder="Password" size="large" />
        </Form.Item>
        <Form.Item>
          <Button type="primary" htmlType="submit" loading={loading} block size="large">
            Sign In
          </Button>
        </Form.Item>
      </Form>
    </Card>
  )
}
