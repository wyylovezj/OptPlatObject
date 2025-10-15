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
export const searchData = async (searchQuery) => {
  try {
    searchQuery.state = searchQuery.state === '' ? '未处理': searchQuery.state
    const response = await axios.post('http://127.0.0.1:8000/searchData', {
      searchQuery
    })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '查询失败')
  }
}

// 关闭告警接口
export const closeAlert = async (selectedEventIds, handleOpinion) => {
  try {
    console.log('111')
    const response = await axios.post('http://127.0.0.1:8000/closeAlarm', {
      selectedEventIds,
      handleOpinion
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '关闭告警失败')
  }
}
