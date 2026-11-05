import { useState } from 'react'
import { Table, Input, Space, Tag, Button, Typography, Switch, message, Modal, Form, Select, Segmented, Popconfirm, Tooltip } from 'antd'
import type { TablePaginationConfig } from 'antd'
import type { SorterResult } from 'antd/es/table/interface'
import { SearchOutlined, PlusOutlined, KeyOutlined, CrownOutlined, TeamOutlined, CloseOutlined } from '@ant-design/icons'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { usersApi } from '../../api/endpoints/users'
import { subscriptionsApi } from '../../api/endpoints/subscriptions'
import { useAuth } from '../../contexts/AuthContext'

const { Title } = Typography

interface User {
  id: string
  email: string
  full_name: string
  is_active: boolean
  is_admin: boolean
  admin_role: string | null
  role: string
  preferred_language?: string
  subscription_plan_id: number | null
  subscription_plan_slug: string | null
  household_id: number | null
  household_name: string | null
  is_household_owner: boolean
  created_at: string
}

const ROLES = [
  { value: 'user', label: 'User', color: 'blue' },
  { value: 'super_admin', label: 'Super admin', color: 'gold' },
  { value: 'content_manager', label: 'Content manager', color: 'purple' },
  { value: 'support', label: 'Support', color: 'cyan' },
]

