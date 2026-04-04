import { useState } from 'react'
import { Table, Button, Space, Typography, Modal, Form, Input, Select, message } from 'antd'
import { PlusOutlined } from '@ant-design/icons'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { cuisinesApi } from '../../api/endpoints/cuisines'

const { Title } = Typography

const CONTINENTS = ['europe', 'asia', 'north_america', 'south_america', 'africa', 'oceania']

export function CuisinesPage() {
  const [modalOpen, setModalOpen] = useState(false)
  const [form] = Form.useForm()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['cuisines'],
    queryFn: () => cuisinesApi.list().then((r) => r.data as { id: number; continent: string; country_code: string; translations: { language_code: string; name: string }[] }[]),
  })

  const createMutation = useMutation({
    mutationFn: (values: unknown) => cuisinesApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cuisines'] })
      message.success('Cuisine created')
      setModalOpen(false)
      form.resetFields()
    },
  })

  const columns = [
    { title: 'Country Code', dataIndex: 'country_code', key: 'country_code' },
    { title: 'Continent', dataIndex: 'continent', key: 'continent' },
    {
      title: 'English',
      render: (_: unknown, r: { translations: { language_code: string; name: string }[] }) =>
        r.translations.find((t) => t.language_code === 'en')?.name ?? '—',
    },
    {
      title: 'Български',
      render: (_: unknown, r: { translations: { language_code: string; name: string }[] }) =>
        r.translations.find((t) => t.language_code === 'bg')?.name ?? '—',
    },
  ]

  const onSave = (values: { continent: string; country_code: string; en: string; bg: string }) => {
    createMutation.mutate({
      continent: values.continent,
      country_code: values.country_code,
      translations: [
        { language_code: 'en', name: values.en },
        { language_code: 'bg', name: values.bg },
      ],
    })
  }

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center">
        <Title level={3} style={{ margin: 0 }}>Cuisines</Title>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => setModalOpen(true)}>Add Cuisine</Button>
      </Space>
      <Table rowKey="id" dataSource={data ?? []} columns={columns} loading={isLoading} />
      <Modal title="New Cuisine" open={modalOpen} onCancel={() => setModalOpen(false)} footer={null}>
        <Form form={form} layout="vertical" onFinish={onSave}>
          <Form.Item name="continent" label="Continent" rules={[{ required: true }]}>
            <Select options={CONTINENTS.map((c) => ({ value: c, label: c }))} />
          </Form.Item>
          <Form.Item name="country_code" label="Country Code (e.g. BG)" rules={[{ required: true }]}>
            <Input maxLength={3} />
          </Form.Item>
          <Form.Item name="en" label="English Name" rules={[{ required: true }]}><Input /></Form.Item>
          <Form.Item name="bg" label="Bulgarian Name" rules={[{ required: true }]}><Input /></Form.Item>
          <Button type="primary" htmlType="submit" loading={createMutation.isPending} block>Create</Button>
        </Form>
      </Modal>
    </div>
  )
}
