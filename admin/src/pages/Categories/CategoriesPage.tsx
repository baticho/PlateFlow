import { useState } from 'react'
import { Table, Button, Space, Typography, Modal, Form, Input, Popconfirm, message } from 'antd'
import { PlusOutlined, DeleteOutlined } from '@ant-design/icons'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { categoriesApi } from '../../api/endpoints/categories'

const { Title } = Typography

export function CategoriesPage() {
  const [modalOpen, setModalOpen] = useState(false)
  const [form] = Form.useForm()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['categories'],
    queryFn: () => categoriesApi.list().then((r) => r.data as { id: number; slug: string; translations: { language_code: string; name: string }[] }[]),
  })

  const createMutation = useMutation({
    mutationFn: (values: unknown) => categoriesApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['categories'] })
      message.success('Category created')
      setModalOpen(false)
      form.resetFields()
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: number) => categoriesApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['categories'] })
      message.success('Category deleted')
    },
  })

  const getName = (translations: { language_code: string; name: string }[], lang: string) =>
    translations.find((t) => t.language_code === lang)?.name ?? '—'

  const columns = [
    { title: 'Slug', dataIndex: 'slug', key: 'slug' },
    { title: 'English', key: 'en', render: (_: unknown, r: { translations: { language_code: string; name: string }[] }) => getName(r.translations, 'en') },
    { title: 'Български', key: 'bg', render: (_: unknown, r: { translations: { language_code: string; name: string }[] }) => getName(r.translations, 'bg') },
    {
      title: 'Actions', key: 'actions',
      render: (_: unknown, r: { id: number }) => (
        <Popconfirm title="Delete?" onConfirm={() => deleteMutation.mutate(r.id)} okText="Delete" okButtonProps={{ danger: true }}>
          <Button size="small" danger icon={<DeleteOutlined />}>Delete</Button>
        </Popconfirm>
      ),
    },
  ]

  const onSave = (values: { slug: string; en: string; bg: string }) => {
    createMutation.mutate({
      slug: values.slug,
      translations: [
        { language_code: 'en', name: values.en },
        { language_code: 'bg', name: values.bg },
      ],
    })
  }

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center">
        <Title level={3} style={{ margin: 0 }}>Categories</Title>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => setModalOpen(true)}>Add Category</Button>
      </Space>
      <Table rowKey="id" dataSource={data ?? []} columns={columns} loading={isLoading} pagination={false} />
      <Modal title="New Category" open={modalOpen} onCancel={() => setModalOpen(false)} footer={null}>
        <Form form={form} layout="vertical" onFinish={onSave}>
          <Form.Item name="slug" label="Slug" rules={[{ required: true }]}><Input /></Form.Item>
          <Form.Item name="en" label="English Name" rules={[{ required: true }]}><Input /></Form.Item>
          <Form.Item name="bg" label="Bulgarian Name" rules={[{ required: true }]}><Input /></Form.Item>
          <Button type="primary" htmlType="submit" loading={createMutation.isPending} block>Create</Button>
        </Form>
      </Modal>
    </div>
  )
}
