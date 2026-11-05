import { useMemo, useState } from 'react'
import {
  Table, Button, Space, Typography, Modal, Form, Input, Select, InputNumber, Popconfirm, message,
  Image, Segmented, Card, Row, Col, Tag, Upload, Empty, Tooltip,
} from 'antd'
import {
  PlusOutlined, DeleteOutlined, SearchOutlined, UploadOutlined, AppstoreOutlined, UnorderedListOutlined,
  PictureOutlined,
} from '@ant-design/icons'
import type { UploadRequestOption } from 'rc-upload/lib/interface'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ingredientsApi } from '../../api/endpoints/ingredients'
import { ImageUpload, mediaUrl, uploadImage } from '../../components/ImageUpload'

const { Title, Text } = Typography
const CATEGORIES = ['produce', 'dairy', 'meat', 'seafood', 'grains', 'spices', 'oils', 'sauces', 'baking', 'canned', 'frozen', 'beverages', 'other']
const UNITS = ['g', 'kg', 'ml', 'l', 'tsp', 'tbsp', 'cup', 'piece', 'oz', 'lb', 'fl_oz']
const CATEGORY_COLORS: Record<string, string> = {
  produce: 'green', dairy: 'gold', meat: 'red', seafood: 'blue', grains: 'orange', spices: 'volcano',
  oils: 'lime', sauces: 'magenta', baking: 'purple', canned: 'geekblue', frozen: 'cyan', beverages: 'blue', other: 'default',
}

type Translation = { language_code: string; name: string }
type Ingredient = {
  id: number
  default_unit: string
  category: string
  calories_per_100g: number | null
  image_url?: string | null
  translations: Translation[]
}
type SortKey = 'name_en' | 'name_bg' | 'category' | 'image' | 'id'
type ImageFilter = 'all' | 'with' | 'without'

const nameOf = (r: Ingredient, lang: string) => r.translations.find((t) => t.language_code === lang)?.name ?? ''
const cat = (r: Ingredient) => (r.category || '').toLowerCase()

function compare(a: Ingredient, b: Ingredient, key: SortKey): number {
  switch (key) {
    case 'name_en': return nameOf(a, 'en').localeCompare(nameOf(b, 'en'))
    case 'name_bg': return nameOf(a, 'bg').localeCompare(nameOf(b, 'bg'), 'bg')
    case 'category': return cat(a).localeCompare(cat(b)) || nameOf(a, 'en').localeCompare(nameOf(b, 'en'))
    case 'image': return Number(!!b.image_url) - Number(!!a.image_url) || nameOf(a, 'en').localeCompare(nameOf(b, 'en'))
    default: return a.id - b.id
  }
}

function ReplaceImageButton({ id, onDone, block }: { id: number; onDone: (id: number, url: string) => void; block?: boolean }) {
  const [loading, setLoading] = useState(false)
  const customRequest = async ({ file, onSuccess, onError }: UploadRequestOption) => {
    setLoading(true)
    try {
      const url = await uploadImage(file as File, 'ingredients')
      onDone(id, url)
      onSuccess?.({ url })
    } catch (e) {
      message.error('Upload failed')
      onError?.(e as Error)
    } finally {
      setLoading(false)
    }
  }
  return (
    <Upload accept="image/*" showUploadList={false} customRequest={customRequest}>
      <Button size="small" icon={<UploadOutlined />} loading={loading} block={block}>Replace</Button>
    </Upload>
  )
}

