import axios from 'axios'

const rbacIp = window.APP_CONFIG?.RBAC_IP || '127.0.0.1'

export const getTodoList = async (params = {}) => {
  const response = await axios.post(`${rbacIp}/getTodoList`, {
    username: params.username || '',
    page: params.page || 1,
    pageSize: params.pageSize || 20,
    status: params.status !== undefined ? params.status : '',
    keyword: params.keyword || '',
    startDate: params.startDate || '',
    endDate: params.endDate || '',
    completedStartDate: params.completedStartDate || '',
    completedEndDate: params.completedEndDate || ''
  })
  return response.data
}

export const createTodo = async (data) => {
  const response = await axios.post(`${rbacIp}/createTodo`, {
    title: data.title,
    content: data.content || '',
    createdBy: data.createdBy || '',
    todoType: data.todoType !== undefined ? data.todoType : 0,
    reminderTime: data.reminderTime || '',
    recurringPattern: data.recurringPattern !== undefined ? data.recurringPattern : '',
    recurringDay: data.recurringDay !== undefined ? data.recurringDay : '',
    recurringTime: data.recurringTime || ''
  })
  return response.data
}

export const updateTodo = async (data) => {
  const response = await axios.post(`${rbacIp}/updateTodo`, {
    id: data.id,
    title: data.title,
    content: data.content || '',
    todoType: data.todoType !== undefined ? data.todoType : 0,
    reminderTime: data.reminderTime || '',
    recurringPattern: data.recurringPattern !== undefined ? data.recurringPattern : '',
    recurringDay: data.recurringDay !== undefined ? data.recurringDay : '',
    recurringTime: data.recurringTime || ''
  })
  return response.data
}

export const toggleTodoStatus = async (id) => {
  const response = await axios.post(`${rbacIp}/toggleTodoStatus`, { id })
  return response.data
}

export const deleteTodo = async (id) => {
  const response = await axios.post(`${rbacIp}/deleteTodo`, { id })
  return response.data
}

export const getTodoReminders = async (username) => {
  const response = await axios.post(`${rbacIp}/getTodoReminders`, { username })
  return response.data
}
