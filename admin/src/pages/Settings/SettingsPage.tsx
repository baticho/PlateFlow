import { Card, Typography, Descriptions, Tag } from 'antd'

const { Title } = Typography

export function SettingsPage() {
  return (
    <div>
      <Title level={3} style={{ marginBottom: 16 }}>Settings</Title>
      <Card title="Supported Languages" style={{ marginBottom: 16 }}>
        <Descriptions column={1}>
          <Descriptions.Item label="Active Languages">
            <Tag color="green">English (en)</Tag>
            <Tag color="blue">Български (bg)</Tag>
          </Descriptions.Item>
          <Descriptions.Item label="Default Language">
            <Tag>English</Tag>
          </Descriptions.Item>
        </Descriptions>
      </Card>
      <Card title="Measurement Systems">
        <Descriptions column={1}>
          <Descriptions.Item label="Default System"><Tag color="green">Metric</Tag></Descriptions.Item>
          <Descriptions.Item label="Available"><Tag>Metric</Tag><Tag>Imperial</Tag></Descriptions.Item>
        </Descriptions>
      </Card>
    </div>
  )
}
