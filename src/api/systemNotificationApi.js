import axios from 'axios'

const rbacIp = window.APP_CONFIG?.RBAC_IP || '127.0.0.1'

export const getSystemNotifications = async (params = {}) => {
  const response = await axios.post(`${rbacIp}/getSystemNotifications`, {
    page: params.page || 1,
    pageSize: params.pageSize || 20,
    createdBy: params.createdBy || '',
    status: params.status !== undefined ? params.status : '',
    notificationType: params.notificationType || '',
    createdTimeStart: params.createdTimeStart || '',
    createdTimeEnd: params.createdTimeEnd || '',
    publishTimeStart: params.publishTimeStart || '',
    publishTimeEnd: params.publishTimeEnd || ''
  })
  return response.data
}

export const createSystemNotification = async (data) => {
  const response = await axios.post(`${rbacIp}/createSystemNotification`, {
    title: data.title,
    content: data.content,
    notificationType: data.notificationType || 'info',
    createdBy: data.createdBy || '',
    targetGroupIds: data.targetGroupIds || []
  })
  return response.data
}

export const deleteSystemNotification = async (id) => {
  const response = await axios.post(`${rbacIp}/deleteSystemNotification`, {
    id
  })
  return response.data
}

export const publishSystemNotification = async (id, targetGroupIds) => {
  const response = await axios.post(`${rbacIp}/publishSystemNotification`, {
    id,
    targetGroupIds: targetGroupIds || []
  })
  return response.data
}

export const updateSystemNotification = async (data) => {
  const response = await axios.post(`${rbacIp}/updateSystemNotification`, {
    id: data.id,
    title: data.title,
    content: data.content,
    notificationType: data.notificationType || 'info',
    targetGroupIds: data.targetGroupIds || []
  })
  return response.data
}

export const getNotificationStats = async () => {
  const response = await axios.get(`${rbacIp}/getNotificationStats`)
  return response.data
}

export const getNotificationHistory = async () => {
  const response = await axios.get(`${rbacIp}/getNotificationHistory`)
  return response.data
}

export const getUserOnlineHistory = async (params = {}) => {
  const response = await axios.post(`${rbacIp}/getUserOnlineHistory`, {
    page: params.page || 1,
    pageSize: params.pageSize || 20,
    username: params.username || '',
    startDate: params.startDate || '',
    endDate: params.endDate || ''
  })
  return response.data
}

export const getAllGroups = async () => {
  const response = await axios.post(`${rbacIp}/getAllGroups`, {})
  return response.data
}

export const getGroupUsers = async (groupCode) => {
  const response = await axios.post(`${rbacIp}/getGroupUsers`, {
    groupCode
  })
  return response.data
}

export const getUserNotificationHistory = async (params = {}) => {
  const response = await axios.post(`${rbacIp}/getUserNotificationHistory`, {
    username: params.username || '',
    page: params.page || 1,
    pageSize: params.pageSize || 10,
    startDate: params.startDate || '',
    endDate: params.endDate || '',
    title: params.title || ''
  })
  return response.data
}

export const markUserNotificationsRead = async (username, maxNotificationId) => {
  const response = await axios.post(`${rbacIp}/markUserNotificationsRead`, {
    username,
    maxNotificationId: maxNotificationId || null
  })
  return response.data
}

export const getUserUnreadCount = async (username) => {
  const response = await axios.post(`${rbacIp}/getUserUnreadCount`, {
    username
  })
  return response.data
}
