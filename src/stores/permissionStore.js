/**
 * @author: 魏阳阳
 * @email: weiyangyang@cinda.com.cn
 * @desc: Pinia 用户角色权限信息管理
 * @date: 2026-03-30 10:00:00
 * @lastModifiedBy: 魏阳阳
 * @lastModifiedTime: 2026-03-30 10:00:00
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const usePermissionStore = defineStore('permission', () => {
  // 用户信息
  const userInfo = ref(null)
  // 用户角色列表
  const userRoles = ref([])
  // 角色列表
  const roleList = ref([])
  // 菜单列表
  const menuList = ref([])
  // 用户可访问的菜单权限
  const accessibleMenus = ref([])
  // 用户权限码列表
  const permissionCodes = ref([])

  // 设置用户信息
  const setUserInfo = (info) => {
    userInfo.value = info
  }

  // 设置用户角色
  const setUserRoles = (roles) => {
    userRoles.value = roles
  }

  // 设置角色列表
  const setRoleList = (roles) => {
    roleList.value = roles
  }

  // 设置菜单列表
  const setMenuList = (menus) => {
    menuList.value = menus
  }

  // 设置可访问菜单
  const setAccessibleMenus = (menus) => {
    accessibleMenus.value = menus
  }

  // 设置权限码
  const setPermissionCodes = (codes) => {
    permissionCodes.value = codes
  }

  // 检查是否有某个权限
  const hasPermission = (permissionCode) => {
    return permissionCodes.value.includes(permissionCode)
  }

  // 检查是否有某些权限之一
  const hasAnyPermission = (permissionCodes) => {
    return permissionCodes.some(code => permissionCodes.value.includes(code))
  }

  // 检查是否有所有权限
  const hasAllPermissions = (permissionCodes) => {
    return permissionCodes.every(code => permissionCodes.value.includes(code))
  }

  // 检查是否有某个角色
  const hasRole = (roleCode) => {
    return userRoles.value.some(role => role.code === roleCode)
  }

  // 根据角色过滤菜单
  const filterMenusByRoles = (roles) => {
    if (!roles || roles.length === 0) {
      return []
    }

    const roleCodes = roles.map(role => role.code)
    const filteredMenus = menuList.value.filter(menu => {
      // 如果菜单没有设置角色限制，则所有人都可以访问
      if (!menu.roles || menu.roles.length === 0) {
        return true
      }
      // 检查菜单是否在用户的角色权限范围内
      return menu.roles.some(roleCode => roleCodes.includes(roleCode))
    })

    return filteredMenus
  }

  // 清除所有权限信息
  const clearPermissions = () => {
    userInfo.value = null
    userRoles.value = []
    roleList.value = []
    menuList.value = []
    accessibleMenus.value = []
    permissionCodes.value = []
  }

  return {
    userInfo,
    userRoles,
    roleList,
    menuList,
    accessibleMenus,
    permissionCodes,
    setUserInfo,
    setUserRoles,
    setRoleList,
    setMenuList,
    setAccessibleMenus,
    setPermissionCodes,
    hasPermission,
    hasAnyPermission,
    hasAllPermissions,
    hasRole,
    filterMenusByRoles,
    clearPermissions
  }
})
