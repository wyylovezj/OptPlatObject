import { ref, computed } from 'vue'
import { getWeekDateRanges, getServerCurrentWeek } from '@/api/weeklyReportApi'

// 运维模块列表（全局共享）
export const reportModules = ref([])

// 服务端当前周次（由 API 获取，避免用户修改本地时间绕过限制）
// 服务端返回的是“有效周周次”（节假日感知）：被合并吸收的 ISO 周会归入吸收它的周次
export const serverCurrentWeek = ref(0)

// 服务端当前年份
export const serverCurrentYear = ref(0)

// 被节假日合并吸收的 ISO 周（weekNum -> 归属的有效周 weekNum）
// 这类周不独立成周，其日期已归入前一短周（如 2026 年第 41 周并入第 40 周 9/28~10/10）
export const weekAbsorbedMap = ref({})

// 当前周次（有效周周次），优先使用服务端返回的值
// 若使用的周次已被节假日合并吸收（如服务端不可用时回退的本地 ISO 周），则归到吸收它的有效周
export const currentWeek = computed(() => {
  let weekNum
  if (serverCurrentWeek.value > 0) {
    weekNum = serverCurrentWeek.value
  } else {
    const now = new Date()
    const startOfYear = new Date(now.getFullYear(), 0, 1)
    const days = Math.floor((now - startOfYear) / (24 * 60 * 60 * 1000))
    weekNum = Math.ceil((days + startOfYear.getDay() + 1) / 7)
  }
  return weekAbsorbedMap.value[weekNum] || weekNum
})

// 当前年份，优先使用服务端返回的值
export const currentYear = computed(() => serverCurrentYear.value || new Date().getFullYear())

// 拉取服务端当前周次与年份（失败时保留本地时间兜底）
export const fetchServerCurrentWeek = async () => {
  try {
    const sw = await getServerCurrentWeek()
    if (sw.code === 200) {
      serverCurrentWeek.value = sw.weekNum
      if (sw.year) serverCurrentYear.value = sw.year
    }
    return sw
  } catch (e) {
    console.warn('获取服务端当前周次失败，将使用本地时间计算:', e)
    return null
  }
}

/**
 * @deprecated 请直接使用响应式的 currentWeek (computed ref)，
 * 在 setup 中快照取值会在服务端周次返回前固定为本地 ISO 周，导致节假日合并周的“本周”显示错误
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
    const res = await getWeekDateRanges(year)
    const map = {}
    ;(res.ranges || []).forEach(item => {
      map[item.weekNum] = { startDate: item.startDate, endDate: item.endDate }
    })
    weekDateRangesMap.value = map
    const abMap = {}
    ;(res.absorbed || []).forEach(item => {
      abMap[item.weekNum] = item.mergedInto
    })
    weekAbsorbedMap.value = abMap
    weekDateRangesLoaded.value = true
  } catch (e) {
    console.warn('获取有效周范围失败，将使用ISO周计算:', e)
    weekDateRangesLoaded.value = false
  }
}

// 该周次是否被合并吸收到上一个有效周（不独立成周）
export const isAbsorbedWeek = (weekNum) => !!weekAbsorbedMap.value[weekNum]

// 被合并吸收时返回归属的有效周周次，否则返回 0
export const getMergedIntoWeek = (weekNum) => weekAbsorbedMap.value[weekNum] || 0

// 上一个有效周（跳过被合并吸收、不独立成周的周次），无则返回 0
export const getPrevEffectiveWeek = (weekNum) => {
  let w = weekNum - 1
  while (w >= 1 && weekAbsorbedMap.value[w]) w--
  return w >= 1 ? w : 0
}

// 设置自定义周配置
export const setWeekConfig = (weekNum, startDate, endDate) => {
  weekConfigMap.value[weekNum] = { startDate, endDate }
}

// 清除自定义周配置
export const clearWeekConfigMap = (weekNum) => {
  delete weekConfigMap.value[weekNum]
}

// 根据周次获取起始日与结束日
// 优先级：自定义配置 > 后端有效周范围（节假日感知）> ISO周计算
// 被合并吸收的周沿用其归属有效周的范围，避免出现与邻周重叠的日期
export const getWeekDateRange = (year, weekNum) => {
  // 1. 优先检查自定义配置
  const custom = weekConfigMap.value[weekNum]
  if (custom && custom.startDate && custom.endDate) {
    const monday = new Date(custom.startDate)
    const sunday = new Date(custom.endDate)
    return { monday, sunday }
  }

  // 2. 检查后端有效周范围（节假日感知）
  let effective = weekDateRangesMap.value[weekNum]
  if (!effective && weekAbsorbedMap.value[weekNum]) {
    effective = weekDateRangesMap.value[weekAbsorbedMap.value[weekNum]]
  }
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
