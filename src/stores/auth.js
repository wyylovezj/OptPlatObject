import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  // 用户信息
  const user = ref(null)
  // 访问令牌
  const token = ref(localStorage.getItem('token') || null)
  // 是否已登录
  const isAuthenticated = ref(false)

  // 初始化时检查本地存储
  if (token.value) {
    isAuthenticated.value = true
    // 这里可以添加从本地存储加载用户信息的逻辑
  }

  // 登录方法
  const login = (userData, authToken) => {
    user.value = userData
    token.value = authToken
    isAuthenticated.value = true

    // 存储到本地存储
    localStorage.setItem('token', authToken)
    localStorage.setItem('user', JSON.stringify(userData))
  }

  // 退出登录方法
  const logout = () => {
    user.value = null
    token.value = null
    isAuthenticated.value = false

    // 清除本地存储
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    console.log("退出登录")
  }

  // 检查是否已登录
  const checkAuth = () => {
    return isAuthenticated.value
  }

  return {
    user,
    token,
    isAuthenticated,
    login,
    logout,
    checkAuth
  }
})
