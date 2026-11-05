import { useState } from 'react'
import { Upload, Image, Button, Space, message } from 'antd'
import { InboxOutlined, DeleteOutlined, UploadOutlined } from '@ant-design/icons'
import type { UploadRequestOption } from 'rc-upload/lib/interface'
import apiClient from '../api/client'

export type UploadKind = 'recipes' | 'ingredients' | 'steps' | 'categories'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

/** Images are stored by the backend under /media; turn a stored path into a browser URL. */
export function mediaUrl(url?: string | null): string | undefined {
  if (!url) return undefined
  if (/^https?:\/\//.test(url)) return url
  return `${API_BASE}${url.startsWith('/') ? '' : '/'}${url}`
}

export async function uploadImage(file: File, kind: UploadKind): Promise<string> {
  const body = new FormData()
  body.append('file', file)
  const res = await apiClient.post(`/api/v1/admin/upload?kind=${kind}`, body, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return res.data.url as string
}

function beforeUpload(file: File) {
  if (!file.type.startsWith('image/')) {
    message.error('Please choose an image file')
    return Upload.LIST_IGNORE
  }
  if (file.size > 15 * 1024 * 1024) {
    message.error('Image must be under 15 MB')
    return Upload.LIST_IGNORE
  }
  return true
}

interface Props {
  value?: string | null
  onChange?: (url: string | null) => void
  kind?: UploadKind
  height?: number
}

/** Form control: drag & drop / pick an image file, uploads it, stores the returned /media path. */
export function ImageUpload({ value, onChange, kind = 'recipes', height = 180 }: Props) {
  const [loading, setLoading] = useState(false)

  const customRequest = async ({ file, onSuccess, onError }: UploadRequestOption) => {
    setLoading(true)
    try {
      const url = await uploadImage(file as File, kind)
      onChange?.(url)
      onSuccess?.({ url })
    } catch (e) {
      message.error('Upload failed')
      onError?.(e as Error)
    } finally {
      setLoading(false)
    }
  }

  if (value) {
    return (
      <Space direction="vertical" style={{ width: '100%' }}>
        <Image src={mediaUrl(value)} style={{ width: '100%', maxHeight: height, objectFit: 'cover', borderRadius: 8 }} />
        <Space>
          <Upload accept="image/*" showUploadList={false} beforeUpload={beforeUpload} customRequest={customRequest}>
            <Button icon={<UploadOutlined />} loading={loading}>Replace</Button>
          </Upload>
          <Button danger icon={<DeleteOutlined />} onClick={() => onChange?.(null)}>Remove</Button>
        </Space>
      </Space>
    )
  }

  return (
    <Upload.Dragger accept="image/*" showUploadList={false} beforeUpload={beforeUpload} customRequest={customRequest} disabled={loading}>
      <p className="ant-upload-drag-icon"><InboxOutlined /></p>
      <p className="ant-upload-text">{loading ? 'Uploading…' : 'Click or drag an image here'}</p>
      <p className="ant-upload-hint">JPG, PNG or WebP, up to 15 MB</p>
    </Upload.Dragger>
  )
}

/** Compact thumbnail for tables: click to upload / replace. */
export function ImageThumbUpload({ value, kind, onUploaded, size = 48 }: {
  value?: string | null; kind: UploadKind; onUploaded: (url: string) => void; size?: number
}) {
  const [loading, setLoading] = useState(false)
  const customRequest = async ({ file, onSuccess, onError }: UploadRequestOption) => {
    setLoading(true)
    try {
      const url = await uploadImage(file as File, kind)
      onUploaded(url)
      onSuccess?.({ url })
    } catch (e) {
      message.error('Upload failed')
      onError?.(e as Error)
    } finally {
      setLoading(false)
    }
  }
  return (
    <Upload accept="image/*" showUploadList={false} beforeUpload={beforeUpload} customRequest={customRequest}>
      <div
        title="Click to upload image"
        style={{
          width: size, height: size, borderRadius: 6, overflow: 'hidden', cursor: 'pointer',
          border: '1px dashed #d9d9d9', display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: '#fafafa', opacity: loading ? 0.5 : 1,
        }}
      >
        {value
          ? <img src={mediaUrl(value)} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          : <UploadOutlined style={{ color: '#999' }} />}
      </div>
    </Upload>
  )
}
