import { useState, useEffect, useMemo, useRef } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  Form, Input, InputNumber, Select, Button, Card, Row, Col,
  Tabs, Space, Typography, message, Divider
} from 'antd'
import { ArrowLeftOutlined, PlusOutlined, MinusCircleOutlined } from '@ant-design/icons'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { recipesApi } from '../../api/endpoints/recipes'
import { ingredientsApi } from '../../api/endpoints/ingredients'

const { Title } = Typography
const { TextArea } = Input
const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'bg', label: 'Български' },
]

function useDebounce<T extends (...args: any[]) => void>(fn: T, delay: number): T {
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null)
  return useMemo(
    () =>
      ((...args: any[]) => {
        if (timer.current) clearTimeout(timer.current)
        timer.current = setTimeout(() => fn(...args), delay)
      }) as T,
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [delay],
  )
}

export function RecipeFormPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [form] = Form.useForm()
  const isEdit = !!id

  // Ingredient suggest state
  const [ingredientOptions, setIngredientOptions] = useState<{ value: number; label: string }[]>([])
  const [ingredientSearching, setIngredientSearching] = useState(false)

  const searchIngredients = async (q: string) => {
    if (!q) return
    setIngredientSearching(true)
    try {
      const res = await ingredientsApi.list({ q })
      setIngredientOptions(
        res.data.map((ing: any) => ({
          value: ing.id,
          label: ing.translations?.find((t: any) => t.language_code === 'en')?.name ?? `#${ing.id}`,
        }))
      )
    } finally {
      setIngredientSearching(false)
    }
  }

  const handleIngredientSearch = useDebounce(searchIngredients, 400)

  // Load recipe data when editing
  const { data: recipeData } = useQuery({
    queryKey: ['recipe', id],
    queryFn: () => recipesApi.get(id!).then(r => r.data),
    enabled: isEdit,
  })

  useEffect(() => {
    if (!recipeData) return
    const translations: Record<string, { title: string; description?: string }> = {}
    for (const t of recipeData.translations) {
      translations[t.language_code] = { title: t.title, description: t.description }
    }
    const steps: Record<string, string[]> = {}
    for (const step of [...recipeData.steps].sort((a: any, b: any) => a.order - b.order)) {
      for (const t of step.translations) {
        steps[t.language_code] = [...(steps[t.language_code] ?? []), t.instruction]
      }
    }
    // Pre-populate ingredient options so existing selections display correctly
    const existingIngredients = recipeData.ingredients ?? []
    if (existingIngredients.length > 0) {
      setIngredientOptions(prev => {
        const existingIds = new Set(prev.map((o: any) => o.value))
        const toAdd = existingIngredients
          .filter((i: any) => !existingIds.has(i.ingredient_id))
          .map((i: any) => ({
            value: i.ingredient_id,
            label: i.ingredient_translations?.find((t: any) => t.language_code === 'en')?.name
              ?? i.ingredient_translations?.[0]?.name
              ?? `#${i.ingredient_id}`,
          }))
        return [...prev, ...toAdd]
      })
    }
    form.setFieldsValue({
      translations,
      steps,
      ingredients: existingIngredients.map((i: any) => ({
        ingredient_id: i.ingredient_id,
        quantity: i.quantity,
        unit: i.unit,
      })),
      prep_time_minutes: recipeData.prep_time_minutes,
      cook_time_minutes: recipeData.cook_time_minutes,
      servings: recipeData.servings,
      difficulty: recipeData.difficulty,
      status: recipeData.status,
      image_url: recipeData.image_url,
    })
  }, [recipeData, form])

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
                            <Select
                              showSearch
                              placeholder="Search ingredient..."
                              filterOption={false}
                              onSearch={handleIngredientSearch}
                              loading={ingredientSearching}
                              options={ingredientOptions}
                              style={{ width: '100%' }}
                            />
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
