/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： 调用后端接口的方法
 * @date： 2025-12-05 16:14:57
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2025-12-05 16:14:57
 */
import { useSpeakStore } from '@/stores/alarmSpeakStore.js'
import {
  processSpeechQueue,
  dataDictionary,
  serverIp,
  orderModel,
} from '@/utils/publicData.js'
import axios from 'axios'
import { exportIp } from '@/utils/publicDataTools.js'


// 获取用户组/用户（触发工单）
export const getUserGroup = async (visible,type) => {
  try {
    if (visible) {
      const response = await axios.post(`${serverIp.value}/itsm_user_data`, {
        "group": orderModel.value.userGroup,
        "data": type
      })
      if (type === '用户组') {
        dataDictionary.value.userGroup = response.data.data
      } else if (type === '用户') {
        dataDictionary.value.username = response.data.data
      }
    }
  } catch (error) {
    console.error('Error fetching user group:', error)
    throw error
  }
}

/**
 * 创建工单
 * @returns {Promise<*>}
 */
export const creatOrder = async () => {
  try {
    // 发送POST请求到后端API以关闭告警
    const response = await axios.post(`${serverIp.value}/itsm_event`, {
      "user": orderModel.value.createUser, // 创建人
      "Alarm_Handle": orderModel.value.username, // 处理人
      "system_name": orderModel.value.system_name, // 系统名称
      "event_id": orderModel.value.eventId, // 事件ID
      "alarm_details": orderModel.value.orderHandleOpinion, // 告警描述
    })
    return response.data
  } catch (error) {
    // 如果发生错误，抛出带有错误信息的Error对象
    // 优先使用后端返回的错误信息，否则使用默认错误信息
    throw new Error(error.response?.data?.message || '创建工单失败，服务器未连接')
  }
}

/**
 * 获取数据字典
 * @param visible
 * @param type
 * @returns {Promise<void>}
 */
export const getAlarmDictionary = async (visible,type) => {
  try {
    if (visible) {
      const response = await axios.post(`${serverIp.value}/dataDictionary_get`, {
        "data": type
      })
      if (type === '告警分类') {
        dataDictionary.value.category = response.data.data
      } else if (type === '系统名称') {
        dataDictionary.value.system_name = response.data.data
      }
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
    const response = await axios.post(`${serverIp.value}/login`, {
      username,
      password,
    })
    console.log("response",response.data)
    return response.data
  }
  catch (error) {
    // 如果发生错误，抛出一个新的错误对象
    // 优先使用服务器返回的错误信息，否则使用默认的'登录失败'
    throw new Error(error.response?.data?.message  || '服务器连接失败')
  }
}

// SSO单点登录
export const ssoLogin = async (code) => {
  try{
    const getAccessTokenUrl = "http://100.18.16.225:3000/sso_server/oauth2/access_token"
    const response = await axios.get(`${getAccessTokenUrl}`, {
      params: {
        code: code,
      },
      withCredentials: true  // 设置axios默认携带cookies，需要服务端设置相应的响应头
    })
    console.log("response",response.data.data.sub)
    return response.data.data.sub
  }
  catch (error) {
    console.error('Error fetching alarm dictionary:', error)
    throw new Error(error.response?.data?.message  || '服务器连接失败')
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
      // state: searchQuery.state === '' ? '未处理' : searchQuery.state, // 处理状态参数
    }
    // 发送POST请求到后端API
    const response = await axios.post(`${serverIp.value}/searchData`, params)
    // 获取响应数据
    console.log("response",response.data)
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
    throw new Error(error.response?.data?.message || '服务器连接失败')
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
    const response = await axios.post(`${serverIp.value}/closeAlarm`, {
      selectedEventIds, // 要关闭的事件ID数组
      handleOpinion, // 处理意见
    })
    return response.data // 返回响应数据
  } catch (error) {
    // 如果发生错误，抛出带有错误信息的Error对象
    // 优先使用后端返回的错误信息，否则使用默认错误信息
    throw new Error(error.response?.data?.message || '服务器连接失败')
  }
}

/**
 * 导出订单文件函数：异步函数
 * @param {Object} data - 包含订单类型和开始时间的对象
 * @param {object} percentageInfo 数据模型
 * @returns {Promise} - 返回一个Promise，解析为响应数据
 * @throws {Error} - 如果导出文件失败，抛出错误
 */
export const exportOrderFile = async (data, percentageInfo) => {
  try {
    console.log('exportOrderFile', data.username)
    // 发送POST请求到后端API以关闭告警
    const response = await axios.post(`${exportIp.value}/api/itsm/export_file`, {
      control_type: data.OrderType,
      start_time: data.startTime,
      end_time: data.endTime,
      export_user: data.username,
    });

    console.log("response", response.data.task_id);
    let timeout;

    if (timeout) {
      clearTimeout(timeout);
    }

    return new Promise((resolve) => {
      timeout = setInterval(async () => {
        const response2 = await axios.get(`${exportIp.value}/api/itsm/export_progress/${response.data.data.task_id}`);
        console.log("response", response2.data);
        percentageInfo.percentage = response2.data.data.progress;
        if (response2.data.status === 'failed') {
          clearInterval(timeout);
          percentageInfo.percentage = response2.data.data.status;
          resolve(null);
        }
        if (response2.data.status === 'completed') {
          clearInterval(timeout);
          // 下载Excel文件
          try {
            const datetime = new Date();
            const formattedDatetime =
              datetime.getFullYear().toString() +
              (datetime.getMonth() + 1).toString().padStart(2, '0') + // 月份从0开始，需要+1
              datetime.getDate().toString().padStart(2, '0') +
              datetime.getHours().toString().padStart(2, '0') +
              datetime.getMinutes().toString().padStart(2, '0');
              datetime.getSeconds().toString().padStart(2, '0'); // 添加秒
            const downloadResponse = await axios.get(`${exportIp.value}/api/itsm/export_download/${response.data.data.task_id}`, {
              responseType: 'blob' // 设置响应类型为blob
            });
            const url = window.URL.createObjectURL(new Blob([downloadResponse.data]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `工单导出-${formattedDatetime}.xlsx`); // 设置下载文件名
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            // 返回完成状态
            resolve(true); // 使用 resolve 返回值
          } catch (downloadError) {
            console.error('下载文件失败:', downloadError);
            resolve(null); // 失败时返回 null 或其他值
          }
        }
      }, 1000);
    });
  } catch (error) {
    // 如果发生错误，抛出带有错误信息的Error对象
    // 优先使用后端返回的错误信息，否则使用默认错误信息
    throw new Error(error.response?.data?.message || '服务器连接失败');
  }
};

// 解锁账户
export const unlockAccountInterface = async (data) => {
  try {
    // 发送POST请求到后端API以关闭告警
    const response = await axios.post(`${exportIp.value}/unlockAccount `, {
      unlock_type: data.type,
      username: data.username,
    });
    console.log("response", response.data);
    return response.data;
  }
  catch (error) {
    throw new Error(error.response?.data?.message || '服务器连接失败');
  }
}
