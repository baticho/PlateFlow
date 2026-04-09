import { useState } from 'react'
import { Button, Typography, Select, Form, Modal, message, Spin, Tooltip } from 'antd'
import { PlusOutlined, EditOutlined, DeleteOutlined } from '@ant-design/icons'
import { useQueries, useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { weeklySuggestionsApi } from '../../api/endpoints/weeklySuggestions'
import dayjs from 'dayjs'

const { Title, Text } = Typography
const ALL_POSITIONS = [1, 2, 3, 4, 5, 6, 7]
const WEEKS_SHOWN = 5

type Translation = { language_code: string; title: string }
type Suggestion = {
  id: number
  position: number
  recipe?: { id: string; image_url?: string | null; translations?: Translation[] }
}

function getTitle(translations?: Translation[], lang = 'en') {
  return translations?.find((t) => t.language_code === lang)?.title ?? ''
}

function recipeLabel(translations?: Translation[]) {
  const en = getTitle(translations, 'en')
  const bg = getTitle(translations, 'bg')
  if (en && bg) return `${en} / ${bg}`
  return en || bg || '—'
}

function weekLabel(weekStart: string) {
  const start = dayjs(weekStart)
  const end = start.add(6, 'day')
  return `${start.format('DD MMM')} – ${end.format('DD MMM YYYY')}`
}

// Current week's Monday + next WEEKS_SHOWN-1 Mondays
// dayjs().startOf('week') = Sunday, +1 day = Monday
function getUpcomingWeeks(): string[] {
  const monday = dayjs().startOf('week').add(1, 'day')
  return Array.from({ length: WEEKS_SHOWN }, (_, i) =>
    monday.add(i * 7, 'day').format('YYYY-MM-DD')
  )
}

export function WeeklySuggestionsPage() {
  const { t } = useTranslation()
  const queryClient = useQueryClient()

  const weeks = getUpcomingWeeks()

  // pre-fill when opening add modal
  const [addContext, setAddContext] = useState<{ weekStart: string; position: number } | null>(null)
  const [editItem, setEditItem] = useState<(Suggestion & { weekStart: string }) | null>(null)
  const [recipeSearch, setRecipeSearch] = useState('')
  const [addForm] = Form.useForm()
  const [editForm] = Form.useForm()

  const weekResults = useQueries({
    queries: weeks.map((weekStart) => ({
      queryKey: ['weekly-suggestions', weekStart],
      queryFn: () => weeklySuggestionsApi.list({ week_start: weekStart }).then((r) => r.data),
    })),
  })

  const { data: recipesData, isFetching: recipesLoading } = useQuery({
    queryKey: ['recipe-search', recipeSearch],
    queryFn: () =>
      weeklySuggestionsApi.searchRecipes(recipeSearch || undefined).then((r) => r.data),
    enabled: !!addContext,
  })

  const recipeOptions = (
    (recipesData as { items?: { id: string; translations?: Translation[] }[] })?.items ?? []
  ).map((r) => ({
    value: r.id,
    label: recipeLabel(r.translations),
  }))

  const createMutation = useMutation({
    mutationFn: (values: unknown) => weeklySuggestionsApi.create(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['weekly-suggestions'] })
      message.success(t('weeklySuggestions.added'))
      setAddContext(null)
      addForm.resetFields()
      setRecipeSearch('')
    },
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, position }: { id: number; position: number }) =>
      weeklySuggestionsApi.update(id, { position }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['weekly-suggestions'] })
      message.success(t('weeklySuggestions.updated'))
      setEditItem(null)
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: number) => weeklySuggestionsApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['weekly-suggestions'] })
      message.success(t('weeklySuggestions.deleted'))
    },
  })

  const handleDelete = (id: number, label: string) => {
    Modal.confirm({
      title: t('weeklySuggestions.confirmDeleteTitle'),
      content: label,
      okText: t('weeklySuggestions.confirmDeleteOk'),
      cancelText: t('weeklySuggestions.confirmDeleteCancel'),
      okButtonProps: { danger: true },
      centered: true,
      onOk: () => deleteMutation.mutateAsync(id),
    })
  }

  const openAdd = (weekStart: string, position: number) => {
    setAddContext({ weekStart, position })
    addForm.resetFields()
    setRecipeSearch('')
  }

  const openEdit = (suggestion: Suggestion, weekStart: string) => {
    setEditItem({ ...suggestion, weekStart })
    editForm.setFieldsValue({ position: suggestion.position })
  }

  return (
    <div>
      <Title level={3} style={{ marginBottom: 24 }}>{t('weeklySuggestions.title')}</Title>

      {weeks.map((weekStart, idx) => {
        const result = weekResults[idx]
        const items: Suggestion[] = (result.data as { items?: Suggestion[] })?.items ?? []

        return (
          <div key={weekStart} style={{ marginBottom: 32 }}>
            <Text strong style={{ fontSize: 15, display: 'block', marginBottom: 12 }}>
              {weekLabel(weekStart)}
            </Text>

            {result.isLoading ? (
              <Spin size="small" />
            ) : (
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                {ALL_POSITIONS.map((pos) => {
                  const suggestion = items.find((s) => s.position === pos)
                  const label = suggestion ? recipeLabel(suggestion.recipe?.translations) : ''

                  return suggestion ? (
                    <div
                      key={pos}
                      style={{
                        width: 150,
                        border: '1px solid #d9d9d9',
                        borderRadius: 8,
                        background: '#fff',
                        display: 'flex',
                        flexDirection: 'column',
                        overflow: 'hidden',
                      }}
                    >
                      {suggestion.recipe?.image_url ? (
                        <img
                          src={suggestion.recipe.image_url}
                          alt={label}
                          style={{ width: '100%', height: 90, objectFit: 'cover' }}
                        />
                      ) : (
                        <div
                          style={{
                            width: '100%',
                            height: 90,
                            background: '#f5f5f5',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            color: '#ccc',
                            fontSize: 24,
                          }}
                        >
                          🍽
                        </div>
                      )}
                      <div style={{ padding: '6px 8px', display: 'flex', flexDirection: 'column', flex: 1 }}>
                        <Text style={{ fontSize: 11, color: '#888', marginBottom: 2 }}>#{pos}</Text>
                        <Tooltip title={label}>
                          <Text
                            style={{
                              fontSize: 12,
                              flex: 1,
                              display: '-webkit-box',
                              WebkitLineClamp: 2,
                              WebkitBoxOrient: 'vertical',
                              overflow: 'hidden',
                              lineHeight: 1.4,
                            }}
                          >
                            {label}
                          </Text>
                        </Tooltip>
                        <div style={{ display: 'flex', gap: 4, marginTop: 6 }}>
                          <Button
                            size="small"
                            icon={<EditOutlined />}
                            style={{ flex: 1 }}
                            onClick={() => openEdit(suggestion, weekStart)}
                          />
                          <Button
                            size="small"
                            danger
                            icon={<DeleteOutlined />}
                            style={{ flex: 1 }}
                            onClick={() => handleDelete(suggestion.id, label)}
                          />
                        </div>
                      </div>
                    </div>
                  ) : (
                    <Button
                      key={pos}
                      type="dashed"
                      icon={<PlusOutlined />}
                      style={{
                        width: 150,
                        minHeight: 90,
                        borderRadius: 8,
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: 'center',
                        justifyContent: 'center',
                        gap: 4,
                        color: '#bbb',
                        borderColor: '#d9d9d9',
                      }}
                      onClick={() => openAdd(weekStart, pos)}
                    >
                      <span style={{ fontSize: 11 }}>#{pos}</span>
                    </Button>
                  )
                })}
              </div>
            )}
          </div>
        )
      })}

      {/* Add modal */}
      <Modal
        title={t('weeklySuggestions.add')}
        open={!!addContext}
        onCancel={() => { setAddContext(null); addForm.resetFields() }}
        footer={null}
        destroyOnClose
      >
        <Form
          form={addForm}
          layout="vertical"
          onFinish={(values: { recipe_id: string }) => {
            createMutation.mutate({
              week_start_date: addContext!.weekStart,
              recipe_id: values.recipe_id,
              position: addContext!.position,
            })
          }}
        >
          <Form.Item name="recipe_id" label={t('weeklySuggestions.recipe')} rules={[{ required: true }]}>
            <Select
              showSearch
              filterOption={false}
              placeholder={t('weeklySuggestions.selectRecipe')}
              onSearch={setRecipeSearch}
              loading={recipesLoading}
              options={recipeOptions}
              notFoundContent={recipesLoading ? t('weeklySuggestions.searching') : t('weeklySuggestions.noResults')}
            />
          </Form.Item>
          <Button type="primary" htmlType="submit" loading={createMutation.isPending} block>
            {t('weeklySuggestions.add')}
          </Button>
        </Form>
      </Modal>

      {/* Edit modal */}
      <Modal
        title={t('weeklySuggestions.changePosition')}
        open={!!editItem}
        onCancel={() => setEditItem(null)}
        footer={null}
        destroyOnClose
        afterOpenChange={(open) => {
          if (open && editItem) {
            editForm.setFieldsValue({ position: editItem.position })
          }
        }}
      >
        {editItem && (
          <Form
            form={editForm}
            layout="vertical"
            onFinish={(values: { position: number }) => {
              updateMutation.mutate({ id: editItem.id, position: values.position })
            }}
          >
            <Form.Item label={t('weeklySuggestions.recipe')}>
              <Text>{recipeLabel(editItem.recipe?.translations)}</Text>
            </Form.Item>
            <Form.Item name="position" label={t('weeklySuggestions.position')} rules={[{ required: true }]}>
              <Select
                options={ALL_POSITIONS.map((p) => {
                  const weekItems: Suggestion[] = (
                    weekResults[weeks.indexOf(editItem.weekStart)]?.data as { items?: Suggestion[] }
                  )?.items ?? []
                  const taken = new Set(weekItems.map((s) => s.position))
                  return {
                    value: p,
                    label: t('weeklySuggestions.positionLabel', { n: p }),
                    disabled: taken.has(p) && p !== editItem.position,
                  }
                })}
              />
            </Form.Item>
            <Button type="primary" htmlType="submit" loading={updateMutation.isPending} block>
              {t('weeklySuggestions.save')}
            </Button>
          </Form>
        )}
      </Modal>
    </div>
  )
}
