import { RBAC_IP } from '@/utils/dutyPageData.js'
import axios from 'axios'



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
 * 获取跑批人员
 * @returns {Promise} - 返回跑批人员数组
 */
export const getBatch = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/getBatch`)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取跑批人员失败')
  }
}

/**
 * 获取运维服务台人员
 * @returns {Promise} - 返回运维服务台人员数组
 */
export const getService = async () => {
  try {
    const response = await axios.get(`${RBAC_IP.value}/getService`)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取运维服务台人员失败')
  }
}

/**
 * 新增排班
 * @param {Object} dutyData - 排班数据
 * @returns {Promise} - 返回响应数据
 */
/**
 * 更新排班
 * @param {Object} dutyData - 排班数据对象 { schedule_date, ecc_day_personnel_id, ecc_night_personnel_id, sys_ops_personnel_id, net_ops_personnel_id, pm_personnel_id }
 * @returns {Promise} - 返回响应数据
 */
export const updateDuty = async (dutyData) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/updateDuty`, dutyData)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新排班失败')
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

/**
 * 获取指定月份的排班数据
 * @param {Array} dateRange - 日期范围数组 [开始日期, 结束日期], 格式: ['2026-05-01', '2026-05-31']
 * @returns {Promise} - 返回排班数据
 */
export const getDuty = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/getDuty`, dateRange)
    console.log('getMonthDuty', response.data.data)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取月度排班数据失败')
  }
}

/**
 * 保存交接班记录（含系统运行状态、待跟进事项、附件子表）
 * @param {Object} handoverData - 交接班完整数据
 * @param {string} handoverData.date - 排班日期 YYYY-MM-DD
 * @param {number} handoverData.personnelType - 值班类型 1-ECC,2-系统运维,3-网络运维,4-甲方PM
 * @param {number} handoverData.shiftType - 交班类型 1-白→夜,2-夜→白,3-同组交接
 * @param {string} handoverData.fromName - 交班人姓名
 * @param {string} handoverData.toName - 接班人姓名
 * @param {string} handoverData.handoverTime - 交接时间 YYYY-MM-DD HH:mm
 * @param {string} handoverData.statusClass - 'pending'|'completed'
 * @param {string} [handoverData.confirmTime] - 确认时间
 * @param {Array} handoverData.systemStatus - 系统运行状态数组 [{text, level}]
 * @param {Array} handoverData.todoItems - 待跟进事项数组 [{text, level, attachments}]
 * @param {File[]} [files] - 附件原始文件数组，存在时使用 FormData 上传
 * @returns {Promise} - 返回响应数据
 */
export const saveHandover = async (handoverData, files = []) => {
  try {
    const formData = new FormData()
    formData.append('handoverData', JSON.stringify(handoverData))
    files.forEach((file) => {
      formData.append('files', file, file.name)
    })
    const response = await axios.post(`${RBAC_IP.value}/saveHandover`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    console.log('saveHandover', response.data)
    const res = response.data
    if (res.status === 'fail') {
      throw new Error(res.message || '保存交接班记录失败')
    }
    return res
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '保存交接班记录失败')
  }
}

/**
 * 获取交接班记录列表
 * @param {Object} [params] - 筛选参数
 * @param {string} [params.date] - 排班日期 YYYY-MM-DD
 * @param {number} [params.personnelType] - 值班类型 1-ECC,2-系统运维,3-网络运维,4-甲方PM
 * @param {number} [params.status] - 状态 0-待确认,1-已完成
 * @param {string} [params.startDate] - 开始日期范围 YYYY-MM-DD
 * @param {string} [params.endDate] - 结束日期范围 YYYY-MM-DD
 * @returns {Promise<Array>} - 返回交接班记录数组，每条记录含 systemStatus、todoItems、attachments 子数组
 */
export const getHandovers = async (params = {}) => {
  try {
    console.log('getHandovers', params)
    const response = await axios.post(`${RBAC_IP.value}/getHandover`, params)
    console.log('getHandovers', response.data.data)
    return response.data.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取交接班记录失败')
  }
}

/**
 * 删除交接班记录
 * @param {number|string} handoverId - 交接班记录 ID
 * @returns {Promise} - 返回响应数据
 */
/**
 * 确认交接班记录
 * @param {string} handoverId - 交接班记录 ID
 * @returns {Promise} - 返回响应数据
 */
export const confirmHandovers = async (handoverId) => {
  try {
    console.log('confirmHandovers', handoverId)
    const response = await axios.post(`${RBAC_IP.value}/confirmHandover`, { handover_id: handoverId })
    const res = response.data
    if (res.status === 'fail') {
      throw new Error(res.message || '确认交接班记录失败')
    }
    return res
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '确认交接班记录失败')
  }
}

/**
 * 删除交接班记录
 * @param {number|string} handoverId - 交接班记录 ID
 * @returns {Promise} - 返回响应数据
 */
export const deleteHandover = async (handoverId) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/deleteHandover`, { handover_id: handoverId })
    const res = response.data
    if (res.status === 'fail') {
      throw new Error(res.message || '删除交接班记录失败')
    }
    return res
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '删除交接班记录失败')
  }
}

