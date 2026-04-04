import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  Form, Input, InputNumber, Select, Button, Card, Row, Col,
  Tabs, Space, Typography, message, Divider
} from 'antd'
import { ArrowLeftOutlined, PlusOutlined, MinusCircleOutlined } from '@ant-design/icons'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { recipesApi } from '../../api/endpoints/recipes'

const { Title } = Typography
const { TextArea } = Input
const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'bg', label: 'Български' },
]

export function RecipeFormPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [form] = Form.useForm()
  const isEdit = !!id

  const saveMutation = useMutation({
    mutationFn: (values: unknown) =>
      isEdit ? recipesApi.update(id!, values) : recipesApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-recipes'] })
      message.success(isEdit ? 'Recipe updated' : 'Recipe created')
      navigate('/recipes')
    },
    onError: () => message.error('Failed to save recipe'),
  })

  const onFinish = (values: unknown) => saveMutation.mutate(values)

  const translationTabs = LANGUAGES.map((lang) => ({
    key: lang.code,
    label: lang.label,
    children: (
      <Row gutter={16}>
        <Col span={24}>
          <Form.Item
            name={['translations', lang.code, 'title']}
            label="Title"
            rules={[{ required: lang.code === 'en', message: 'English title is required' }]}
          >
            <Input placeholder={`Recipe title in ${lang.label}`} />
          </Form.Item>
        </Col>
        <Col span={24}>
          <Form.Item name={['translations', lang.code, 'description']} label="Description">
            <TextArea rows={3} placeholder={`Description in ${lang.label}`} />
          </Form.Item>
        </Col>
        <Col span={24}>
          <Divider orientation="left">Steps</Divider>
          <Form.List name={['steps', lang.code]}>
            {(fields, { add, remove }) => (
              <>
                {fields.map((field, idx) => (
                  <Space key={field.key} align="baseline" style={{ display: 'flex', marginBottom: 8 }}>
                    <span style={{ color: '#888', minWidth: 24 }}>{idx + 1}.</span>
                    <Form.Item {...field} style={{ flex: 1, marginBottom: 0 }}>
                      <TextArea rows={2} placeholder={`Step ${idx + 1}`} style={{ width: 500 }} />
                    </Form.Item>
                    <MinusCircleOutlined onClick={() => remove(field.name)} style={{ color: '#ff4d4f' }} />
                  </Space>
                ))}
                <Button type="dashed" onClick={() => add()} icon={<PlusOutlined />}>
                  Add Step
                </Button>
              </>
            )}
          </Form.List>
        </Col>
      </Row>
    ),
  }))

  return (
    <div>
      <Space style={{ marginBottom: 16 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate('/recipes')}>Back</Button>
        <Title level={3} style={{ margin: 0 }}>{isEdit ? 'Edit Recipe' : 'New Recipe'}</Title>
      </Space>

      <Form form={form} layout="vertical" onFinish={onFinish}>
        <Row gutter={16}>
          <Col xs={24} lg={16}>
            <Card title="Translations" style={{ marginBottom: 16 }}>
              <Tabs items={translationTabs} />
            </Card>
            <Card title="Ingredients" style={{ marginBottom: 16 }}>
              <Form.List name="ingredients">
                {(fields, { add, remove }) => (
                  <>
                    {fields.map((field) => (
                      <Row key={field.key} gutter={8} align="middle" style={{ marginBottom: 8 }}>
                        <Col span={8}>
                          <Form.Item {...field} name={[field.name, 'ingredient_id']} noStyle>
                            <InputNumber placeholder="Ingredient ID" style={{ width: '100%' }} />
                          </Form.Item>
                        </Col>
                        <Col span={6}>
                          <Form.Item {...field} name={[field.name, 'quantity']} noStyle>
                            <InputNumber placeholder="Qty" style={{ width: '100%' }} />
                          </Form.Item>
                        </Col>
                        <Col span={6}>
                          <Form.Item {...field} name={[field.name, 'unit']} noStyle>
                            <Input placeholder="Unit (g, ml, ...)" />
                          </Form.Item>
                        </Col>
                        <Col span={4}>
                          <MinusCircleOutlined onClick={() => remove(field.name)} style={{ color: '#ff4d4f' }} />
                        </Col>
                      </Row>
                    ))}
                    <Button type="dashed" onClick={() => add()} icon={<PlusOutlined />}>
                      Add Ingredient
                    </Button>
                  </>
                )}
              </Form.List>
            </Card>
          </Col>
          <Col xs={24} lg={8}>
            <Card title="Details" style={{ marginBottom: 16 }}>
              <Form.Item name="prep_time_minutes" label="Prep Time (min)">
                <InputNumber min={0} style={{ width: '100%' }} />
              </Form.Item>
              <Form.Item name="cook_time_minutes" label="Cook Time (min)">
                <InputNumber min={0} style={{ width: '100%' }} />
              </Form.Item>
              <Form.Item name="servings" label="Servings">
                <InputNumber min={1} style={{ width: '100%' }} />
              </Form.Item>
              <Form.Item name="difficulty" label="Difficulty">
                <Select options={[
                  { value: 'easy', label: 'Easy' },
                  { value: 'medium', label: 'Medium' },
                  { value: 'hard', label: 'Hard' },
                ]} />
              </Form.Item>
              <Form.Item name="status" label="Status" initialValue="draft">
                <Select options={[
                  { value: 'draft', label: 'Draft' },
                  { value: 'published', label: 'Published' },
                ]} />
              </Form.Item>
              <Form.Item name="image_url" label="Image URL">
                <Input placeholder="https://..." />
              </Form.Item>
            </Card>
            <Button type="primary" htmlType="submit" loading={saveMutation.isPending} block size="large">
              {isEdit ? 'Save Changes' : 'Create Recipe'}
            </Button>
          </Col>
        </Row>
      </Form>
    </div>
  )
}