export function UsersPage() {
  const { user: me } = useAuth()
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(20)
  const [role, setRole] = useState<string | undefined>()
  const [plan, setPlan] = useState<string | undefined>()
  const [active, setActive] = useState<'all' | 'active' | 'inactive'>('all')
  const [sort, setSort] = useState<{ key: string; order: 'asc' | 'desc' }>({ key: 'created_at', order: 'desc' })
  const [createOpen, setCreateOpen] = useState(false)
  const [passwordUser, setPasswordUser] = useState<User | null>(null)
  const [createForm] = Form.useForm()
  const [passwordForm] = Form.useForm()
  const queryClient = useQueryClient()

  const params = {
    page, page_size: pageSize, q: search || undefined, role, plan, sort: sort.key, order: sort.order,
    active: active === 'all' ? undefined : active === 'active',
  }
  const { data, isLoading } = useQuery({
    queryKey: ['admin-users', params],
    queryFn: () => usersApi.list(params).then((r) => r.data),
    placeholderData: (prev) => prev,
  })

  const { data: plans } = useQuery({
    queryKey: ['subscription-plans'],
    queryFn: () => subscriptionsApi.list().then((r) => r.data as { id: number; slug: string; name: string; price_monthly: string }[]),
  })
  const { data: households } = useQuery({
    queryKey: ['households'],
    queryFn: () => usersApi.households().then((r) => r.data as { id: number; name: string; owner_id: string; members: { id: string }[] }[]),
  })
  const refreshFamilies = () => {
    queryClient.invalidateQueries({ queryKey: ['admin-users'] })
    queryClient.invalidateQueries({ queryKey: ['households'] })
  }
  const familyAction = useMutation({
    mutationFn: (fn: () => Promise<unknown>) => fn(),
    onSuccess: () => { refreshFamilies(); message.success('Family updated') },
    onError: (err) => message.error(errorText(err, 'Failed to update family')),
  })
  const isPaid = (slug: string | null) => !!slug && slug !== 'free'

  const errorText = (err: any, fallback: string) => {
    const detail = err?.response?.data?.detail
    return typeof detail === 'string' ? detail : fallback
  }

  const updateUser = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Record<string, unknown> }) => usersApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] })
      message.success('User updated')
    },
    onError: (err) => message.error(errorText(err, 'Failed to update user')),
  })

  const createUser = useMutation({
    mutationFn: (values: unknown) => usersApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] })
      message.success('User created')
      setCreateOpen(false)
      createForm.resetFields()
    },
    onError: (err) => message.error(errorText(err, 'Failed to create user')),
  })

  const setPassword = useMutation({
    mutationFn: ({ id, password }: { id: string; password: string }) => usersApi.update(id, { password }),
    onSuccess: () => {
      message.success('Password updated')
      setPasswordUser(null)
      passwordForm.resetFields()
    },
    onError: () => message.error('Failed to update password'),
  })

  const sortOrder = (key: string) => (sort.key === key ? (sort.order === 'asc' ? 'ascend' : 'descend') : null) as 'ascend' | 'descend' | null
  const isMe = (r: User) => r.email === me?.email

  const columns = [
    { title: 'Name', dataIndex: 'full_name', key: 'name', sorter: true, sortOrder: sortOrder('name') },
    { title: 'Email', dataIndex: 'email', key: 'email', sorter: true, sortOrder: sortOrder('email') },
    {
      title: 'Role', key: 'role', width: 200, sorter: true, sortOrder: sortOrder('role'),
      render: (_: unknown, r: User) => isMe(r) ? (
        <Tag color={ROLES.find((x) => x.value === r.role)?.color}>{ROLES.find((x) => x.value === r.role)?.label ?? r.role} (you)</Tag>
      ) : (
        <Select
          size="small"
          value={r.role}
          style={{ width: 170 }}
          onChange={(value) => updateUser.mutate({ id: r.id, data: { admin_role: value } })}
          options={ROLES.map((x) => ({ value: x.value, label: <Tag color={x.color} style={{ margin: 0 }}>{x.label}</Tag> }))}
        />
      ),
    },
    {
      title: 'Plan', key: 'plan', width: 190, sorter: true, sortOrder: sortOrder('plan'),
      render: (_: unknown, r: User) => (
        <Select
          size="small"
          style={{ width: 170 }}
          value={r.subscription_plan_id ?? 0}
          onChange={(value) => updateUser.mutate({ id: r.id, data: { subscription_plan_id: value } })}
          options={[
            { value: 0, label: <Tag style={{ margin: 0 }}>Free (none)</Tag> },
            ...(plans ?? []).map((p) => ({
              value: p.id,
              label: <Tag color={isPaid(p.slug) ? 'green' : undefined} style={{ margin: 0 }}>{p.name}</Tag>,
            })),
          ]}
        />
      ),
    },
    {
      title: 'Family', key: 'family', width: 230, sorter: true, sortOrder: sortOrder('family'),
      render: (_: unknown, r: User) => r.household_id ? (
        <Space size={4}>
          <Tooltip title={r.is_household_owner ? 'Family owner: members use this account\'s meal plan, shopping list and plan' : 'Member: uses the owner\'s meal plan, shopping list and plan'}>
            <Tag color={r.is_household_owner ? 'gold' : 'geekblue'} icon={r.is_household_owner ? <CrownOutlined /> : <TeamOutlined />}>
              {r.household_name}
            </Tag>
          </Tooltip>
          <Popconfirm
            title={r.is_household_owner ? 'Dissolve this family?' : 'Remove from family?'}
            description={r.is_household_owner ? 'All members go back to their own meal plans.' : 'The user goes back to their own meal plan.'}
            onConfirm={() => familyAction.mutate(() => usersApi.removeMember(r.household_id!, r.id))}
          >
            <Button size="small" type="text" danger icon={<CloseOutlined />} />
          </Popconfirm>
        </Space>
      ) : (
        <Select
          size="small"
          style={{ width: 200 }}
          placeholder="Add to family…"
          value={null}
          onChange={(value: number | 'new') => {
            if (value === 'new') {
              familyAction.mutate(() => usersApi.createHousehold({ name: `${r.full_name} family`, owner_id: r.id }))
            } else {
              familyAction.mutate(() => usersApi.addMember(value, r.id))
            }
          }}
          options={[
            { value: 'new', label: <span><PlusOutlined /> New family (owner)</span> },
            ...(households ?? []).map((h) => ({ value: h.id, label: `${h.name} (${h.members.length})` })),
          ]}
        />
      ),
    },
    {
      title: 'Active', key: 'active', width: 90, sorter: true, sortOrder: sortOrder('active'),
      render: (_: unknown, r: User) => (
        <Switch checked={r.is_active} disabled={isMe(r)}
          onChange={(checked) => updateUser.mutate({ id: r.id, data: { is_active: checked } })} />
      ),
    },
    {
      title: 'Lang', dataIndex: 'preferred_language', key: 'lang', width: 70,
      render: (v?: string) => v ? <Tag>{v.toUpperCase()}</Tag> : '—',
    },
    {
      title: 'Joined', dataIndex: 'created_at', key: 'created_at', width: 120, sorter: true, sortOrder: sortOrder('created_at'),
      render: (v: string) => new Date(v).toLocaleDateString(),
    },
    {
      title: 'Actions', key: 'actions', width: 150,
      render: (_: unknown, r: User) => (
        <Button size="small" icon={<KeyOutlined />} onClick={() => { setPasswordUser(r); passwordForm.resetFields() }}>
          Set Password
        </Button>
      ),
    },
  ]

  const onTableChange = (p: TablePaginationConfig, _f: unknown, s: SorterResult<User> | SorterResult<User>[]) => {
    const one = Array.isArray(s) ? s[0] : s
    setSort(one?.order && one.columnKey
      ? { key: String(one.columnKey), order: one.order === 'ascend' ? 'asc' : 'desc' }
      : { key: 'created_at', order: 'desc' })
    if (p.pageSize && p.pageSize !== pageSize) { setPageSize(p.pageSize); setPage(1) } else setPage(p.current ?? 1)
  }

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center">
        <Title level={3} style={{ margin: 0 }}>Users</Title>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => setCreateOpen(true)}>Add User</Button>
      </Space>
      <Space style={{ marginBottom: 16 }} wrap>
        <Input placeholder="Search by name or email..." prefix={<SearchOutlined />} value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1) }} style={{ width: 300 }} allowClear />
        <Select placeholder="Plan" allowClear style={{ width: 170 }} value={plan}
          onChange={(v) => { setPlan(v); setPage(1) }}
          options={[{ value: 'none', label: 'Free (none)' }, ...(plans ?? []).map((p) => ({ value: p.slug, label: p.name }))]} />
        <Select placeholder="Role" allowClear style={{ width: 170 }} value={role}
          onChange={(v) => { setRole(v); setPage(1) }} options={ROLES.map((x) => ({ value: x.value, label: x.label }))} />
        <Segmented value={active} onChange={(v) => { setActive(v as typeof active); setPage(1) }}
          options={[{ value: 'all', label: 'All' }, { value: 'active', label: 'Active' }, { value: 'inactive', label: 'Inactive' }]} />
      </Space>

      <Table
        rowKey="id"
        dataSource={data?.items ?? []}
        columns={columns}
        loading={isLoading}
        onChange={onTableChange as never}
        pagination={{
          current: page, total: data?.total ?? 0, pageSize, showSizeChanger: true,
          pageSizeOptions: [20, 50, 100, 200], showTotal: (total) => `${total} users`,
        }}
      />

      <Modal title="Add New User" open={createOpen} onCancel={() => { setCreateOpen(false); createForm.resetFields() }}
        onOk={() => createForm.submit()} confirmLoading={createUser.isPending} okText="Create User">
        <Form form={createForm} layout="vertical" onFinish={(values) => createUser.mutate(values)} style={{ marginTop: 16 }}>
          <Form.Item name="full_name" label="Full Name" rules={[{ required: true, message: 'Enter full name' }]}><Input /></Form.Item>
          <Form.Item name="email" label="Email" rules={[{ required: true, type: 'email', message: 'Enter valid email' }]}><Input /></Form.Item>
          <Form.Item name="password" label="Password" rules={[{ required: true, min: 6, message: 'Min 6 characters' }]}><Input.Password /></Form.Item>
        </Form>
      </Modal>

      <Modal title={`Set Password — ${passwordUser?.full_name ?? ''}`} open={!!passwordUser}
        onCancel={() => { setPasswordUser(null); passwordForm.resetFields() }}
        onOk={() => passwordForm.submit()} confirmLoading={setPassword.isPending} okText="Update Password">
        <Form form={passwordForm} layout="vertical"
          onFinish={(values) => passwordUser && setPassword.mutate({ id: passwordUser.id, password: values.password })}
          style={{ marginTop: 16 }}>
          <Form.Item name="password" label="New Password" rules={[{ required: true, min: 6, message: 'Min 6 characters' }]}><Input.Password /></Form.Item>
        </Form>
      </Modal>
    </div>
  )
}