/**
 * 保存值班日志
 * @param {Object} logData - 日志完整数据
 * @param {string} logData.log_id - 业务唯一标识 YYYYMMDDHHmmss
 * @param {string} logData.log_date - 日志日期 YYYY-MM-DD
 * @param {string} logData.log_time - 日志时间 HH:mm:ss
 * @param {number} logData.dot_class - 事件级别 0-普通,1-正常,2-警告,3-危险
 * @param {string} logData.title - 事件标题
 * @param {string} [logData.description] - 详细描述
 * @param {string} [logData.personnel_id] - 录入人 user_code
 * @param {number} logData.status - 状态 0-草稿,1-已保存,2-已确认
 * @param {number} logData.sort_order - 排序号
 * @param {Array} [logData.tags] - 标签数组 [{tag_text, tag_class, sort_order}]
 * @param {Array} [logData.attachments] - 附件数组 [{file_name, file_size, content_type, sort_order}]
 * @param {File[]} [files] - 附件原始文件数组，存在时使用 FormData 上传
 * @returns {Promise} - 返回响应数据
 */
export const saveDutyLog = async (logData, files = []) => {
  try {
    let requestData
    let config = {}

    if (files.length > 0) {
      const formData = new FormData()
      formData.append('logData', JSON.stringify(logData))
      files.forEach((file) => {
        formData.append('files', file, file.name)
      })
      requestData = formData
      config = { headers: { 'Content-Type': 'multipart/form-data' } }
    } else {
      requestData = logData
    }

    console.log('saveDutyLog', requestData)
    const response = await axios.post(`${RBAC_IP.value}/saveDutyLog`, requestData, config)
    console.log('saveDutyLogResponse', response.data)
    const res = response.data
    if (res.status === 'fail') {
      throw new Error(res.message || '保存值班日志失败')
    }
    return res
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '保存值班日志失败')
  }
}

/**
 * 获取指定日期的值班日志列表
 * @param {string} logDate - 日志日期，格式 YYYY-MM-DD
 * @returns {Promise<Array>} - 返回日志数组，每条记录含 tags、attachments 子数组
 */
export const getDutyLogs = async (logDate) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/getDutyLogs`, { log_date: logDate })
    console.log('getDutyLogs', response.data)
    const raw = response.data
    if (Array.isArray(raw)) {
      // 如果第一个元素有 data 字段（嵌套格式），展平
      if (raw.length > 0 && raw[0].data && Array.isArray(raw[0].data)) {
        const allLogs = []
        raw.forEach(item => {
          if (item.data && Array.isArray(item.data)) {
            allLogs.push(...item.data)
          }
        })
        return allLogs
      }
      // 否则直接返回（后端返回直接数组格式）
      return raw
    }
    // 兼容单个对象包在 data 里的情况
    if (raw && raw.data && Array.isArray(raw.data)) {
      return raw.data
    }
    return []
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取值班日志失败')
  }
}

/**
 * 删除值班日志
 * @param {string} logId - 日志唯一标识 YYYYMMDDHHmmss
 * @returns {Promise} - 返回响应数据
 */
export const deleteDutyLog = async (logId) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/deleteDutyLog`, { log_id: logId })
    const res = response.data
    console.log('deleteDutyLog', res)
    if (res.status === 'fail') {
      throw new Error(res.message || '删除值班日志失败')
    }
    return res
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '删除值班日志失败')
  }
}

