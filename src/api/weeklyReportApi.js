import { RBAC_IP } from '@/utils/dutyPageData.js'
import axios from 'axios'

/**
 * 获取服务端当前周次，避免用户修改本地时间的绕过风险
 * @returns {Promise<{weekNum: number, year: number}>}
 */
export const getServerCurrentWeek = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/currentWeek`)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取当前周次失败')
  }
}

/**
 * 获取所有运维模块列表
 * @param {number} [weekNum] - 可选，指定周次时返回该周结束前创建的所有模块（含已删除）
 * @returns {Promise<Array>} - 返回模块数组
 */
export const getReportModules = async (weekNum) => {
  try {
    const params = {}
    if (weekNum) params.weekNum = weekNum
    const response = await axios.get(`${RBAC_IP.value}/reportModules`, { params })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取运维模块列表失败')
  }
}

/**
 * 新增运维模块
 * @param {Object} moduleData - { name, desc, category, color }
 * @returns {Promise}
 */
export const addReportModule = async (moduleData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportModules`, moduleData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '新增模块失败')
  }
}

/**
 * 更新运维模块
 * @param {number} moduleId
 * @param {Object} moduleData
 * @returns {Promise}
 */
export const updateReportModule = async (moduleId, moduleData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportModules/${moduleId}`, moduleData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新模块失败')
  }
}

/**
 * 删除运维模块
 * @param {number} moduleId
 * @returns {Promise}
 */
export const deleteReportModule = async (moduleId) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportModules/${moduleId}/delete`)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除模块失败')
  }
}

/**
 * 更新模块排序
 * @param {Array} sortData - [{ id, order }]
 * @returns {Promise}
 */
export const updateModuleSortOrder = async (sortData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportModules/sort`, sortData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新排序失败')
  }
}

/**
 * 切换模块启用/停用状态
 * @param {number} moduleId
 * @param {boolean} active
 * @returns {Promise}
 */
export const toggleModuleStatus = async (moduleId, active) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportModules/${moduleId}/status`, { active })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '切换模块状态失败')
  }
}

/**
 * 获取当前用户的周报列表（我的周报）
 * @param {number} weekNum - 周次
 * @param {string} username - 用户名
 * @returns {Promise}
 */
export const getMyReports = async (weekNum, username) => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/myReports`, { params: { weekNum, username } })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取我的周报失败')
  }
}

/**
 * 保存/提交周报（追加插入新条目）
 * @param {Object} reportData - { username, weekNum, entries: [{ moduleId, content }], status: 'draft'|'submitted' }
 * @returns {Promise}
 */
export const saveReport = async (reportData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/saveReport`, reportData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存周报失败')
  }
}

/**
 * 更新指定周报条目
 * @param {number} reportId
 * @param {Object} updateData - { content, status }
 * @returns {Promise}
 */
export const updateReport = async (reportId, updateData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/updateReport/${reportId}`, updateData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新周报失败')
  }
}

/**
 * 删除指定周报条目
 * @param {number} reportId
 * @returns {Promise}
 */
export const deleteReport = async (reportId) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/deleteReport/${reportId}`)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除周报失败')
  }
}

/**
 * 获取周报汇总数据（管理员视角，按模块聚合所有人）
 * @param {number} weekNum
 * @returns {Promise}
 */
export const getSummaryReports = async (weekNum) => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/summaryReports`, { params: { weekNum } })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取周报汇总失败')
  }
}

/**
 * 管理员编辑指定周报条目内容
 * @param {Object} editData - { reportId, content }
 * @returns {Promise}
 */
export const editSummaryContent = async (editData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/summaryReports/edit`, editData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '编辑周报内容失败')
  }
}

/**
 * 打回指定周报（汇总人员操作，让填报人重新编辑）
 * @param {number} reportId
 * @returns {Promise}
 */
export const returnReport = async (reportId) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/returnReport`, { reportId })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '退回周报失败')
  }
}

/**
 * 批量退回指定人员的所有周报（合并推送一条通知给被退回人）
 * @param {number[]} reportIds - 周报 ID 数组
 * @returns {Promise}
 */
export const batchReturnReports = async (reportIds) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/batchReturn`, { reportIds })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '批量退回失败')
  }
}

/**
 * 一键提醒未提交人员
 * @param {number} weekNum
 * @returns {Promise}
 */
export const remindUnsubmitted = async (weekNum) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/remindUnsubmitted`, { weekNum })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '发送提醒失败')
  }
}

/**
 * 导出周报 Excel
 * @param {Object} params - { weekNum, moduleId, personId }
 * @returns {Promise}
 */
export const exportReportExcel = async (params) => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/exportReport/excel`, {
      params,
      responseType: 'blob'
    })
    return response
  } catch (error) {
    throw new Error(error.response?.data?.message || '导出 Excel 失败')
  }
}

/**
 * 导出周报 Markdown / HTML
 * @param {Object} params - { weekNum, moduleId, personId, format: 'md'|'html' }
 * @returns {Promise}
 */
export const exportReportText = async (params) => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/exportReport/text`, { params })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '导出文本失败')
  }
}

/**
 * 导出周报 DOCX（调用后端 docxtpl 渲染）
 * @param {number} weekNum - 周次
 * @returns {Promise<AxiosResponse>} - 返回 response（blob），由调用方处理下载
 */
export const exportReportDocx = async (weekNum) => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/exportReport/docx`, {
      params: { weekNum },
      responseType: 'blob'
    })
    return response
  } catch (error) {
    throw new Error(error.response?.data?.message || '导出 DOCX 失败')
  }
}

