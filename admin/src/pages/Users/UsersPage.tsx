import { useState } from 'react'
import { Table, Input, Space, Tag, Button, Typography, Switch, message } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { usersApi } from '../../api/endpoints/users'

const { Title } = Typography

interface User {
  id: string
  email: string
  full_name: string
  is_active: boolean
  is_admin: boolean
  admin_role: string | null
  created_at: string
}

export function UsersPage() {
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['admin-users', page, search],
    queryFn: () => usersApi.list({ page, page_size: 20, q: search || undefined }).then((r) => r.data),
  })

  const toggleActive = useMutation({
    mutationFn: ({ id, is_active }: { id: string; is_active: boolean }) =>
      usersApi.update(id, { is_active }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] })
      message.success('User updated')
    },
  })

  const columns = [
    { title: 'Name', dataIndex: 'full_name', key: 'full_name' },
    { title: 'Email', dataIndex: 'email', key: 'email' },
    {
      title: 'Role',
      key: 'role',
      render: (_: unknown, r: User) => r.is_admin ? (
        <Tag color="gold">{r.admin_role ?? 'admin'}</Tag>
      ) : (
        <Tag color="blue">User</Tag>
      ),
    },
    {
      title: 'Active',
      key: 'is_active',
      render: (_: unknown, r: User) => (
        <Switch
          checked={r.is_active}
          onChange={(checked) => toggleActive.mutate({ id: r.id, is_active: checked })}
        />
      ),
    },
    {
      title: 'Joined',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (v: string) => new Date(v).toLocaleDateString(),
    },
  ]

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center">
        <Title level={3} style={{ margin: 0 }}>Users</Title>
        <Input
          placeholder="Search by name or email..."
          prefix={<SearchOutlined />}
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1) }}
          style={{ width: 300 }}
          allowClear
        />
      </Space>
      <Table
        rowKey="id"
        dataSource={data?.items ?? []}
        columns={columns}
        loading={isLoading}
        pagination={{
          current: page,
          total: data?.total ?? 0,
          pageSize: 20,
          onChange: setPage,
          showTotal: (total) => `${total} users`,
        }}
      />
    </div>
  )
}
