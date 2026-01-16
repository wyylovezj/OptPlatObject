/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： Pinia 用户登录状态信息管理
 * @date： 2025-12-05 16:39:53
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2025-12-05 16:39:53
 */
import { defineStore } from 'pinia'
import { ref } from 'vue'
/**
 * @description： 用户登录状态信息管理
 */
export const useAuthStore = defineStore('auth', () => {
  // 用户名
  const user = ref(null)
  // 登录状态：success 登录成功，null 未登录
  const state = ref(sessionStorage.getItem('status')||null)
  // 登录标志：false 未登录，true 登录成功
  const isAuthenticated = ref(false)
  // 初始化检查用户登录状态
  if (state.value === 'success') {
    isAuthenticated.value = true
  }
  // 登录时存储登录信息
  const loginInfoStorage = (username, status) => {
    // 存储用户名
    user.value = username
    // 存储登录状态
    state.value = status
    // 设置登录标志为登录成功
    isAuthenticated.value = true
    // 存储用户名、登录状态到本地存储
    sessionStorage.setItem('user', user.value)
    sessionStorage.setItem('status', state.value)
  }
  // 退出登录时清除登录信息
  const logoutInfoClear = () => {
    // 清除用户名
    user.value = null
    // 清除登录状态
    state.value = null
    // 设置登录标志为未登录
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

// 返回一个包含多个用户认证相关属性和方法的对象
// 这些属性和方法可以被其他组件或模块导入和使用
  return {
    user,              // 用户信息对象，包含用户的基本数据
    state,             // 应用状态对象，可能包含全局状态信息
    isAuthenticated,   // 布尔值，表示用户是否已通过认证
    loginInfoStorage,  // 函数，用于存储用户的登录信息
    logoutInfoClear,   // 函数，用于清除用户的登出信息
    checkIsAuth        // 函数，用于检查用户的认证状态
  }
})
