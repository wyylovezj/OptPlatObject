import { RBAC_IP } from '@/utils/dutyPageData.js'
import axios from 'axios'

/**
 * 添加或更新值班人员信息
 * @param {Array} users - 值班人员数组 [{name, phone, email, category}, ...]
 * @returns {Promise} - 返回响应数据
 */
export const saveDutyUsers = async (users) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/dutyUserManage`, users)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存值班人员信息失败')
  }
}

/**
 * 获取值班人员列表
 * @returns {Promise} - 返回值班人员数组
 */
export const fetchDutyUsers = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/dutyUserManage`)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取值班人员列表失败')
  }
}

/**
 * 保存值班表信息
 * @param {Object} scheduleData - 值班表数据 { date, dayShift, nightShift }
 * @returns {Promise} - 返回响应数据
 */
export const saveDutySchedule = async (scheduleData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/dutySchedule`, scheduleData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存值班表信息失败')
  }
}

/**
 * 获取指定日期的值班表信息
 * @param {string} date - 日期字符串 (YYYY-MM-DD)
 * @returns {Promise} - 返回值班表数据
 */
export const fetchDutySchedule = async (date) => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/dutySchedule`, { params: { date } })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取值班表信息失败')
  }
}

/**
 * 获取ECC值班人员
 * @returns {Promise} - 返回ECC值班人员数组
 */
export const getEcc = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/getEcc`)
    console.log('getEcc', response.data.data)
    return response.data.data

  } catch (error) {
    throw new Error(error.response?.data?.message || '获取ECC值班人员失败')
  }
}

/**
 * 获取系统运维值班人员
 * @returns {Promise} - 返回系统运维值班人员数组
 */
export const getSys = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/getSys`)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取系统运维值班人员失败')
  }
}

/**
 * 获取网络运维值班人员
 * @returns {Promise} - 返回网络运维值班人员数组
 */
export const getNet = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/getNet`)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取网络运维值班人员失败')
  }
}

/**
 * 获取甲方PM值班人员
 * @returns {Promise} - 返回甲方PM值班人员数组
 */
export const getPM = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/getPM`)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取甲方PM值班人员失败')
  }
}

/**
 * 新增排班
 * @param {Object} dutyData - 排班数据
 * @returns {Promise} - 返回响应数据
 */
export const saveDuty = async (dutyData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/saveDuty`, dutyData)
    console.log('saveDuty', response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '新增排班失败')
  }
}
