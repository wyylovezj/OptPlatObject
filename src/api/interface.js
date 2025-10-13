// src/api/auth.js
import axios from 'axios'


// 登录验证接口
export const loginAuthentication = async (username, password) => {
  try {
    const response = await axios.post('http://127.0.0.1:8000/login', {
      username,
      password
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '登录失败')
  }
}

//数据查询接口


// 关闭告警接口
export const closeAlert = async (alertId, handleOpinion) => {
  try {
    console.log(alertId)
    const response = await axios.post('http://127.0.0.1:8000/closeAlarm', {
      alertId,
      handleOpinion
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '关闭告警失败')
  }
}
