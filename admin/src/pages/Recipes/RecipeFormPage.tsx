import { useState, useEffect, useMemo, useRef, useCallback } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  Form, Input, InputNumber, Select, Button, Card, Row, Col,
  Tabs, Space, Typography, message, Divider, Checkbox
} from 'antd'
import { ArrowLeftOutlined, PlusOutlined, MinusCircleOutlined } from '@ant-design/icons'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { recipesApi } from '../../api/endpoints/recipes'
import { ingredientsApi } from '../../api/endpoints/ingredients'
import { categoriesApi } from '../../api/endpoints/categories'
import { cuisinesApi } from '../../api/endpoints/cuisines'
import { useTranslation } from 'react-i18next'
import { ImageUpload } from '../../components/ImageUpload'

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
  const { i18n } = useTranslation()
  const uiLang = i18n.language === 'bg' ? 'bg' : 'en'
  const nameOf = (translations: { language_code: string; name: string }[] | undefined, fallback: string) =>
    translations?.find((t) => t.language_code === uiLang)?.name
    ?? translations?.find((t) => t.language_code === 'en')?.name ?? fallback

  const { data: categories } = useQuery({ queryKey: ['categories'], queryFn: () => categoriesApi.list().then((r) => r.data) })
  const { data: cuisines } = useQuery({ queryKey: ['cuisines'], queryFn: () => cuisinesApi.list().then((r) => r.data) })
  const { data: tags } = useQuery({ queryKey: ['admin-tags'], queryFn: () => recipesApi.tags().then((r) => r.data) })

  // Active language tab (used for ingredient name labels)
  const [activeLanguage, setActiveLanguage] = useState('en')
  const activeLanguageRef = useRef('en')

  const handleLanguageChange = (key: string) => {
    setActiveLanguage(key)
    activeLanguageRef.current = key
  }

  // Ingredient suggest state
  const [ingredientOptions, setIngredientOptions] = useState<{ value: number; label: string; translations: any[] }[]>([])
  const [ingredientSearching, setIngredientSearching] = useState(false)

  const getIngredientLabel = useCallback((translations: any[], fallbackId: number) => {
    const lang = activeLanguageRef.current
    return translations?.find((t: any) => t.language_code === lang)?.name
      ?? translations?.find((t: any) => t.language_code === 'en')?.name
      ?? translations?.[0]?.name
      ?? `#${fallbackId}`
  }, [])

  const searchIngredients = async (q: string) => {
    if (!q) return
    setIngredientSearching(true)
    try {
      const res = await ingredientsApi.list({ q })
      setIngredientOptions(
        res.data.map((ing: any) => ({
          value: ing.id,
          label: getIngredientLabel(ing.translations, ing.id),
          translations: ing.translations,
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
    form.setFieldsValue({
      translations: recipeData.translations,
      steps: recipeData.steps,
      category_ids: recipeData.category_ids,
      tag_ids: recipeData.tag_ids,
      cuisine_id: recipeData.cuisine_id,
      ingredients: recipeData.ingredients.map((i: any) => ({
        ingredient_id: i.ingredient_id,
        quantity: i.quantity,
        unit: i.unit,
        is_optional: i.is_optional,
      })),
      prep_time_minutes: recipeData.prep_time_minutes,
      cook_time_minutes: recipeData.cook_time_minutes,
      servings: recipeData.servings,
      difficulty: recipeData.difficulty,
      status: recipeData.status,
      image_url: recipeData.image_url,
    })
    setIngredientOptions(
      recipeData.ingredients.map((i: any) => ({
        value: i.ingredient_id,
        label: getIngredientLabel(i.ingredient_translations, i.ingredient_id),
        translations: i.ingredient_translations,
      }))
    )
  }, [recipeData, form])

  // Re-map all ingredient option labels when language tab changes
  useEffect(() => {
    if (!ingredientOptions.length) return
    setIngredientOptions(prev =>
      prev.map(opt => ({
        ...opt,
        label: getIngredientLabel(opt.translations, opt.value),
      }))
    )
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeLanguage])

  const saveMutation = useMutation({
    mutationFn: (values: unknown) =>
      isEdit ? recipesApi.save(id!, values) : recipesApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-recipes'] })
      queryClient.invalidateQueries({ queryKey: ['recipe', id] })
      message.success(isEdit ? 'Recipe updated' : 'Recipe created')
      navigate('/recipes')
    },
    onError: (err: any) => message.error(err?.response?.data?.detail ?? 'Failed to save recipe'),
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
              <Tabs items={translationTabs} onChange={handleLanguageChange} />
            </Card>
            <Card title="Ingredients" style={{ marginBottom: 16 }}>
              <Form.List name="ingredients">
                {(fields, { add, remove }) => (
                  <>
                    {fields.map((field) => (
                      <Row key={field.key} gutter={8} align="middle" style={{ marginBottom: 8 }}>
                        <Col span={10}>
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
                        <Col span={4}>
                          <Form.Item {...field} name={[field.name, 'quantity']} noStyle>
                            <InputNumber placeholder="Qty" style={{ width: '100%' }} />
                          </Form.Item>
                        </Col>
                        <Col span={4}>
                          <Form.Item {...field} name={[field.name, 'unit']} noStyle initialValue="g">
                            <Select style={{ width: '100%' }} options={['g', 'kg', 'ml', 'l', 'tsp', 'tbsp', 'piece', 'pinch'].map((u) => ({ value: u, label: u }))} />
                          </Form.Item>
                        </Col>
                        <Col span={4}>
                          <Form.Item {...field} name={[field.name, 'is_optional']} valuePropName="checked" noStyle>
                            <Checkbox>optional</Checkbox>
                          </Form.Item>
                        </Col>
                        <Col span={2}>
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
            <Card title="Classification" style={{ marginBottom: 16 }}>
              <Form.Item name="category_ids" label="Categories" initialValue={[]}>
                <Select mode="multiple" allowClear placeholder="Choose categories" optionFilterProp="label"
                  options={(categories ?? []).map((c: any) => ({ value: c.id, label: nameOf(c.translations, c.slug) }))} />
              </Form.Item>
              <Form.Item name="tag_ids" label="Tags" initialValue={[]}>
                <Select mode="multiple" allowClear placeholder="Choose tags" optionFilterProp="label"
                  options={(tags ?? []).map((t: any) => ({ value: t.id, label: nameOf(t.translations, t.slug) }))} />
              </Form.Item>
              <Form.Item name="cuisine_id" label="Cuisine">
                <Select allowClear showSearch placeholder="Choose cuisine" optionFilterProp="label"
                  options={(cuisines ?? []).map((c: any) => ({ value: c.id, label: `${nameOf(c.translations, c.country_code)} (${c.country_code})` }))} />
              </Form.Item>
            </Card>
            <Card title="Details" style={{ marginBottom: 16 }}>
              <Form.Item name="prep_time_minutes" label="Prep Time (min)">
                <InputNumber min={0} style={{ width: '100%' }} />
              </Form.Item>
              <Form.Item name="cook_time_minutes" label="Cook Time (min)">
                <InputNumber min={0} style={{ width: '100%' }} />
              </Form.Item>
              <Form.Item name="servings" label="Servings (base)" initialValue={2}>
                <Select options={[
                  { value: 2, label: '2 portions' },
                  { value: 4, label: '4 portions' },
                  { value: 6, label: '6 portions' },
                ]} />
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
              <Form.Item name="image_url" label="Image">
                <ImageUpload kind="recipes" />
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