/**
 * 确认值班日志
 * @param {string} logId - 日志唯一标识 YYYYMMDDHHmmss
 * @returns {Promise} - 返回响应数据
 */
export const confirmDutyLog = async (logId) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/confirmDutyLog`, { log_id: logId })
    const res = response.data
    if (res.status === 'fail') {
      throw new Error(res.message || '确认值班日志失败')
    }
    return res
  } catch (error) {
    throw new Error(error.response?.data?.message || error.message || '确认值班日志失败')
  }
}

/**
 * 保存值班备注（支持批量）
 * @param {Array} notesData - 备注数据数组，每项包含 note_id, note_date, description, level, sort_order
 * @returns {Promise} - 返回响应数据
 */
export const saveNotes = async (notesData) => {
  try {
    console.log('saveNotes', notesData)
    const response = await axios.post(`${RBAC_IP.value}/saveNotes`, { notes: notesData })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存值班备注失败')
  }
}

/**
 * 获取指定日期的值班备注
 * @param {string} noteDate - 备注日期，格式 YYYY-MM-DD
 * @returns {Promise<Array>} - 返回备注数组，每项含 note_id, note_date, description, level, sort_order
 */
export const getNotes = async (noteDate) => {
  try {
    console.log('getNotes', noteDate)
    const response = await axios.post(`${RBAC_IP.value}/getNotes`, { note_date: noteDate })
    console.log('getNotes', response.data)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取值班备注失败')
  }
}

// ===================== 日常工作交接（动态表格）接口 =====================

/**
 * 获取字段列配置列表
 * @returns {Promise<{status: string, data: Array}>} - 返回字段配置数组
 */
export const getDailyHandoverFieldConfig = async () => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/getDailyHandoverFieldConfig`)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取字段配置失败')
  }
}

/**
 * 批量同步字段配置（全量覆盖）
 * @param {Array} configs - 字段配置数组 [{field_key, field_label, is_visible, sort_order, is_system}]
 * @returns {Promise<{status: string, message: string}>}
 */
export const saveDailyHandoverFieldConfig = async (configs) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/saveDailyHandoverFieldConfig`, { configs })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存字段配置失败')
  }
}

/**
 * 新增自定义字段
 * @param {string} fieldKey - 字段标识
 * @param {string} fieldLabel - 显示名称
 * @returns {Promise<{status: string, message: string, data: Object}>}
 */
export const addDailyHandoverField = async (fieldKey, fieldLabel) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/addDailyHandoverField`, {
      field_key: fieldKey,
      field_label: fieldLabel,
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '新增字段失败')
  }
}

/**
 * 删除自定义字段
 * @param {string} fieldKey - 字段标识
 * @returns {Promise<{status: string, message: string}>}
 */
export const deleteDailyHandoverField = async (fieldKey) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/deleteDailyHandoverField`, {
      field_key: fieldKey,
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除字段失败')
  }
}

/**
 * 保存日常工作交接数据（批量 upsert）
 * @param {Array} records - 记录数组，每条含 handover_date, shift_type, duty_person, remark1, items
 * @returns {Promise<{status: string, message: string}>}
 */
/**
 * 更新字段显示名称
 * @param {string} fieldKey - 字段标识
 * @param {string} fieldLabel - 新的显示名称
 * @returns {Promise<{status: string, message: string}>}
 */
export const updateDailyHandoverFieldLabel = async (fieldKey, fieldLabel) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/updateDailyHandoverFieldLabel`, {
      field_key: fieldKey,
      field_label: fieldLabel,
    })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新字段名称失败')
  }
}

