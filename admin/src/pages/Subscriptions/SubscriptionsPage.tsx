import { Table, Tag, Typography } from 'antd'
import { CheckOutlined, CloseOutlined } from '@ant-design/icons'
import { useQuery } from '@tanstack/react-query'
import { subscriptionsApi } from '../../api/endpoints/subscriptions'

const { Title } = Typography

interface Plan {
  id: number
  slug: string
  name: string
  price_monthly: number
  price_yearly: number | null
  max_recipes_per_week: number
  max_meal_plans: number
  can_export_shopping_list: boolean
  can_use_delivery: boolean
  is_active: boolean
}

export function SubscriptionsPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['subscription-plans'],
    queryFn: () => subscriptionsApi.list().then((r) => r.data as Plan[]),
  })

  const yesNo = (v: boolean) => v ? <Tag color="green" icon={<CheckOutlined />}>Yes</Tag> : <Tag color="red" icon={<CloseOutlined />}>No</Tag>

  const columns = [
    { title: 'Name', dataIndex: 'name', key: 'name' },
    { title: 'Slug', dataIndex: 'slug', key: 'slug', render: (s: string) => <Tag>{s}</Tag> },
    { title: 'Monthly Price', dataIndex: 'price_monthly', key: 'price', render: (v: number) => v === 0 ? 'Free' : `$${v}` },
    { title: 'Yearly Price', dataIndex: 'price_yearly', key: 'yearly', render: (v: number | null) => v ? `$${v}` : '—' },
    { title: 'Recipes/week', dataIndex: 'max_recipes_per_week', key: 'recipes', render: (v: number) => v > 100 ? '∞' : v },
    { title: 'Meal Plans', dataIndex: 'max_meal_plans', key: 'plans', render: (v: number) => v > 100 ? '∞' : v },
    { title: 'Export Shopping List', dataIndex: 'can_export_shopping_list', key: 'export', render: yesNo },
    { title: 'Delivery', dataIndex: 'can_use_delivery', key: 'delivery', render: yesNo },
    { title: 'Active', dataIndex: 'is_active', key: 'active', render: yesNo },
  ]

  return (
    <div>
      <Title level={3} style={{ marginBottom: 16 }}>Subscription Plans</Title>
      <Table rowKey="id" dataSource={data ?? []} columns={columns} loading={isLoading} pagination={false} />
    </div>
  )
}
