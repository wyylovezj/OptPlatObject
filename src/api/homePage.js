/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc：
 * @date： 2026/4/24 11:02
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026/4/24 11:02
 */
import { serverIp } from '@/utils/publicData.js'
import axios from 'axios'

/**
 * 获取告警级别数据
 * @param {string} date - 日期
 * @returns {Promise<Object>} - 告警级别数据
 */
export const getAlertLevelData = async (date) => {
  try {
    const response = await axios.post(`${serverIp.value}/getAlertLevelData`, {
      date: date,
    })
    console.log(response.data)
    return response.data
  } catch (error) {
    console.error('获取告警级别数据失败:', error)
    throw error
  }
}

/**
 * 获取告警分类数据
 * @param {string} date - 日期
 * @returns {Promise<Object>} - 告警分类数据
 */
export const getAlertClassData = async (date) => {
  try {
    const response = await axios.post(`${serverIp.value}/getAlertClassData`, {
      date: date,
    })
    console.log(response.data)
    return response.data
  } catch (error) {
    console.error('获取告警分类数据失败:', error)
    throw error
  }
}

/**
 * 获取告警状态数据
 * @param {string} date - 日期
 * @returns {Promise<Object>} - 告警状态数据
 */
export const getAlertStatusData = async (date) => {
  try {
    const response = await axios.post(`${serverIp.value}/getAlertStatusData`, {
      date: date,
    })
    console.log(response.data)
    return response.data
  } catch (error) {
    console.error('获取告警状态数据失败:', error)
    throw error
  }
}

/**
 * 获取告警统计数据
 * @returns {Promise<Object>} - 告警统计数据
 */
export const getAlertStatisticData = async () => {
  try {
    const response = await axios.get(`${serverIp.value}/getAlertStatisticData`)
    console.log(response.data)
    return response.data
  } catch (error) {
    console.error('获取告警状态数据失败:', error)
    throw error
  }
}

/**
 * 获取告警趋势数据
 * @param {string} date - 日期
 * @param {string} type - 类型
 * @returns {Promise<Object>} - 告警趋势数据
 */
export const getAlertTrendData = async (date, type) => {
  try {
    const response = await axios.post(`${serverIp.value}/getAlertTrendData`, {
      type: type,
      date: date,
    })
    console.log(response.data)
    return response.data
  } catch (error) {
    console.error('获取告警状态数据失败:', error)
    throw error
  }
}

/**
 * 获取处理时长数据
 * @param {string} date - 日期
 * @param {string} type - 类型
 * @returns {Promise<Object>} - 处理时长数据
 */
export const getHandleTimeData = async (date) => {
  try {
    const response = await axios.post(`${serverIp.value}/getHandleTimeData`, {
      date: date,
    })
    console.log(response.data)
    return response.data
  } catch (error) {
    console.error('获取告警状态数据失败:', error)
    throw error
  }
}

export const getOrderData = async (username) => {
  try {
    const response = await axios.post(`${serverIp.value}/getOrderData`, {
      username: username,
    })
    console.log(response.data)
    return response.data
  } catch (error) {
    console.error('获取告警状态数据失败:', error)
    throw error
  }
}