/**
 * 批量更新字段排序号（交换 sort_order）
 * @param {Array} orders - 排序数据数组 [{field_key, sort_order}, ...]
 * @returns {Promise<{status: string, message: string}>}
 */
export const updateDailyHandoverFieldSortOrder = async (orders) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/updateDailyHandoverFieldSortOrder`, { orders })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '更新字段排序失败')
  }
}

export const saveDailyHandoverData = async (records) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/saveDailyHandoverData`, { records })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '保存日常交接数据失败')
  }
}

/**
 * 按日期范围查询日常工作交接数据
 * @param {Array} dateRange - [开始日期, 结束日期] 格式 ['YYYY-MM-DD', 'YYYY-MM-DD']
 * @returns {Promise<{status: string, data: Array}>} - 返回含 items 子数组的记录列表
 */
export const getDailyHandoverData = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/getDailyHandoverData`, { dateRange })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '获取日常交接数据失败')
  }
}

/**
 * 按日期查询ECC排班（白班/夜班值班人姓名）
 * @param {string} dateStr - 日期 YYYY-MM-DD
 * @returns {Promise<{status: string, data: {eccDayName: string|null, eccNightName: string|null}}>}
 */
export const getEccScheduleByDate = async (dateStr) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/getEccScheduleByDate`, { date: dateStr })
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '查询ECC排班失败')
  }
}

/**
 * 删除某天的日常交接记录
 * @param {string} handoverDate - 日期 YYYY-MM-DD
 * @param {number} [shiftType] - 班次类型 1-白班 2-夜班，不传则删除该天所有记录
 * @returns {Promise<{status: string, message: string}>}
 */
/**
 * 按日期范围导出日常交接数据为 Excel
 * @param {Array} dateRange - [开始日期, 结束日期] 格式 ['YYYY-MM-DD', 'YYYY-MM-DD']
 * @returns {Promise<Blob>} - 返回文件 Blob
 */
export const exportDailyHandover = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/exportDailyHandover`, { dateRange }, {
      responseType: 'blob',
    })
    return response
  } catch (error) {
    throw new Error(error.response?.data?.message || '导出日常交接数据失败')
  }
}

/**
 * 按日期范围导出ECC交接班记录为 Excel
 * @param {Array} dateRange - [开始日期, 结束日期] 格式 ['YYYY-MM-DD', 'YYYY-MM-DD']
 * @returns {Promise<Blob>} - 返回文件 Blob
 */
export const exportHandoverExcel = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/exportHandoverExcel`, { dateRange }, {
      responseType: 'blob',
    })
    return response
  } catch (error) {
    throw new Error(error.response?.data?.message || '导出ECC交接班记录失败')
  }
}

/**
 * 按日期范围合并导出ECC交接班记录和日常交接数据到同一个Excel
 * @param {Array} dateRange - [开始日期, 结束日期] 格式 ['YYYY-MM-DD', 'YYYY-MM-DD']
 * @returns {Promise<Blob>} - 返回文件 Blob（交接记录sheet1 + 工作内容sheet2）
 */
export const exportMergedHandover = async (dateRange) => {
  try {
    const response = await axios.post(`${RBAC_IP.value}/mergeExportDailyHandover`, { dateRange }, {
      responseType: 'blob',
    })
    return response
  } catch (error) {
    throw new Error(error.response?.data?.message || '合并导出失败')
  }
}

export const deleteDailyHandoverRecord = async (handoverDate, shiftType) => {
  try {
    const params = { handover_date: handoverDate }
    if (shiftType !== undefined && shiftType !== null) {
      params.shift_type = shiftType
    }
    const response = await axios.post(`${RBAC_IP.value}/deleteDailyHandoverRecord`, params)
    return response.data
  } catch (error) {
    throw new Error(error.response?.data?.message || '删除日常交接记录失败')
  }
}