/**
 * 一键提交所有草稿周报
 * @param {string} username - 用户名
 * @returns {Promise}
 */
export const submitAllDrafts = async (username) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/submitAllDrafts`, { username })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '一键提交失败')
  }
}

/**
 * 向指定人员发送周报提交提醒
 * @param {string} username - 用户名
 * @param {number} weekNum - 周次
 * @returns {Promise}
 */
export const remindPerson = async (username, weekNum) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/remindPerson`, { username, weekNum })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '发送提醒失败')
  }
}

/**
 * 获取周报人员列表
 * @returns {Promise}
 */
export const getReportPersonnel = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/reportPersonnel`)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取人员列表失败')
  }
}

/**
 * 获取可添加的候选人列表（duty_personnel 中 type=4 且未添加的）
 * @returns {Promise}
 */
export const getPersonnelCandidates = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/reportPersonnel/candidates`)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取候选人失败')
  }
}

/**
 * 新增周报人员
 * @param {Object} data - { userCode, name, personnelType }
 * @returns {Promise}
 */
export const addReportPersonnel = async (data) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportPersonnel`, data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '新增人员失败')
  }
}

/**
 * 启用/停用周报人员
 * @param {number} personId
 * @param {boolean} active
 * @returns {Promise}
 */
export const togglePersonnelStatus = async (personId, active) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportPersonnel/${personId}/status`, { active })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '切换状态失败')
  }
}

/**
 * 删除周报人员（逻辑删除）
 * @param {number} personId
 * @returns {Promise}
 */
export const deleteReportPersonnel = async (personId) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportPersonnel/${personId}/delete`)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除人员失败')
  }
}


/**
 * 获取指定周的配置（自定义起止日期）
 * @param {number} weekNum
 * @param {number} [year]
 * @returns {Promise}
 */
export const getWeekConfig = async (weekNum, year) => {
  try {
    const params = { weekNum }
    if (year) params.year = year
    const response = await axios.get(`${RBAC_IP.value}/weekConfig`, { params })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取周配置失败')
  }
}

/**
 * 设置指定周的自定义起止日期
 * @param {number} weekNum
 * @param {string} startDate - YYYY-MM-DD
 * @param {string} endDate - YYYY-MM-DD
 * @returns {Promise}
 */
export const saveWeekConfig = async (weekNum, startDate, endDate) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/weekConfig`, { weekNum, startDate, endDate })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存周配置失败')
  }
}

/**
 * 清除指定周的自定义配置（恢复ISO标准计算）
 * @param {number} weekNum
 * @returns {Promise}
 */
export const clearWeekConfig = async (weekNum) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/weekConfig/clear`, { weekNum })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '清除周配置失败')
  }
}

/**
 * 获取指定年份所有有效周的日期范围（节假日感知）
 * @param {number} [year] - 年份，默认当前年
 * @returns {Promise<Array<{weekNum, startDate, endDate}>>}
 */
export const getWeekDateRanges = async (year) => {
  try {
    const params = {}
    if (year) params.year = year
    const response = await axios.get(`${RBAC_IP.value}/weekDateRanges`, { params })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取有效周范围失败')
  }
}

// ============================================================
//  子模块管理接口（report_sub_module 表）
// ============================================================

/**
 * 获取子模块列表
 * @param {number} [moduleId] - 按模块筛选
 * @param {number} [weekNum] - 可选，指定周次时返回该周结束前创建的所有子模块（含已删除）
 * @returns {Promise<Array>}
 */
export const getReportSubModules = async (moduleId, weekNum) => {
  try {
    const params = {}
    if (moduleId) params.moduleId = moduleId
    if (weekNum) params.weekNum = weekNum
    const response = await axios.get(`${RBAC_IP.value}/reportSubModules`, { params })
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取子模块列表失败')
  }
}

/**
 * 新增子模块
 * @param {Object} data - { moduleId, name, desc }
 * @returns {Promise}
 */
export const addReportSubModule = async (data) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportSubModules`, data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '新增子模块失败')
  }
}

/**
 * 更新子模块
 * @param {number} subId
 * @param {Object} data - { name, desc }
 * @returns {Promise}
 */
export const updateReportSubModule = async (subId, data) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportSubModules/${subId}`, data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新子模块失败')
  }
}

/**
 * 删除子模块
 * @param {number} subId
 * @returns {Promise}
 */
export const deleteReportSubModule = async (subId) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportSubModules/${subId}/delete`)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除子模块失败')
  }
}

/**
 * 更新子模块排序
 * @param {Array} sortData - [{ id, order }]
 * @returns {Promise}
 */
export const updateSubModuleSortOrder = async (sortData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/reportSubModules/sort`, sortData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新子模块排序失败')
  }
}

// ============================================================
//  系统配置接口
// ============================================================

/**
 * 获取综述填写开关状态
 * @returns {Promise<{enabled: boolean}>}
 */
export const getSummaryFillerConfig = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/systemConfig/summaryFiller`)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取综述填写开关失败')
  }
}

/**
 * 设置综述填写开关状态
 * @param {boolean} enabled
 * @returns {Promise}
 */
export const updateSummaryFillerConfig = async (enabled) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/systemConfig/summaryFiller`, { enabled })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '设置综述填写开关失败')
  }
}
