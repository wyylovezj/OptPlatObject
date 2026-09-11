import { RBAC_IP } from '@/utils/dutyPageData.js'
import axios from 'axios'

// 复用已有接口：用户列表、PM列表、排班查询
export { getDuty } from '@/api/dutyPageInterface.js'

// ==================== MOA及VPN权限使用记录 ====================

/**
 * 保存MOA及VPN记录（批量upsert）
 * @param {Array} records - 记录数组
 * @returns {Promise} - 返回响应数据
 */
export const saveMoaVpnRecord = async (records) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/saveMoaVpnRecord`, { records })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存MOA及VPN记录失败')
  }
}

/**
 * 查询MOA及VPN记录
 * @param {Array} dateRange - [开始日期, 结束日期] 格式 ['YYYY-MM-DD', 'YYYY-MM-DD']
 * @returns {Promise} - 返回记录数组
 */
export const getMoaVpnRecord = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/getMoaVpnRecord`, { dateRange })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '查询MOA及VPN记录失败')
  }
}

/**
 * 删除MOA及VPN记录
 * @param {number} id - 记录ID
 * @returns {Promise} - 返回响应数据
 */
export const deleteMoaVpnRecord = async (id) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/deleteMoaVpnRecord`, { id })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除MOA及VPN记录失败')
  }
}

/**
 * 导出MOA及VPN记录为Excel
 * @param {Array} dateRange - [开始日期, 结束日期]
 * @returns {Promise<Blob>} - 返回文件Blob
 */
export const exportMoaVpnRecord = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/exportMoaVpnRecord`, { dateRange }, {
      responseType: 'blob',
    })
    return response
  } catch (error) {
    throw new Error(error.response?.data?.message || '导出MOA及VPN记录失败')
  }
}

// ==================== ECC联系异常情况 ====================

/**
 * 保存ECC联系异常记录（批量upsert）
 * @param {Array} records - 记录数组
 * @returns {Promise} - 返回响应数据
 */
export const saveEccContactException = async (records) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/saveEccContactException`, { records })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存ECC联系异常记录失败')
  }
}

/**
 * 查询ECC联系异常记录
 * @param {Array} dateRange - [开始日期, 结束日期]
 * @returns {Promise} - 返回记录数组
 */
export const getEccContactException = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/getEccContactException`, { dateRange })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '查询ECC联系异常记录失败')
  }
}

/**
 * 删除ECC联系异常记录
 * @param {number} id - 记录ID
 * @returns {Promise} - 返回响应数据
 */
export const deleteEccContactException = async (id) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/deleteEccContactException`, { id })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除ECC联系异常记录失败')
  }
}

/**
 * 导出ECC联系异常记录为Excel
 * @param {Array} dateRange - [开始日期, 结束日期]
 * @returns {Promise<Blob>} - 返回文件Blob
 */
export const exportEccContactException = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/exportEccContactException`, { dateRange }, {
      responseType: 'blob',
    })
    return response
  } catch (error) {
    throw new Error(error.response?.data?.message || '导出ECC联系异常记录失败')
  }
}

// ==================== 合并导出（MOA/VPN + ECC） ====================

/**
 * 合并导出两个Tab的数据为一个Excel（两个Sheet）
 * @param {Array} moaVpnDateRange - MOA/VPN日期范围
 * @param {Array} eccContactDateRange - ECC联系异常日期范围
 * @returns {Promise<Blob>} - 返回文件Blob
 */
export const exportMergedRemoteRecord = async (moaVpnDateRange, eccContactDateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/exportMergedRemoteRecord`, {
      moaVpnDateRange,
      eccContactDateRange,
    }, {
      responseType: 'blob',
    })
    return response
  } catch (error) {
    throw new Error(error.response?.data?.message || '合并导出失败')
  }
}
