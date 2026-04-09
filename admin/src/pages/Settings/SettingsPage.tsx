import { Card, Typography, Descriptions, Tag, Select } from 'antd'
import { useTranslation } from 'react-i18next'

const { Title } = Typography

export function SettingsPage() {
  const { t, i18n } = useTranslation()

  const handleLangChange = (lang: string) => {
    i18n.changeLanguage(lang)
    localStorage.setItem('admin_lang', lang)
  }

  return (
    <div>
      <Title level={3} style={{ marginBottom: 16 }}>{t('settings.title')}</Title>
      <Card title={t('settings.languages')} style={{ marginBottom: 16 }}>
        <Descriptions column={1}>
          <Descriptions.Item label={t('settings.activeLanguages')}>
            <Tag color="green">English (en)</Tag>
            <Tag color="blue">Български (bg)</Tag>
          </Descriptions.Item>
          <Descriptions.Item label={t('settings.interfaceLanguage')}>
            <Select
              value={i18n.language}
              onChange={handleLangChange}
              style={{ width: 160 }}
              options={[
                { value: 'en', label: 'English' },
                { value: 'bg', label: 'Български' },
              ]}
            />
          </Descriptions.Item>
        </Descriptions>
      </Card>
      <Card title={t('settings.measurementSystems')}>
        <Descriptions column={1}>
          <Descriptions.Item label={t('settings.defaultSystem')}><Tag color="green">Metric</Tag></Descriptions.Item>
          <Descriptions.Item label={t('settings.available')}><Tag>Metric</Tag><Tag>Imperial</Tag></Descriptions.Item>
        </Descriptions>
      </Card>
    </div>
  )
}
