import { Outlet, useNavigate, useLocation } from 'react-router-dom'
import { Layout, Menu, Avatar, Dropdown, Typography, Space } from 'antd'
import {
  DashboardOutlined,
  UserOutlined,
  BookOutlined,
  TagOutlined,
  GlobalOutlined,
  ShoppingOutlined,
  CrownOutlined,
  CalendarOutlined,
  SettingOutlined,
  LogoutOutlined,
  AppstoreOutlined,
} from '@ant-design/icons'
import { useAuth } from '../contexts/AuthContext'

const { Sider, Header, Content } = Layout
const { Text } = Typography

const menuItems = [
  { key: '/dashboard', icon: <DashboardOutlined />, label: 'Dashboard' },
  { key: '/users', icon: <UserOutlined />, label: 'Users' },
  { key: '/recipes', icon: <BookOutlined />, label: 'Recipes' },
  { key: '/categories', icon: <AppstoreOutlined />, label: 'Categories' },
  { key: '/cuisines', icon: <GlobalOutlined />, label: 'Cuisines' },
  { key: '/ingredients', icon: <ShoppingOutlined />, label: 'Ingredients' },
  { key: '/subscriptions', icon: <CrownOutlined />, label: 'Subscriptions' },
  { key: '/weekly-suggestions', icon: <CalendarOutlined />, label: 'Weekly Suggestions' },
  { key: '/settings', icon: <SettingOutlined />, label: 'Settings' },
]

export function AdminLayout() {
  const navigate = useNavigate()
  const location = useLocation()
  const { user, logout } = useAuth()

  const userMenuItems = [
    { key: 'logout', icon: <LogoutOutlined />, label: 'Logout', danger: true },
  ]

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider
        theme="dark"
        width={220}
        style={{
          position: 'fixed',
          height: '100vh',
          left: 0,
          top: 0,
          background: '#1b1b1b',
        }}
      >
        <div style={{ padding: '20px 16px', borderBottom: '1px solid #333' }}>
          <Text style={{ color: '#4caf50', fontSize: 20, fontFamily: 'Poppins, sans-serif', fontWeight: 700 }}>
            🌿 PlateFlow
          </Text>
          <Text style={{ color: '#888', fontSize: 11, display: 'block' }}>Admin Panel</Text>
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname]}
          items={menuItems}
          onClick={({ key }) => navigate(key)}
          style={{ background: '#1b1b1b', borderRight: 0, marginTop: 8 }}
        />
      </Sider>
      <Layout style={{ marginLeft: 220 }}>
        <Header style={{
          background: '#fff',
          padding: '0 24px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'flex-end',
          borderBottom: '1px solid #f0f0f0',
          position: 'sticky',
          top: 0,
          zIndex: 10,
        }}>
          <Dropdown
            menu={{
              items: userMenuItems,
              onClick: ({ key }) => key === 'logout' && logout(),
            }}
            placement="bottomRight"
          >
            <Space style={{ cursor: 'pointer' }}>
              <Avatar style={{ background: '#2E7D32' }} icon={<UserOutlined />} />
              <Text>{user?.full_name}</Text>
            </Space>
          </Dropdown>
        </Header>
        <Content style={{ padding: 24, background: '#f5f5f5' }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}
