import { defineStore } from 'pinia'
import { ref } from 'vue'


// 本地存储用户验证信息
export const useAuthStore = defineStore('auth', () => {
  // 用户信息
  const user = ref(null)
  // 访问令牌
  const state = ref(sessionStorage.getItem('status')||null)
  // 是否已登录
  const isAuthenticated = ref(false)
  // 初始化时检查本地存储
  if (state.value === 'success') {
    isAuthenticated.value = true
    // 这里可以添加从本地存储加载用户信息的逻辑
  }

  // 登录时存储登录信息
  const loginInfoStorage = (username, status) => {
    user.value = username

    state.value = status

    isAuthenticated.value = true

    // 存储到本地存储
    sessionStorage.setItem('user', user.value)
    sessionStorage.setItem('status', state.value)
  }

  // 退出登录时清除登录信息
  const logoutInfoClear = () => {
    user.value = null
    state.value = null
    isAuthenticated.value = false

    // 清除本地存储
    if (sessionStorage.getItem('user')) {
      sessionStorage.removeItem('user')
    }
    if (sessionStorage.getItem('status')) {
      sessionStorage.removeItem('status')
    }
  }
  // 检查是否已登录
  const checkIsAuth = () => {
    return isAuthenticated.value
  }

  return {
    user,
    state,
    isAuthenticated,
    loginInfoStorage,
    logoutInfoClear,
    checkIsAuth
  }
})