function Thumb({ url, size }: { url?: string | null; size: number }) {
  if (!url) {
    return (
      <div style={{ width: size, height: size, borderRadius: 8, background: '#f5f5f5', border: '1px dashed #d9d9d9',
        display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#bbb', fontSize: size / 3 }}>
        <PictureOutlined />
      </div>
    )
  }
  return (
    <Image src={mediaUrl(url)} width={size} height={size}
      style={{ objectFit: 'cover', borderRadius: 8, background: '#fff', border: '1px solid #f0f0f0' }}
      preview={{ mask: 'Preview' }} />
  )
}

export function IngredientsPage() {
  const [modalOpen, setModalOpen] = useState(false)
  const [search, setSearch] = useState('')
  const [view, setView] = useState<'table' | 'grid'>(() => (localStorage.getItem('ingredients_view') as 'table' | 'grid') || 'table')
  const [sortKey, setSortKey] = useState<SortKey>('name_en')
  const [categoryFilter, setCategoryFilter] = useState<string[]>([])
  const [imageFilter, setImageFilter] = useState<ImageFilter>('all')
  const [form] = Form.useForm()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['ingredients', search],
    queryFn: () => ingredientsApi.list({ q: search || undefined }).then((r) => r.data as Ingredient[]),
  })

  const createMutation = useMutation({
    mutationFn: (values: unknown) => ingredientsApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ingredients'] })
      message.success('Ingredient created')
      setModalOpen(false)
      form.resetFields()
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: number) => ingredientsApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ingredients'] })
      message.success('Ingredient deleted')
    },
  })

  const imageMutation = useMutation({
    mutationFn: ({ id, image_url }: { id: number; image_url: string }) => ingredientsApi.update(id, { image_url }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ingredients'] })
      message.success('Image updated')
    },
  })
  const setImage = (id: number, url: string) => imageMutation.mutate({ id, image_url: url })

  const filtered = useMemo(() => {
    let rows = data ?? []
    if (categoryFilter.length) rows = rows.filter((r) => categoryFilter.includes(cat(r)))
    if (imageFilter === 'with') rows = rows.filter((r) => !!r.image_url)
    if (imageFilter === 'without') rows = rows.filter((r) => !r.image_url)
    return rows
  }, [data, categoryFilter, imageFilter])

  const gridRows = useMemo(() => [...filtered].sort((a, b) => compare(a, b, sortKey)), [filtered, sortKey])
  const withImages = (data ?? []).filter((r) => r.image_url).length

  const columns = [
    {
      title: 'Image', key: 'image', width: 120,
      sorter: (a: Ingredient, b: Ingredient) => compare(a, b, 'image'),
      render: (_: unknown, r: Ingredient) => (
        <Space direction="vertical" size={4} align="center">
          <Thumb url={r.image_url} size={80} />
          <ReplaceImageButton id={r.id} onDone={setImage} />
        </Space>
      ),
    },
    {
      title: 'Name (EN)', key: 'name_en', defaultSortOrder: 'ascend' as const,
      sorter: (a: Ingredient, b: Ingredient) => compare(a, b, 'name_en'),
      render: (_: unknown, r: Ingredient) => <Text strong>{nameOf(r, 'en') || '—'}</Text>,
    },
    {
      title: 'Name (BG)', key: 'name_bg',
      sorter: (a: Ingredient, b: Ingredient) => compare(a, b, 'name_bg'),
      render: (_: unknown, r: Ingredient) => nameOf(r, 'bg') || '—',
    },
    {
      title: 'Category', key: 'category',
      sorter: (a: Ingredient, b: Ingredient) => compare(a, b, 'category'),
      render: (_: unknown, r: Ingredient) => <Tag color={CATEGORY_COLORS[cat(r)]}>{cat(r)}</Tag>,
    },
    { title: 'Unit', dataIndex: 'default_unit', key: 'default_unit', width: 80 },
    { title: 'Cal/100g', dataIndex: 'calories_per_100g', key: 'cal', width: 100, render: (v: number | null) => v ?? '—' },
    {
      title: 'Actions', key: 'actions', width: 110,
      render: (_: unknown, r: Ingredient) => (
        <Popconfirm title="Delete?" onConfirm={() => deleteMutation.mutate(r.id)} okButtonProps={{ danger: true }}>
          <Button size="small" danger icon={<DeleteOutlined />}>Delete</Button>
        </Popconfirm>
      ),
    },
  ]

  const onSave = (values: Record<string, unknown>) => {
    createMutation.mutate({
      default_unit: values.default_unit,
      category: values.category,
      calories_per_100g: values.calories_per_100g ?? null,
      protein_per_100g: values.protein_per_100g ?? null,
      carbs_per_100g: values.carbs_per_100g ?? null,
      fat_per_100g: values.fat_per_100g ?? null,
      image_url: values.image_url ?? null,
      translations: [
        { language_code: 'en', name: values.en },
        { language_code: 'bg', name: values.bg },
      ],
    })
  }

  const changeView = (v: 'table' | 'grid') => {
    setView(v)
    try { localStorage.setItem('ingredients_view', v) } catch { /* ignore */ }
  }

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center" wrap>
        <Space align="baseline">
          <Title level={3} style={{ margin: 0 }}>Ingredients</Title>
          <Text type="secondary">{data?.length ?? 0} total · {withImages} with image</Text>
        </Space>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => setModalOpen(true)}>Add Ingredient</Button>
      </Space>

      <Space style={{ marginBottom: 16 }} wrap>
        <Input prefix={<SearchOutlined />} placeholder="Search..." value={search} onChange={(e) => setSearch(e.target.value)} style={{ width: 220 }} allowClear />
        <Select mode="multiple" allowClear placeholder="All categories" value={categoryFilter} onChange={setCategoryFilter}
          style={{ minWidth: 200 }} maxTagCount="responsive"
          options={CATEGORIES.map((c) => ({ value: c, label: c }))} />
        <Segmented value={imageFilter} onChange={(v) => setImageFilter(v as ImageFilter)}
          options={[{ label: 'All', value: 'all' }, { label: 'With image', value: 'with' }, { label: 'No image', value: 'without' }]} />
        {view === 'grid' && (
          <Select value={sortKey} onChange={setSortKey} style={{ width: 170 }}
            options={[
              { value: 'name_en', label: 'Sort: Name (EN)' },
              { value: 'name_bg', label: 'Sort: Name (BG)' },
              { value: 'category', label: 'Sort: Category' },
              { value: 'image', label: 'Sort: Image first' },
              { value: 'id', label: 'Sort: Newest last' },
            ]} />
        )}
        <Segmented value={view} onChange={(v) => changeView(v as 'table' | 'grid')}
          options={[
            { value: 'table', icon: <UnorderedListOutlined />, label: 'Table' },
            { value: 'grid', icon: <AppstoreOutlined />, label: 'Gallery' },
          ]} />
      </Space>

      {view === 'table' ? (
        <Table rowKey="id" dataSource={filtered} columns={columns} loading={isLoading}
          pagination={{ defaultPageSize: 20, showSizeChanger: true, pageSizeOptions: [20, 50, 100, 200] }} />
      ) : gridRows.length === 0 ? (
        <Empty style={{ marginTop: 48 }} />
      ) : (
        <Image.PreviewGroup>
          <Row gutter={[16, 16]}>
            {gridRows.map((r) => (
              <Col key={r.id} xs={12} sm={8} md={6} lg={4} xl={4} xxl={3}>
                <Card size="small" hoverable bodyStyle={{ padding: 10 }}
                  cover={
                    <div style={{ aspectRatio: '1 / 1', background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
                      {r.image_url
                        ? <Image src={mediaUrl(r.image_url)} width="100%" height="100%" style={{ objectFit: 'cover' }} preview={{ mask: 'Preview' }} />
                        : <PictureOutlined style={{ fontSize: 48, color: '#ddd' }} />}
                    </div>
                  }>
                  <Tooltip title={nameOf(r, 'en')}>
                    <Text strong ellipsis style={{ display: 'block' }}>{nameOf(r, 'en') || '—'}</Text>
                  </Tooltip>
                  <Text type="secondary" ellipsis style={{ display: 'block', fontSize: 12 }}>{nameOf(r, 'bg') || '—'}</Text>
                  <Space style={{ marginTop: 8, width: '100%', justifyContent: 'space-between' }}>
                    <Tag color={CATEGORY_COLORS[cat(r)]} style={{ margin: 0 }}>{cat(r)}</Tag>
                    <ReplaceImageButton id={r.id} onDone={setImage} />
                  </Space>
                </Card>
              </Col>
            ))}
          </Row>
        </Image.PreviewGroup>
      )}

      <Modal title="New Ingredient" open={modalOpen} onCancel={() => setModalOpen(false)} footer={null} width={600}>
        <Form form={form} layout="vertical" onFinish={onSave}>
          <Form.Item name="en" label="English Name" rules={[{ required: true }]}><Input /></Form.Item>
          <Form.Item name="bg" label="Bulgarian Name" rules={[{ required: true }]}><Input /></Form.Item>
          <Form.Item name="category" label="Category" rules={[{ required: true }]}>
            <Select options={CATEGORIES.map((c) => ({ value: c, label: c }))} />
          </Form.Item>
          <Form.Item name="default_unit" label="Default Unit" rules={[{ required: true }]}>
            <Select options={UNITS.map((u) => ({ value: u, label: u }))} />
          </Form.Item>
          <Space>
            <Form.Item name="calories_per_100g" label="Calories/100g"><InputNumber /></Form.Item>
            <Form.Item name="protein_per_100g" label="Protein/100g"><InputNumber /></Form.Item>
            <Form.Item name="carbs_per_100g" label="Carbs/100g"><InputNumber /></Form.Item>
            <Form.Item name="fat_per_100g" label="Fat/100g"><InputNumber /></Form.Item>
          </Space>
          <Form.Item name="image_url" label="Image">
            <ImageUpload kind="ingredients" height={160} />
          </Form.Item>
          <Button type="primary" htmlType="submit" loading={createMutation.isPending} block>Create</Button>
        </Form>
      </Modal>
    </div>
  )
}
