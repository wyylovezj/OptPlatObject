import { RBAC_IP } from '@/utils/dutyPageData.js'
import axios from 'axios'

// 复用已有接口：排班查询
export { getDuty } from '@/api/dutyPageInterface.js'

// ==================== 安全设备监控记录 ====================

/**
 * 保存安全设备监控记录（批量upsert）
 * @param {Array} records - 记录数组
 * @returns {Promise} - 返回响应数据
 */
export const saveSecurityDeviceRecord = async (records) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/saveSecurityDeviceRecord`, { records })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存安全设备监控记录失败')
  }
}

/**
 * 查询安全设备监控记录
 * @param {Array} dateRange - [开始日期, 结束日期] 格式 ['YYYY-MM-DD', 'YYYY-MM-DD']
 * @returns {Promise} - 返回记录数组
 */
export const getSecurityDeviceRecord = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/getSecurityDeviceRecord`, { dateRange })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '查询安全设备监控记录失败')
  }
}

/**
 * 删除安全设备监控记录
 * @param {number} id - 记录ID
 * @returns {Promise} - 返回响应数据
 */
export const deleteSecurityDeviceRecord = async (id) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/deleteSecurityDeviceRecord`, { id })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除安全设备监控记录失败')
  }
}

/**
 * 导出安全设备监控记录为Excel
 * @param {Array} dateRange - [开始日期, 结束日期]
 * @returns {Promise<Blob>} - 返回文件Blob
 */
export const exportSecurityDeviceRecord = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/exportSecurityDeviceRecord`, { dateRange }, {
      responseType: 'blob',
    })
    return response
  } catch (error) {
    throw new Error(error.response?.data?.message || '导出安全设备监控记录失败')
  }
}
