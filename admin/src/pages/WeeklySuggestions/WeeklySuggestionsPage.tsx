import { useState } from 'react'
import { Table, Button, Space, Typography, DatePicker, InputNumber, Popconfirm, message, Form, Modal, Input } from 'antd'
import { PlusOutlined, DeleteOutlined } from '@ant-design/icons'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { weeklySuggestionsApi } from '../../api/endpoints/weeklySuggestions'
import dayjs from 'dayjs'

const { Title } = Typography

export function WeeklySuggestionsPage() {
  const [weekDate, setWeekDate] = useState<string>(
    dayjs().startOf('week').add(1, 'day').format('YYYY-MM-DD')
  )
  const [modalOpen, setModalOpen] = useState(false)
  const [form] = Form.useForm()
  const queryClient = useQueryClient()

  const { data, isLoading } = useQuery({
    queryKey: ['weekly-suggestions', weekDate],
    queryFn: () => weeklySuggestionsApi.list({ week_start: weekDate }).then((r) => r.data),
  })

  const createMutation = useMutation({
    mutationFn: (values: unknown) => weeklySuggestionsApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['weekly-suggestions'] })
      message.success('Suggestion added')
      setModalOpen(false)
      form.resetFields()
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: number) => weeklySuggestionsApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['weekly-suggestions'] })
      message.success('Removed')
    },
  })

  const columns = [
    { title: 'Position', dataIndex: 'position', key: 'position' },
    {
      title: 'Recipe',
      render: (_: unknown, r: { recipe?: { translations?: { language_code: string; title: string }[] } }) =>
        r.recipe?.translations?.find((t) => t.language_code === 'en')?.title ?? '—',
    },
    {
      title: 'Actions', key: 'actions',
      render: (_: unknown, r: { id: number }) => (
        <Popconfirm title="Remove?" onConfirm={() => deleteMutation.mutate(r.id)} okButtonProps={{ danger: true }}>
          <Button size="small" danger icon={<DeleteOutlined />}>Remove</Button>
        </Popconfirm>
      ),
    },
  ]

  const onSave = (values: { recipe_id: string; position: number }) => {
    createMutation.mutate({ week_start_date: weekDate, recipe_id: values.recipe_id, position: values.position })
  }

  return (
    <div>
      <Space style={{ marginBottom: 16, justifyContent: 'space-between', width: '100%' }} align="center">
        <Title level={3} style={{ margin: 0 }}>Weekly Suggestions</Title>
        <Space>
          <DatePicker
            picker="week"
            defaultValue={dayjs(weekDate)}
            onChange={(d) => d && setWeekDate(d.startOf('week').add(1, 'day').format('YYYY-MM-DD'))}
          />
          <Button type="primary" icon={<PlusOutlined />} onClick={() => setModalOpen(true)}>Add</Button>
        </Space>
      </Space>
      <Table rowKey="id" dataSource={(data as { items?: unknown[] })?.items ?? []} columns={columns} loading={isLoading} />
      <Modal title="Add Suggestion" open={modalOpen} onCancel={() => setModalOpen(false)} footer={null}>
        <Form form={form} layout="vertical" onFinish={onSave}>
          <Form.Item name="recipe_id" label="Recipe ID (UUID)" rules={[{ required: true }]}><Input /></Form.Item>
          <Form.Item name="position" label="Position" initialValue={0}><InputNumber min={0} /></Form.Item>
          <Button type="primary" htmlType="submit" loading={createMutation.isPending} block>Add</Button>
        </Form>
      </Modal>
    </div>
  )
}
