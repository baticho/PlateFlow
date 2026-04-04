import { useState } from 'react'
import { Table, Input, Space, Tag, Button, Typography, Popconfirm, message } from 'antd'
import { PlusOutlined, EditOutlined, DeleteOutlined, SearchOutlined } from '@ant-design/icons'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { recipesApi } from '../../api/endpoints/recipes'

const { Title } = Typography

interface Recipe {
  id: string
  difficulty: string
  status: string
  total_time_minutes: number
  servings: number
  created_at: string
  translations: { language_code: string; title: string }[]
}

export function RecipesPage() {
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['admin-recipes', page, search],
    queryFn: () =>
      recipesApi.list({ page, page_size: 20, q: search || undefined }).then((r) => r.data),
  })

  const deleteRecipe = useMutation({
    mutationFn: (id: string) => recipesApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-recipes'] })
      message.success('Recipe deleted')
    },
  })

  const getTitle = (recipe: Recipe) =>
    recipe.translations?.find((t) => t.language_code === 'en')?.title ??
    recipe.translations?.[0]?.title ??
    '—'

  const statusColor = (s: string) => s === 'published' ? 'green' : 'orange'
  const difficultyColor = (d: string) => ({ easy: 'green', medium: 'orange', hard: 'red' }[d] ?? 'default')

  const columns = [
    { title: 'Title (EN)', key: 'title', render: (_: unknown, r: Recipe) => getTitle(r) },
    {
      title: 'Status', dataIndex: 'status', key: 'status',
      render: (s: string) => <Tag color={statusColor(s)}>{s}</Tag>,
    },
    {
      title: 'Difficulty', dataIndex: 'difficulty', key: 'difficulty',
      render: (d: string) => <Tag color={difficultyColor(d)}>{d}</Tag>,
    },
    { title: 'Time (min)', dataIndex: 'total_time_minutes', key: 'time' },
    { title: 'Servings', dataIndex: 'servings', key: 'servings' },
    {
      title: 'Actions', key: 'actions',
      render: (_: unknown, r: Recipe) => (
        <Space>
          <Button size="small" icon={<EditOutlined />} onClick={() => navigate(`/recipes/${r.id}/edit`)}>
            Edit
          </Button>
          <Popconfirm
            title="Delete this recipe?"
            onConfirm={() => deleteRecipe.mutate(r.id)}
            okText="Delete"
            okButtonProps={{ danger: true }}
          >
            <Button size="small" danger icon={<DeleteOutlined />}>Delete</Button>
          </Popconfirm>
        </Space>
      ),
    },
  ]

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center">
        <Title level={3} style={{ margin: 0 }}>Recipes</Title>
        <Space>
          <Input
            placeholder="Search recipes..."
            prefix={<SearchOutlined />}
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1) }}
            style={{ width: 280 }}
            allowClear
          />
          <Button type="primary" icon={<PlusOutlined />} onClick={() => navigate('/recipes/new')}>
            Add Recipe
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
          showTotal: (total) => `${total} recipes`,
        }}
      />
    </div>
  )
}
