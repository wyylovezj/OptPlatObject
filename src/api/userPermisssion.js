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
    if (response.data.code !== 200) {
      throw new Error(response.data.message || '获取用户信息失败')
    }
    console.log("getUserInfo",response.data.data)
    return response.data.data

  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '获取用户信息失败')
  }
}
/**
 * 获取用户告警语音播报配置
 * @param {string} username - 用户名
 * @returns {Promise<number>} - 0-关闭播报，1-开启播报（默认）
 */
export const getAlarmConfig = async (username) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getAlarmConfig`, {
      username,
      currentUser: getCurrentUser(),
    })
    if (response.data.code !== 200) {
      throw new Error(response.data.message || '获取告警播报配置失败')
    }
    const value = Number(response.data.data?.configAlarmStatus)
    return Number.isNaN(value) ? 1 : value
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '获取告警播报配置失败')
  }
}
/**
 * 更新用户告警语音播报配置
 * @param {string} username - 用户名
 * @param {number} configAlarmStatus - 0-关闭播报，1-开启播报
 * @returns {Promise<number>} - 更新后的配置值
 */
export const updateAlarmConfig = async (username, configAlarmStatus) => {
  try {
    const response = await axios.post(`${rbacIp.value}/updateAlarmConfig`, {
      username,
      configAlarmStatus,
      currentUser: getCurrentUser(),
    })
    if (response.data.code !== 200) {
      throw new Error(response.data.message || '保存告警播报配置失败')
    }
    const value = Number(response.data.data?.configAlarmStatus)
    return Number.isNaN(value) ? Number(configAlarmStatus) : value
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '保存告警播报配置失败')
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
    if (response.data.code !== 200) {
      throw new Error(response.data.message || '获取用户角色失败')
    }
    console.log("getUserRoles",response.data.data)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '获取用户角色失败')
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
    if (response.data.code !== 200) {
      throw new Error(response.data.message || '获取用户菜单失败')
    }
    console.log("getUserMenus",response.data.data)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '获取用户菜单失败')
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

// ===================== 用户组管理接口 =====================

/**
 * 获取所有用户组
 * @param {Object} form - 查询条件 {groupName, status}
 * @returns {Promise<Array>}
 */
export const getAllGroups = async (form) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getAllGroups`, {
      groupName: form.groupName || '',
      status: form.status || '',
    })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户组列表失败')
  }
}

/**
 * 创建用户组
 * @param {Object} groupData - {groupName, groupCode, description}
 * @returns {Promise<Object>}
 */
export const createGroup = async (groupData) => {
  try {
    const response = await axios.post(`${rbacIp.value}/createGroup`, groupData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '创建用户组失败')
  }
}

/**
 * 更新用户组
 * @param {string} groupCode - 用户组编码
 * @param {Object} groupData - {groupName, description}
 * @returns {Promise<Object>}
 */
export const updateGroup = async (groupCode, groupData) => {
  try {
    const response = await axios.post(`${rbacIp.value}/updateGroup`, {
      groupCode,
      ...groupData
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新用户组失败')
  }
}

/**
 * 删除用户组
 * @param {string} groupCode - 用户组编码
 * @returns {Promise<Object>}
 */
export const deleteGroup = async (groupCode) => {
  try {
    const response = await axios.post(`${rbacIp.value}/deleteGroup`, {
      groupCode
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除用户组失败')
  }
}

/**
 * 启用用户组
 * @param {string} groupCode - 用户组编码
 * @returns {Promise<Object>}
 */
export const enableGroup = async (groupCode) => {
  try {
    const response = await axios.post(`${rbacIp.value}/enableGroup`, {
      groupCode
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '启用用户组失败')
  }
}

/**
 * 禁用用户组
 * @param {string} groupCode - 用户组编码
 * @returns {Promise<Object>}
 */
export const disableGroup = async (groupCode) => {
  try {
    const response = await axios.post(`${rbacIp.value}/disableGroup`, {
      groupCode
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '禁用用户组失败')
  }
}

/**
 * 获取用户组内用户
 * @param {string} groupCode - 用户组编码
 * @returns {Promise<Array>}
 */
export const getGroupUsers = async (groupCode) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getGroupUsers`, {
      groupCode
    })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户组用户失败')
  }
}

/**
 * 分配用户到用户组
 * @param {string} groupCode - 用户组编码
 * @param {Array} usernames - 用户名数组
 * @returns {Promise<Object>}
 */
export const assignGroupUsers = async (groupCode, usernames) => {
  try {
    const response = await axios.post(`${rbacIp.value}/assignGroupUsers`, {
      groupCode,
      usernames
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '分配用户失败')
  }
}

/**
 * 获取用户组角色
 * @param {string} groupCode - 用户组编码
 * @returns {Promise<Array>}
 */
export const getGroupRoles = async (groupCode) => {
  try {
    const response = await axios.post(`${rbacIp.value}/getGroupRoles`, {
      groupCode
    })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取用户组角色失败')
  }
}

/**
 * 分配角色到用户组
 * @param {string} groupCode - 用户组编码
 * @param {Array} roleCodes - 角色编码数组
 * @returns {Promise<Object>}
 */
export const assignGroupRoles = async (groupCode, roleCodes) => {
  try {
    const response = await axios.post(`${rbacIp.value}/assignGroupRoles`, {
      groupCode,
      roleCodes
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '分配角色失败')
  }
}
