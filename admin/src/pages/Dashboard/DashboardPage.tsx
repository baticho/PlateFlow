import { Card, Col, Row, Statistic, Typography, Spin } from 'antd'
import { UserOutlined, BookOutlined, CheckCircleOutlined, ShoppingOutlined } from '@ant-design/icons'
import { useQuery } from '@tanstack/react-query'
import { statisticsApi } from '../../api/endpoints/statistics'

const { Title } = Typography

interface DashboardStats {
  total_users: number
  active_users: number
  total_recipes: number
  published_recipes: number
  total_ingredients: number
}

export function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: () => statisticsApi.dashboard().then((r) => r.data as DashboardStats),
  })

  if (isLoading) {
    return <div style={{ textAlign: 'center', padding: 80 }}><Spin size="large" /></div>
  }

  const stats = [
    { title: 'Total Users', value: data?.total_users ?? 0, icon: <UserOutlined />, color: '#2E7D32' },
    { title: 'Active Users', value: data?.active_users ?? 0, icon: <CheckCircleOutlined />, color: '#1976D2' },
    { title: 'Total Recipes', value: data?.total_recipes ?? 0, icon: <BookOutlined />, color: '#F57C00' },
    { title: 'Published Recipes', value: data?.published_recipes ?? 0, icon: <CheckCircleOutlined />, color: '#7B1FA2' },
    { title: 'Ingredients', value: data?.total_ingredients ?? 0, icon: <ShoppingOutlined />, color: '#D32F2F' },
  ]

  return (
    <div>
      <Title level={3} style={{ marginBottom: 24 }}>Dashboard</Title>
      <Row gutter={[16, 16]}>
        {stats.map((s) => (
          <Col key={s.title} xs={24} sm={12} lg={8} xl={4}>
            <Card style={{ borderRadius: 12, borderTop: `4px solid ${s.color}` }}>
              <Statistic
                title={s.title}
                value={s.value}
                prefix={<span style={{ color: s.color }}>{s.icon}</span>}
                valueStyle={{ color: s.color, fontWeight: 600 }}
              />
            </Card>
          </Col>
        ))}
      </Row>
    </div>
  )
}
