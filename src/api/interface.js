/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： 调用后端接口的方法
 * @date： 2025-12-05 16:14:57
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2025-12-05 16:14:57
 */
import { useSpeakStore } from '@/stores/alarmSpeakStore.js'
import { processSpeechQueue, dataDictionary } from '@/utils/publicData.js'
import axios from 'axios'



// 获取数据字典
export const getAlarmDictionary = async (visible,type) => {
  try {
    if (visible) {
      const response = await axios.post('http://127.0.0.1:8000/getDict', {
        "data": type
      })
      console.log('Alarm dictionary:', response.data.data)
      dataDictionary.value = response.data.data
    }
  } catch (error) {
    console.error('Error fetching alarm dictionary:', error)
    throw error
  }
}

/**
 * 登录认证函数：异步函数
 * 该函数用于向服务器发送登录请求，并处理响应和错误
 * @param {string} username - 用户名
 * @param {string} password - 密码
 * @returns {Promise} - 返回一个Promise，解析后为服务器返回的数据
 * @throws {Error} - 如果登录失败，抛出一个错误对象
 */
export const loginAuthentication = async (username, password) => {
  try {
    // 发送POST请求到登录接口
    const response = await axios.post('http://127.0.0.1:8000/login', {
      username,
      password,
    })
    return response.data // 返回响应数据
  } catch (error) {
    // 如果发生错误，抛出一个新的错误对象
    // 优先使用服务器返回的错误信息，否则使用默认的'登录失败'
    throw new Error(error.response?.data?.message || '登录失败')
  }
}

/**
 * 查询数据函数：异步函数
 * @param {Object} searchQuery - 搜索条件对象，包含各种查询参数
 * @returns {Promise} - 返回一个Promise，解析后为查询到的数据
 * @throws {Error} - 当查询失败时抛出错误
 */
export const searchData = async (searchQuery) => {
  try {
    // 处理搜索参数，如果state为空字符串则设置为'未处理'
    const params = {
      ...searchQuery, // 展开搜索条件对象
      state: searchQuery.state === '' ? '未处理' : searchQuery.state, // 处理状态参数
    }
    // 发送POST请求到后端API
    const response = await axios.post('http://127.0.0.1:8000/searchData', params)
    // 获取响应数据
    const data = response.data.data
    // 获取告警数据的Pinia store
    const alarmStore = useSpeakStore()
    // 清除列表中发生时间在2分钟以前的数据
    alarmStore.removeSpeechQueue()
    // // 获取2分钟内的数据并存入语音播报列表
    const twoMinutesAgo = new Date(Date.now() - 365 * 24 * 60 * 60 * 1000) // 2分钟前的时间戳
    data.forEach(item => {
      // 检查发生时间是否在2分钟内
      const occurrenceTime = new Date(item.occurrenceTime)
      if (occurrenceTime > twoMinutesAgo && item.severity ==='严重' && item.state === '未处理') {
        // 添加到语音播报列表（自动去重）
        alarmStore.addSpeechQueue(item)
      }
    })
    // 处理语音队列
    processSpeechQueue() // 使用队列方式
    // 返回响应数据中的data字段
    return data
  } catch (error) {
    // 捕获错误并抛出，优先显示后端返回的错误信息，否则显示默认错误信息
    throw new Error(error.response?.data?.message || '查询失败')
  }
}

/**
 * 关闭告警函数：异步函数
 * @param {Array} selectedEventIds - 选中的事件ID数组
 * @param {Function} handleOpinion - 处理意见的回调函数
 * @returns {Promise} - 返回一个Promise，解析为响应数据
 * @throws {Error} - 如果关闭告警失败，抛出错误
 */
export const closeAlert = async (selectedEventIds, handleOpinion) => {
  try {
    // 发送POST请求到后端API以关闭告警
    const response = await axios.post('http://127.0.0.1:8000/closeAlarm', {
      selectedEventIds, // 要关闭的事件ID数组
      handleOpinion, // 处理意见
    })
    return response.data // 返回响应数据
  } catch (error) {
    // 如果发生错误，抛出带有错误信息的Error对象
    // 优先使用后端返回的错误信息，否则使用默认错误信息
    throw new Error(error.response?.data?.message || '关闭告警失败')
  }
}
