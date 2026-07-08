import { ref } from 'vue'

// 运维模块列表（全局共享）
export const reportModules = ref([])

// 当前周次（ISO 周数）
export const getCurrentWeek = () => {
  const now = new Date()
  const startOfYear = new Date(now.getFullYear(), 0, 1)
  const days = Math.floor((now - startOfYear) / (24 * 60 * 60 * 1000))
  return Math.ceil((days + startOfYear.getDay() + 1) / 7)
}

// 自定义周配置映射（weekNum -> { startDate, endDate } 日期字符串 YYYY-MM-DD）
export const weekConfigMap = ref({})

// 设置自定义周配置
export const setWeekConfig = (weekNum, startDate, endDate) => {
  weekConfigMap.value[weekNum] = { startDate, endDate }
}

// 清除自定义周配置
export const clearWeekConfigMap = (weekNum) => {
  delete weekConfigMap.value[weekNum]
}

// 根据周次获取周一和周日日期（优先使用自定义配置）
export const getWeekDateRange = (year, weekNum) => {
  // 优先检查自定义配置
  const custom = weekConfigMap.value[weekNum]
  if (custom && custom.startDate && custom.endDate) {
    const monday = new Date(custom.startDate)
    const sunday = new Date(custom.endDate)
    return { monday, sunday }
  }
  // ISO 周：第1周是包含1月4日的那一周
  const jan4 = new Date(year, 0, 4)
  const dow = jan4.getDay() || 7 // 周一=1，周日=7
  const monday = new Date(jan4)
  monday.setDate(jan4.getDate() - dow + 1 + (weekNum - 1) * 7)
  const sunday = new Date(monday)
  sunday.setDate(monday.getDate() + 6)
  return { monday, sunday }
}

// 格式化日期为 MM-DD
export const fmtDate = (date) => {
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${m}-${d}`
}

// 格式化日期为 M月D日
export const fmtDateCN = (date) => {
  return `${date.getMonth() + 1}月${date.getDate()}日`
}

// 格式化日期为 YYYY-MM-DD
export const fmtDateFull = (date) => {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

// 模块颜色选项
export const moduleColorOptions = [
  '#2563eb', '#7c3aed', '#0891b2', '#16a34a',
  '#f59e0b', '#dc2626', '#ec4899', '#64748b'
]

// 模块类别选项
export const moduleCategories = ['基础设施', '平台服务', '业务系统', '安全管理', '其他']
