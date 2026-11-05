import { useState } from 'react'
import { Table, Input, Space, Tag, Button, Typography, Popconfirm, message, Image, Select, Segmented, Switch, Tooltip } from 'antd'
import type { TablePaginationConfig } from 'antd'
import type { SorterResult } from 'antd/es/table/interface'
import { PlusOutlined, EditOutlined, DeleteOutlined, SearchOutlined, PictureOutlined } from '@ant-design/icons'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { recipesApi } from '../../api/endpoints/recipes'
import { mediaUrl } from '../../components/ImageUpload'

const { Title, Text } = Typography

interface Recipe {
  id: string
  difficulty: string
  status: string
  total_time_minutes: number
  servings: number
  image_url: string | null
  created_at: string
  translations: { language_code: string; title: string }[]
}

const SORT_KEYS: Record<string, string> = {
  title: 'title', status: 'status', difficulty: 'difficulty', time: 'time', servings: 'servings',
  created_at: 'created_at', image: 'image',
}

export function RecipesPage() {
  const { i18n } = useTranslation()
  const lang = i18n.language === 'bg' ? 'bg' : 'en'
  const other = lang === 'bg' ? 'en' : 'bg'
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(20)
  const [sort, setSort] = useState<{ key: string; order: 'asc' | 'desc' }>({ key: 'created_at', order: 'desc' })
  const [status, setStatus] = useState<string | undefined>()
  const [difficulty, setDifficulty] = useState<string | undefined>()
  const [imageFilter, setImageFilter] = useState<'all' | 'with' | 'without'>('all')
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const params = {
    page, page_size: pageSize, q: search || undefined, lang, sort: sort.key, order: sort.order,
    status, difficulty, has_image: imageFilter === 'all' ? undefined : imageFilter === 'with',
  }
  const { data, isLoading } = useQuery({
    queryKey: ['admin-recipes', params],
    queryFn: () => recipesApi.list(params).then((r) => r.data),
    placeholderData: (prev) => prev,
  })

  const deleteRecipe = useMutation({
    mutationFn: (id: string) => recipesApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-recipes'] })
      message.success('Recipe deleted')
    },
  })

  const setRecipeStatus = useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) => recipesApi.update(id, { status }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-recipes'] }),
  })

  const titleIn = (r: Recipe, l: string) => r.translations?.find((t) => t.language_code === l)?.title

  const difficultyColor = (d: string) => ({ easy: 'green', medium: 'orange', hard: 'red' }[d] ?? 'default')
  const sortOrder = (key: string) => (sort.key === key ? (sort.order === 'asc' ? 'ascend' : 'descend') : null) as 'ascend' | 'descend' | null

  const columns = [
    {
      title: <PictureOutlined />, key: 'image', width: 96, sorter: true, sortOrder: sortOrder('image'),
      render: (_: unknown, r: Recipe) => r.image_url ? (
        <Image src={mediaUrl(r.image_url)} width={80} height={60} style={{ objectFit: 'cover', borderRadius: 6 }} />
      ) : (
        <div style={{ width: 80, height: 60, borderRadius: 6, background: '#f0f0f0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <PictureOutlined style={{ color: '#bbb', fontSize: 20 }} />
        </div>
      ),
    },
    {
      title: `Title (${lang.toUpperCase()})`, key: 'title', sorter: true, sortOrder: sortOrder('title'),
      render: (_: unknown, r: Recipe) => (
        <div>
          <Text strong>{titleIn(r, lang) ?? titleIn(r, other) ?? '—'}</Text>
          {titleIn(r, other) && <div><Text type="secondary" style={{ fontSize: 12 }}>{titleIn(r, other)}</Text></div>}
        </div>
      ),
    },
    {
      title: 'Status', dataIndex: 'status', key: 'status', width: 130, sorter: true, sortOrder: sortOrder('status'),
      render: (s: string, r: Recipe) => (
        <Tooltip title="Published / draft">
          <Space size={6}>
            <Switch size="small" checked={s === 'published'}
              onChange={(on) => setRecipeStatus.mutate({ id: r.id, status: on ? 'published' : 'draft' })} />
            <Tag color={s === 'published' ? 'green' : 'orange'}>{s}</Tag>
          </Space>
        </Tooltip>
      ),
    },
    {
      title: 'Difficulty', dataIndex: 'difficulty', key: 'difficulty', width: 110, sorter: true, sortOrder: sortOrder('difficulty'),
      render: (d: string) => <Tag color={difficultyColor(d)}>{d}</Tag>,
    },
    { title: 'Time', dataIndex: 'total_time_minutes', key: 'time', width: 90, sorter: true, sortOrder: sortOrder('time'), render: (m: number) => `${m} min` },
    { title: 'Servings', dataIndex: 'servings', key: 'servings', width: 100, sorter: true, sortOrder: sortOrder('servings') },
    {
      title: 'Created', dataIndex: 'created_at', key: 'created_at', width: 110, sorter: true, sortOrder: sortOrder('created_at'),
      render: (v: string) => new Date(v).toLocaleDateString(),
    },
    {
      title: 'Actions', key: 'actions', width: 170,
      render: (_: unknown, r: Recipe) => (
        <Space>
          <Button size="small" icon={<EditOutlined />} onClick={() => navigate(`/recipes/${r.id}/edit`)}>Edit</Button>
          <Popconfirm title="Delete this recipe?" onConfirm={() => deleteRecipe.mutate(r.id)} okText="Delete" okButtonProps={{ danger: true }}>
            <Button size="small" danger icon={<DeleteOutlined />} />
          </Popconfirm>
        </Space>
      ),
    },
  ]

  const onTableChange = (p: TablePaginationConfig, _f: unknown, s: SorterResult<Recipe> | SorterResult<Recipe>[]) => {
    const one = Array.isArray(s) ? s[0] : s
    if (one?.order && one.columnKey) {
      setSort({ key: SORT_KEYS[String(one.columnKey)] ?? 'created_at', order: one.order === 'ascend' ? 'asc' : 'desc' })
    } else {
      setSort({ key: 'created_at', order: 'desc' })
    }
    if (p.pageSize && p.pageSize !== pageSize) { setPageSize(p.pageSize); setPage(1) } else setPage(p.current ?? 1)
  }

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center" wrap>
        <Title level={3} style={{ margin: 0 }}>Recipes</Title>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => navigate('/recipes/new')}>Add Recipe</Button>
      </Space>
      <Space style={{ marginBottom: 16 }} wrap>
        <Input placeholder="Search title (EN or BG)..." prefix={<SearchOutlined />} value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1) }} style={{ width: 280 }} allowClear />
        <Select placeholder="Status" allowClear style={{ width: 130 }} value={status}
          onChange={(v) => { setStatus(v); setPage(1) }}
          options={[{ value: 'published', label: 'Published' }, { value: 'draft', label: 'Draft' }]} />
        <Select placeholder="Difficulty" allowClear style={{ width: 130 }} value={difficulty}
          onChange={(v) => { setDifficulty(v); setPage(1) }}
          options={['easy', 'medium', 'hard'].map((d) => ({ value: d, label: d }))} />
        <Segmented value={imageFilter} onChange={(v) => { setImageFilter(v as typeof imageFilter); setPage(1) }}
          options={[{ value: 'all', label: 'All' }, { value: 'with', label: 'With image' }, { value: 'without', label: 'No image' }]} />
      </Space>
      <Table
        rowKey="id"
        dataSource={data?.items ?? []}
        columns={columns}
        loading={isLoading}
        onChange={onTableChange as never}
        pagination={{
          current: page, total: data?.total ?? 0, pageSize, showSizeChanger: true,
          pageSizeOptions: [20, 50, 100, 200], showTotal: (total) => `${total} recipes`,
        }}
      />
    </div>
  )
}
