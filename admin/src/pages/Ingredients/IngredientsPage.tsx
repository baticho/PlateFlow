import { useState } from 'react'
import { Table, Button, Space, Typography, Modal, Form, Input, Select, InputNumber, Popconfirm, message } from 'antd'
import { PlusOutlined, DeleteOutlined, SearchOutlined } from '@ant-design/icons'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ingredientsApi } from '../../api/endpoints/ingredients'

const { Title } = Typography
const CATEGORIES = ['produce', 'dairy', 'meat', 'seafood', 'grains', 'spices', 'oils', 'sauces', 'baking', 'canned', 'frozen', 'beverages', 'other']
const UNITS = ['g', 'kg', 'ml', 'l', 'tsp', 'tbsp', 'cup', 'piece', 'oz', 'lb', 'fl_oz']

export function IngredientsPage() {
  const [modalOpen, setModalOpen] = useState(false)
  const [search, setSearch] = useState('')
  const [form] = Form.useForm()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['ingredients', search],
    queryFn: () => ingredientsApi.list({ q: search || undefined }).then((r) => r.data as { id: number; default_unit: string; category: string; calories_per_100g: number | null; translations: { language_code: string; name: string }[] }[]),
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

  const getName = (translations: { language_code: string; name: string }[]) =>
    translations.find((t) => t.language_code === 'en')?.name ?? '—'

  const columns = [
    { title: 'Name (EN)', render: (_: unknown, r: { translations: { language_code: string; name: string }[] }) => getName(r.translations) },
    { title: 'Name (BG)', render: (_: unknown, r: { translations: { language_code: string; name: string }[] }) => r.translations.find((t) => t.language_code === 'bg')?.name ?? '—' },
    { title: 'Category', dataIndex: 'category', key: 'category' },
    { title: 'Unit', dataIndex: 'default_unit', key: 'default_unit' },
    { title: 'Cal/100g', dataIndex: 'calories_per_100g', key: 'cal', render: (v: number | null) => v ?? '—' },
    {
      title: 'Actions', key: 'actions',
      render: (_: unknown, r: { id: number }) => (
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
      translations: [
        { language_code: 'en', name: values.en },
        { language_code: 'bg', name: values.bg },
      ],
    })
  }

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center">
        <Title level={3} style={{ margin: 0 }}>Ingredients</Title>
        <Space>
          <Input prefix={<SearchOutlined />} placeholder="Search..." value={search} onChange={(e) => setSearch(e.target.value)} style={{ width: 250 }} allowClear />
          <Button type="primary" icon={<PlusOutlined />} onClick={() => setModalOpen(true)}>Add Ingredient</Button>
        </Space>
      </Space>
      <Table rowKey="id" dataSource={data ?? []} columns={columns} loading={isLoading} />
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
          <Button type="primary" htmlType="submit" loading={createMutation.isPending} block>Create</Button>
        </Form>
      </Modal>
    </div>
  )
}
