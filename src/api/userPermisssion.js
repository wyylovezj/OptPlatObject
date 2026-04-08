import axios from 'axios'
import { ref } from 'vue'

// 获取当前登录用户名
const getCurrentUser = () => {
  return sessionStorage.getItem('user') || ''
}
export const rbacIp = ref(window.APP_CONFIG?.RBAC_IP || '127.0.0.1');
/**
 * 获取用户信息
 * @param {string} username - 用户名
 * @returns {Promise<Object>} - 返回用户信息对象
 */
export const getUserInfo = async (username) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getUserInfo`, {
      username,
      currentUser: getCurrentUser(),
    })
    console.log("getUserInfo",response.data.data)
    return response.data.data

  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户信息失败')
  }
}
/**
 * 禁用用户
 * @param {string} username - 用户名
 * @returns {Promise<Object>} - 返回用户信息对象
 */
export const disableUser = async (username) => {
  try {
    const response = await axios.post(`${rbacIp.value}/disableUser`, {
      username,
      currentUser: getCurrentUser(),
    })
    console.log("getUserInfo",response.data)
    return response.data

  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户信息失败')
  }
}
/**
 * 启用用户
 * @param {string} username - 用户名
 * @returns {Promise<Object>} - 返回用户信息对象
 */
export const enableUser = async (username) => {
  try {
    const response = await axios.post(`${rbacIp.value}/enableUser`, {
      username,
      currentUser: getCurrentUser(),
    })
    console.log("getUserInfo",response.data)
    return response.data

  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户信息失败')
  }
}
/**
 * 启用角色
 * @param {string} username - 用户名
 * @returns {Promise<Object>} - 返回用户信息对象
 */
export const disableRole = async (roleCode) => {
  try {
    const response = await axios.post(`${rbacIp.value}/disableRole`, {
      roleCode,
      currentUser: getCurrentUser(),
    })
    console.log("getUserInfo",response.data)
    return response.data

  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户信息失败')
  }
}
/**
 * 启用角色
 * @param {string} username - 用户名
 * @returns {Promise<Object>} - 返回用户信息对象
 */
export const enableRole = async (roleCode) => {
  try {
    const response = await axios.post(`${rbacIp.value}/enableRole`, {
      roleCode,
      currentUser: getCurrentUser(),
    })
    console.log("getUserInfo",response.data)
    return response.data

  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户信息失败')
  }
}
/**
 * 获取用户角色列表
 * @param {string} username - 用户名
 * @returns {Promise<Array>} - 返回用户角色数组
 */
export const getUserRoles = async (username) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getUserRoles`, {
      username,
      currentUser: getCurrentUser(),
    })
    console.log("getUserRoles",response.data.data)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户角色失败')
  }
}

/**
 * 获取所有角色列表
 * @returns {Promise<Array>} - 返回角色数组
 */
export const getAllRoles = async (form) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getAllRoles`,{
      roleCode: form.roleCode? form.roleCode:'',
      status: form.status? form.status:'',
      roleName: form.roleName? form.roleName:'',
    })
    console.log("getAllRoles",response.data.data)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取角色列表失败')
  }
}
/**
 * 获取用户角色列表
 * @returns {Promise<Array>} - 返回角色数组
 */
export const getUserList = async (form) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getAllUsersWithRoles`,{
      username: form.username ,
      roleCode: form.roleCode ,
      status: form.status,
      currentUser: getCurrentUser(),
    })
    console.log("getAllUsersWithRoles",response.data.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取角色列表失败')
  }
}
/**
 * 获取菜单列表
 * @returns {Promise<Array>} - 返回菜单树形结构数组
 */
export const getMenuList = async () => {
  try {
    const response = await axios.get(`${rbacIp.value}/getMenuList`)
    console.log("getMenuList",response.data.data)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取菜单列表失败')
  }
}

/**
 * 获取角色可访问菜单
 * @param {string} username - 用户名
 * @returns {Promise<Array>} - 返回用户可访问的菜单数组
 */
