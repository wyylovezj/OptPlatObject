import { ref, computed } from 'vue'
import { getWeekDateRanges } from '@/api/weeklyReportApi'

// 运维模块列表（全局共享）
export const reportModules = ref([])

// 服务端当前周次（由 API 获取，避免用户修改本地时间绕过限制）
export const serverCurrentWeek = ref(0)

// 当前周次（ISO 周数），优先使用服务端返回的值
export const currentWeek = computed(() => {
  if (serverCurrentWeek.value > 0) return serverCurrentWeek.value
  const now = new Date()
  const startOfYear = new Date(now.getFullYear(), 0, 1)
  const days = Math.floor((now - startOfYear) / (24 * 60 * 60 * 1000))
  return Math.ceil((days + startOfYear.getDay() + 1) / 7)
})

/**
 * @deprecated 请使用 currentWeek (computed ref) 替代
 */
export const getCurrentWeek = () => currentWeek.value

// 自定义周配置映射（weekNum -> { startDate, endDate } 日期字符串 YYYY-MM-DD）
export const weekConfigMap = ref({})

// 后端有效周范围映射（weekNum -> { startDate, endDate } 日期字符串 YYYY-MM-DD）
export const weekDateRangesMap = ref({})

// 是否已从后端获取有效周范围
export const weekDateRangesLoaded = ref(false)

// 综述填写开关（控制填写页是否显示综述区域）
export const summaryFillerEnabled = ref(true)

// 从后端获取有效周范围并缓存
export const fetchWeekDateRanges = async (year) => {
  try {
    const ranges = await getWeekDateRanges(year)
    const map = {}
    ranges.forEach(item => {
      map[item.weekNum] = { startDate: item.startDate, endDate: item.endDate }
    })
    weekDateRangesMap.value = map
    weekDateRangesLoaded.value = true
  } catch (e) {
    console.warn('获取有效周范围失败，将使用ISO周计算:', e)
    weekDateRangesLoaded.value = false
  }
}

// 设置自定义周配置
export const setWeekConfig = (weekNum, startDate, endDate) => {
  weekConfigMap.value[weekNum] = { startDate, endDate }
}

// 清除自定义周配置
export const clearWeekConfigMap = (weekNum) => {
  delete weekConfigMap.value[weekNum]
}

// 根据周次获取周一和周日日期
// 优先级：自定义配置 > 后端有效周范围 > ISO周计算
export const getWeekDateRange = (year, weekNum) => {
  // 1. 优先检查自定义配置
  const custom = weekConfigMap.value[weekNum]
  if (custom && custom.startDate && custom.endDate) {
    const monday = new Date(custom.startDate)
    const sunday = new Date(custom.endDate)
    return { monday, sunday }
  }

  // 2. 检查后端有效周范围（节假日感知）
  const effective = weekDateRangesMap.value[weekNum]
  if (effective && effective.startDate && effective.endDate) {
    const monday = new Date(effective.startDate)
    const sunday = new Date(effective.endDate)
    return { monday, sunday }
  }

  // 3. 回退：ISO 周计算
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
