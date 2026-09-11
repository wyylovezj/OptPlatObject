/**
 * @author： 魏阳阳
 * @email： weiyangyang@cinda.com.cn
 * @desc： Linux系统工具接口（访问5000端口的RBAC后端服务）
 * @date： 2026-09-01
 * @lastModifiedBy： 魏阳阳
 * @lastModifiedTime： 2026-09-01
 */
import axios from 'axios'

// Linux系统工具服务地址：5000端口的RBAC后端服务
const linuxToolIp = window.APP_CONFIG?.RBAC_IP || 'http://127.0.0.1:5000'

// Linux系统工具root权限鉴定接口：上传当前登录用户名，返回data.root标识是否拥有root权限
export const checkLinuxToolRoot = async (username) => {
  try {
    // 发送POST请求
    const response = await axios.post(`${linuxToolIp}/linux_tool_check_root`, {
      username: username,
    })
    console.log(response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '服务器连接失败')
  }
}

// Linux系统工具脚本下发接口
export const linuxToolExecute = async (formData) => {
  try {
    // 发送POST请求
    const response = await axios.post(`${linuxToolIp}/linux_tool_execute`, formData)
    console.log(response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '服务器连接失败')
  }
}

// Linux系统工具历史任务查询接口
export const historyLinuxToolTask = async (execUser, execTime, sysUser, status) => {
  try {
    // 发送POST请求
    const response = await axios.post(`${linuxToolIp}/linux_tool_history_task`, {
      username: execUser,
      execute_time: execTime,
      sys_user: sysUser,
      status: status,
    })
    console.log(response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '服务器连接失败')
  }
}