export const getRoleMenus = async (roleCode) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getRoleMenus`, {
      roleCode: roleCode,
      currentUser: getCurrentUser(),
    })
    console.log("getUserMenus",response.data)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户菜单失败')
  }
}

/**
 * 获取用户可访问菜单
 * @param {string} username - 用户名
 * @returns {Promise<Array>} - 返回用户可访问的菜单数组
 */
export const getUserMenus = async (username) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getUserMenus`, {
      username,
      currentUser: getCurrentUser(),
    })
    console.log("getUserMenus",response.data.data)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户菜单失败')
  }
}

/**
 * 分配用户角色
 * @param {string} username - 用户名
 * @param {Array} roleCodes - 角色代码数组
 * @returns {Promise<Object>} - 返回操作结果
 */
export const assignUserRoles = async (username, roleCodes) => {
  try {
    const response = await axios.post(`${rbacIp.value}/assignUserRoles`, {
      username,
      roleCodes,
    })
    console.log("assignUserRoles",response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '分配角色失败')
  }
}

/**
 * 分配角色菜单权限
 * @param {string} roleCode - 角色代码
 * @param {Array} menuIds - 菜单 ID 数组
 * @returns {Promise<Object>} - 返回操作结果
 */
export const assignRoleMenus = async (roleCode, menuIds) => {
  try {
    const response = await axios.post(`${rbacIp.value}/assignRoleMenus`, {
      roleCode,
      menuIds,
    })
    console.log("menuIds",menuIds)
    console.log("assignRoleMenus",response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '分配菜单权限失败')
  }
}

/**
 * 创建角色
 * @param {Object} roleData - 角色数据对象 {code, name, description}
 * @returns {Promise<Object>} - 返回创建结果
 */
export const createRole = async (roleData) => {
  try {
    const response = await axios.post(`${rbacIp.value}/createRole`, roleData)
    console.log("createRole",response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '创建角色失败')
  }
}

/**
 * 更新角色信息
 * @param {string} roleCode - 角色代码
 * @param {Object} roleData - 角色数据对象 {name, description}
 * @returns {Promise<Object>} - 返回更新结果
 */
export const updateRole = async (roleCode, roleData) => {
  try {
    const response = await axios.post(`${rbacIp.value}/updateRole`, {
      roleCode,
      ...roleData
    })
    console.log("updateRole",response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新角色失败')
  }
}

/**
 * 删除角色
 * @param {string} roleCode - 角色代码
 * @returns {Promise<Object>} - 返回删除结果
 */
export const deleteRole = async (roleCode) => {
  try {
    const response = await axios.post(`${rbacIp.value}/deleteRole`, {
      roleCode
    })
    console.log("deleteRole",response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除角色失败')
  }
}

/**
 * 创建菜单
 * @param {Object} menuData - 菜单数据对象
 * @returns {Promise<Object>} - 返回创建结果
 */
export const createMenu = async (menuData) => {
  try {
    const response = await axios.post(`${rbacIp.value}/createMenu`, menuData)
    console.log("createMenu",response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '创建菜单失败')
  }
}

/**
 * 更新菜单信息
 * @param {number} menuId - 菜单 ID
 * @param {Object} menuData - 菜单数据对象
 * @returns {Promise<Object>} - 返回更新结果
 */
export const updateMenu = async (menuId, menuData) => {
  try {
    const response = await axios.post(`${rbacIp.value}/updateMenu`, {
      menuId,
      ...menuData
    })
    console.log("updateMenu",response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新菜单失败')
  }
}

/**
 * 删除菜单
 * @param {number} menuId - 菜单 ID
 * @returns {Promise<Object>} - 返回删除结果
 */
export const deleteMenu = async (menuId) => {
  try {
    const response = await axios.post(`${rbacIp.value}/deleteMenu`, {
      menuId
    })
    console.log("deleteMenu",response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除菜单失败')
  }
}
