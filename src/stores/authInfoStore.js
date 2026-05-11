/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： Pinia 用户登录状态信息管理
 * @date： 2025-12-05 16:39:53
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2025-12-05 16:39:53
 */
import { getUserInfo, getUserMenus, getUserRoles } from '@/api/userPermisssion.js'
import { usePermissionStore } from '@/stores/permissionStore.js'
import { isSsoLogin } from '@/utils/publicData.js'
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

  // 用户类型：admin 管理员，user 普通用户
  const userType = ref(sessionStorage.getItem('userType') || 'user')

  // 是否正在加载权限
  const isLoadingPermissions = ref(false)
  // 权限是否已加载完成
  const permissionsLoaded = ref(false)
  // 获取权限 store 实例
  const permissionStore = usePermissionStore()
  // 加载用户权限信息
  const loadUserPermissions = async (username) => {
    try {
      // 设置加载状态
      isLoadingPermissions.value = true
      permissionsLoaded.value = false
      
      // 获取用户信息
      const userInfo = await getUserInfo(username)
      permissionStore.setUserInfo(userInfo)

      // 获取用户角色
      const roles = await getUserRoles(username)
      permissionStore.setUserRoles(roles)

      // 获取用户可访问菜单
      const menus = await getUserMenus(username)
      permissionStore.setAccessibleMenus(menus)

      // 提取权限码
      const codes = extractPermissionCodes(menus)
      permissionStore.setPermissionCodes(codes)

      // 设置用户类型
      const isAdmin = roles.some(role => role.code === 'admin' || role.type === 'admin')
      userType.value = isAdmin ? 'admin' : 'user'
      sessionStorage.setItem('userType', userType.value)
      
      // 标记权限加载完成
      permissionsLoaded.value = true
      isLoadingPermissions.value = false
    } catch (error) {
      console.error('加载用户权限失败:', error)
      // 出错时重置状态
      isLoadingPermissions.value = false
      permissionsLoaded.value = false
      throw error
    }
  }
  // 初始化检查用户登录状态
  if (state.value === 'success') {
    isAuthenticated.value = true
    // 从 sessionStorage 中恢复用户名
    const savedUser = sessionStorage.getItem('user')
    if (savedUser) {
      user.value = savedUser
      // 自动加载权限数据（如果是刷新页面）
      if (!permissionsLoaded.value && !isLoadingPermissions.value) {
        loadUserPermissions(savedUser).catch(error => {
          console.error('自动加载权限失败:', error)
          // 加载失败时清除登录信息
          logoutInfoClear()
        })
      }
    }
  }
  // 登录时存储登录信息
  const loginInfoStorage = async (username, status) => {
    // 存储用户名
    user.value = username
    // 存储登录状态
    state.value = status
    // 设置登录标志为登录成功
    isAuthenticated.value = true
    // 存储用户名、登录状态到本地存储
    sessionStorage.setItem('user', user.value)
    sessionStorage.setItem('status', state.value)
    sessionStorage.setItem('userType', userType.value)
    
    // 只有在权限未加载时才加载用户权限信息，避免重复加载
    if (!permissionsLoaded.value && !isLoadingPermissions.value) {
      await loadUserPermissions(username)
    }
    
    if (isSsoLogin.value) {
      // 登录成功后，设置标记表示这是登录重定向
      sessionStorage.setItem('isLoginRedirect', 'true')
    }
  }

  // 从菜单中提取权限码
  const extractPermissionCodes = (menus) => {
    const codes = []
    const traverse = (menuList) => {
      if (!menuList || menuList.length === 0) return
      for (const menu of menuList) {
        if (menu.permissionCode) {
          codes.push(menu.permissionCode)
        }
        if (menu.children && menu.children.length > 0) {
          traverse(menu.children)
        }
      }
    }
    traverse(menus)
    return codes
  }
  // 退出登录时清除登录信息
  const logoutInfoClear = () => {
      // 域登录退出
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
      if (sessionStorage.getItem('userType')) {
        sessionStorage.removeItem('userType')
      }
      if (isSsoLogin.value) {
        isSsoLogin.value = false
        // SSO登录退出
        sessionStorage.removeItem('isLoginRedirect')
      }
      // 清除权限信息
      permissionStore.clearPermissions()
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
    userType,          // 用户类型
    loginInfoStorage,  // 函数，用于存储用户的登录信息
    logoutInfoClear,   // 函数，用于清除用户的登出信息
    checkIsAuth,        // 函数，用于检查用户的认证状态
    loadUserPermissions, // 函数，用于加载用户权限信息
  }
})
