import { useState } from 'react'
import { Table, Input, Space, Tag, Button, Typography, Switch, message, Modal, Form } from 'antd'
import { SearchOutlined, PlusOutlined, KeyOutlined } from '@ant-design/icons'
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
  const [createOpen, setCreateOpen] = useState(false)
  const [passwordUser, setPasswordUser] = useState<User | null>(null)
  const [createForm] = Form.useForm()
  const [passwordForm] = Form.useForm()
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

  const createUser = useMutation({
    mutationFn: (values: unknown) => usersApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] })
      message.success('User created')
      setCreateOpen(false)
      createForm.resetFields()
    },
    onError: (err: any) => {
      const detail = err?.response?.data?.detail
      message.error(typeof detail === 'string' ? detail : 'Failed to create user')
    },
  })

  const setPassword = useMutation({
    mutationFn: ({ id, password }: { id: string; password: string }) =>
      usersApi.update(id, { password }),
    onSuccess: () => {
      message.success('Password updated')
      setPasswordUser(null)
      passwordForm.resetFields()
    },
    onError: () => message.error('Failed to update password'),
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
    {
      title: 'Actions',
      key: 'actions',
      render: (_: unknown, r: User) => (
        <Button
          size="small"
          icon={<KeyOutlined />}
          onClick={() => { setPasswordUser(r); passwordForm.resetFields() }}
        >
          Set Password
        </Button>
      ),
    },
  ]

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center">
        <Title level={3} style={{ margin: 0 }}>Users</Title>
        <Space>
          <Input
            placeholder="Search by name or email..."
            prefix={<SearchOutlined />}
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1) }}
            style={{ width: 300 }}
            allowClear
          />
          <Button type="primary" icon={<PlusOutlined />} onClick={() => setCreateOpen(true)}>
            Add User
          </Button>
        </Space>
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

      {/* Create User Modal */}
      <Modal
        title="Add New User"
        open={createOpen}
        onCancel={() => { setCreateOpen(false); createForm.resetFields() }}
        onOk={() => createForm.submit()}
        confirmLoading={createUser.isPending}
        okText="Create User"
      >
        <Form
          form={createForm}
          layout="vertical"
          onFinish={(values) => createUser.mutate(values)}
          style={{ marginTop: 16 }}
        >
          <Form.Item
            name="full_name"
            label="Full Name"
            rules={[{ required: true, message: 'Enter full name' }]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            name="email"
            label="Email"
            rules={[{ required: true, type: 'email', message: 'Enter valid email' }]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            name="password"
            label="Password"
            rules={[{ required: true, min: 6, message: 'Min 6 characters' }]}
          >
            <Input.Password />
          </Form.Item>
        </Form>
      </Modal>

      {/* Set Password Modal */}
      <Modal
        title={`Set Password — ${passwordUser?.full_name ?? ''}`}
        open={!!passwordUser}
        onCancel={() => { setPasswordUser(null); passwordForm.resetFields() }}
        onOk={() => passwordForm.submit()}
        confirmLoading={setPassword.isPending}
        okText="Update Password"
      >
        <Form
          form={passwordForm}
          layout="vertical"
          onFinish={(values) => passwordUser && setPassword.mutate({ id: passwordUser.id, password: values.password })}
          style={{ marginTop: 16 }}
        >
          <Form.Item
            name="password"
            label="New Password"
            rules={[{ required: true, min: 6, message: 'Min 6 characters' }]}
          >
            <Input.Password />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  )
}
